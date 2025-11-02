//
//  DataManager.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//  Refactored by AI Assistant on 2025-10-10.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

/// Orchestrates data operations through specialized repositories
/// Provides unified interface for all data access with request deduplication
@MainActor
@Observable
public class DataManager {
    // MARK: - Singleton
    private static var sharedInstance: DataManager?

    // MARK: - Dependencies
    private let _modelContext: ModelContext
    private let riotClient: RiotClient

    /// Public accessor for modelContext (needed for baseline caching)
    public var modelContext: ModelContext {
        return _modelContext
    }

    // MARK: - Repositories
    private let summonerRepository: SummonerRepository
    private let matchRepository: MatchRepository
    private let coachingCacheRepository: CoachingCacheRepository
    private let championDataLoader: ChampionDataLoader
    private let baselineDataLoader: BaselineDataLoader
    private let matchParser: MatchParser

    // MARK: - Cache Configuration
    private let maxMatchesPerSummoner = 100
    private let maxGameAgeInDays = 365

    // MARK: - Request Deduplication
    private var activeRequests: Set<String> = []
    private var requestTasks: [String: Any] = [:]

    // MARK: - Observable State
    public var isLoading = false
    public var lastRefreshTime: Date?
    public var errorMessage: String?

    // MARK: - Initialization

    private init(
        modelContext: ModelContext,
        riotClient: RiotClient,
        dataDragonService: DataDragonServiceProtocol
    ) {
        self._modelContext = modelContext
        self.riotClient = riotClient

        // Initialize shared components
        self.matchParser = MatchParser(modelContext: modelContext)

        // Initialize repositories
        self.summonerRepository = SummonerRepository(
            modelContext: modelContext,
            riotClient: riotClient
        )
        self.matchRepository = MatchRepository(
            modelContext: modelContext,
            riotClient: riotClient,
            matchParser: matchParser,
            maxMatchesPerSummoner: maxMatchesPerSummoner
        )
        self.coachingCacheRepository = CoachingCacheRepository(modelContext: modelContext)
        self.championDataLoader = ChampionDataLoader(
            modelContext: modelContext,
            dataDragonService: dataDragonService
        )
        self.baselineDataLoader = BaselineDataLoader(modelContext: modelContext)
    }

    /// Gets the shared DataManager instance, creating it if needed
    /// WARNING: All calls must use the same ModelContext. Using different contexts will cause data inconsistencies.
    public static func shared(with modelContext: ModelContext) -> DataManager {
        if let existing = sharedInstance {
            // Validate that the same ModelContext is being used
            if existing._modelContext !== modelContext {
                ClaimbLogger.warning(
                    "DataManager.shared() called with different ModelContext! This may cause data inconsistencies.",
                    service: "DataManager",
                    metadata: [
                        "existingContext": String(describing: existing._modelContext),
                        "newContext": String(describing: modelContext)
                    ]
                )
            }
            return existing
        }

        let instance = DataManager(
            modelContext: modelContext,
            riotClient: RiotProxyClient(),
            dataDragonService: DataDragonService()
        )

        sharedInstance = instance
        ClaimbLogger.info(
            "DataManager singleton initialized",
            service: "DataManager",
            metadata: ["context": String(describing: modelContext)]
        )
        return instance
    }

    // MARK: - Request Deduplication Helpers

