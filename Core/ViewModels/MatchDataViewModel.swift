//
//  MatchDataViewModel.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

/// Unified view model for all data loading and statistics
@MainActor
@Observable
public class MatchDataViewModel {
    // MARK: - Published Properties

    public var matchState: UIState<[Match]> = .idle
    public var championState: UIState<[Champion]> = .idle
    public var roleStats: [RoleStats] = []
    public var championStats: [ChampionStats] = []
    public var kpiMetrics: [KPIMetric] = []
    public var isRefreshing = false

    // MARK: - Private Properties

    private let dataManager: DataManager?
    private let summoner: Summoner
    private let userSession: UserSession?
    public let kpiCalculationService: KPICalculationService?
    // Note: Using private var for task management, accessed carefully in deinit
    private var currentTask: Task<Void, Never>?

    // MARK: - In-Memory Caches
    private var kpiCache: [String: [KPIMetric]] = [:]
    private let kpiPersistPrefix = "kpiCache_"

    // Baseline cache to eliminate RunLoop blocking pattern
    private var baselineCache: [String: Baseline] = [:]
    private var baselinesLoaded = false

    private func kpiCacheKey(matches: [Match], role: String) -> String {
        // Use recent 20 matches for cache key to ensure cache consistency
        let recentCount = min(matches.count, 20)
        let latestId = matches.first?.matchId ?? "none"
        return "\(summoner.puuid)|\(role)|\(recentCount)|\(latestId)"
    }

    /// Creates baseline cache key
    private func baselineCacheKey(role: String, classTag: String, metric: String) -> String {
        return "\(role)_\(classTag)_\(metric)"
    }

    // MARK: - Initialization

    public init(dataManager: DataManager?, summoner: Summoner, userSession: UserSession? = nil) {
        self.dataManager = dataManager
        self.summoner = summoner
        self.userSession = userSession

        // Initialize KPI calculation service if userSession is provided
        if let userSession = userSession {
            let kpiDataManager = DataManager.shared(with: userSession.modelContext)
            self.kpiCalculationService = KPICalculationService(dataManager: kpiDataManager)
        } else {
            self.kpiCalculationService = nil
        }
    }

    // MARK: - Public Methods

    /// Loads all data: matches, champions, and calculates all statistics
    public func loadAllData(limit: Int = 100) async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataManager = dataManager else {
                matchState = .error(DataManagerError.notAvailable)
                championState = .error(DataManagerError.notAvailable)
                return
            }

            matchState = .loading
            championState = .loading

            // Load matches and champions in parallel
            // Note: We capture summoner here to avoid Sendable issues with async let
            let currentSummoner = summoner
            async let matchResult = dataManager.loadMatches(for: currentSummoner, limit: limit)
            async let championResult = dataManager.loadChampions()

            let (matches, champions) = await (matchResult, championResult)

            matchState = matches
            championState = champions

            // Pre-cache baselines to eliminate RunLoop blocking pattern
            if !baselinesLoaded {
                await loadBaselinesIntoCache()
            }

