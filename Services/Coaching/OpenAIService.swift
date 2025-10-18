//
//  OpenAIService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//  Refactored on 2025-10-09 to eliminate code duplication and improve maintainability.
//

import Foundation
import Observation
import SwiftData

/// OpenAI API service for generating coaching insights
/// Focuses on API orchestration only - delegates prompt building and parsing to utilities
@MainActor
@Observable
public class OpenAIService {

    // MARK: - Initialization

    public init() {
        // No initialization needed - using ProxyService
    }

    // MARK: - Public API Methods

    /// Generates post-game analysis focused on champion-specific advice with timeline data
    public func generatePostGameAnalysis(
        match: Match,
        summoner: Summoner,
        kpiService: KPICalculationService
    ) async throws -> PostGameAnalysis {

        // Validate proxy service availability
        guard !AppConfig.appToken.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        // Get participant data for the summoner
        guard let participant = MatchStatsCalculator.findParticipant(summoner: summoner, in: match)
        else {
            throw OpenAIError.invalidResponse
        }

        // Get champion data
        let championName = participant.champion?.name ?? "Unknown Champion"
        let role = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)

        // Get lane opponent and team context
        let (laneOpponent, teamContext) = extractLaneContext(
            match: match,
            userParticipant: participant
        )

        // Get baseline context for key metrics (simple approach - no complex formatting)
        let baselineContext = await fetchBaselineContext(
            for: participant,
            role: role,
            dataManager: kpiService.dataManager
        )

        // Create split prompts using PromptBuilder (for better organization)
        let (systemPrompt, userPrompt) = CoachingPromptBuilder.createPostGamePrompt(
            match: match,
            participant: participant,
            summoner: summoner,
            championName: championName,
            role: role,
            timelineData: nil,  // Timeline feature removed
            laneOpponent: laneOpponent,
            teamContext: teamContext,
            baselineContext: baselineContext
        )

        // Combine system and user prompts into single request (like working version)
        // This maintains the dual prompt architecture but uses single request approach
        let combinedPrompt = """
            <SYSTEM>
            \(systemPrompt)
            </SYSTEM>

            <USER>
            \(userPrompt)
            </USER>
            """

