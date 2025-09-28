//
//  DataManager.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

/// Manages SwiftData operations with cache-first offline strategy
@MainActor
@Observable
public class DataManager {
    // MARK: - Singleton
    private static var sharedInstance: DataManager?

    private let modelContext: ModelContext
    private let riotClient: RiotClient
    private let dataDragonService: DataDragonServiceProtocol

    // Extracted components
    private let matchParser: MatchParser
    private let championDataLoader: ChampionDataLoader
    private let baselineDataLoader: BaselineDataLoader

    // Cache limits
    private let maxMatchesPerSummoner = 100  // Increased from 50 to 100
    private let maxGameAgeInDays = 365  // Filter out games older than 1 year

    // Request deduplication - unified generic system
    private var activeRequests: Set<String> = []
    private var requestTasks: [String: Any] = [:]

    public var isLoading = false
    public var lastRefreshTime: Date?
    public var errorMessage: String?

    private init(
        modelContext: ModelContext, riotClient: RiotClient,
        dataDragonService: DataDragonServiceProtocol
    ) {
        self.modelContext = modelContext
        self.riotClient = riotClient
        self.dataDragonService = dataDragonService

        // Initialize extracted components
        self.matchParser = MatchParser(modelContext: modelContext)
        self.championDataLoader = ChampionDataLoader(
            modelContext: modelContext, dataDragonService: dataDragonService)
        self.baselineDataLoader = BaselineDataLoader(modelContext: modelContext)
    }

    /// Gets the shared DataManager instance, creating it if needed
    /// Ensures all views use the same instance for proper request deduplication
    public static func shared(with modelContext: ModelContext) -> DataManager {
        if let existing = sharedInstance {
            return existing
        }

        let instance = DataManager(
            modelContext: modelContext,
            riotClient: RiotProxyClient(),
            dataDragonService: DataDragonService()
        )

        sharedInstance = instance
        return instance
    }

    /// Factory method to create DataManager with default dependencies (deprecated - use shared instead)
    /// Eliminates boilerplate by providing standard RiotClient and DataDragonService instances
    @available(
        *, deprecated,
        message: "Use DataManager.shared(with:) instead to prevent multiple instances"
    )
    public static func create(with modelContext: ModelContext) -> DataManager {
        return shared(with: modelContext)
    }

    // MARK: - Request Deduplication Helper

    /// Generic helper for request deduplication
    /// Eliminates code duplication across different request types
    private func deduplicateRequest<T>(
        key: String,
        operation: @escaping @MainActor () async -> UIState<T>
    ) async -> UIState<T> {
        // Check if request is already in progress
        if let existingTask = requestTasks[key] as? Task<UIState<T>, Never> {
            ClaimbLogger.debug(
                "Request already in progress, waiting for result", service: "DataManager",
                metadata: ["requestKey": key])
            return await existingTask.value
        }

        // Create new task
        let task = Task<UIState<T>, Never> { @MainActor in
            defer {
                // Clean up when task completes
                requestTasks.removeValue(forKey: key)
                activeRequests.remove(key)
            }

            activeRequests.insert(key)
            return await operation()
        }

        requestTasks[key] = task
        return await task.value
    }

    /// Internal deduplication helper for methods that don't return UIState
    private func deduplicateRequestInternal<T>(
        key: String,
        operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        // Check if request is already in progress
        if let existingTask = requestTasks[key] as? Task<T, Error> {
            ClaimbLogger.debug(
                "Request already in progress, waiting for result", service: "DataManager",
                metadata: ["requestKey": key])
            return try await existingTask.value
        }

        // Create new task
        let task = Task<T, Error> { @MainActor in
            defer {
                // Clean up when task completes
                requestTasks.removeValue(forKey: key)
                activeRequests.remove(key)
            }

            activeRequests.insert(key)
            return try await operation()
        }

        requestTasks[key] = task
        return try await task.value
    }

    // MARK: - Summoner Management