            // Update all statistics if we have data
            if case .loaded(let matchData) = matches {
                roleStats = calculateRoleStats(from: matchData, summoner: summoner)

                // Calculate champion stats if we have champions
                if case .loaded(let championData) = champions {
                    await calculateChampionStats(matches: matchData, champions: championData)
                }

                // KPIs: serve cached first, then refresh in background
                if userSession != nil {
                    let servedFromCache = loadKPIsFromCacheIfAvailable(matches: matchData)
                    if !servedFromCache {
                        await calculateKPIs(matches: matchData)
                    } else {
                        Task { await calculateKPIs(matches: matchData) }
                    }
                }
            }
        }

        await currentTask?.value
    }

    /// Loads matches and calculates role statistics (legacy method for compatibility)
    public func loadMatches(limit: Int = 100) async {
        await loadAllData(limit: limit)
    }

    /// Refreshes matches from the API and recalculates role statistics
    public func refreshMatches() async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataManager = dataManager else { return }

            isRefreshing = true

            // Use force refresh to bypass cache for pull-to-refresh
            let result = await dataManager.forceRefreshMatches(for: summoner)

            matchState = result
            isRefreshing = false

            // Update role stats if we have matches
            if case .loaded(let matches) = result {
                roleStats = calculateRoleStats(from: matches, summoner: summoner)
            }
        }

        await currentTask?.value
    }

    /// Clears all cached data and reloads matches
    public func clearCache() async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataManager = dataManager else { return }

            isRefreshing = true

            let result = await dataManager.clearAllCache()

            isRefreshing = false

            if case .loaded = result {
                // Reload matches after clearing cache
                await loadMatches()
            }
        }

        await currentTask?.value
    }

    deinit {
        // Note: Cannot access @Observable properties in deinit
        // Task will be automatically cancelled when the object is deallocated
    }

    /// Gets the current matches if loaded
    public var currentMatches: [Match] {
        return matchState.data ?? []
    }

    /// Checks if matches are currently loaded
    public var hasMatches: Bool {
        return matchState.isLoaded && !currentMatches.isEmpty
    }

    /// Gets the most recent matches up to a specified limit
    public func getRecentMatches(limit: Int = 5) -> [Match] {
        return Array(currentMatches.prefix(limit))
    }

    /// Gets the current champions if loaded
    public var currentChampions: [Champion] {
        return championState.data ?? []
    }

    /// Checks if champions are currently loaded
    public var hasChampions: Bool {
        return championState.isLoaded && !currentChampions.isEmpty
    }

    /// Loads champion statistics for the current role and filter
    public func loadChampionStats(role: String? = nil, filter: ChampionFilter = .mostPlayed) async {
        guard let matches = matchState.data, let champions = championState.data else { return }

        let currentRole = role ?? userSession?.selectedPrimaryRole ?? "BOTTOM"
        championStats = calculateChampionStats(
            from: matches,
            champions: champions,
            role: currentRole,
            filter: filter
        )
    }

    /// Calculates KPIs for the current role
    public func calculateKPIsForCurrentRole() async {
        guard let matches = matchState.data else { return }
        await calculateKPIs(matches: matches)
    }

    /// Gets role-specific KPIs for a specific champion
    public func getRoleSpecificKPIsForChampion(_ championStat: ChampionStats, role: String) async
        -> [KPIMetric]
    {
        guard let matches = matchState.data else { return [] }

        // Filter matches for this specific champion
        let championMatches = matches.filter { match in
            match.participants.contains { participant in
                participant.championId == championStat.champion.id
                    && participant.puuid == summoner.puuid
            }
        }

        guard !championMatches.isEmpty else { return [] }

        // Calculate KPIs for this champion's matches
        var kpis: [KPIMetric] = []

        // Calculate deaths per game
        let totalDeaths = championMatches.compactMap { match in
            match.participants.first {
                $0.championId == championStat.champion.id && $0.puuid == summoner.puuid
            }
        }.reduce(0) { $0 + $1.deaths }
        let deathsPerGame = Double(totalDeaths) / Double(championMatches.count)

        // Calculate vision score per minute
        let totalVisionScore = championMatches.compactMap { match in
            match.participants.first {
                $0.championId == championStat.champion.id && $0.puuid == summoner.puuid
            }
        }.reduce(0) { $0 + $1.visionScore }
        let totalGameTime = championMatches.reduce(0) { $0 + $1.gameDuration }
        let visionScorePerMin =
            totalGameTime > 0 ? Double(totalVisionScore) / (Double(totalGameTime) / 60.0) : 0.0

        // Calculate CS per minute
        let totalCS = championMatches.compactMap { match in
            match.participants.first {
                $0.championId == championStat.champion.id && $0.puuid == summoner.puuid
            }
        }.reduce(0) { $0 + $1.totalMinionsKilled }
        let csPerMin = totalGameTime > 0 ? Double(totalCS) / (Double(totalGameTime) / 60.0) : 0.0

        // Get baseline data for this role
        let baseline = await getBaselineForRole(role)

        // Create KPIs with proper baseline data
        kpis.append(
            KPIMetric(
                metric: "deaths_per_game",
                value: String(format: "%.1f", deathsPerGame),
                baseline: baseline,
                performanceLevel: .good,
                color: DesignSystem.Colors.accent
            ))

        kpis.append(
            KPIMetric(
                metric: "vision_score_per_min",
                value: String(format: "%.2f", visionScorePerMin),
                baseline: baseline,
                performanceLevel: .good,
                color: DesignSystem.Colors.accent
            ))

        kpis.append(
            KPIMetric(
                metric: "cs_per_min",
                value: String(format: "%.1f", csPerMin),
                baseline: baseline,
                performanceLevel: .good,
                color: DesignSystem.Colors.accent
            ))

        return kpis
    }

    /// Gets baseline data for a specific role
    private func getBaselineForRole(_ role: String) async -> Baseline? {
        guard let dataManager = dataManager else { return nil }

        do {
            // Try to get baseline for the role with "ALL" class tag
            let baselineRole = RoleUtils.normalizedRoleToBaselineRole(role)
            return try await dataManager.getBaseline(
                role: baselineRole,
                classTag: "ALL",
                metric: "deaths_per_game"  // Default metric for baseline lookup
            )
        } catch {
            ClaimbLogger.warning(
                "Failed to get baseline for role \(role)",
                service: "MatchDataViewModel",
                metadata: ["error": error.localizedDescription])
            return nil
        }
    }

    // MARK: - Private Methods

    /// Calculates champion statistics from matches and champions
    private func calculateChampionStats(matches: [Match], champions: [Champion]) async {
        guard let userSession = userSession else { return }

        let currentRole = userSession.selectedPrimaryRole
        championStats = calculateChampionStats(
            from: matches,
            champions: champions,
            role: currentRole,
            filter: .mostPlayed
        )
    }

    /// Calculates KPIs for matches
    private func calculateKPIs(matches: [Match]) async {
        guard let kpiCalculationService = kpiCalculationService,
            let userSession = userSession
        else { return }

        let role = userSession.selectedPrimaryRole

        do {
            // Use only the last 20 matches for KPI calculations (recent performance focus)
            let recentMatches = Array(matches.prefix(20))
            let roleKPIs = try await kpiCalculationService.calculateRoleKPIs(
                matches: recentMatches,
                role: role,
                summoner: summoner
            )

            let key = kpiCacheKey(matches: matches, role: role)

            // Sort KPIs by priority (worst performing first)
            let sortedKPIs = roleKPIs.sorted { $0.sortPriority < $1.sortPriority }

            kpiCache[key] = sortedKPIs
            kpiMetrics = sortedKPIs

            // Persist lightweight cache
            let persistedKey = kpiPersistPrefix + key
            let payload = roleKPIs.map { $0.toPersisted() }
            UserDefaults.standard.set(payload, forKey: persistedKey)

        } catch {
            ClaimbLogger.error(
                "Failed to calculate KPIs", service: "MatchDataViewModel", error: error)
            kpiMetrics = []
        }
    }

    // Attempts to serve KPIs from cache; returns true if served
    private func loadKPIsFromCacheIfAvailable(matches: [Match]) -> Bool {
        guard let userSession = userSession else { return false }
        let role = userSession.selectedPrimaryRole
        let key = kpiCacheKey(matches: matches, role: role)
        if let cached = kpiCache[key] {
            kpiMetrics = cached.sorted { $0.sortPriority < $1.sortPriority }
            ClaimbLogger.debug(
                "Served KPIs from cache", service: "MatchDataViewModel",
                metadata: [
                    "role": role,
                    "matchCount": String(matches.count),
                ])
            return true
        }
        // Try persisted cache
        let persistedKey = kpiPersistPrefix + key
        if let array = UserDefaults.standard.array(forKey: persistedKey) as? [[String: String]] {
            let restored = array.compactMap { KPIMetric.fromPersisted($0) }
            if !restored.isEmpty {
                let sortedRestored = restored.sorted { $0.sortPriority < $1.sortPriority }
                kpiCache[key] = sortedRestored
                kpiMetrics = sortedRestored
                ClaimbLogger.debug(
                    "Served KPIs from persisted cache", service: "MatchDataViewModel",
                    metadata: [
                        "role": role,
                        "matchCount": String(matches.count),
                    ])
                return true
            }
        }
        return false
    }

    /// Calculates role statistics from matches
    private func calculateRoleStats(from matches: [Match], summoner: Summoner) -> [RoleStats] {
        var roleStats: [String: (wins: Int, total: Int)] = [:]

        for match in matches {
            // Find the summoner's participant in this match
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                continue
            }

            let normalizedRole = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)
            let isWin = participant.win

            if roleStats[normalizedRole] == nil {
                roleStats[normalizedRole] = (wins: 0, total: 0)
            }

            roleStats[normalizedRole]?.total += 1
            if isWin {
                roleStats[normalizedRole]?.wins += 1
            }
        }

        // Convert to RoleStats array
        return roleStats.map { (role, stats) in
            let winRate = stats.total > 0 ? Double(stats.wins) / Double(stats.total) : 0.0
            return RoleStats(role: role, winRate: winRate, totalGames: stats.total)
        }.sorted { $0.totalGames > $1.totalGames }  // Sort by most played
    }

    /// Calculates champion statistics from matches and champions (delegates to ChampionStatsCalculator)
    private func calculateChampionStats(
        from matches: [Match], champions: [Champion], role: String, filter: ChampionFilter
    ) -> [ChampionStats] {
        return ChampionStatsCalculator.calculateChampionStats(
            from: matches,
            champions: champions,
            summoner: summoner,
            role: role,
            filter: filter
        )
    }

    /// Gets champion KPI display data using existing ChampionStats and baselines
    public func getChampionKPIDisplay(for championStat: ChampionStats, role: String)
        -> [ChampionKPIDisplay]
    {
        return KPIDisplayService.getChampionKPIDisplay(
            for: championStat,
            role: role,
            summoner: summoner,
            allMatches: currentMatches,
            baselineCache: baselineCache
        )
    }

    /// Loads all baselines into memory cache (eliminates async→sync RunLoop hack)
    private func loadBaselinesIntoCache() async {
        guard let dataManager = dataManager else {
            ClaimbLogger.debug(
                "No dataManager available for baseline loading",
                service: AppConstants.LoggingServices.matchDataViewModel
            )
            return
        }

        ClaimbLogger.info(
            "Pre-caching baselines to eliminate blocking pattern",
            service: AppConstants.LoggingServices.matchDataViewModel
        )

        do {
            // Load all baselines from database
            let descriptor = FetchDescriptor<Baseline>()
            let baselines = try dataManager.modelContext.fetch(descriptor)

            // Store in dictionary for O(1) lookup
            for baseline in baselines {
                let key = baselineCacheKey(
                    role: baseline.role,
                    classTag: baseline.classTag,
                    metric: baseline.metric
                )
                baselineCache[key] = baseline
            }

            baselinesLoaded = true

            ClaimbLogger.info(
                "Baselines cached in memory",
                service: AppConstants.LoggingServices.matchDataViewModel,
                metadata: [
                    "baselineCount": String(baselines.count),
                    "cacheSize": String(baselineCache.count),
                ]
            )
        } catch {
            ClaimbLogger.error(
                "Failed to load baselines into cache",
                service: AppConstants.LoggingServices.matchDataViewModel,
                error: error
            )
        }
    }

}

