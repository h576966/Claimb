//
//  MatchDataViewModel.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
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
    private let kpiCalculationService: KPICalculationService?
    // Note: Using private var for task management, accessed carefully in deinit
    private var currentTask: Task<Void, Never>?

    // MARK: - In-Memory Caches
    private var kpiCache: [String: [KPIMetric]] = [:]
    private let kpiPersistPrefix = "kpiCache_"

    private func kpiCacheKey(matches: [Match], role: String) -> String {
        let count = matches.count
        let latestId = matches.first?.matchId ?? "none"
        return "\(summoner.puuid)|\(role)|\(count)|\(latestId)"
    }

    // MARK: - Initialization

    public init(dataManager: DataManager?, summoner: Summoner, userSession: UserSession? = nil) {
        self.dataManager = dataManager
        self.summoner = summoner
        self.userSession = userSession

        // Initialize KPI calculation service if userSession is provided
        if let userSession = userSession {
            let kpiDataManager = DataManager.create(with: userSession.modelContext)
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
        // TODO: Implement proper baseline loading for champion-specific KPIs
        // For now, return nil to avoid compilation issues
        return nil
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
            let roleKPIs = try await kpiCalculationService.calculateRoleKPIs(
                matches: matches,
                role: role,
                summoner: summoner
            )

            let key = kpiCacheKey(matches: matches, role: role)
            kpiCache[key] = roleKPIs
            kpiMetrics = roleKPIs

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
            kpiMetrics = cached
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
                kpiCache[key] = restored
                kpiMetrics = restored
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

            let normalizedRole = RoleUtils.normalizeRole(participant.role, lane: participant.lane)
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

    /// Calculates champion statistics from matches and champions
    private func calculateChampionStats(
        from matches: [Match], champions: [Champion], role: String, filter: ChampionFilter
    ) -> [ChampionStats] {
        var championStats: [String: ChampionStats] = [:]

        for match in matches {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                continue
            }

            let championId = participant.championId
            let champion = champions.first { $0.id == championId }

            guard let champion = champion else { continue }

            let actualRole = RoleUtils.normalizeRole(participant.role, lane: participant.lane)

            // Only include champions played in the selected role
            if actualRole != role {
                continue
            }

            if championStats[champion.name] == nil {
                championStats[champion.name] = ChampionStats(
                    champion: champion,
                    gamesPlayed: 0,
                    wins: 0,
                    winRate: 0.0,
                    averageKDA: 0.0,
                    averageCS: 0.0,
                    averageVisionScore: 0.0,
                    averageDeaths: 0.0,
                    averageGoldPerMin: 0.0,
                    averageKillParticipation: 0.0,
                    averageObjectiveParticipation: 0.0,
                    averageTeamDamagePercent: 0.0,
                    averageDamageTakenShare: 0.0
                )
            }

            championStats[champion.name]?.gamesPlayed += 1
            if participant.win {
                championStats[champion.name]?.wins += 1
            }

            // Update averages (simplified calculation)
            let current = championStats[champion.name]!
            let newKDA =
                (current.averageKDA * Double(current.gamesPlayed - 1) + participant.kda)
                / Double(current.gamesPlayed)
            let newCS =
                (current.averageCS * Double(current.gamesPlayed - 1) + participant.csPerMinute)
                / Double(current.gamesPlayed)
            let newVision =
                (current.averageVisionScore * Double(current.gamesPlayed - 1)
                    + participant.visionScorePerMinute) / Double(current.gamesPlayed)
            let newDeaths =
                (current.averageDeaths * Double(current.gamesPlayed - 1)
                    + Double(participant.deaths)) / Double(current.gamesPlayed)
            championStats[champion.name]?.averageKDA = newKDA
            championStats[champion.name]?.averageCS = newCS
            championStats[champion.name]?.averageVisionScore = newVision
            championStats[champion.name]?.averageDeaths = newDeaths
            // Note: Other metrics (kill participation, team damage, etc.) are calculated
            // directly from match data in getChampionKPIDisplay to avoid duplication with KPICalculationService
        }

        // Filter champions with at least minimum games and calculate win rates
        let filteredStats = championStats.values.compactMap { stats -> ChampionStats? in
            guard stats.gamesPlayed >= AppConstants.ChampionFiltering.minimumGamesForBestPerforming
            else { return nil }

            let winRate =
                stats.gamesPlayed > 0 ? Double(stats.wins) / Double(stats.gamesPlayed) : 0.0

            return ChampionStats(
                champion: stats.champion,
                gamesPlayed: stats.gamesPlayed,
                wins: stats.wins,
                winRate: winRate,
                averageKDA: stats.averageKDA,
                averageCS: stats.averageCS,
                averageVisionScore: stats.averageVisionScore,
                averageDeaths: stats.averageDeaths,
                averageGoldPerMin: stats.averageGoldPerMin,
                averageKillParticipation: stats.averageKillParticipation,
                averageObjectiveParticipation: stats.averageObjectiveParticipation,
                averageTeamDamagePercent: stats.averageTeamDamagePercent,
                averageDamageTakenShare: stats.averageDamageTakenShare
            )
        }

        // Apply sorting and filtering based on filter type
        switch filter {
        case .mostPlayed:
            return filteredStats.sorted { $0.gamesPlayed > $1.gamesPlayed }
        case .bestPerforming:
            return applyBestPerformingFilter(to: filteredStats)
        }
    }

    /// Applies smart filtering for Best Performing champions
    private func applyBestPerformingFilter(to stats: [ChampionStats]) -> [ChampionStats] {
        // First try with default 50% win rate threshold
        let highPerformers = stats.filter {
            $0.winRate >= AppConstants.ChampionFiltering.defaultWinRateThreshold
        }

        // If we have enough champions, return them sorted by win rate
        if highPerformers.count >= AppConstants.ChampionFiltering.minimumChampionsForFallback {
            ClaimbLogger.debug(
                "Using default win rate threshold for Best Performing",
                service: AppConstants.LoggingServices.matchDataViewModel,
                metadata: [
                    "threshold": String(AppConstants.ChampionFiltering.defaultWinRateThreshold),
                    "championCount": String(highPerformers.count),
                ]
            )
            return highPerformers.sorted { $0.winRate > $1.winRate }
        }

        // Fallback to 40% threshold if too few champions meet 50% criteria
        let fallbackPerformers = stats.filter {
            $0.winRate >= AppConstants.ChampionFiltering.fallbackWinRateThreshold
        }

        ClaimbLogger.debug(
            "Using fallback win rate threshold for Best Performing",
            service: AppConstants.LoggingServices.matchDataViewModel,
            metadata: [
                "defaultThreshold": String(AppConstants.ChampionFiltering.defaultWinRateThreshold),
                "fallbackThreshold": String(
                    AppConstants.ChampionFiltering.fallbackWinRateThreshold),
                "defaultCount": String(highPerformers.count),
                "fallbackCount": String(fallbackPerformers.count),
            ]
        )

        return fallbackPerformers.sorted { $0.winRate > $1.winRate }
    }

    /// Converts normalized role names to baseline role names
    private func normalizedRoleToBaselineRole(_ role: String) -> String {
        switch role.uppercased() {
        case "MID": return "MIDDLE"
        case "BOTTOM": return "BOTTOM"
        case "TOP": return "TOP"
        case "JUNGLE": return "JUNGLE"
        case "SUPPORT": return "UTILITY"
        default: return role.uppercased()
        }
    }

    /// Gets champion KPI display data using existing ChampionStats and baselines
    public func getChampionKPIDisplay(for championStat: ChampionStats, role: String)
        -> [ChampionKPIDisplay]
    {
        let championClass = championStat.champion.championClass
        let baselineRole = normalizedRoleToBaselineRole(role)
        let keyMetrics = AppConstants.ChampionKPIs.keyMetricsByRole[baselineRole] ?? []

        ClaimbLogger.debug(
            "Getting champion KPI display",
            service: AppConstants.LoggingServices.matchDataViewModel,
            metadata: [
                "champion": championStat.champion.name,
                "championClass": championClass,
                "role": role,
                "baselineRole": baselineRole,
                "keyMetrics": keyMetrics.joined(separator: ", "),
            ]
        )

        // Get champion-specific matches for this role
        let championMatches = getChampionMatches(for: championStat.champion, role: role)

        guard !championMatches.isEmpty else {
            ClaimbLogger.debug(
                "No matches found for champion",
                service: AppConstants.LoggingServices.matchDataViewModel,
                metadata: [
                    "champion": championStat.champion.name,
                    "role": role,
                ]
            )
            return []
        }

        let results = keyMetrics.compactMap { metric in
            let value = calculateChampionMetricValue(
                metric: metric,
                matches: championMatches,
                champion: championStat.champion,
                role: role
            )

            // Try to get baseline for specific class, fallback to "ALL"
            let baseline =
                getBaselineSync(role: baselineRole, classTag: championClass, metric: metric)
                ?? getBaselineSync(role: baselineRole, classTag: "ALL", metric: metric)

            // Use the same logic as KPICalculationService for consistent color coding
            let (performanceLevel, _) = getPerformanceLevelWithBaseline(
                value: value,
                metric: metric,
                baseline: baseline
            )

            ClaimbLogger.debug(
                "KPI calculation",
                service: AppConstants.LoggingServices.matchDataViewModel,
                metadata: [
                    "metric": metric,
                    "value": String(value),
                    "formattedValue": formatValue(value, for: metric),
                    "hasBaseline": baseline != nil ? "true" : "false",
                    "performanceLevel": performanceLevel.rawValue,
                ]
            )

            return ChampionKPIDisplay(
                metric: metric,
                value: formatValue(value, for: metric),
                performanceLevel: performanceLevel,
                color: getPerformanceColor(performanceLevel)
            )
        }

        ClaimbLogger.debug(
            "Champion KPI display results",
            service: AppConstants.LoggingServices.matchDataViewModel,
            metadata: [
                "champion": championStat.champion.name,
                "resultCount": String(results.count),
            ]
        )

        return results
    }

    /// Gets champion-specific matches for a role
    private func getChampionMatches(for champion: Champion, role: String) -> [Match] {
        return currentMatches.filter { match in
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                return false
            }
            let actualRole = RoleUtils.normalizeRole(participant.role, lane: participant.lane)
            return participant.championId == champion.id && actualRole == role
        }
    }

    /// Calculates metric value using KPICalculationService logic (reused to avoid duplication)
    private func calculateChampionMetricValue(
        metric: String, matches: [Match], champion: Champion, role: String
    ) -> Double {
        let participants = matches.compactMap { match in
            match.participants.first(where: {
                $0.puuid == summoner.puuid && $0.championId == champion.id
            })
        }

        guard !participants.isEmpty else { return 0.0 }

        switch metric {
        case "cs_per_min":
            return participants.map { participant in
                let match = matches.first { $0.participants.contains(participant) }
                let gameDurationMinutes = Double(match?.gameDuration ?? 1800) / 60.0
                return gameDurationMinutes > 0
                    ? Double(participant.totalMinionsKilled) / gameDurationMinutes : 0.0
            }.reduce(0, +) / Double(participants.count)

        case "deaths_per_game":
            return participants.map { Double($0.deaths) }.reduce(0, +) / Double(participants.count)

        case "kill_participation_pct":
            return participants.map { participant in
                let match = matches.first { $0.participants.contains(participant) }
                let teamKills =
                    match?.participants
                    .filter { $0.teamId == participant.teamId }
                    .reduce(0) { $0 + $1.kills } ?? 0
                return teamKills > 0
                    ? Double(participant.kills + participant.assists) / Double(teamKills) : 0.0
            }.reduce(0, +) / Double(participants.count)

        case "vision_score_per_min":
            return participants.map { $0.visionScorePerMinute }.reduce(0, +)
                / Double(participants.count)

        case "team_damage_pct":
            return participants.map { $0.teamDamagePercentage }.reduce(0, +)
                / Double(participants.count)

        case "objective_participation_pct":
            return participants.map { $0.objectiveParticipationPercentage }.reduce(0, +)
                / Double(participants.count)

        case "damage_taken_share_pct":
            return participants.map { $0.damageTakenSharePercentage }.reduce(0, +)
                / Double(participants.count)

        default:
            return 0.0
        }
    }

    /// Synchronous baseline lookup (baselines are already loaded)
    private func getBaselineSync(role: String, classTag: String, metric: String) -> Baseline? {
        guard let dataManager = dataManager else {
            ClaimbLogger.debug(
                "No dataManager available for baseline lookup",
                service: AppConstants.LoggingServices.matchDataViewModel)
            return nil
        }

        // Use RunLoop to avoid deadlocks with semaphores on MainActor
        var result: Baseline?
        var completed = false

        Task {
            do {
                result = try await dataManager.getBaseline(
                    role: role, classTag: classTag, metric: metric)
                ClaimbLogger.debug(
                    "Baseline lookup result",
                    service: AppConstants.LoggingServices.matchDataViewModel,
                    metadata: [
                        "role": role,
                        "classTag": classTag,
                        "metric": metric,
                        "found": result != nil ? "true" : "false",
                    ]
                )
            } catch {
                ClaimbLogger.debug(
                    "Baseline lookup failed",
                    service: AppConstants.LoggingServices.matchDataViewModel,
                    metadata: [
                        "role": role,
                        "classTag": classTag,
                        "metric": metric,
                        "error": error.localizedDescription,
                    ]
                )
                result = nil
            }
            completed = true
        }

        // Wait for completion with timeout
        let timeout = Date().addingTimeInterval(1.0)  // 1 second timeout
        while !completed && Date() < timeout {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        if !completed {
            ClaimbLogger.warning(
                "Baseline lookup timed out",
                service: AppConstants.LoggingServices.matchDataViewModel,
                metadata: [
                    "role": role,
                    "classTag": classTag,
                    "metric": metric,
                ]
            )
        }

        return result
    }

    /// Formats metric values for display
    private func formatValue(_ value: Double, for metric: String) -> String {
        switch metric {
        case "kill_participation_pct", "team_damage_pct", "objective_participation_pct",
            "damage_taken_share_pct":
            return String(format: "%.0f%%", value * 100)
        case "cs_per_min", "vision_score_per_min":
            return String(format: "%.1f", value)
        case "deaths_per_game":
            return String(format: "%.1f", value)
        default:
            return String(format: "%.1f", value)
        }
    }

    /// Gets performance color based on level
    private func getPerformanceColor(_ level: Baseline.PerformanceLevel) -> Color {
        switch level {
        case .excellent: return DesignSystem.Colors.accent
        case .good: return DesignSystem.Colors.primary
        case .needsImprovement: return DesignSystem.Colors.secondary
        }
    }

    /// Gets performance level and color using the same logic as KPICalculationService
    private func getPerformanceLevelWithBaseline(value: Double, metric: String, baseline: Baseline?)
        -> (Baseline.PerformanceLevel, Color)
    {
        if let baseline = baseline {
            // Special handling for Deaths per Game - lower is better
            if metric == "deaths_per_game" {
                if value <= baseline.p40 * 0.9 {
                    return (.excellent, DesignSystem.Colors.accent)
                } else if value <= baseline.p60 {
                    return (.good, DesignSystem.Colors.white)
                } else if value <= baseline.p60 * 1.2 {
                    return (.needsImprovement, DesignSystem.Colors.warning)
                } else {
                    return (.needsImprovement, DesignSystem.Colors.secondary)
                }
            } else {
                // Standard logic for other metrics - higher is better
                if value >= baseline.p60 * 1.1 {
                    return (.excellent, DesignSystem.Colors.accent)
                } else if value >= baseline.p60 {
                    return (.good, DesignSystem.Colors.white)
                } else if value >= baseline.p40 {
                    return (.needsImprovement, DesignSystem.Colors.warning)
                } else {
                    return (.needsImprovement, DesignSystem.Colors.secondary)
                }
            }
        } else {
            // Fallback to basic performance levels
            return getBasicPerformanceLevel(value: value, metric: metric)
        }
    }

    /// Basic performance levels without baseline data
    private func getBasicPerformanceLevel(value: Double, metric: String) -> (
        Baseline.PerformanceLevel, Color
    ) {
        // Basic performance levels without baseline data
        switch metric {
        case "deaths_per_game":
            // For deaths, lower is better
            if value <= 3.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value <= 5.0 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        case "kill_participation_pct", "objective_participation_pct", "team_damage_pct", "damage_taken_share_pct":
            // Percentage metrics - higher is better
            if value >= 0.7 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value >= 0.5 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        case "cs_per_min", "vision_score_per_min":
            // Rate metrics - higher is better
            if value >= 8.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value >= 6.0 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        default:
            return (.needsImprovement, DesignSystem.Colors.warning)
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