    /// Creates or updates a summoner with account data
    public func createOrUpdateSummonerInternal(gameName: String, tagLine: String, region: String)
        async throws -> Summoner
    {
        ClaimbLogger.info(
            "Creating/updating summoner", service: "DataManager",
            metadata: [
                "gameName": gameName,
                "tagLine": tagLine,
                "region": region,
            ])

        // Get account data from Riot API
        let accountResponse = try await riotClient.getAccountByRiotId(
            gameName: gameName,
            tagLine: tagLine,
            region: region
        )

        // Check if summoner already exists
        let existingSummoner = try await getSummoner(by: accountResponse.puuid)

        if let existing = existingSummoner {
            ClaimbLogger.debug("Updating existing summoner", service: "DataManager")
            existing.gameName = gameName
            existing.tagLine = tagLine
            existing.region = region
            existing.lastUpdated = Date()

            // Get updated summoner data
            let summonerResponse = try await riotClient.getSummonerByPuuid(
                puuid: accountResponse.puuid,
                region: region
            )

            existing.summonerId = summonerResponse.id
            existing.accountId = summonerResponse.accountId
            existing.profileIconId = summonerResponse.profileIconId
            existing.summonerLevel = summonerResponse.summonerLevel

            try modelContext.save()
            return existing
        } else {
            ClaimbLogger.debug("Creating new summoner", service: "DataManager")
            let newSummoner = Summoner(
                puuid: accountResponse.puuid,
                gameName: gameName,
                tagLine: tagLine,
                region: region
            )

            // Get summoner data
            let summonerResponse = try await riotClient.getSummonerByPuuid(
                puuid: accountResponse.puuid,
                region: region
            )

            newSummoner.summonerId = summonerResponse.id
            newSummoner.accountId = summonerResponse.accountId
            newSummoner.profileIconId = summonerResponse.profileIconId
            newSummoner.summonerLevel = summonerResponse.summonerLevel

            modelContext.insert(newSummoner)
            try modelContext.save()
            return newSummoner
        }
    }