// MARK: - Supporting Types

public enum ChampionFilter: String, CaseIterable {
    case mostPlayed = "Most Played"
    case bestPerforming = "Best Performing"

    var description: String {
        switch self {
        case .mostPlayed:
            return "Champions you've played most frequently"
        case .bestPerforming:
            return "Champions where you excel based on performance"
        }
    }
}

public struct ChampionStats {
    public let champion: Champion
    public var gamesPlayed: Int
    public var wins: Int
    public var winRate: Double
    public var averageKDA: Double
    public var averageCS: Double
    public var averageVisionScore: Double
    public var averageDeaths: Double
    public var averageGoldPerMin: Double
    public var averageKillParticipation: Double
    public var averageObjectiveParticipation: Double
    public var averageTeamDamagePercent: Double
    public var averageDamageTakenShare: Double
}

public struct ChampionKPIDisplay {
    public let metric: String
    public let value: String
    public let performanceLevel: Baseline.PerformanceLevel
    public let color: Color

    public var displayName: String {
        switch metric {
        case "cs_per_min": return "CS/Min"
        case "deaths_per_game": return "Deaths"
        case "kill_participation_pct": return "Kill Part."
        case "team_damage_pct": return "Damage %"
        case "vision_score_per_min": return "Vision"
        case "objective_participation_pct": return "Objectives"
        case "damage_taken_share_pct": return "Dmg Taken"
        default: return metric
        }
    }
}

