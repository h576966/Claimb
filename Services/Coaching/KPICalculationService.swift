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
                    && RoleUtils.normalizeRole($0.role, lane: $0.lane) == role
            })
        }

        guard !participants.isEmpty else { return [] }

        // Calculate basic KPIs
        let deathsPerGame = calculateDeathsPerGame(participants: participants)
        let visionScore = calculateVisionScore(participants: participants)
        let killParticipation = calculateKillParticipation(
            participants: participants, matches: matches)
        let csPerMinute = calculateCSPerMinute(participants: participants, matches: matches)

        // Debug logging for KPI calculations
        ClaimbLogger.debug(
            "KPI Calculations for \(role)", service: "KPICalculationService",
            metadata: [
                "deathsPerGame": String(format: "%.2f", deathsPerGame),
                "visionScore": String(format: "%.2f", visionScore),
                "killParticipation": String(format: "%.2f", killParticipation),
                "csPerMinute": String(format: "%.2f", csPerMinute),
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

        // Add Primary Role Consistency KPI (last 20 games)
        let primaryRoleConsistency = calculatePrimaryRoleConsistency(
            matches: matches, primaryRole: role, summoner: summoner)
        kpis.append(
            await createKPIMetric(
                metric: "primary_role_consistency",
                value: primaryRoleConsistency,
                role: role,
                matches: matches
            ))

        // Add Champion Pool Size KPI (last 20 games) - role independent
        let championPoolSize = calculateChampionPoolSize(matches: matches, summoner: summoner)
        kpis.append(
            await createKPIMetric(
                metric: "champion_pool_size",
                value: championPoolSize,
                role: role,
                matches: matches
            ))

        return kpis
    }

    // MARK: - Private Calculation Methods

    private func calculateDeathsPerGame(participants: [Participant]) -> Double {
        return participants.map { Double($0.deaths) }.reduce(0, +) / Double(participants.count)
    }

    private func calculateVisionScore(participants: [Participant]) -> Double {
        return participants.map { $0.visionScorePerMinute }.reduce(0, +)
            / Double(participants.count)
    }

    private func calculateKillParticipation(participants: [Participant], matches: [Match]) -> Double
    {
        return participants.map { participant in
            let match = matches.first { $0.participants.contains(participant) }
            let teamKills =
                match?.participants
                .filter { $0.teamId == participant.teamId }
                .reduce(0) { $0 + $1.kills } ?? 0
            return teamKills > 0
                ? Double(participant.kills + participant.assists) / Double(teamKills) : 0.0
        }.reduce(0, +) / Double(participants.count)
    }

    private func calculateCSPerMinute(participants: [Participant], matches: [Match]) -> Double {
        return participants.map { participant in
            let match = matches.first { $0.participants.contains(participant) }
            let gameDurationMinutes = Double(match?.gameDuration ?? 1800) / 60.0
            return gameDurationMinutes > 0
                ? Double(participant.totalMinionsKilled) / gameDurationMinutes : 0.0
        }.reduce(0, +) / Double(participants.count)
    }

    private func calculatePrimaryRoleConsistency(
        matches: [Match], primaryRole: String, summoner: Summoner
    ) -> Double {
        // Get last 20 games
        let recentMatches = Array(matches.prefix(20))

        guard !recentMatches.isEmpty else { return 0.0 }

        // Count games played in primary role
        let primaryRoleGames = recentMatches.compactMap { match in
            match.participants.first(where: {
                $0.puuid == summoner.puuid
                    && RoleUtils.normalizeRole($0.role, lane: $0.lane) == primaryRole
            })
        }.count

        let consistency = Double(primaryRoleGames) / Double(recentMatches.count) * 100.0

        // Debug logging for role consistency calculation
        ClaimbLogger.debug(
            "Role Consistency Calculation", service: "KPICalculationService",
            metadata: [
                "primaryRole": primaryRole,
                "totalGames": String(recentMatches.count),
                "primaryRoleGames": String(primaryRoleGames),
                "consistency": String(format: "%.1f", consistency),
            ])

        return consistency
    }

    private func calculateChampionPoolSize(matches: [Match], summoner: Summoner) -> Double {
        // Get last 20 games
        let recentMatches = Array(matches.prefix(20))

        // Get all participants for the summoner across all roles
        let allParticipants = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })
        }

        // Count unique champions
        let uniqueChampions = Set(allParticipants.map { $0.championId }).count

        // Debug logging for champion pool size calculation
        ClaimbLogger.debug(
            "Champion Pool Size Calculation", service: "KPICalculationService",
            metadata: [
                "totalGames": String(recentMatches.count),
                "participantCount": String(allParticipants.count),
                "uniqueChampions": String(uniqueChampions),
                "championIds": allParticipants.map { String($0.championId) }.joined(separator: ","),
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

        // For Role Consistency and Champion Pool Size, use hardcoded targets if no baseline found
        let finalBaseline: Baseline?
        if baseline == nil
            && (metric == "primary_role_consistency" || metric == "champion_pool_size")
        {
            finalBaseline = createHardcodedBaseline(for: metric)
        } else {
            finalBaseline = baseline
        }

        let (performanceLevel, color) = getPerformanceLevelWithBaseline(
            value: value,
            metric: metric,
            baseline: finalBaseline
        )

        return KPIMetric(
            metric: metric,
            value: String(format: "%.2f", value),
            baseline: finalBaseline,
            performanceLevel: performanceLevel,
            color: color
        )
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
            // Special handling for Deaths per Game and Champion Pool Size - lower is better
            if metric == "deaths_per_game" || metric == "champion_pool_size" {
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
        case "primary_role_consistency":
            // Hardcoded target values for role consistency (accepted exception - these values are fundamental and don't change)
            if value > 80.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value > 70.0 {
                return (.good, DesignSystem.Colors.white)
            } else if value >= 65.0 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.needsImprovement, DesignSystem.Colors.secondary)
            }
        case "champion_pool_size":
            // Hardcoded target values for champion pool size (accepted exception - these values are fundamental and don't change)
            if value <= 3 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value <= 5 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        default:
            return (.needsImprovement, DesignSystem.Colors.textSecondary)
        }
    }

    /// Creates hardcoded baseline values for Role Consistency and Champion Pool Size
    /// These are fundamental metrics with well-established target values that don't change
    private func createHardcodedBaseline(for metric: String) -> Baseline? {
        switch metric {
        case "primary_role_consistency":
            // Role Consistency targets: 80%+ excellent, 70%+ good, 65% needs improvement
            return Baseline(
                role: "ALL",
                classTag: "ALL",
                metric: metric,
                mean: 70.0,  // Average role consistency
                median: 75.0,  // Median role consistency
                p40: 65.0,  // 40th percentile (needs improvement threshold)
                p60: 80.0  // 60th percentile (excellent threshold)
            )
        case "champion_pool_size":
            // Champion Pool Size targets: 1-3 excellent, 4-5 good, 6+ needs improvement
            return Baseline(
                role: "ALL",
                classTag: "ALL",
                metric: metric,
                mean: 4.0,  // Average champion pool size
                median: 3.0,  // Median champion pool size
                p40: 3.0,  // 40th percentile (excellent threshold)
                p60: 5.0  // 60th percentile (good threshold)
            )
        default:
            return nil
        }
    }
}