    /// Generic helper for request deduplication
    private func deduplicateRequest<T>(
        key: String,
        operation: @escaping @MainActor () async -> UIState<T>
    ) async -> UIState<T> {
        if let existingTask = requestTasks[key] as? Task<UIState<T>, Never> {
            ClaimbLogger.debug(
                "Request already in progress, waiting for result",
                service: "DataManager",
                metadata: ["requestKey": key]
            )
            return await existingTask.value
        }

        let task = Task<UIState<T>, Never> { @MainActor in
            defer {
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
        if let existingTask = requestTasks[key] as? Task<T, Error> {
            ClaimbLogger.debug(
                "Request already in progress, waiting for result",
                service: "DataManager",
                metadata: ["requestKey": key]
            )
            return try await existingTask.value
        }

        let task = Task<T, Error> { @MainActor in
            defer {
                requestTasks.removeValue(forKey: key)
                activeRequests.remove(key)
            }
            activeRequests.insert(key)
            return try await operation()
        }

        requestTasks[key] = task
        return try await task.value
    }

    // MARK: - Summoner Operations (Delegated to SummonerRepository)

    /// Gets a summoner by PUUID
    public func getSummoner(by puuid: String) async throws -> Summoner? {
        return try await summonerRepository.getSummoner(by: puuid)
    }

    /// Gets all summoners
    public func getAllSummoners() async throws -> [Summoner] {
        return try await summonerRepository.getAllSummoners()
    }

    /// Creates or updates a summoner with deduplication
    public func createOrUpdateSummoner(
        gameName: String,
        tagLine: String,
        region: String
    ) async -> UIState<Summoner> {
        let requestKey = "summoner_\(gameName)_\(tagLine)_\(region)"

        return await deduplicateRequest(key: requestKey) {
            ClaimbLogger.info(
                "Creating/updating summoner",
                service: "DataManager",
                metadata: [
                    "gameName": gameName,
                    "tagLine": tagLine,
                    "region": region,
                ])

            do {
                let summoner = try await self.summonerRepository.createOrUpdate(
                    gameName: gameName,
                    tagLine: tagLine,
                    region: region
                )

                try await self.championDataLoader.loadChampionData()
                _ = await self.refreshMatches(for: summoner)

                return .loaded(summoner)
            } catch {
                ClaimbLogger.error(
                    "Failed to create/update summoner",
                    service: "DataManager",
                    error: error
                )
                return .error(error)
            }
        }
    }

    /// Refreshes rank data for an existing summoner
    public func refreshSummonerRanks(for summoner: Summoner) async -> UIState<Void> {
        let requestKey = "refresh_ranks_\(summoner.puuid)"

        return await deduplicateRequest(key: requestKey) {
            ClaimbLogger.info(
                "Refreshing rank data for existing summoner",
                service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "puuid": summoner.puuid,
                ])

            do {
                try await self.summonerRepository.updateRanks(summoner, region: summoner.region)
                try self.modelContext.save()

                ClaimbLogger.info(
                    "Successfully refreshed rank data",
                    service: "DataManager",
                    metadata: [
                        "summoner": summoner.gameName,
                        "soloDuoRank": summoner.soloDuoRank ?? "Unranked",
                        "flexRank": summoner.flexRank ?? "Unranked",
                    ])

                return .loaded(())
            } catch {
                ClaimbLogger.error(
                    "Failed to refresh rank data",
                    service: "DataManager",
                    error: error,
                    metadata: [
                        "summoner": summoner.gameName,
                        "error": error.localizedDescription,
                    ])
                return .error(error)
            }
        }
    }

    // MARK: - Match Operations (Delegated to MatchRepository)

    /// Gets a match by ID
    public func getMatch(by matchId: String) async throws -> Match? {
        return try await matchRepository.getMatch(by: matchId)
    }

    /// Gets matches for a summoner
    public func getMatches(for summoner: Summoner, limit: Int = 50) async throws -> [Match] {
        return try await matchRepository.getMatches(for: summoner, limit: limit)
    }

    /// Loads matches with cache-first strategy and deduplication
    public func loadMatches(for summoner: Summoner, limit: Int = 50) async -> UIState<[Match]> {
        let requestKey = "matches_\(summoner.puuid)_\(limit)"

        return await deduplicateRequest(key: requestKey) {
            ClaimbLogger.info(
                "Loading matches",
                service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "limit": String(limit),
                ])

            do {
                // CACHE-FIRST STRATEGY
                let existingMatches = try await self.matchRepository.getMatches(for: summoner)

                if !existingMatches.isEmpty {
                    ClaimbLogger.info(
                        "Returning cached matches immediately",
                        service: "DataManager",
                        metadata: [
                            "count": String(existingMatches.count),
                            "lastUpdated": summoner.lastUpdated.description,
                        ])

                    // Background refresh if needed
                    if self.shouldRefreshMatches(for: summoner) {
                        Task {
                            ClaimbLogger.info(
                                "Refreshing matches in background", service: "DataManager")
                            do {
                                try await self.matchRepository.refreshMatches(for: summoner)
                                self.lastRefreshTime = Date()
                                ClaimbLogger.info(
                                    "Background refresh completed", service: "DataManager")
                            } catch {
                                ClaimbLogger.warning(
                                    "Background refresh failed (cached data still available)",
                                    service: "DataManager",
                                    metadata: ["error": error.localizedDescription]
                                )
                            }
                        }
                    }

                    return .loaded(existingMatches)
                }

                // No cache - load from network
                ClaimbLogger.info("No cached matches, loading from network", service: "DataManager")
                self.isLoading = true

                do {
                    try await self.matchRepository.loadInitialMatches(for: summoner)
                    let loadedMatches = try await self.matchRepository.getMatches(
                        for: summoner, limit: limit)
                    self.isLoading = false
                    self.lastRefreshTime = Date()
                    return .loaded(loadedMatches)
                } catch {
                    self.isLoading = false
                    ClaimbLogger.error(
                        "Failed to load initial matches (no cache available)",
                        service: "DataManager",
                        error: error
                    )
                    return .error(error)
                }

            } catch {
                ClaimbLogger.error("Failed to load matches", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Refreshes matches with fallback to cache
    public func refreshMatches(for summoner: Summoner) async -> UIState<[Match]> {
        ClaimbLogger.info(
            "Refreshing matches",
            service: "DataManager",
            metadata: ["summoner": summoner.gameName]
        )

        do {
            try await matchRepository.refreshMatches(for: summoner)
            let refreshedMatches = try await matchRepository.getMatches(for: summoner)
            lastRefreshTime = Date()
            return .loaded(refreshedMatches)
        } catch {
            // Fall back to cached data
            ClaimbLogger.warning(
                "Refresh failed, falling back to cached data",
                service: "DataManager",
                metadata: [
                    "error": error.localizedDescription,
                    "summoner": summoner.gameName,
                ])

            do {
                let cachedMatches = try await matchRepository.getMatches(for: summoner)
                if !cachedMatches.isEmpty {
                    ClaimbLogger.info(
                        "Using cached matches as fallback",
                        service: "DataManager",
                        metadata: ["cachedCount": String(cachedMatches.count)]
                    )
                    return .loaded(cachedMatches)
                } else {
                    return .error(error)
                }
            } catch {
                ClaimbLogger.error(
                    "Failed to load cached matches", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Forces a refresh of matches (bypasses cache freshness check)
    public func forceRefreshMatches(for summoner: Summoner) async -> UIState<[Match]> {
        ClaimbLogger.info(
            "Force refreshing matches",
            service: "DataManager",
            metadata: ["summoner": summoner.gameName]
        )

        do {
            try await matchRepository.refreshMatches(for: summoner)
            let refreshedMatches = try await matchRepository.getMatches(for: summoner)
            lastRefreshTime = Date()
            return .loaded(refreshedMatches)
        } catch {
            // Fall back to cached data
            ClaimbLogger.warning(
                "Force refresh failed, falling back to cached data",
                service: "DataManager",
                metadata: [
                    "error": error.localizedDescription,
                    "summoner": summoner.gameName,
                ])

            do {
                let cachedMatches = try await matchRepository.getMatches(for: summoner)
                if !cachedMatches.isEmpty {
                    return .loaded(cachedMatches)
                } else {
                    return .error(error)
                }
            } catch {
                ClaimbLogger.error(
                    "Failed to load cached matches", service: "DataManager", error: error)
                return .error(error)
            }
        }
    }

    /// Gets match statistics
    public func getMatchStatistics(for summoner: Summoner) async throws -> MatchStatistics {
        return try await matchRepository.getMatchStatistics(for: summoner)
    }

    /// Gets match statistics with age filtering
    public func getMatchStatisticsWithAgeFilter(for summoner: Summoner) async throws
        -> MatchStatisticsWithAge
    {
        return try await matchRepository.getMatchStatisticsWithAgeFilter(
            for: summoner,
            maxGameAgeInDays: maxGameAgeInDays
        )
    }

    // MARK: - Champion Operations (Delegated to ChampionDataLoader)

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

    // MARK: - Baseline Operations (Delegated to BaselineDataLoader)

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

    /// Saves a baseline
    public func saveBaseline(_ baseline: Baseline) async throws {
        try await baselineDataLoader.saveBaseline(baseline)
    }

    /// Gets a baseline
    public func getBaseline(role: String, classTag: String, metric: String) async throws
        -> Baseline?
    {
        return try await baselineDataLoader.getBaseline(
            role: role,
            classTag: classTag,
            metric: metric
        )
    }

    /// Clears all baselines
    public func clearBaselines() async throws {
        try await baselineDataLoader.clearBaselines()
    }

    // MARK: - Coaching Cache Operations (Delegated to CoachingCacheRepository)

    /// Caches a PostGameAnalysis response
    public func cachePostGameAnalysis(
        _ analysis: PostGameAnalysis,
        for summoner: Summoner,
        matchId: String,
        expirationHours: Int = 24
    ) async throws {
        try await coachingCacheRepository.cachePostGameAnalysis(
            analysis,
            for: summoner,
            matchId: matchId,
            expirationHours: expirationHours
        )
    }

    /// Caches a PerformanceSummary response
    public func cachePerformanceSummary(
        _ summary: PerformanceSummary,
        for summoner: Summoner,
        matchCount: Int,
        expirationHours: Int = 24
    ) async throws {
        try await coachingCacheRepository.cachePerformanceSummary(
            summary,
            for: summoner,
            matchCount: matchCount,
            expirationHours: expirationHours
        )
    }

    /// Retrieves cached PostGameAnalysis
    public func getCachedPostGameAnalysis(
        for summoner: Summoner,
        matchId: String
    ) async throws -> PostGameAnalysis? {
        return try await coachingCacheRepository.getCachedPostGameAnalysis(
            for: summoner,
            matchId: matchId
        )
    }

    /// Retrieves cached PerformanceSummary
    public func getCachedPerformanceSummary(
        for summoner: Summoner,
        matchCount: Int
    ) async throws -> PerformanceSummary? {
        return try await coachingCacheRepository.getCachedPerformanceSummary(
            for: summoner,
            matchCount: matchCount
        )
    }

    /// Cleans up expired coaching responses
    public func cleanupExpiredCoachingResponses() async throws {
        try await coachingCacheRepository.cleanupExpiredResponses()
    }

    // MARK: - Cache Management

    /// Determines if matches should be refreshed based on smart caching strategy
    private func shouldRefreshMatches(for summoner: Summoner) -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(summoner.lastUpdated)

        if timeSinceLastUpdate < 5 * 60 {  // Less than 5 minutes
            ClaimbLogger.debug(
                "Matches are fresh, using cache",
                service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "cache",
                ])
            return false
        } else if timeSinceLastUpdate < 60 * 60 {  // Less than 1 hour
            ClaimbLogger.debug(
                "Matches are stale, incremental refresh",
                service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "incremental",
                ])
            return true
        } else {  // More than 1 hour
            ClaimbLogger.debug(
                "Matches are very old, full refresh",
                service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "full",
                ])
            return true
        }
    }

    /// Clears all cached data
    public func clearAllCache() async -> UIState<Void> {
        ClaimbLogger.info("Clearing all cache", service: "DataManager")

        do {
            try await matchRepository.clearMatchData()
            return .loaded(())
        } catch {
            ClaimbLogger.error("Failed to clear cache", service: "DataManager", error: error)
            return .error(error)
        }
    }

    /// Clears URL cache only
    public func clearURLCache() {
        ClaimbLogger.info("Clearing URL cache...", service: "DataManager")
        URLCache.shared.removeAllCachedResponses()
        ClaimbLogger.info("URL cache cleared", service: "DataManager")
    }

    /// Cancels all pending requests
    public func cancelAllRequests() {
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
            return "Data manager not available"
        case .missingResource(let resource):
            return "Missing required resource: \(resource)"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        case .databaseError(let details):
            return "Database error: \(details)"
        }
    }
}