public struct KPIMetric {
    public let metric: String
    public let value: String
    public let baseline: Baseline?
    public let performanceLevel: Baseline.PerformanceLevel
    public let color: Color

    public var displayName: String {
        switch metric {
        case "deaths_per_game": return "Deaths per Game"
        case "vision_score_per_min": return "Vision Score/min"
        case "kill_participation_pct": return "Kill Participation"
        case "cs_per_min": return "CS per Minute"
        case "objective_participation_pct": return "Objective Participation"
        case "team_damage_pct": return "Damage Share"
        case "damage_taken_share_pct": return "Damage Taken Share"
        case "primary_role_consistency": return "Role Consistency"
        case "champion_pool_size": return "Champion Pool Size"
        default: return metric
        }
    }

    public var formattedValue: String {
        return value
    }

    /// Priority for sorting KPIs (lower number = higher priority = shown first)
    /// KPIs that need improvement are shown first, then good, then excellent
    public var sortPriority: Int {
        // Performance level priority (0 = needs improvement, 1 = good, 2 = excellent)
        let performancePriority: Int
        switch performanceLevel {
        case .needsImprovement: performancePriority = 0
        case .good: performancePriority = 1
        case .excellent: performancePriority = 2
        }

        // Metric type priority (within same performance level)
        let metricPriority: Int
        switch metric {
        case "deaths_per_game": metricPriority = 0  // Deaths is most important
        case "cs_per_min": metricPriority = 1  // CS is critical for laners
        case "vision_score_per_min": metricPriority = 2  // Vision is important
        case "kill_participation_pct": metricPriority = 3  // Kill participation
        case "objective_participation_pct": metricPriority = 4  // Objectives
        default: metricPriority = 5
        }

        // Combine priorities: performance level is primary, metric type is secondary
        return (performancePriority * 10) + metricPriority
    }

