//
//  KPICalculationService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-17.
//

import Foundation
import SwiftData
import SwiftUI

/// Service responsible for calculating KPI metrics and performance levels
@MainActor
public class KPICalculationService {
    private let dataManager: DataManager

    public init(dataManager: DataManager) {
        self.dataManager = dataManager
    }

    // MARK: - Public Methods

    /// Calculates diversity metrics for coaching analysis (last 10 games)
    func calculateDiversityMetrics(
        matches: [Match],
        summoner: Summoner
    ) -> (roleCount: Int, championCount: Int) {
        let recentMatches = Array(matches.prefix(10))

        guard !recentMatches.isEmpty else { return (0, 0) }

        // Count unique roles
        let uniqueRoles = Set(
            recentMatches.compactMap { match in
                match.participants.first(where: { $0.puuid == summoner.puuid })
                    .map { RoleUtils.normalizeRole(teamPosition: $0.teamPosition) }
            }
        ).count

        // Count unique champions
        let allParticipants = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })
        }
        let uniqueChampions = Set(allParticipants.map { $0.championId }).count

        ClaimbLogger.debug(
            "Diversity Metrics Calculated", service: "KPICalculationService",
            metadata: [
                "roleCount": String(uniqueRoles),
                "championCount": String(uniqueChampions),
                "totalGames": String(recentMatches.count),
            ])

        return (uniqueRoles, uniqueChampions)
    }

    /// Calculates all KPIs for a specific role and matches
    func calculateRoleKPIs(
        matches: [Match],
        role: String,
        summoner: Summoner
    ) async throws -> [KPIMetric] {
        guard !matches.isEmpty else { return [] }

        // Get role-specific participants
        let participants = matches.compactMap { match in
            match.participants.first(where: {
                $0.puuid == summoner.puuid
                    && RoleUtils.normalizeRole(teamPosition: $0.teamPosition) == role
            })
        }

        guard !participants.isEmpty else { return [] }

        // Calculate basic KPIs
        let deathsPerGame = calculateDeathsPerGame(participants: participants)
        let visionScore = calculateVisionScore(participants: participants)
        let killParticipation = calculateKillParticipation(
            participants: participants, matches: matches)
        let csPerMinute = calculateCSPerMinute(participants: participants, matches: matches)
        let objectiveParticipation = calculateObjectiveParticipation(
            participants: participants, matches: matches)

        // Debug logging for KPI calculations
        ClaimbLogger.debug(
            "KPI Calculations for \(role)", service: "KPICalculationService",
            metadata: [
                "deathsPerGame": String(format: "%.2f", deathsPerGame),
                "visionScore": String(format: "%.2f", visionScore),
                "killParticipation": String(format: "%.2f", killParticipation),
                "csPerMinute": String(format: "%.2f", csPerMinute),
                "objectiveParticipation": String(format: "%.2f", objectiveParticipation),
                "participantCount": String(participants.count),
            ])

        var kpis: [KPIMetric] = []

        // Create KPIs with baseline comparison
        kpis.append(
            await createKPIMetric(
                metric: "deaths_per_game",
                value: deathsPerGame,
                role: role,
                matches: matches
            ))

        kpis.append(
            await createKPIMetric(
                metric: "vision_score_per_min",
                value: visionScore,
                role: role,
                matches: matches
            ))

        kpis.append(
            await createKPIMetric(
                metric: "kill_participation_pct",
                value: killParticipation,
                role: role,
                matches: matches
            ))

        // Add CS per minute for relevant roles
        let shouldIncludeCS = shouldIncludeCSPerMinute(for: role)
        if shouldIncludeCS {
            kpis.append(
                await createKPIMetric(
                    metric: "cs_per_min",
                    value: csPerMinute,
                    role: role,
                    matches: matches
                ))
        }

        // Add objective participation for all roles
        kpis.append(
            await createKPIMetric(
                metric: "objective_participation_pct",
                value: objectiveParticipation,
                role: role,
                matches: matches
            ))

        // Note: Role Consistency and Champion Pool Size are now calculated for coaching use only
        // and are not displayed in the Performance section

        return kpis
    }

    // MARK: - Private Calculation Methods

    private func calculateDeathsPerGame(participants: [Participant]) -> Double {
        guard !participants.isEmpty else { return 0.0 }
        let totalDeaths = participants.map { Double($0.deaths) }.reduce(0, +)
        let result = totalDeaths / Double(participants.count)
        return result.isNaN ? 0.0 : result
    }

    private func calculateVisionScore(participants: [Participant]) -> Double {
        guard !participants.isEmpty else { return 0.0 }
        let totalVisionScore = participants.map { $0.visionScorePerMinute }.reduce(0, +)
        let result = totalVisionScore / Double(participants.count)
        return result.isNaN ? 0.0 : result
    }

    private func calculateKillParticipation(participants: [Participant], matches: [Match]) -> Double
    {
        guard !participants.isEmpty else { return 0.0 }
        let killParticipations = participants.map { participant in
            let match = matches.first { $0.participants.contains(participant) }
            let teamKills =
                match?.participants
                .filter { $0.teamId == participant.teamId }
                .reduce(0) { $0 + $1.kills } ?? 0
            let participation =
                teamKills > 0
                ? Double(participant.kills + participant.assists) / Double(teamKills) : 0.0
            return participation.isNaN ? 0.0 : participation
        }
        let result = killParticipations.reduce(0, +) / Double(participants.count)
        return result.isNaN ? 0.0 : result
    }

    private func calculateCSPerMinute(participants: [Participant], matches: [Match]) -> Double {
        guard !participants.isEmpty else { return 0.0 }
        let csPerMinuteValues = participants.map { participant in
            let match = matches.first { $0.participants.contains(participant) }
            let gameDurationMinutes = Double(match?.gameDuration ?? 1800) / 60.0
            let csPerMin =
                gameDurationMinutes > 0
                ? Double(participant.totalMinionsKilled) / gameDurationMinutes : 0.0
            return csPerMin.isNaN ? 0.0 : csPerMin
        }
        let result = csPerMinuteValues.reduce(0, +) / Double(participants.count)
        return result.isNaN ? 0.0 : result
    }

    private func calculateObjectiveParticipation(participants: [Participant], matches: [Match])
        -> Double
    {
        guard !participants.isEmpty else { return 0.0 }
        let objectiveParticipations = participants.map { participant in
            let match = matches.first { $0.participants.contains(participant) }
            let teamObjectives = match?.getTeamObjectives(teamId: participant.teamId) ?? 0

            if teamObjectives == 0 {
                return 0.0
            }

            let totalParticipated =
                participant.dragonTakedowns + participant.riftHeraldTakedowns
                + participant.baronTakedowns + participant.hordeTakedowns
                + participant.atakhanTakedowns

            let participation = Double(totalParticipated) / Double(teamObjectives)
            return participation.isNaN ? 0.0 : participation
        }
        let result = objectiveParticipations.reduce(0, +) / Double(participants.count)
        return result.isNaN ? 0.0 : result
    }

    private func calculatePrimaryRoleConsistency(
        matches: [Match], primaryRole: String, summoner: Summoner
    ) -> Double {
        // Get last 10 games for coaching analysis
        let recentMatches = Array(matches.prefix(10))

        guard !recentMatches.isEmpty else { return 0.0 }

        // Count unique roles played in last 10 games
        let uniqueRoles = Set(
            recentMatches.compactMap { match in
                match.participants.first(where: { $0.puuid == summoner.puuid })
                    .map { RoleUtils.normalizeRole(teamPosition: $0.teamPosition) }
            }
        ).count

        // Debug logging for simplified role consistency calculation
        ClaimbLogger.debug(
            "Role Diversity Calculation", service: "KPICalculationService",
            metadata: [
                "primaryRole": primaryRole,
                "totalGames": String(recentMatches.count),
                "uniqueRoles": String(uniqueRoles),
            ])

        return Double(uniqueRoles)
    }

    private func calculateChampionPoolSize(matches: [Match], summoner: Summoner) -> Double {
        // Get last 10 games for coaching analysis
        let recentMatches = Array(matches.prefix(10))

        // Get all participants for the summoner across all roles
        let allParticipants = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })
        }

        // Count unique champions
        let uniqueChampions = Set(allParticipants.map { $0.championId }).count

        // Debug logging for simplified champion pool size calculation
        ClaimbLogger.debug(
            "Champion Diversity Calculation", service: "KPICalculationService",
            metadata: [
                "totalGames": String(recentMatches.count),
                "participantCount": String(allParticipants.count),
                "uniqueChampions": String(uniqueChampions),
            ])

        return Double(uniqueChampions)
    }

    // MARK: - Helper Methods

    private func shouldIncludeCSPerMinute(for role: String) -> Bool {
        let csEligibleRoles = ["MID", "MIDDLE", "ADC", "BOTTOM", "JUNGLE", "TOP"]
        return csEligibleRoles.contains(role)
            || csEligibleRoles.contains(mapRoleToBaselineFormat(role))
    }

    private func createKPIMetric(
        metric: String,
        value: Double,
        role: String,
        matches: [Match]
    ) async -> KPIMetric {
        // Try to get baseline data for this metric and role
        let baseline = await getBaselineForMetric(metric: metric, role: role)

        // Use baseline if available
        let finalBaseline = baseline

        let (performanceLevel, color) = getPerformanceLevelWithBaseline(
            value: value,
            metric: metric,
            baseline: finalBaseline
        )

        return KPIMetric(
            metric: metric,
            value: formatKPIValue(value, for: metric),
            baseline: finalBaseline,
            performanceLevel: performanceLevel,
            color: color
        )
    }

    /// Formats KPI values according to their specific requirements
    private func formatKPIValue(_ value: Double, for metric: String) -> String {
        // Ensure value is not NaN or infinite
        let safeValue = value.isNaN || value.isInfinite ? 0.0 : value

        switch metric {
        case "deaths_per_game":
            // Deaths per Game: 1 decimal place
            return String(format: "%.1f", safeValue)
        case "kill_participation_pct":
            // Kill Participation: percentage (0.45 -> 45%)
            return String(format: "%.0f%%", safeValue * 100)
        case "cs_per_min":
            // CS per Minute: 1 decimal place
            return String(format: "%.1f", safeValue)
        case "primary_role_consistency":
            // Role Consistency: percentage (55.00 -> 55%)
            return String(format: "%.0f%%", safeValue)
        case "champion_pool_size":
            // Champion Pool Size: integer (6.00 -> 6)
            return String(format: "%.0f", safeValue)
        case "vision_score_per_min":
            // Vision Score per Minute: 1 decimal place
            return String(format: "%.1f", safeValue)
        case "objective_participation_pct", "team_damage_pct", "damage_taken_share_pct":
            // Other percentage metrics: percentage format
            return String(format: "%.0f%%", safeValue * 100)
        default:
            // Default: 1 decimal place
            return String(format: "%.1f", safeValue)
        }
    }

    private func getBaselineForMetric(metric: String, role: String) async -> Baseline? {
        do {
            // Map role names to match baseline data format
            let baselineRole = mapRoleToBaselineFormat(role)

            // Try to get baseline for "ALL" class tag
            if let baseline = try await dataManager.getBaseline(
                role: baselineRole, classTag: "ALL", metric: metric)
            {
                ClaimbLogger.debug(
                    "Found baseline for \(metric) in \(baselineRole)",
                    service: "KPICalculationService",
                    metadata: [
                        "mean": String(format: "%.3f", baseline.mean),
                        "p40": String(format: "%.3f", baseline.p40),
                        "p60": String(format: "%.3f", baseline.p60),
                    ])
                return baseline
            }

            ClaimbLogger.warning(
                "No baseline found for \(metric) in \(baselineRole)",
                service: "KPICalculationService")
            return nil
        } catch {
            ClaimbLogger.error(
                "Failed to get baseline for \(metric) in \(role)", service: "KPICalculationService",
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

    private func getPerformanceLevelWithBaseline(value: Double, metric: String, baseline: Baseline?)
        -> (Baseline.PerformanceLevel, Color)
    {
        if let baseline = baseline {
            // Special handling for Deaths per Game - lower is better
            if metric == "deaths_per_game" {
                if value <= baseline.p40 {
                    return (.excellent, DesignSystem.Colors.accent)
                } else if value < baseline.mean {
                    return (.good, DesignSystem.Colors.white)
                } else if value <= baseline.p60 * 1.2 {
                    return (.needsImprovement, DesignSystem.Colors.warning)
                } else {
                    return (.needsImprovement, DesignSystem.Colors.secondary)
                }
            } else {
                // Standard logic for other metrics - higher is better
                if value >= baseline.p60 {
                    return (.excellent, DesignSystem.Colors.accent)
                } else if value > baseline.mean {
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

    private func getBasicPerformanceLevel(value: Double, metric: String) -> (
        Baseline.PerformanceLevel, Color
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
                return (.needsImprovement, DesignSystem.Colors.secondary)
            }
        case "vision_score_per_min", "vision_score_per_minute":
            if value > 2.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value > 1.5 {
                return (.good, DesignSystem.Colors.white)
            } else if value > 1.0 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.needsImprovement, DesignSystem.Colors.secondary)
            }
        case "kill_participation_pct", "kill_participation":
            if value > 0.7 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value > 0.5 {
                return (.good, DesignSystem.Colors.white)
            } else if value > 0.3 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.needsImprovement, DesignSystem.Colors.secondary)
            }
        case "cs_per_min":
            if value > 8.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value > 6.5 {
                return (.good, DesignSystem.Colors.white)
            } else if value > 5.0 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.needsImprovement, DesignSystem.Colors.secondary)
            }
        default:
            return (.needsImprovement, DesignSystem.Colors.textSecondary)
        }
    }

}
