//
//  BaselineService.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-09.
//

// MARK: - Performance Analysis Models

/// Represents the result of a performance analysis against baselines
public struct PerformanceAnalysis {
    public let metric: String
    public let playerValue: Double
    public let baseline: Baseline
    public let performance: Baseline.PerformanceLevel
    public let message: String

    public init(
        metric: String, playerValue: Double, baseline: Baseline,
        performance: Baseline.PerformanceLevel, message: String
    ) {
        self.metric = metric
        self.playerValue = playerValue
        self.baseline = baseline
        self.performance = performance
        self.message = message
    }
}

/// Represents a complete role-based performance analysis
public struct RolePerformanceAnalysis {
    public let role: String
    public let championClass: String
    public let analyses: [PerformanceAnalysis]
    public let overallScore: Double
    public let summary: String

    public init(
        role: String, championClass: String, analyses: [PerformanceAnalysis], overallScore: Double,
        summary: String
    ) {
        self.role = role
        self.championClass = championClass
        self.analyses = analyses
        self.overallScore = overallScore
        self.summary = summary
    }
}

// MARK: - Baseline Service

@MainActor
public class BaselineService {
    private let dataManager: DataManager
    private var championClassMapping: [String: String] = [:]

    public init(dataManager: DataManager) {
        self.dataManager = dataManager
    }

    // MARK: - Data Loading

    /// Loads baseline data and champion class mapping
    public func loadBaselineData() async throws {
        // Load baseline data
        try await dataManager.loadBaselineData()

        // Load champion class mapping
        championClassMapping = try await dataManager.loadChampionClassMapping()
    }

    // MARK: - Performance Analysis

    /// Gets performance analysis for a participant
    public func getPerformanceAnalysis(
        for participant: Participant,
        in match: Match,
        champion: Champion
    ) async throws -> RolePerformanceAnalysis {

        let role = participant.role
        let championClass = getChampionClass(for: champion.name)

        // Get role-specific KPIs
        let kpis = getRoleSpecificKPIs(for: role)

        var analyses: [PerformanceAnalysis] = []

        for kpi in kpis {
            if let analysis = try await analyzeKPI(
                kpi: kpi,
                participant: participant,
                match: match,
                role: role,
                championClass: championClass
            ) {
                analyses.append(analysis)
            }
        }

        let overallScore = calculateOverallScore(analyses)
        let summary = generateSummary(analyses, role: role)

        return RolePerformanceAnalysis(
            role: role,
            championClass: championClass,
            analyses: analyses,
            overallScore: overallScore,
            summary: summary
        )
    }

    // MARK: - Private Methods

    private func getChampionClass(for championName: String) -> String {
        return championClassMapping[championName] ?? "ALL"
    }

    private func getRoleSpecificKPIs(for role: String) -> [String] {
        switch role {
        case "TOP":
            return [
                "deaths_per_game", "kill_participation_pct", "vision_score_per_min",
                "damage_taken_share_pct", "cs_per_min",
            ]
        case "JUNGLE":
            return [
                "deaths_per_game", "kill_participation_pct", "vision_score_per_min",
                "objective_participation_pct", "cs_per_min",
            ]
        case "MIDDLE":
            return [
                "deaths_per_game", "kill_participation_pct", "vision_score_per_min",
                "team_damage_pct", "cs_per_min",
            ]
        case "BOTTOM":
            return [
                "deaths_per_game", "kill_participation_pct", "vision_score_per_min", "cs_per_min",
                "team_damage_pct",
            ]
        case "UTILITY":
            return [
                "deaths_per_game", "kill_participation_pct", "vision_score_per_min",
                "objective_participation_pct",
            ]
        default:
            return ["deaths_per_game", "kill_participation_pct", "vision_score_per_min"]
        }
    }

    private func analyzeKPI(
        kpi: String,
        participant: Participant,
        match: Match,
        role: String,
        championClass: String
    ) async throws -> PerformanceAnalysis? {

        guard
            let baseline = try await getBaseline(
                role: role,
                classTag: championClass,
                metric: kpi
            )
        else {
            return nil
        }

        let playerValue = calculateKPIValue(kpi: kpi, participant: participant, match: match)
        let performance = baseline.getPerformanceLevel(playerValue)
        let message = generatePerformanceMessage(
            kpi: kpi, value: playerValue, performance: performance)

        return PerformanceAnalysis(
            metric: kpi,
            playerValue: playerValue,
            baseline: baseline,
            performance: performance,
            message: message
        )
    }