    /// Gets a summoner by PUUID
    public func getSummoner(by puuid: String) async throws -> Summoner? {
        let descriptor = FetchDescriptor<Summoner>(
            predicate: #Predicate { $0.puuid == puuid }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets all summoners
    public func getAllSummoners() async throws -> [Summoner] {
        let descriptor = FetchDescriptor<Summoner>()
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Match Management

    /// Forces a refresh of matches (bypasses cache)
    public func forceRefreshMatches(for summoner: Summoner) async -> UIState<[Match]> {
        ClaimbLogger.info(
            "Force refreshing matches", service: "DataManager",
            metadata: ["summoner": summoner.gameName])

        do {
            try await refreshMatchesInternal(for: summoner)
            let refreshedMatches = try await getMatches(for: summoner)
            return .loaded(refreshedMatches)
        } catch {
            // If force refresh fails due to network, fall back to cached data
            ClaimbLogger.warning(
                "Force refresh failed, falling back to cached data", service: "DataManager",
                metadata: [
                    "error": error.localizedDescription,
                    "summoner": summoner.gameName,
                ])

            do {
                let cachedMatches = try await getMatches(for: summoner)
                if !cachedMatches.isEmpty {
                    ClaimbLogger.info(
                        "Using cached matches as fallback", service: "DataManager",
                        metadata: ["cachedCount": String(cachedMatches.count)])
                    return .loaded(cachedMatches)
                } else {
                    ClaimbLogger.error(
                        "No cached data available and network failed", service: "DataManager",
                        error: error)
                    return .error(error)
                }
            } catch {
                ClaimbLogger.error(
                    "Failed to load cached matches", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Refreshes match data for a summoner with efficient incremental fetching
    public func refreshMatchesInternal(for summoner: Summoner) async throws {
        let requestKey = "refresh_matches_\(summoner.puuid)"

        // Use deduplication to prevent concurrent refresh requests
        return try await deduplicateRequestInternal(key: requestKey) {
            self.isLoading = true
            self.errorMessage = nil

            do {
                // Ensure baseline data is loaded
                _ = await self.loadBaselineData()
                // Get existing matches to determine how many new ones to fetch
                let existingMatches = try await self.getMatches(for: summoner)
                let existingMatchIds = Set(existingMatches.map { $0.matchId })

                // Efficient incremental fetching strategy
                let targetCount = self.maxMatchesPerSummoner
                let currentCount = existingMatches.count

                // Only fetch if we're below target or if matches are very old
                guard currentCount < targetCount else {
                    ClaimbLogger.debug(
                        "Already at target match count, skipping refresh", service: "DataManager",
                        metadata: [
                            "currentCount": String(currentCount),
                            "targetCount": String(targetCount),
                        ])
                    return
                }

                // Calculate how many new matches to fetch
                let neededMatches = targetCount - currentCount
                let fetchCount = min(neededMatches, 20)  // Conservative: fetch max 20 new matches per refresh

                ClaimbLogger.debug(
                    "Incremental fetch: need \(neededMatches), fetching \(fetchCount) new matches",
                    service: "DataManager",
                    metadata: [
                        "currentCount": String(currentCount),
                        "neededMatches": String(neededMatches),
                        "fetchCount": String(fetchCount),
                    ]
                )

                let matchHistory = try await self.riotClient.getMatchHistory(
                    puuid: summoner.puuid,
                    region: summoner.region,
                    count: fetchCount
                )

                var newMatchesCount = 0
                var skippedMatchesCount = 0
                for matchId in matchHistory.history {
                    // Skip if we already have this match
                    if existingMatchIds.contains(matchId) {
                        continue
                    }

                    do {
                        try await self.processMatch(
                            matchId: matchId, region: summoner.region, summoner: summoner)
                        newMatchesCount += 1
                    } catch MatchFilterError.irrelevantMatch {
                        skippedMatchesCount += 1
                        // Continue processing other matches
                    }
                }

                ClaimbLogger.dataOperation(
                    "Added new matches", count: newMatchesCount, service: "DataManager")

                if skippedMatchesCount > 0 {
                    ClaimbLogger.debug(
                        "Skipped irrelevant matches", service: "DataManager",
                        metadata: [
                            "skippedCount": String(skippedMatchesCount),
                            "addedCount": String(newMatchesCount),
                        ])
                }

                try await self.cleanupOldMatches(for: summoner)
                summoner.lastUpdated = Date()
                self.lastRefreshTime = Date()
                try self.modelContext.save()

            } catch {
                self.errorMessage = "Failed to refresh matches: \(error.localizedDescription)"
                throw error
            }

            self.isLoading = false
        }
    }

    /// Loads initial match data for a summoner (bulk load for first time)
    public func loadInitialMatches(for summoner: Summoner) async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Load baseline data first if not already loaded
            _ = await loadBaselineData()

            ClaimbLogger.info(
                "Bulk loading initial matches", service: "DataManager",
                metadata: [
                    "gameName": summoner.gameName,
                    "count": "100",  // API limit is 100 matches per request
                ])

            // Bulk fetch: get maximum matches in one request
            let matchHistory = try await riotClient.getMatchHistory(
                puuid: summoner.puuid,
                region: summoner.region,
                count: 100  // API limit: maximum 100 matches per request
            )

            var addedMatchesCount = 0
            var skippedMatchesCount = 0
            for matchId in matchHistory.history {
                do {
                    try await processMatch(
                        matchId: matchId, region: summoner.region, summoner: summoner)
                    addedMatchesCount += 1
                } catch MatchFilterError.irrelevantMatch {
                    skippedMatchesCount += 1
                    // Continue processing other matches
                }
            }

            summoner.lastUpdated = Date()
            lastRefreshTime = Date()
            try modelContext.save()

            ClaimbLogger.dataOperation(
                "Bulk loaded initial matches", count: addedMatchesCount, service: "DataManager")

            if skippedMatchesCount > 0 {
                ClaimbLogger.debug(
                    "Skipped irrelevant matches during bulk load", service: "DataManager",
                    metadata: [
                        "skippedCount": String(skippedMatchesCount),
                        "addedCount": String(addedMatchesCount),
                    ])
            }

        } catch {
            errorMessage = "Failed to load initial matches: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    /// Processes a single match and stores it in the database
    private func processMatch(matchId: String, region: String, summoner: Summoner) async throws {
        // Check if match already exists
        let existingMatch = try await getMatch(by: matchId)
        if existingMatch != nil {
            ClaimbLogger.cache(
                "Match already exists, skipping", key: matchId, service: "DataManager")
            return
        }

        ClaimbLogger.apiRequest("match/\(matchId)", service: "DataManager")

        do {
            let matchData = try await riotClient.getMatch(matchId: matchId, region: region)
            ClaimbLogger.debug(
                "Received match data", service: "DataManager",
                metadata: [
                    "matchId": matchId,
                    "bytes": String(matchData.count),
                ])

            do {
                let match = try await matchParser.parseMatchData(
                    matchData, matchId: matchId, summoner: summoner)

                modelContext.insert(match)
                ClaimbLogger.debug(
                    "Inserted match \(matchId) with \(match.participants.count) participants",
                    service: "DataManager",
                    metadata: [
                        "matchId": matchId,
                        "participantCount": String(match.participants.count),
                    ]
                )
            } catch MatchFilterError.irrelevantMatch {
                // Skip irrelevant matches silently - this is expected behavior
                ClaimbLogger.debug(
                    "Skipped irrelevant match", service: "DataManager",
                    metadata: ["matchId": matchId])
                throw MatchFilterError.irrelevantMatch
            }
        } catch RiotAPIError.serverError(let statusCode) where statusCode == 400 {
            // Handle 400 errors gracefully - match might be invalid or unavailable
            ClaimbLogger.warning(
                "Match unavailable (400 error), skipping", service: "DataManager",
                metadata: [
                    "matchId": matchId,
                    "statusCode": String(statusCode),
                ])
            throw MatchFilterError.irrelevantMatch
        } catch RiotAPIError.notFound {
            // Handle 404 errors gracefully - match not found
            ClaimbLogger.warning(
                "Match not found (404 error), skipping", service: "DataManager",
                metadata: ["matchId": matchId])
            throw MatchFilterError.irrelevantMatch
        } catch {
            // Log other errors but continue processing
            ClaimbLogger.error(
                "Failed to fetch match details, skipping", service: "DataManager",
                error: error,
                metadata: ["matchId": matchId])
            throw MatchFilterError.irrelevantMatch
        }
    }

    /// Gets a match by ID
    public func getMatch(by matchId: String) async throws -> Match? {
        let descriptor = FetchDescriptor<Match>(
            predicate: #Predicate { $0.matchId == matchId }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets matches for a summoner
    public func getMatches(for summoner: Summoner, limit: Int = 100) async throws -> [Match] {
        // For now, get all matches and filter manually to avoid SwiftData predicate issues
        let descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\.gameCreation, order: .reverse)]
        )
        let allMatches = try modelContext.fetch(descriptor)

        // Filter matches for this summoner and apply role analysis filter
        let filteredMatches = allMatches.filter { match in
            match.summoner?.puuid == summoner.puuid && match.isIncludedInRoleAnalysis
        }

        return Array(filteredMatches.prefix(limit))
    }

    /// Cleans up old matches to maintain the cache limit
    private func cleanupOldMatches(for summoner: Summoner) async throws {
        let allMatches = try await getMatches(for: summoner, limit: maxMatchesPerSummoner + 10)

        if allMatches.count > maxMatchesPerSummoner {
            let matchesToDelete = Array(allMatches.dropFirst(maxMatchesPerSummoner))
            for match in matchesToDelete {
                modelContext.delete(match)
            }
            ClaimbLogger.debug(
                "Cleaned up \(matchesToDelete.count) old matches",
                service: "DataManager",
                metadata: [
                    "deletedCount": String(matchesToDelete.count)
                ]
            )
        }
    }

    // MARK: - Champion Management (Delegated to ChampionDataLoader)
    // Note: Direct champion access methods removed - use championDataLoader directly if needed

    // MARK: - Cache Management

    /// Clears all cached data (for debugging/testing) - internal
    public func clearAllCacheInternal() async throws {
        ClaimbLogger.info("Starting cache clear...", service: "DataManager")

        // Clear matches and participants
        let matchDescriptor = FetchDescriptor<Match>()
        let allMatches = try modelContext.fetch(matchDescriptor)
        for match in allMatches {
            modelContext.delete(match)
        }

        let participantDescriptor = FetchDescriptor<Participant>()
        let allParticipants = try modelContext.fetch(participantDescriptor)
        for participant in allParticipants {
            modelContext.delete(participant)
        }

        // Reset summoner lastUpdated timestamps
        let summonerDescriptor = FetchDescriptor<Summoner>()
        let allSummoners = try modelContext.fetch(summonerDescriptor)
        for summoner in allSummoners {
            summoner.lastUpdated = Date.distantPast
        }

        // Clear baselines using BaselineDataLoader
        try await baselineDataLoader.clearBaselineData()

        // Champion class mappings are now loaded directly from JSON in Champion model

        try modelContext.save()

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Reset last refresh time
        lastRefreshTime = nil
        errorMessage = nil

        ClaimbLogger.info("Cache clear completed", service: "DataManager")
    }

    /// Clears only match data while preserving summoner and champion data
    public func clearMatchData() async throws {
        ClaimbLogger.info("Clearing match data...", service: "DataManager")

        // Clear matches and participants
        let matchDescriptor = FetchDescriptor<Match>()
        let allMatches = try modelContext.fetch(matchDescriptor)
        for match in allMatches {
            modelContext.delete(match)
        }

        let participantDescriptor = FetchDescriptor<Participant>()
        let allParticipants = try modelContext.fetch(participantDescriptor)
        for participant in allParticipants {
            modelContext.delete(participant)
        }

        // Reset summoner lastUpdated timestamps
        let summonerDescriptor = FetchDescriptor<Summoner>()
        let allSummoners = try modelContext.fetch(summonerDescriptor)
        for summoner in allSummoners {
            summoner.lastUpdated = Date.distantPast
        }

        try modelContext.save()

        // Reset last refresh time
        lastRefreshTime = nil
        errorMessage = nil

        ClaimbLogger.info("Match data cleared", service: "DataManager")
    }

    /// Clears URL cache only
    public func clearURLCache() {
        ClaimbLogger.info("Clearing URL cache...", service: "DataManager")
        URLCache.shared.removeAllCachedResponses()
        ClaimbLogger.info("URL cache cleared", service: "DataManager")
    }

    // MARK: - Statistics

    /// Gets match statistics for a summoner
    public func getMatchStatistics(for summoner: Summoner) async throws -> MatchStatistics {
        let matches = try await getMatches(for: summoner)

        let totalMatches = matches.count
        let wins = matches.filter { match in
            match.participants.contains { $0.puuid == summoner.puuid && $0.win }
        }.count

        let winRate = totalMatches > 0 ? Double(wins) / Double(totalMatches) : 0.0

        return MatchStatistics(
            totalMatches: totalMatches,
            wins: wins,
            losses: totalMatches - wins,
            winRate: winRate
        )
    }

    /// Gets match statistics with age filtering for a summoner
    public func getMatchStatisticsWithAgeFilter(for summoner: Summoner) async throws
        -> MatchStatisticsWithAge
    {
        let allMatches = try await getMatches(for: summoner, limit: 1000)  // Get more to analyze age distribution

        // Filter matches by age
        let oneYearAgo =
            Calendar.current.date(byAdding: .day, value: -maxGameAgeInDays, to: Date()) ?? Date()
        let recentMatches = allMatches.filter { match in
            let gameDate = Date(timeIntervalSince1970: TimeInterval(match.gameCreation) / 1000.0)
            return gameDate >= oneYearAgo
        }

        let totalMatches = recentMatches.count
        let wins = recentMatches.filter { match in
            match.participants.contains { $0.puuid == summoner.puuid && $0.win }
        }.count

        let winRate = totalMatches > 0 ? Double(wins) / Double(totalMatches) : 0.0

        // Calculate age distribution
        let oldMatchesCount = allMatches.count - recentMatches.count
        let oldestMatch = allMatches.last
        let newestMatch = allMatches.first

        return MatchStatisticsWithAge(
            totalMatches: totalMatches,
            wins: wins,
            losses: totalMatches - wins,
            winRate: winRate,
            oldMatchesFiltered: oldMatchesCount,
            oldestMatchDate: oldestMatch?.gameCreation,
            newestMatchDate: newestMatch?.gameCreation
        )
    }

    // MARK: - Baseline Management (Delegated to BaselineDataLoader)

    /// Saves a baseline to the database
    public func saveBaseline(_ baseline: Baseline) async throws {
        try await baselineDataLoader.saveBaseline(baseline)
    }

    /// Gets a baseline by role, class tag, and metric
    public func getBaseline(role: String, classTag: String, metric: String) async throws
        -> Baseline?
    {
        return try await baselineDataLoader.getBaseline(
            role: role, classTag: classTag, metric: metric)
    }

    /// Clears all baselines (for debugging/testing)
    public func clearBaselines() async throws {
        try await baselineDataLoader.clearBaselines()
    }

    // MARK: - Cache Management

    /// Determines if matches should be refreshed based on smart caching strategy
    private func shouldRefreshMatches(for summoner: Summoner) -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(summoner.lastUpdated)

        // Smart caching strategy:
        // - First time: always refresh
        // - Recent data (< 5 minutes): use cache
        // - Stale data (> 5 minutes): incremental refresh
        // - Very old data (> 1 hour): full refresh

        if timeSinceLastUpdate < 5 * 60 {  // Less than 5 minutes
            ClaimbLogger.debug(
                "Matches are fresh, using cache", service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "cache",
                ])
            return false
        } else if timeSinceLastUpdate < 60 * 60 {  // Less than 1 hour
            ClaimbLogger.debug(
                "Matches are stale, incremental refresh", service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "incremental",
                ])
            return true
        } else {  // More than 1 hour
            ClaimbLogger.debug(
                "Matches are very old, full refresh", service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "full",
                ])
            return true
        }
    }

    // MARK: - Request Deduplication

    /// Loads matches with deduplication
    public func loadMatches(for summoner: Summoner, limit: Int = 100) async -> UIState<[Match]> {
        let requestKey = "matches_\(summoner.puuid)_\(limit)"

        return await deduplicateRequest(key: requestKey) {
            ClaimbLogger.info(
                "Loading matches", service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "limit": String(limit),
                ])

            do {
                // Check if we have existing matches
                let existingMatches = try await self.getMatches(for: summoner)

                if existingMatches.isEmpty {
                    // Load initial matches
                    ClaimbLogger.info(
                        "No existing matches, loading initial batch", service: "DataManager")
                    try await self.loadInitialMatches(for: summoner)
                } else {
                    // Check if we need to refresh based on time
                    let shouldRefresh = self.shouldRefreshMatches(for: summoner)

                    if shouldRefresh {
                        ClaimbLogger.info(
                            "Found existing matches, refreshing with new data",
                            service: "DataManager",
                            metadata: [
                                "count": String(existingMatches.count),
                                "lastUpdated": summoner.lastUpdated.description,
                            ])

                        // Try to refresh, but don't fail if network is unavailable
                        do {
                            try await self.refreshMatchesInternal(for: summoner)
                            ClaimbLogger.info(
                                "Successfully refreshed matches from network",
                                service: "DataManager")
                        } catch {
                            // Network failed, but we have cached data - log warning and continue
                            ClaimbLogger.warning(
                                "Network refresh failed, using cached data", service: "DataManager",
                                metadata: [
                                    "error": error.localizedDescription,
                                    "cachedCount": String(existingMatches.count),
                                ])
                            // Continue with cached data instead of failing
                        }
                    } else {
                        ClaimbLogger.info(
                            "Using cached matches (no refresh needed)", service: "DataManager",
                            metadata: [
                                "count": String(existingMatches.count),
                                "lastUpdated": summoner.lastUpdated.description,
                            ])
                    }
                }

                // Get all matches after loading (will include cached data if network failed)
                let loadedMatches = try await self.getMatches(for: summoner, limit: limit)
                return .loaded(loadedMatches)

            } catch {
                // This catch block should only handle critical errors (database issues, etc.)
                // Network failures are now handled above
                ClaimbLogger.error(
                    "Failed to load matches", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Loads champions with deduplication
    public func loadChampions() async -> UIState<[Champion]> {
        let requestKey = "champions"

        return await deduplicateRequest(key: requestKey) {
            ClaimbLogger.info("Loading champions", service: "DataManager")

            do {
                try await self.championDataLoader.loadChampionData()
                let champions = try await self.championDataLoader.getAllChampions()

                ClaimbLogger.info(
                    "Successfully loaded \(champions.count) champions",
                    service: "DataManager",
                    metadata: ["championCount": String(champions.count)]
                )

                return .loaded(champions)
            } catch {
                ClaimbLogger.error("Failed to load champions", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Creates or updates summoner with deduplication
    public func createOrUpdateSummoner(gameName: String, tagLine: String, region: String) async
        -> UIState<Summoner>
    {
        let requestKey = "summoner_\(gameName)_\(tagLine)_\(region)"

        return await deduplicateRequest(key: requestKey) {

            ClaimbLogger.info(
                "Creating/updating summoner", service: "DataManager",
                metadata: [
                    "gameName": gameName,
                    "tagLine": tagLine,
                    "region": region,
                ])

            do {
                let summoner = try await self.createOrUpdateSummonerInternal(
                    gameName: gameName,
                    tagLine: tagLine,
                    region: region
                )

                try await self.championDataLoader.loadChampionData()
                _ = await self.refreshMatches(for: summoner)

                return .loaded(summoner)
            } catch {
                ClaimbLogger.error(
                    "Failed to create/update summoner", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Loads baseline data with deduplication
    public func loadBaselineData() async -> UIState<Void> {
        let requestKey = "baseline_data"

        return await deduplicateRequest(key: requestKey) {
            ClaimbLogger.info("Loading baseline data", service: "DataManager")

            do {
                try await self.baselineDataLoader.loadBaselineDataInternal()
                return .loaded(())
            } catch {
                ClaimbLogger.error(
                    "Failed to load baseline data", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Refreshes matches with deduplication
    public func refreshMatches(for summoner: Summoner) async -> UIState<[Match]> {
        ClaimbLogger.info(
            "Refreshing matches", service: "DataManager",
            metadata: [
                "summoner": summoner.gameName
            ])

        do {
            try await self.refreshMatchesInternal(for: summoner)
            let refreshedMatches = try await getMatches(for: summoner)
            return .loaded(refreshedMatches)
        } catch {
            // If refresh fails due to network, fall back to cached data
            ClaimbLogger.warning(
                "Refresh failed, falling back to cached data", service: "DataManager",
                metadata: [
                    "error": error.localizedDescription,
                    "summoner": summoner.gameName,
                ])

            do {
                let cachedMatches = try await getMatches(for: summoner)
                if !cachedMatches.isEmpty {
                    ClaimbLogger.info(
                        "Using cached matches as fallback", service: "DataManager",
                        metadata: ["cachedCount": String(cachedMatches.count)])
                    return .loaded(cachedMatches)
                } else {
                    ClaimbLogger.error(
                        "No cached data available and network failed", service: "DataManager",
                        error: error)
                    return .error(error)
                }
            } catch {
                ClaimbLogger.error(
                    "Failed to load cached matches", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Clears all cached data with deduplication
    public func clearAllCache() async -> UIState<Void> {
        ClaimbLogger.info("Clearing all cache", service: "DataManager")

        do {
            try await clearAllCacheInternal()
            return .loaded(())
        } catch {
            ClaimbLogger.error("Failed to clear cache", service: "DataManager", error: error)
            return .error(error)
        }
    }

    /// Cancels all pending requests (useful for cleanup)
    public func cancelAllRequests() {
        // Cancel all requests using the unified system
        for task in requestTasks.values {
            if let cancellableTask = task as? Task<Any, Never> {
                cancellableTask.cancel()
            }
        }
        requestTasks.removeAll()
        activeRequests.removeAll()

        ClaimbLogger.info("Cancelled all pending requests", service: "DataManager")
    }
}

// MARK: - Supporting Types

public struct MatchStatistics {
    public let totalMatches: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double
}

public struct MatchStatisticsWithAge {
    public let totalMatches: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double
    public let oldMatchesFiltered: Int
    public let oldestMatchDate: Int?
    public let newestMatchDate: Int?
}

// MARK: - DataManager Errors

public enum DataManagerError: Error, LocalizedError {
    case notAvailable
    case missingResource(String)
    case invalidData(String)
    case databaseError(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "DataManager is not available"
        case .missingResource(let resource):
            return "Missing resource: \(resource)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}
