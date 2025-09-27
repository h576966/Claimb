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
    // Note: nonisolated(unsafe) is required for deinit access, despite compiler warning
    nonisolated(unsafe) private var currentTask: Task<Void, Never>?

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

                // Calculate KPIs if userSession is available
                if userSession != nil {
                    await calculateKPIs(matches: matchData)
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
        currentTask?.cancel()
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

            kpiMetrics = roleKPIs

        } catch {
            ClaimbLogger.error(
                "Failed to calculate KPIs", service: "MatchDataViewModel", error: error)
            kpiMetrics = []
        }
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
        }

        // Filter champions with at least 3 games and calculate win rates
        let filteredStats = championStats.values.compactMap { stats -> ChampionStats? in
            guard stats.gamesPlayed >= 3 else { return nil }

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

        // Apply sorting based on filter type
        switch filter {
        case .mostPlayed:
            return filteredStats.sorted { $0.gamesPlayed > $1.gamesPlayed }
        case .bestPerforming:
            return filteredStats.sorted { $0.winRate > $1.winRate }
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
}
