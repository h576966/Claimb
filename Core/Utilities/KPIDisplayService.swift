//
//  KPIDisplayService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-10.
//

import Foundation
import SwiftData
import SwiftUI

/// Service for calculating and displaying champion KPIs with baseline comparisons
/// Extracted from MatchDataViewModel to reduce file size and improve testability
public struct KPIDisplayService {

    // MARK: - KPI Display Calculation

    /// Gets champion KPI display data using baselines from cache
    public static func getChampionKPIDisplay(
        for championStat: ChampionStats,
        role: String,
        summoner: Summoner,
        allMatches: [Match],
        baselineCache: [String: Baseline]
    ) -> [ChampionKPIDisplay] {
        let championClass = championStat.champion.championClass
        let baselineRole = RoleUtils.normalizedRoleToBaselineRole(role)
        let keyMetrics = AppConstants.ChampionKPIs.keyMetricsByRole[baselineRole] ?? []

        ClaimbLogger.debug(
            "Getting champion KPI display",
            service: "KPIDisplayService",
            metadata: [
                "champion": championStat.champion.name,
                "championClass": championClass,
                "role": role,
                "baselineRole": baselineRole,
                "keyMetrics": keyMetrics.joined(separator: ", "),
            ]
        )

        // Get champion-specific matches for this role
        let championMatches = ChampionStatsCalculator.getChampionMatches(
            for: championStat.champion,
            role: role,
            summoner: summoner,
            allMatches: allMatches
        )
        let recentChampionMatches = Array(championMatches.prefix(20))

        guard !recentChampionMatches.isEmpty else {
            ClaimbLogger.debug(
                "No recent matches found for champion",
                service: "KPIDisplayService",
                metadata: [
                    "champion": championStat.champion.name,
                    "role": role,
                    "totalMatches": String(championMatches.count),
                    "recentMatches": String(recentChampionMatches.count),
                ]
            )
            return []
        }

        let results = keyMetrics.compactMap { metric in
            let value = calculateChampionMetricValue(
                metric: metric,
                matches: recentChampionMatches,
                champion: championStat.champion,
                role: role,
                summoner: summoner
            )

            // Try to get baseline for specific class, fallback to "ALL"
            let baseline =
                getBaselineFromCache(
                    role: baselineRole,
                    classTag: championClass,
                    metric: metric,
                    cache: baselineCache
                )
                ?? getBaselineFromCache(
                    role: baselineRole,
                    classTag: "ALL",
                    metric: metric,
                    cache: baselineCache
                )

            // Use the same logic as KPICalculationService for consistent color coding
            let (performanceLevel, color) = getPerformanceLevelWithBaseline(
                value: value,
                metric: metric,
                baseline: baseline
            )

            ClaimbLogger.debug(
                "KPI calculation",
                service: "KPIDisplayService",
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
                color: color
            )
        }

        ClaimbLogger.debug(
            "Champion KPI display results",
            service: "KPIDisplayService",
            metadata: [
                "champion": championStat.champion.name,
                "resultCount": String(results.count),
            ]
        )

        return results
    }

    // MARK: - Metric Calculation

    /// Calculates metric value for a champion
    private static func calculateChampionMetricValue(
        metric: String,
        matches: [Match],
        champion: Champion,
        role: String,
        summoner: Summoner
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
            return participants.map { participant in
                if participant.teamDamagePercentage > 0 {
                    return participant.teamDamagePercentage
                } else {
                    let match = matches.first { $0.participants.contains(participant) }
                    let teamParticipants =
                        match?.participants.filter { $0.teamId == participant.teamId } ?? []
                    let teamTotalDamage = teamParticipants.reduce(0) {
                        $0 + $1.totalDamageDealtToChampions
                    }
                    return teamTotalDamage > 0
                        ? Double(participant.totalDamageDealtToChampions) / Double(teamTotalDamage)
                        : 0.0
                }
            }.reduce(0, +) / Double(participants.count)

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

    // MARK: - Baseline Operations

    /// Gets baseline from cache (synchronous, no blocking!)
    private static func getBaselineFromCache(
        role: String,
        classTag: String,
        metric: String,
        cache: [String: Baseline]
    ) -> Baseline? {
        let key = "\(role)_\(classTag)_\(metric)"
        return cache[key]
    }

    // MARK: - Performance Level Determination

    /// Gets performance level and color using baseline comparison
    private static func getPerformanceLevelWithBaseline(
        value: Double,
        metric: String,
        baseline: Baseline?
    ) -> (Baseline.PerformanceLevel, Color) {
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
                    return (.poor, DesignSystem.Colors.secondary)
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
                    return (.poor, DesignSystem.Colors.secondary)
                }
            }
        } else {
            // Fallback to basic performance levels
            return getBasicPerformanceLevel(value: value, metric: metric)
        }
    }

    /// Basic performance levels without baseline data
    private static func getBasicPerformanceLevel(value: Double, metric: String) -> (
        Baseline.PerformanceLevel, Color
    ) {
        switch metric {
        case "deaths_per_game":
            if value <= 3.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value <= 5.0 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        case "kill_participation_pct", "objective_participation_pct", "team_damage_pct",
            "damage_taken_share_pct":
            if value >= 0.7 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value >= 0.5 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        case "cs_per_min", "vision_score_per_min":
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

    // MARK: - Formatting

    /// Formats metric values for display
    public static func formatValue(_ value: Double, for metric: String) -> String {
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
}
