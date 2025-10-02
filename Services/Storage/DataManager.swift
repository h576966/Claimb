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

            // Debug logging for summoner response
            ClaimbLogger.debug(
                "Received summoner response", service: "DataManager",
                metadata: [
                    "summoner": existing.gameName,
                    "summonerId": summonerResponse.id,
                    "accountId": summonerResponse.accountId,
                    "puuid": summonerResponse.puuid,
                    "name": summonerResponse.name,
                    "summonerLevel": String(summonerResponse.summonerLevel),
                ])

            existing.summonerId = summonerResponse.id
            existing.accountId = summonerResponse.accountId
            existing.profileIconId = summonerResponse.profileIconId
            existing.summonerLevel = summonerResponse.summonerLevel

            // Fetch rank data using PUUID
            print(
                "🔍 DataManager: Calling updateSummonerRanks for existing summoner \(existing.gameName) with puuid: \(existing.puuid)"
            )
            try await updateSummonerRanks(existing, region: region)

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

            // Debug logging for summoner response
            ClaimbLogger.debug(
                "Received summoner response", service: "DataManager",
                metadata: [
                    "summoner": newSummoner.gameName,
                    "summonerId": summonerResponse.id,
                    "accountId": summonerResponse.accountId,
                    "puuid": summonerResponse.puuid,
                    "name": summonerResponse.name,
                    "summonerLevel": String(summonerResponse.summonerLevel),
                ])

            newSummoner.summonerId = summonerResponse.id
            newSummoner.accountId = summonerResponse.accountId
            newSummoner.profileIconId = summonerResponse.profileIconId
            newSummoner.summonerLevel = summonerResponse.summonerLevel

            // Fetch rank data using PUUID
            print(
                "🔍 DataManager: Calling updateSummonerRanks for new summoner \(newSummoner.gameName) with puuid: \(newSummoner.puuid)"
            )
            try await updateSummonerRanks(newSummoner, region: region)

            modelContext.insert(newSummoner)
            try modelContext.save()
            return newSummoner
        }
    }

    /// Updates summoner rank data from league entries
    public func updateSummonerRanks(_ summoner: Summoner, region: String)
        async throws
    {
        print(
            "🔍 DataManager: updateSummonerRanks called for \(summoner.gameName) with region: \(region)"
        )

        do {
            ClaimbLogger.info(
                "Fetching rank data", service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "puuid": summoner.puuid,
                    "region": region,
                ])

            print(
                "🔍 DataManager: About to call getLeagueEntriesByPUUID with puuid: \(summoner.puuid), region: \(region)"
            )

            // Use PUUID instead of summonerId for league entries
            let leagueResponse = try await riotClient.getLeagueEntriesByPUUID(
                puuid: summoner.puuid, region: region)

            print(
                "🔍 DataManager: Successfully received league response with \(leagueResponse.entries.count) entries"
            )

            ClaimbLogger.info(
                "Received league response", service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "entryCount": String(leagueResponse.entries.count),
                    "entries": leagueResponse.entries.map {
                        "\($0.queueType): \($0.tier) \($0.rank)"
                    }.joined(separator: ", "),
                ])

            // Reset rank data
            summoner.soloDuoRank = nil
            summoner.flexRank = nil
            summoner.soloDuoLP = nil
            summoner.flexLP = nil
            summoner.soloDuoWins = nil
            summoner.soloDuoLosses = nil
            summoner.flexWins = nil
            summoner.flexLosses = nil

            // Process league entries
            for entry in leagueResponse.entries {
                switch entry.queueType {
                case "RANKED_SOLO_5x5":
                    summoner.soloDuoRank = "\(entry.tier) \(entry.rank)"
                    summoner.soloDuoLP = entry.leaguePoints
                    summoner.soloDuoWins = entry.wins
                    summoner.soloDuoLosses = entry.losses
                case "RANKED_FLEX_SR":
                    summoner.flexRank = "\(entry.tier) \(entry.rank)"
                    summoner.flexLP = entry.leaguePoints
                    summoner.flexWins = entry.wins
                    summoner.flexLosses = entry.losses
                default:
                    // Skip other queue types
                    continue
                }
            }

            ClaimbLogger.info(
                "Updated summoner ranks", service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "soloDuoRank": summoner.soloDuoRank ?? "Unranked",
                    "flexRank": summoner.flexRank ?? "Unranked",
                ])

        } catch {
            print("🔍 DataManager: Error in updateSummonerRanks: \(error)")
            print("🔍 DataManager: Error type: \(type(of: error))")
            print("🔍 DataManager: Error localizedDescription: \(error.localizedDescription)")

            ClaimbLogger.warning(
                "Failed to fetch rank data, continuing without ranks", service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "error": error.localizedDescription,
                ])

            // Don't throw - ranks are optional, continue without them
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

    /// Refreshes rank data for an existing summoner
    public func refreshSummonerRanks(for summoner: Summoner) async -> UIState<Void> {
        let requestKey = "refresh_ranks_\(summoner.puuid)"

        return await deduplicateRequest(key: requestKey) {
            ClaimbLogger.info(
                "Refreshing rank data for existing summoner", service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "puuid": summoner.puuid,
                ])

            do {
                try await self.updateSummonerRanks(summoner, region: summoner.region)
                try self.modelContext.save()

                ClaimbLogger.info(
                    "Successfully refreshed rank data", service: "DataManager",
                    metadata: [
                        "summoner": summoner.gameName,
                        "soloDuoRank": summoner.soloDuoRank ?? "Unranked",
                        "flexRank": summoner.flexRank ?? "Unranked",
                    ])

                return .loaded(())
            } catch {
                ClaimbLogger.error(
                    "Failed to refresh rank data", service: "DataManager",
                    error: error,
                    metadata: [
                        "summoner": summoner.gameName,
                        "error": error.localizedDescription,
                    ])
                return .error(error)
            }
        }
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
                let targetCount = MatchFilteringUtils.targetInitialMatchCount
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

                // Use the same smart fetching strategy as initial load
                ClaimbLogger.info(
                    "Incremental refresh: using smart fetch strategy", service: "DataManager",
                    metadata: [
                        "currentCount": String(currentCount),
                        "targetCount": String(targetCount),
                        "neededMatches": String(targetCount - currentCount),
                    ]
                )

                // Use smart fetch to get more matches from all queues
                let smartFetchResult = try await self.performSmartMatchFetch(for: summoner)

                var newMatchesCount = 0
                var skippedMatchesCount = 0
                for matchId in smartFetchResult.matchIds {
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

    /// Loads initial match data for a summoner using smart fetching strategy
    public func loadInitialMatches(for summoner: Summoner) async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Load baseline data first if not already loaded
            _ = await loadBaselineData()

            ClaimbLogger.info(
                "Smart loading initial matches", service: "DataManager",
                metadata: [
                    "gameName": summoner.gameName,
                    "strategy": "ranked-first-with-fallback",
                ])

            // Smart fetching strategy: Try ranked games first, fallback to normal if needed
            let smartResult = try await performSmartMatchFetch(for: summoner)

            var addedMatchesCount = 0
            var skippedMatchesCount = 0

            for matchId in smartResult.matchIds {
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
                "Smart loaded initial matches", count: addedMatchesCount, service: "DataManager")

            // Get final count of matches in database for this summoner
            let finalMatchCount = try await getMatches(for: summoner).count

            ClaimbLogger.info(
                "Smart fetch completed", service: "DataManager",
                metadata: [
                    "strategy": String(describing: smartResult.strategy),
                    "totalFetched": String(smartResult.totalFetched),
                    "relevantCount": String(smartResult.relevantCount),
                    "addedCount": String(addedMatchesCount),
                    "skippedCount": String(skippedMatchesCount),
                    "finalDatabaseCount": String(finalMatchCount),
                ])

        } catch {
            isLoading = false
            errorMessage = "Failed to load initial matches: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    /// Performs smart match fetching with ranked-first strategy and fallback
    private func performSmartMatchFetch(for summoner: Summoner) async throws -> SmartFetchResult {
        let targetCount = MatchFilteringUtils.targetInitialMatchCount
        var allMatchIds: [String] = []
        var totalFetched = 0

        // Smart strategy: Prioritize ranked games, only fetch normal if needed
        let rankedQueues = [420, 440]  // Solo/Duo, Flex
        let normalQueue = 400  // Normal Draft

        // Start with ranked games - fetch 50 per queue to get ~100 total
        let matchesPerRankedQueue = min(50, targetCount / 2)

        ClaimbLogger.info(
            "Smart fetch: prioritizing ranked games first", service: "DataManager",
            metadata: [
                "targetCount": String(targetCount),
                "rankedQueues": rankedQueues.map(String.init).joined(separator: ","),
                "matchesPerRankedQueue": String(matchesPerRankedQueue),
                "strategy": "ranked-first-with-normal-fallback",
            ]
        )

        // Fetch from ranked queues first
        for queueId in rankedQueues {
            do {
                let queueHistory = try await riotClient.getMatchHistory(
                    puuid: summoner.puuid,
                    region: summoner.region,
                    count: matchesPerRankedQueue,
                    type: nil,
                    queue: queueId,
                    startTime: nil,
                    endTime: nil
                )

                let queueCount = queueHistory.history.count
                totalFetched += queueCount
                allMatchIds.append(contentsOf: queueHistory.history)

                ClaimbLogger.info(
                    "Fetched from ranked queue", service: "DataManager",
                    metadata: [
                        "queueId": String(queueId),
                        "queueName": MatchFilteringUtils.queueDisplayName(queueId),
                        "requestedCount": String(matchesPerRankedQueue),
                        "receivedCount": String(queueCount),
                        "totalSoFar": String(allMatchIds.count),
                    ]
                )

                // Stop early if we have enough matches
                if allMatchIds.count >= targetCount {
                    ClaimbLogger.info(
                        "Target reached with ranked games, stopping", service: "DataManager",
                        metadata: [
                            "currentCount": String(allMatchIds.count),
                            "targetCount": String(targetCount),
                        ]
                    )
                    break
                }
            } catch {
                ClaimbLogger.warning(
                    "Failed to fetch from ranked queue", service: "DataManager",
                    metadata: [
                        "queueId": String(queueId),
                        "queueName": MatchFilteringUtils.queueDisplayName(queueId),
                        "error": error.localizedDescription,
                    ]
                )
            }
        }

        // Only fetch normal games if we still need more matches
        let currentCount = allMatchIds.count
        if currentCount < targetCount {
            let neededMatches = targetCount - currentCount
            let normalMatchesToFetch = min(neededMatches + 20, 100)  // Add buffer, cap at API limit

            ClaimbLogger.info(
                "Need more matches, fetching from normal draft", service: "DataManager",
                metadata: [
                    "currentCount": String(currentCount),
                    "neededMatches": String(neededMatches),
                    "normalMatchesToFetch": String(normalMatchesToFetch),
                ]
            )

            do {
                let normalHistory = try await riotClient.getMatchHistory(
                    puuid: summoner.puuid,
                    region: summoner.region,
                    count: normalMatchesToFetch,
                    type: nil,
                    queue: normalQueue,
                    startTime: nil,
                    endTime: nil
                )

                let normalCount = normalHistory.history.count
                totalFetched += normalCount
                allMatchIds.append(contentsOf: normalHistory.history)

                ClaimbLogger.info(
                    "Fetched from normal draft", service: "DataManager",
                    metadata: [
                        "queueId": String(normalQueue),
                        "queueName": MatchFilteringUtils.queueDisplayName(normalQueue),
                        "requestedCount": String(normalMatchesToFetch),
                        "receivedCount": String(normalCount),
                        "totalSoFar": String(allMatchIds.count),
                    ]
                )
            } catch {
                ClaimbLogger.warning(
                    "Failed to fetch from normal draft", service: "DataManager",
                    metadata: [
                        "queueId": String(normalQueue),
                        "queueName": MatchFilteringUtils.queueDisplayName(normalQueue),
                        "error": error.localizedDescription,
                    ]
                )
            }
        }

        // Remove duplicates and limit to target count
        let uniqueMatchIds = Array(Set(allMatchIds))  // Remove duplicates
        let finalMatchIds = Array(uniqueMatchIds.prefix(targetCount))

        ClaimbLogger.info(
            "Smart fetch completed", service: "DataManager",
            metadata: [
                "totalFetched": String(totalFetched),
                "uniqueCount": String(uniqueMatchIds.count),
                "finalCount": String(finalMatchIds.count),
                "targetCount": String(targetCount),
                "duplicatesRemoved": String(totalFetched - uniqueMatchIds.count),
                "strategy": allMatchIds.count >= targetCount ? "ranked-only" : "ranked-plus-normal",
            ]
        )

        return SmartFetchResult(
            matchIds: finalMatchIds,
            strategy: .rankedFirst,
            totalFetched: totalFetched,
            relevantCount: finalMatchIds.count
        )
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

    // MARK: - Coaching Response Cache Management

    /// Caches a PostGameAnalysis response
    public func cachePostGameAnalysis(
        _ analysis: PostGameAnalysis,
        for summoner: Summoner,
        matchId: String,
        expirationHours: Int = 24
    ) async throws {
        let jsonData = try JSONEncoder().encode(analysis)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

        let cache = CoachingResponseCache(
            summonerPuuid: summoner.puuid,
            responseType: "postGame",
            matchId: matchId,
            responseJSON: jsonString,
            expirationHours: expirationHours
        )

        modelContext.insert(cache)
        try modelContext.save()

        ClaimbLogger.debug(
            "Cached post-game analysis", service: "DataManager",
            metadata: [
                "summoner": summoner.gameName,
                "matchId": matchId,
            ]
        )
    }

    /// Caches a PerformanceSummary response
    public func cachePerformanceSummary(
        _ summary: PerformanceSummary,
        for summoner: Summoner,
        expirationHours: Int = 24
    ) async throws {
        let jsonData = try JSONEncoder().encode(summary)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

        let cache = CoachingResponseCache(
            summonerPuuid: summoner.puuid,
            responseType: "performance",
            responseJSON: jsonString,
            expirationHours: expirationHours
        )

        modelContext.insert(cache)
        try modelContext.save()

        ClaimbLogger.debug(
            "Cached performance summary", service: "DataManager",
            metadata: [
                "summoner": summoner.gameName
            ]
        )
    }

    /// Retrieves cached PostGameAnalysis for a specific match
    public func getCachedPostGameAnalysis(
        for summoner: Summoner,
        matchId: String
    ) async throws -> PostGameAnalysis? {
        let descriptor = FetchDescriptor<CoachingResponseCache>()
        let allCaches = try modelContext.fetch(descriptor)

        let cached = allCaches.first { cache in
            cache.summonerPuuid == summoner.puuid && cache.responseType == "postGame"
                && cache.matchId == matchId && cache.isValid
        }

        return try cached?.getPostGameAnalysis()
    }

    /// Retrieves cached PerformanceSummary
    public func getCachedPerformanceSummary(
        for summoner: Summoner
    ) async throws -> PerformanceSummary? {
        let descriptor = FetchDescriptor<CoachingResponseCache>()
        let allCaches = try modelContext.fetch(descriptor)

        let cached = allCaches.first { cache in
            cache.summonerPuuid == summoner.puuid && cache.responseType == "performance"
                && cache.isValid
        }

        return try cached?.getPerformanceSummary()
    }

    /// Cleans up expired coaching responses
    public func cleanupExpiredCoachingResponses() async throws {
        let descriptor = FetchDescriptor<CoachingResponseCache>()
        let allCaches = try modelContext.fetch(descriptor)

        let expired = allCaches.filter { !$0.isValid }
        for cache in expired {
            modelContext.delete(cache)
        }

        if !expired.isEmpty {
            try modelContext.save()
            ClaimbLogger.debug(
                "Cleaned up expired coaching responses", service: "DataManager",
                metadata: [
                    "expiredCount": String(expired.count)
                ]
            )
        }
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
                // CACHE-FIRST STRATEGY: Check if we have existing matches
                let existingMatches = try await self.getMatches(for: summoner)

                if !existingMatches.isEmpty {
                    // We have cached data - return immediately
                    ClaimbLogger.info(
                        "Returning cached matches immediately", service: "DataManager",
                        metadata: [
                            "count": String(existingMatches.count),
                            "lastUpdated": summoner.lastUpdated.description,
                        ])

                    // Try to refresh in background if needed
                    let shouldRefresh = self.shouldRefreshMatches(for: summoner)
                    if shouldRefresh {
                        Task {
                            ClaimbLogger.info(
                                "Refreshing matches in background", service: "DataManager")
                            do {
                                try await self.refreshMatchesInternal(for: summoner)
                                ClaimbLogger.info(
                                    "Background refresh completed", service: "DataManager")
                            } catch {
                                ClaimbLogger.warning(
                                    "Background refresh failed (cached data still available)",
                                    service: "DataManager",
                                    metadata: ["error": error.localizedDescription])
                            }
                        }
                    }

                    return .loaded(existingMatches)
                }

                // No cached data - need to load from network
                ClaimbLogger.info(
                    "No cached matches, loading from network", service: "DataManager")

                do {
                    try await self.loadInitialMatches(for: summoner)
                    let loadedMatches = try await self.getMatches(for: summoner, limit: limit)
                    return .loaded(loadedMatches)
                } catch {
                    // Network failed and no cache - return error
                    ClaimbLogger.error(
                        "Failed to load initial matches (no cache available)",
                        service: "DataManager",
                        error: error)
                    return .error(error)
                }

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
