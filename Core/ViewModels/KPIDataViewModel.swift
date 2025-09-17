//
//  KPIDataViewModel.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData
import SwiftUI

/// Shared view model for KPI calculations and performance metrics
@MainActor
@Observable
public class KPIDataViewModel {
    // MARK: - Published Properties

    public var matchState: UIState<[Match]> = .idle
    public var roleStats: [RoleStats] = []
    var kpiMetrics: [KPIMetric] = []
    public var isRefreshing = false

    // MARK: - Private Properties

    private let dataCoordinator: DataCoordinator?
    private let summoner: Summoner
    private let userSession: UserSession

    // MARK: - Initialization

    public init(dataCoordinator: DataCoordinator?, summoner: Summoner, userSession: UserSession) {
        self.dataCoordinator = dataCoordinator
        self.summoner = summoner
        self.userSession = userSession
    }

    // MARK: - Public Methods

    /// Loads matches and calculates KPIs
    public func loadData() async {
        guard let dataCoordinator = dataCoordinator else {
            matchState = .error(DataCoordinatorError.notAvailable)
            return
        }

        matchState = .loading

        // Load baseline data first
        _ = await dataCoordinator.loadBaselineData()

        let result = await dataCoordinator.loadMatches(for: summoner)

        matchState = result

        // Update role stats and KPIs if we have matches
        if case .loaded(let matches) = result {
            roleStats = dataCoordinator.calculateRoleStats(from: matches, summoner: summoner)
            await calculateKPIs(matches: matches)
        }
    }

    /// Refreshes matches and recalculates KPIs
    public func refreshData() async {
        guard let dataCoordinator = dataCoordinator else { return }

        isRefreshing = true

        let result = await dataCoordinator.refreshMatches(for: summoner)

        matchState = result
        isRefreshing = false

        // Update role stats and KPIs if we have matches
        if case .loaded(let matches) = result {
            roleStats = dataCoordinator.calculateRoleStats(from: matches, summoner: summoner)
            await calculateKPIs(matches: matches)
        }
    }

    /// Calculates KPIs for the current role
    public func calculateKPIsForCurrentRole() async {
        guard let matches = matchState.data else { return }
        await calculateKPIs(matches: matches)
    }

    /// Gets the current matches if loaded
    public var currentMatches: [Match] {
        return matchState.data ?? []
    }

    /// Checks if matches are currently loaded
    public var hasMatches: Bool {
        return matchState.isLoaded && !currentMatches.isEmpty
    }

    /// Gets KPIs for a specific role
    func getKPIsForRole(_ role: String) -> [KPIMetric] {
        return kpiMetrics.filter { $0.metric.contains(role.lowercased()) }
    }

    // MARK: - Private Methods

