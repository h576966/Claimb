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
    internal let dataManager: DataManager

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
                    && RoleUtils.normalizeRole(teamPosition: $0.teamPosition) == role
            })
        }

        guard !participants.isEmpty else { return [] }

        // Calculate basic KPIs
        let deathsPerGame = calculateDeathsPerGame(participants: participants)
        let visionScore = calculateVisionScore(participants: participants)
        let killParticipation = calculateKillParticipation(
            participants: participants, matches: matches)
        
        // Only calculate CS per minute for relevant roles (exclude Support)
        let shouldIncludeCS = shouldIncludeCSPerMinute(for: role)
        let csPerMinute = shouldIncludeCS 
            ? calculateCSPerMinute(participants: participants, matches: matches)
            : 0.0
        
        let objectiveParticipation = calculateObjectiveParticipation(
            participants: participants, matches: matches)

        // Debug logging for KPI calculations
        var debugMetadata: [String: String] = [
            "deathsPerGame": deathsPerGame.twoDecimals,
            "visionScore": visionScore.twoDecimals,
            "killParticipation": killParticipation.twoDecimals,
            "objectiveParticipation": objectiveParticipation.twoDecimals,
            "participantCount": String(participants.count),
        ]
        if shouldIncludeCS {
            debugMetadata["csPerMinute"] = csPerMinute.twoDecimals
        }
        ClaimbLogger.debug(
            "KPI Calculations for \(role)", service: "KPICalculationService",
            metadata: debugMetadata)

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
        // Note: Participant.killParticipation now handles fallback calculation automatically.
        // It uses challenge data when available (more accurate), otherwise calculates from raw stats.
        // We can directly use participant.killParticipation for all participants.
        let killParticipations = participants.map { $0.killParticipation }
        let result = killParticipations.reduce(0, +) / Double(participants.count)
        return result.isNaN ? 0.0 : result
    }

    private func calculateCSPerMinute(participants: [Participant], matches: [Match]) -> Double {
        guard !participants.isEmpty else { return 0.0 }
        // Use participant.csPerMinute which includes both lane minions (totalMinionsKilled)
        // and jungle minions (neutralMinionsKilled = ally + enemy jungle camps)
        let csPerMinuteValues = participants.map { participant in
            return participant.csPerMinute
        }
        let result = csPerMinuteValues.reduce(0, +) / Double(participants.count)
        return result.isNaN ? 0.0 : result
    }

    private func calculateObjectiveParticipation(participants: [Participant], matches: [Match])
        -> Double
    {
        guard !participants.isEmpty else { return 0.0 }
        // Use Participant's computed property which handles all edge cases
        let objectiveParticipations = participants.map { $0.objectiveParticipationPercentage }
        let result = objectiveParticipations.reduce(0, +) / Double(participants.count)
        return result.isNaN ? 0.0 : result
    }

    private func calculatePrimaryRoleConsistency(
        matches: [Match], primaryRole: String, summoner: Summoner
    ) -> Double {
        // Get last 10 ranked games for coaching analysis
        let recentMatches = Array(matches.filter { $0.isRanked }.prefix(10))

        guard !recentMatches.isEmpty else { return 0.0 }

        // Count unique roles played in last 10 ranked games
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
        // Get last 10 ranked games for coaching analysis
        let recentMatches = Array(matches.filter { $0.isRanked }.prefix(10))

        // Get all participants for the summoner across all roles (ranked only)
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
        let csEligibleRoles = ["MIDDLE", "BOTTOM", "JUNGLE", "TOP"]
        let baselineRole = RoleUtils.normalizedRoleToBaselineRole(role)
        return csEligibleRoles.contains(baselineRole)
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
        return StringFormatter.formatKPIValue(safeValue, for: metric)
    }

    private func getBaselineForMetric(metric: String, role: String) async -> Baseline? {
        do {
            // Map role names to match baseline data format
            let baselineRole = RoleUtils.normalizedRoleToBaselineRole(role)

            // Try to get baseline for "ALL" class tag
            if let baseline = try await dataManager.getBaseline(
                role: baselineRole, classTag: "ALL", metric: metric)
            {
                ClaimbLogger.debug(
                    "Found baseline for \(metric) in \(baselineRole)",
                    service: "KPICalculationService",
                    metadata: [
                        "mean": StringFormatter.formatBaseline(baseline.mean),
                        "p40": StringFormatter.formatBaseline(baseline.p40),
                        "p60": StringFormatter.formatBaseline(baseline.p60),
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
                    return (.poor, DesignSystem.Colors.secondary)
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
                    return (.poor, DesignSystem.Colors.secondary)
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
        case "objective_participation_pct":
            if value > 0.6 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value > 0.4 {
                return (.good, DesignSystem.Colors.white)
            } else if value > 0.2 {
                return (.needsImprovement, DesignSystem.Colors.warning)
            } else {
                return (.poor, DesignSystem.Colors.secondary)
            }
        default:
            return (.needsImprovement, DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Streak Analysis

    /// Calculates losing streak for a specific role from recent matches
    func calculateLosingStreak(
        matches: [Match],
        summoner: Summoner,
        role: String
    ) -> Int {
        // Get recent matches for the specific role, sorted by most recent first
        let roleMatches =
            matches
            .filter { match in
                guard
                    let participant = match.participants.first(where: { $0.puuid == summoner.puuid }
                    )
                else {
                    return false
                }
                let participantRole = RoleUtils.normalizeRole(
                    teamPosition: participant.teamPosition)
                return participantRole == role
            }
            .sorted { $0.gameCreation > $1.gameCreation }

        var losingStreak = 0

        for match in roleMatches {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                continue
            }

            if participant.win {
                // Win found, streak ends
                break
            } else {
                // Loss found, increment streak
                losingStreak += 1
            }
        }

        ClaimbLogger.debug(
            "Losing streak calculated", service: "KPICalculationService",
            metadata: [
                "role": role,
                "losingStreak": String(losingStreak),
                "totalRoleMatches": String(roleMatches.count),
            ])

        return losingStreak
    }

    /// Calculates winning streak for a specific role from recent matches
    func calculateWinningStreak(
        matches: [Match],
        summoner: Summoner,
        role: String
    ) -> Int {
        // Get recent matches for the specific role, sorted by most recent first
        let roleMatches =
            matches
            .filter { match in
                guard
                    let participant = match.participants.first(where: { $0.puuid == summoner.puuid }
                    )
                else {
                    return false
                }
                let participantRole = RoleUtils.normalizeRole(
                    teamPosition: participant.teamPosition)
                return participantRole == role
            }
            .sorted { $0.gameCreation > $1.gameCreation }

        var winningStreak = 0

        for match in roleMatches {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                continue
            }

            if participant.win {
                // Win found, increment streak
                winningStreak += 1
            } else {
                // Loss found, streak ends
                break
            }
        }

        ClaimbLogger.debug(
            "Winning streak calculated", service: "KPICalculationService",
            metadata: [
                "role": role,
                "winningStreak": String(winningStreak),
                "totalRoleMatches": String(roleMatches.count),
            ])

        return winningStreak
    }

    /// Calculates recent win rate for a specific role (last 10 games)
    func calculateRecentWinRate(
        matches: [Match],
        summoner: Summoner,
        role: String
    ) -> (wins: Int, losses: Int, winRate: Double) {
        // Get last 10 matches for the specific role
        let recentRoleMatches =
            matches
            .filter { match in
                guard
                    let participant = match.participants.first(where: { $0.puuid == summoner.puuid }
                    )
                else {
                    return false
                }
                let participantRole = RoleUtils.normalizeRole(
                    teamPosition: participant.teamPosition)
                return participantRole == role
            }
            .sorted { $0.gameCreation > $1.gameCreation }
            .prefix(10)

        let wins = recentRoleMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })
        }.filter { $0.win }.count

        let losses = recentRoleMatches.count - wins
        let winRate =
            recentRoleMatches.isEmpty ? 0.0 : Double(wins) / Double(recentRoleMatches.count) * 100

        ClaimbLogger.debug(
            "Recent win rate calculated", service: "KPICalculationService",
            metadata: [
                "role": role,
                "wins": String(wins),
                "losses": String(losses),
                "winRate": String(format: "%.1f", winRate),
                "totalGames": String(recentRoleMatches.count),
            ])

        return (wins: wins, losses: losses, winRate: winRate)
    }

}