        // Create strict JSON schema for Post-Game Analysis
        // Edge function expects top-level json_schema with name, strict, and schema
        let postGameSchema: [String: Any] = [
            "name": "claimb_post_game",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "required": ["keyTakeaways", "championSpecificAdvice", "nextGameFocus"],
                "properties": [
                    "keyTakeaways": [
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 3,
                        "items": ["type": "string", "maxLength": 120],
                    ],
                    "championSpecificAdvice": ["type": "string", "maxLength": 220],
                    "nextGameFocus": [
                        "type": "array",
                        "minItems": 2,
                        "maxItems": 2,
                        "items": ["type": "string", "maxLength": 120],
                    ],
                ],
            ],
        ]

        // Make API request through proxy with combined prompt
        // Note: Using lower token limit for concise responses
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: combinedPrompt,
            model: "gpt-5-mini",
            maxOutputTokens: 800,  // Lower limit for concise responses
            temperature: 0.4,  // Balanced temperature for consistent yet varied coaching
            textFormatSchema: postGameSchema,  // Strict JSON schema for Responses API
            reasoningEffort: "low"  // Use "low" reasoning to reduce token usage
        )

        // Parse response using JSONResponseParser
        let analysis: PostGameAnalysis = try JSONResponseParser.parse(responseText)

        ClaimbLogger.debug(
            "Post-game analysis completed",
            service: "OpenAIService",
            metadata: [
                "championName": championName,
                "gameResult": participant.win ? "Victory" : "Defeat",
            ]
        )

        return analysis
    }

    /// Generates performance summary focused on role-based trends
    public func generatePerformanceSummary(
        matches: [Match],
        summoner: Summoner,
        primaryRole: String,
        kpiService: KPICalculationService
    ) async throws -> PerformanceSummary {

        // Validate proxy service availability
        guard !AppConfig.appToken.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        // Calculate best performing champions using shared utility
        let bestPerformingChampions = MatchStatsCalculator.calculateBestPerformingChampions(
            matches: Array(matches.prefix(10)),
            summoner: summoner,
            primaryRole: primaryRole
        )

        // Calculate streak data for context
        let losingStreak = kpiService.calculateLosingStreak(
            matches: matches, summoner: summoner, role: primaryRole)
        let winningStreak = kpiService.calculateWinningStreak(
            matches: matches, summoner: summoner, role: primaryRole)
        let recentPerformance = kpiService.calculateRecentWinRate(
            matches: matches, summoner: summoner, role: primaryRole)

        let streakData = CoachingPromptBuilder.StreakData(
            losingStreak: losingStreak,
            winningStreak: winningStreak,
            recentWins: recentPerformance.wins,
            recentLosses: recentPerformance.losses,
            recentWinRate: recentPerformance.winRate
        )

        ClaimbLogger.debug(
            "Calculated best performing champions for Summary",
            service: "OpenAIService",
            metadata: [
                "primaryRole": primaryRole,
                "championCount": String(bestPerformingChampions.count),
                "champions": bestPerformingChampions.prefix(3).map {
                    "\($0.name) (\(Int($0.winRate * 100))%)"
                }.joined(separator: ", "),
            ]
        )

        // Create split prompts using PromptBuilder (for better organization)
        let (systemPrompt, userPrompt) = CoachingPromptBuilder.createPerformanceSummaryPrompt(
            matches: matches,
            summoner: summoner,
            primaryRole: primaryRole,
            bestPerformingChampions: bestPerformingChampions,
            streakData: streakData
        )

        // Combine system and user prompts into single request (like working version)
        // This maintains the dual prompt architecture but uses single request approach
        let combinedPrompt = """
            <SYSTEM>
            \(systemPrompt)
            </SYSTEM>

            <USER>
            \(userPrompt)
            </USER>
            """

        // Create strict JSON schema for Performance Summary
        // Edge function expects top-level json_schema with name, strict, and schema
        let performanceSummarySchema: [String: Any] = [
            "name": "claimb_perf_summary",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "required": [
                    "keyTrends", "roleConsistency", "championPoolAnalysis",
                    "areasOfImprovement", "strengthsToMaintain", "climbingAdvice",
                ],
                "properties": [
                    "keyTrends": [
                        "type": "array",
                        "minItems": 2,
                        "maxItems": 2,
                        "items": ["type": "string", "maxLength": 140],
                    ],
                    "roleConsistency": ["type": "string", "maxLength": 140],
                    "championPoolAnalysis": ["type": "string", "maxLength": 240],
                    "areasOfImprovement": [
                        "type": "array",
                        "minItems": 2,
                        "maxItems": 2,
                        "items": ["type": "string", "maxLength": 140],
                    ],
                    "strengthsToMaintain": [
                        "type": "array",
                        "minItems": 2,
                        "maxItems": 2,
                        "items": ["type": "string", "maxLength": 140],
                    ],
                    "climbingAdvice": ["type": "string", "maxLength": 220],
                ],
            ],
        ]

        // Make API request through proxy with combined prompt
        // Note: Using lower token limit for concise responses
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: combinedPrompt,
            model: "gpt-5-mini",
            maxOutputTokens: 800,  // Lower limit for concise responses
            temperature: 0.4,  // Balanced temperature for consistent yet varied coaching
            textFormatSchema: performanceSummarySchema,  // Strict JSON schema for Responses API
            reasoningEffort: "low"  // Use "low" reasoning to reduce token usage
        )

        // Parse response using JSONResponseParser
        let summary: PerformanceSummary = try JSONResponseParser.parse(responseText)

        ClaimbLogger.debug(
            "Performance summary completed",
            service: "OpenAIService",
            metadata: [
                "trendsCount": String(summary.keyTrends.count),
                "improvementsCount": String(summary.areasOfImprovement.count),
            ]
        )

        return summary
    }

    // MARK: - Private Helper Methods

    /// Extracts lane opponent and team context information
    private func extractLaneContext(
        match: Match,
        userParticipant: Participant
    ) -> (laneOpponent: String?, teamContext: String) {
        let userTeamId = userParticipant.teamId
        let userPosition = userParticipant.teamPosition

        // Find lane opponent (same position, different team)
        let laneOpponent = match.participants.first { participant in
            participant.teamId != userTeamId && participant.teamPosition == userPosition
        }

        let laneOpponentInfo: String? =
            if let opponent = laneOpponent {
                "\(opponent.champion?.name ?? "Unknown Champion") (\(opponent.teamPosition))"
            } else {
                nil
            }

        // Create team context (all champions with positions)
        let userTeam = match.participants.filter { $0.teamId == userTeamId }
        let enemyTeam = match.participants.filter { $0.teamId != userTeamId }

        let userTeamInfo = userTeam.map { "\($0.champion?.name ?? "Unknown") (\($0.teamPosition))" }
            .joined(separator: ", ")
        let enemyTeamInfo = enemyTeam.map {
            "\($0.champion?.name ?? "Unknown") (\($0.teamPosition))"
        }.joined(separator: ", ")

        let teamContext = """
            **Your Team:** \(userTeamInfo)
            **Enemy Team:** \(enemyTeamInfo)
            """

        return (laneOpponentInfo, teamContext)
    }

    /// Fetches baseline context for key performance metrics
    /// Keeps it simple - only CS, Deaths, Vision for post-game focus
    private func fetchBaselineContext(
        for participant: Participant,
        role: String,
        dataManager: DataManager
    ) async -> String? {
        // Map role to baseline format using centralized utility
        let baselineRole = RoleUtils.normalizedRoleToBaselineRole(role)

        var context = ""
        var hasAnyBaseline = false

        // Only fetch baselines for CS-eligible roles
        let csEligibleRoles = ["MIDDLE", "BOTTOM", "JUNGLE", "TOP"]
        if csEligibleRoles.contains(baselineRole) {
            if let csBaseline = try? await dataManager.getBaseline(
                role: baselineRole, classTag: "ALL", metric: "cs_per_min"
            ) {
                hasAnyBaseline = true
                let playerCS = participant.csPerMinute
                let target = csBaseline.p60
                let status = playerCS >= target ? "above target" : "below target"
                context +=
                    "CS/min: \(String(format: "%.1f", playerCS)) (\(status), target: \(String(format: "%.1f", target))) | "
            }
        }

        // Deaths baseline (lower is better)
        if let deathsBaseline = try? await dataManager.getBaseline(
            role: baselineRole, classTag: "ALL", metric: "deaths_per_game"
        ) {
            hasAnyBaseline = true
            let playerDeaths = Double(participant.deaths)
            let target = deathsBaseline.p40  // Lower is better, so p40 is the good target
            let status = playerDeaths <= target ? "good" : "high"
            context +=
                "Deaths: \(Int(playerDeaths)) (\(status), target: ≤\(String(format: "%.1f", target))) | "
        }

        // Vision baseline
        if let visionBaseline = try? await dataManager.getBaseline(
            role: baselineRole, classTag: "ALL", metric: "vision_score_per_min"
        ) {
            hasAnyBaseline = true
            let playerVision = participant.visionScorePerMinute
            let target = visionBaseline.p60
            let status = playerVision >= target ? "above target" : "below target"
            context +=
                "Vision/min: \(String(format: "%.1f", playerVision)) (\(status), target: \(String(format: "%.1f", target)))"
        }

        return hasAnyBaseline ? context : nil
    }

}

// MARK: - Error Types

public enum OpenAIError: Error, LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "OpenAI API key is not configured. Please check your API key settings."
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