    private func calculateKPIValue(kpi: String, participant: Participant, match: Match) -> Double {
        let matchDurationMinutes = Double(match.gameDuration) / 60.0

        switch kpi {
        case "deaths_per_game":
            return Double(participant.deaths)

        case "kill_participation_pct":
            let teamTotalKills = match.participants
                .filter { $0.teamId == participant.teamId }
                .reduce(0) { $0 + $1.kills }
            return teamTotalKills > 0
                ? Double(participant.kills + participant.assists) / Double(teamTotalKills) : 0.0

        case "vision_score_per_min":
            return matchDurationMinutes > 0
                ? Double(participant.visionScore) / matchDurationMinutes : 0.0

        case "cs_per_min":
            let totalCS = participant.totalMinionsKilled + participant.neutralMinionsKilled
            return matchDurationMinutes > 0 ? Double(totalCS) / matchDurationMinutes : 0.0

        case "objective_participation_pct":
            let totalParticipated =
                participant.dragonTakedowns + participant.riftHeraldTakedowns
                + participant.baronTakedowns + participant.hordeTakedowns
                + participant.atakhanTakedowns
            let totalTeamObjectives = match.getTeamObjectives(teamId: participant.teamId)
            return totalTeamObjectives > 0
                ? Double(totalParticipated) / Double(totalTeamObjectives) : 0.0

        case "team_damage_pct":
            let teamTotalDamage = match.participants.reduce(0) { $0 + $1.totalDamageDealt }
            return teamTotalDamage > 0
                ? Double(participant.totalDamageDealt) / Double(teamTotalDamage) : 0.0

        case "damage_taken_share_pct":
            let teamTotalDamageTaken = match.participants.reduce(0) { $0 + $1.totalDamageTaken }
            return teamTotalDamageTaken > 0
                ? Double(participant.totalDamageTaken) / Double(teamTotalDamageTaken) : 0.0

        case "gold_per_min":
            return matchDurationMinutes > 0
                ? Double(participant.goldEarned) / matchDurationMinutes : 0.0

        default:
            return 0.0
        }
    }

    private func generatePerformanceMessage(
        kpi: String,
        value: Double,
        performance: Baseline.PerformanceLevel
    ) -> String {
        let formattedValue = formatKPIValue(kpi: kpi, value: value)

        switch performance {
        case .excellent:
            return "\(formattedValue) - Excellent performance!"
        case .good:
            return "\(formattedValue) - Good performance"
        case .needsImprovement:
            return "\(formattedValue) - Needs improvement"
        }
    }

    private func formatKPIValue(kpi: String, value: Double) -> String {
        switch kpi {
        case "kill_participation_pct", "objective_participation_pct", "team_damage_pct",
            "damage_taken_share_pct":
            return String(format: "%.1f%%", value * 100)
        case "cs_per_min", "vision_score_per_min", "gold_per_min":
            return String(format: "%.1f", value)
        case "deaths_per_game":
            return String(format: "%.0f", value)
        default:
            return String(format: "%.2f", value)
        }
    }

    private func calculateOverallScore(_ analyses: [PerformanceAnalysis]) -> Double {
        guard !analyses.isEmpty else { return 0.0 }

        let totalScore = analyses.reduce(0.0) { total, analysis in
            switch analysis.performance {
            case .excellent: return total + 3.0
            case .good: return total + 2.0
            case .needsImprovement: return total + 1.0
            }
        }

        return totalScore / Double(analyses.count)
    }

    private func generateSummary(_ analyses: [PerformanceAnalysis], role: String) -> String {
        let excellentCount = analyses.filter { $0.performance == .excellent }.count
        let goodCount = analyses.filter { $0.performance == .good }.count
        let needsImprovementCount = analyses.filter { $0.performance == .needsImprovement }.count

        if excellentCount > goodCount && excellentCount > needsImprovementCount {
            return "Strong \(role.lowercased()) performance with excellent metrics"
        } else if goodCount > needsImprovementCount {
            return "Solid \(role.lowercased()) performance with room for improvement"
        } else {
            return "\(role.capitalized) performance needs attention in several areas"
        }
    }

    private func getBaseline(
        role: String,
        classTag: String,
        metric: String
    ) async throws -> Baseline? {

        // Try role + class first
        if let baseline = try await dataManager.getBaseline(
            role: role,
            classTag: classTag,
            metric: metric
        ) {
            return baseline
        }

        // Fallback to role + "ALL"
        return try await dataManager.getBaseline(
            role: role,
            classTag: "ALL",
            metric: metric
        )
    }
}