    private func calculateKPIs(matches: [Match]) async {
        guard let dataCoordinator = dataCoordinator else { return }

        let role = userSession.selectedPrimaryRole

        do {
            // Get role-specific participants
            let participants = matches.compactMap { match in
                match.participants.first(where: {
                    $0.puuid == summoner.puuid
                        && RoleUtils.normalizeRole($0.role, lane: $0.lane) == role
                })
            }

            guard !participants.isEmpty else {
                kpiMetrics = []
                return
            }

            // Create a temporary DataManager for KPI calculations
            // This is a bit of a workaround since we need DataManager for baseline calculations
            // In a more ideal setup, we'd have a KPI service that handles this
            let tempDataManager = DataManager(
                modelContext: userSession.modelContext,
                riotClient: RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey),
                dataDragonService: DataDragonService()
            )

            let roleKPIs = try await calculateRoleKPIs(
                matches: matches,
                role: role,
                dataManager: tempDataManager
            )

            kpiMetrics = roleKPIs

        } catch {
            ClaimbLogger.error(
                "Failed to calculate KPIs", service: "KPIDataViewModel", error: error)
            kpiMetrics = []
        }
    }

    private func calculateRoleKPIs(matches: [Match], role: String, dataManager: DataManager)
        async throws -> [KPIMetric]
    {
        guard !matches.isEmpty else { return [] }

        // Get role-specific participants
        let participants = matches.compactMap { match in
            match.participants.first(where: {
                $0.puuid == summoner.puuid
                    && RoleUtils.normalizeRole($0.role, lane: $0.lane) == role
            })
        }

        guard !participants.isEmpty else { return [] }

        // Load champion class mapping
        let classMappingService = ChampionClassMappingService()
        await classMappingService.loadChampionClassMapping(modelContext: userSession.modelContext)

        // Calculate basic KPIs
        let deathsPerGame =
            participants.map { Double($0.deaths) }.reduce(0, +) / Double(participants.count)
        let visionScore =
            participants.map { $0.visionScorePerMinute }.reduce(0, +) / Double(participants.count)
        let killParticipation =
            participants.map { participant in
                let match = matches.first { $0.participants.contains(participant) }
                let teamKills =
                    match?.participants
                    .filter { $0.teamId == participant.teamId }
                    .reduce(0) { $0 + $1.kills } ?? 0
                return teamKills > 0
                    ? Double(participant.kills + participant.assists) / Double(teamKills) : 0.0
            }.reduce(0, +) / Double(participants.count)

        // Calculate CS per minute
        let csPerMinute =
            participants.map { participant in
                let match = matches.first { $0.participants.contains(participant) }
                let gameDurationMinutes = Double(match?.gameDuration ?? 1800) / 60.0
                return gameDurationMinutes > 0
                    ? Double(participant.totalMinionsKilled) / gameDurationMinutes : 0.0
            }.reduce(0, +) / Double(participants.count)

        // Debug logging for KPI calculations
        ClaimbLogger.debug(
            "KPI Calculations for \(role)", service: "KPIDataViewModel",
            metadata: [
                "deathsPerGame": String(format: "%.2f", deathsPerGame),
                "visionScore": String(format: "%.2f", visionScore),
                "killParticipation": String(format: "%.2f", killParticipation),
                "csPerMinute": String(format: "%.2f", csPerMinute),
                "participantCount": String(participants.count),
            ])

        // Note: For deaths_per_game, lower values are better (reversed logic)

        var kpis: [KPIMetric] = []

        // Create KPIs with baseline comparison
        kpis.append(
            await createKPIMetric(
                metric: "deaths_per_game",
                value: deathsPerGame,
                role: role,
                matches: matches,
                dataManager: dataManager
            ))

        kpis.append(
            await createKPIMetric(
                metric: "vision_score_per_min",
                value: visionScore,
                role: role,
                matches: matches,
                dataManager: dataManager
            ))

        kpis.append(
            await createKPIMetric(
                metric: "kill_participation_pct",
                value: killParticipation,
                role: role,
                matches: matches,
                dataManager: dataManager
            ))

        // Add CS per minute for relevant roles
        // Check both original role and mapped role for CS per minute
        let shouldIncludeCS =
            ["MID", "MIDDLE", "ADC", "BOTTOM", "JUNGLE", "TOP"].contains(role)
            || ["MID", "MIDDLE", "ADC", "BOTTOM", "JUNGLE", "TOP"].contains(
                mapRoleToBaselineFormat(role))

        if shouldIncludeCS {
            kpis.append(
                await createKPIMetric(
                    metric: "cs_per_min",
                    value: csPerMinute,
                    role: role,
                    matches: matches,
                    dataManager: dataManager
                ))
        }

        // Add Primary Role Consistency KPI (last 20 games)
        let primaryRoleConsistency = calculatePrimaryRoleConsistency(
            matches: matches, primaryRole: role)
        kpis.append(
            await createKPIMetric(
                metric: "primary_role_consistency",
                value: primaryRoleConsistency,
                role: role,
                matches: matches,
                dataManager: dataManager
            ))

        // Add Champion Pool Size KPI (last 20 games) - role independent
        let championPoolSize = calculateChampionPoolSize(matches: matches)
        kpis.append(
            await createKPIMetric(
                metric: "champion_pool_size",
                value: championPoolSize,
                role: role,
                matches: matches,
                dataManager: dataManager
            ))

        return kpis
    }

    private func createKPIMetric(
        metric: String,
        value: Double,
        role: String,
        matches: [Match],
        dataManager: DataManager
    ) async -> KPIMetric {
        // Try to get baseline data for this metric and role
        let baseline = await getBaselineForMetric(
            metric: metric, role: role, dataManager: dataManager)

        let (performanceLevel, color) = getPerformanceLevelWithBaseline(
            value: value,
            metric: metric,
            baseline: baseline
        )

        return KPIMetric(
            metric: metric,
            value: value,
            baseline: baseline,
            performanceLevel: performanceLevel,
            color: color
        )
    }

    private func getBaselineForMetric(metric: String, role: String, dataManager: DataManager) async
        -> Baseline?
    {
        do {
            // Map role names to match baseline data format
            let baselineRole = mapRoleToBaselineFormat(role)

            // First try to get baseline for "ALL" class tag
            if let baseline = try await dataManager.getBaseline(
                role: baselineRole, classTag: "ALL", metric: metric)
            {
                ClaimbLogger.debug(
                    "Found baseline for \(metric) in \(baselineRole)", service: "KPIDataViewModel",
                    metadata: [
                        "mean": String(format: "%.3f", baseline.mean),
                        "p40": String(format: "%.3f", baseline.p40),
                        "p60": String(format: "%.3f", baseline.p60),
                    ])
                return baseline
            }

            // For custom KPIs that don't have baseline data, create hardcoded baselines
            if metric == "primary_role_consistency" {
                let customBaseline = Baseline(
                    role: baselineRole,
                    classTag: "ALL",
                    metric: metric,
                    mean: 75.0,  // 75% average role consistency
                    median: 75.0,  // 75% median role consistency
                    p40: 60.0,  // 60% for P40 (Below Average threshold)
                    p60: 84.0  // 84% for P60 (Excellent threshold)
                )
                ClaimbLogger.debug(
                    "Using hardcoded baseline for \(metric)", service: "KPIDataViewModel",
                    metadata: [
                        "mean": String(format: "%.1f", customBaseline.mean),
                        "p40": String(format: "%.1f", customBaseline.p40),
                        "p60": String(format: "%.1f", customBaseline.p60),
                    ])
                return customBaseline
            } else if metric == "champion_pool_size" {
                let customBaseline = Baseline(
                    role: baselineRole,
                    classTag: "ALL",
                    metric: metric,
                    mean: 4.0,  // 4 champions average
                    median: 4.0,  // 4 champions median
                    p40: 2.0,  // 2 champions for P40 (Below Average threshold)
                    p60: 5.0  // 5 champions for P60 (Good threshold)
                )
                ClaimbLogger.debug(
                    "Using hardcoded baseline for \(metric)", service: "KPIDataViewModel",
                    metadata: [
                        "mean": String(format: "%.1f", customBaseline.mean),
                        "p40": String(format: "%.1f", customBaseline.p40),
                        "p60": String(format: "%.1f", customBaseline.p60),
                    ])
                return customBaseline
            }

            ClaimbLogger.warning(
                "No baseline found for \(metric) in \(baselineRole)", service: "KPIDataViewModel")
            return nil
        } catch {
            ClaimbLogger.error(
                "Failed to get baseline for \(metric) in \(role)", service: "KPIDataViewModel",
                error: error)
            return nil
        }
    }

    private func mapRoleToBaselineFormat(_ role: String) -> String {
        switch role.uppercased() {
        case "MID":
            return "MIDDLE"
        case "ADC":
            return "BOTTOM"
        case "SUPPORT":
            return "UTILITY"
        case "JUNGLE":
            return "JUNGLE"
        case "TOP":
            return "TOP"
        default:
            return role.uppercased()
        }
    }

    // MARK: - New KPI Calculations

    /// Calculate primary role consistency percentage (last 20 games)
    private func calculatePrimaryRoleConsistency(
        matches: [Match], primaryRole: String
    ) -> Double {
        // Get last 20 games
        let recentMatches = Array(matches.prefix(20))
        
        guard !recentMatches.isEmpty else { return 0.0 }

        // Count games played in primary role
        let primaryRoleGames = recentMatches.compactMap { match in
            match.participants.first(where: {
                $0.puuid == summoner.puuid
                    && mapParticipantRoleToOurFormat($0.role) == primaryRole
            })
        }.count

        return Double(primaryRoleGames) / Double(recentMatches.count) * 100.0
    }

    /// Calculate champion pool size (unique champions in last 20 games) - role independent
    private func calculateChampionPoolSize(matches: [Match]) -> Double {
        // Get last 20 games
        let recentMatches = Array(matches.prefix(20))
        
        // Get all participants for the summoner across all roles
        let allParticipants = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })
        }

        // Count unique champions
        let uniqueChampions = Set(allParticipants.map { $0.championId }).count

        return Double(uniqueChampions)
    }

    /// Map participant team position to our role format
    private func mapParticipantRoleToOurFormat(_ teamPosition: String) -> String {
        switch teamPosition {
        case "MIDDLE":
            return "MID"
        case "BOTTOM":
            return "ADC"
        case "UTILITY":
            return "SUPPORT"
        case "JUNGLE", "TOP":
            return teamPosition
        default:
            return teamPosition
        }
    }

    private func getPerformanceLevelWithBaseline(value: Double, metric: String, baseline: Baseline?)
        -> (PerformanceLevel, Color)
    {
        // Custom logic for new KPIs that don't have baseline data
        if metric == "primary_role_consistency" {
            if value >= 84.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value >= 75.0 {
                return (.good, DesignSystem.Colors.white)
            } else if value >= 60.0 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.poor, DesignSystem.Colors.secondary)
            }
        } else if metric == "champion_pool_size" {
            if value >= 1.0 && value <= 3.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value >= 4.0 && value <= 5.0 {
                return (.good, DesignSystem.Colors.white)
            } else if value >= 6.0 && value <= 7.0 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.poor, DesignSystem.Colors.secondary)
            }
        } else if let baseline = baseline {
            // Special handling for Deaths per Game - lower is better
            if metric == "deaths_per_game" {
                if value <= baseline.p40 * 0.9 {
                    return (.excellent, DesignSystem.Colors.accent)
                } else if value <= baseline.p60 {
                    return (.good, DesignSystem.Colors.white)
                } else if value <= baseline.p60 * 1.2 {
                    return (.needsImprovement, DesignSystem.Colors.warning)
                } else {
                    return (.poor, DesignSystem.Colors.secondary)
                }
            } else {
                // Standard logic for other metrics - higher is better
                // More conservative thresholds for realistic performance assessment
                if value >= baseline.p60 * 1.1 {
                    return (.excellent, DesignSystem.Colors.accent)
                } else if value >= baseline.p60 {
                    return (.good, DesignSystem.Colors.white)
                } else if value >= baseline.p40 {
                    return (.needsImprovement, DesignSystem.Colors.warning)
                } else {
                    return (.poor, DesignSystem.Colors.secondary)
                }
            }
        } else {
            // Fallback to basic performance levels
            return getBasicPerformanceLevel(value: value, metric: metric)
        }
    }

    private func getBasicPerformanceLevel(value: Double, metric: String) -> (
        PerformanceLevel, Color
    ) {
        // Basic performance levels without baseline data
        switch metric {
        case "deaths_per_game":
            if value < 3.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value < 5.0 {
                return (.good, DesignSystem.Colors.white)
            } else if value < 7.0 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.poor, DesignSystem.Colors.secondary)
            }
        case "vision_score_per_min", "vision_score_per_minute":
            if value > 2.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value > 1.5 {
                return (.good, DesignSystem.Colors.white)
            } else if value > 1.0 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.poor, DesignSystem.Colors.secondary)
            }
        case "kill_participation_pct", "kill_participation":
            if value > 0.7 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value > 0.5 {
                return (.good, DesignSystem.Colors.white)
            } else if value > 0.3 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.poor, DesignSystem.Colors.secondary)
            }
        case "cs_per_min":
            if value > 8.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value > 6.5 {
                return (.good, DesignSystem.Colors.white)
            } else if value > 5.0 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.poor, DesignSystem.Colors.secondary)
            }
        default:
            return (.unknown, DesignSystem.Colors.textSecondary)
        }
    }
}