    // MARK: - Lightweight persistence helpers (no Color persistence)
    public func toPersisted() -> [String: String] {
        var dict: [String: String] = [
            "metric": metric,
            "value": value,
            "performanceLevel": performanceLevel.rawValue,
        ]
        if let baseline = baseline {
            dict["baseline_metric"] = baseline.metric
            dict["baseline_role"] = baseline.role
            dict["baseline_classTag"] = baseline.classTag
            dict["baseline_mean"] = String(baseline.mean)
            dict["baseline_median"] = String(baseline.median)
            dict["baseline_p40"] = String(baseline.p40)
            dict["baseline_p60"] = String(baseline.p60)
        }
        return dict
    }

    public static func fromPersisted(_ dict: [String: String]) -> KPIMetric? {
        guard
            let metric = dict["metric"],
            let value = dict["value"],
            let levelRaw = dict["performanceLevel"],
            let level = Baseline.PerformanceLevel(rawValue: levelRaw)
        else { return nil }

        var baseline: Baseline? = nil
        if let m = dict["baseline_metric"], let r = dict["baseline_role"],
            let c = dict["baseline_classTag"], let meanStr = dict["baseline_mean"],
            let medianStr = dict["baseline_median"], let p40Str = dict["baseline_p40"],
            let p60Str = dict["baseline_p60"], let mean = Double(meanStr),
            let median = Double(medianStr), let p40 = Double(p40Str), let p60 = Double(p60Str)
        {
            baseline = Baseline(
                role: r, classTag: c, metric: m, mean: mean, median: median, p40: p40, p60: p60)
        }

        // Use a neutral color; UI can recolor based on performance if needed
        return KPIMetric(
            metric: metric, value: value, baseline: baseline, performanceLevel: level,
            color: .primary)
    }
}
