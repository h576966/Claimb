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

        // Try to get timeline data for enhanced analysis
        let timelineData = await fetchTimelineData(matchId: match.matchId, puuid: summoner.puuid)

        // Create prompt using PromptBuilder
        let prompt = CoachingPromptBuilder.createPostGamePrompt(
            match: match,
            participant: participant,
            summoner: summoner,
            championName: championName,
            role: role,
            timelineData: timelineData,
            laneOpponent: laneOpponent,
            teamContext: teamContext
        )

        // Make API request through proxy
        // Note: Using lower token limit for concise responses
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            model: "gpt-5-mini",
            maxOutputTokens: 800,  // Lower limit for concise responses
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

        // Create prompt using PromptBuilder
        let prompt = CoachingPromptBuilder.createPerformanceSummaryPrompt(
            matches: matches,
            summoner: summoner,
            primaryRole: primaryRole,
            bestPerformingChampions: bestPerformingChampions,
            streakData: streakData
        )

        // Make API request through proxy
        // Note: Using lower token limit for concise responses
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            model: "gpt-5-mini",
            maxOutputTokens: 800,  // Lower limit for concise responses
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

    /// Legacy method for backward compatibility (deprecated)
    @available(
        *, deprecated, message: "Use generatePostGameAnalysis or generatePerformanceSummary instead"
    )
    public func generateCoachingInsights(
        summoner: Summoner,
        matches: [Match],
        primaryRole: String,
        kpiService: KPICalculationService? = nil
    ) async throws -> CoachingResponse {
        // This is kept only for backward compatibility
        // New code should use generatePostGameAnalysis or generatePerformanceSummary

        guard !AppConfig.appToken.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        // Prepare match data for analysis
        let matchSummary = prepareMatchSummary(
            matches: matches, summoner: summoner, primaryRole: primaryRole)

        // Create basic coaching prompt
        let prompt = createLegacyCoachingPrompt(
            summoner: summoner,
            matchSummary: matchSummary,
            primaryRole: primaryRole
        )

        // Make API request through proxy service
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            model: "gpt-4o-mini",
            maxOutputTokens: 1000
        )

        // Parse structured JSON response
        return try JSONResponseParser.parse(responseText)
    }

    // MARK: - Private Helper Methods

    /// Fetches timeline data for a match (with graceful fallback)
    private func fetchTimelineData(matchId: String, puuid: String) async -> String? {
        do {
            let proxyService = ProxyService()
            let timelineData = try await proxyService.riotTimelineLite(
                matchId: matchId,
                puuid: puuid,
                region: "europe"
            )
            ClaimbLogger.info(
                "Retrieved timeline data for post-game analysis",
                service: "OpenAIService",
                metadata: [
                    "matchId": matchId,
                    "timelineLength": String(timelineData.count),
                ]
            )
            return timelineData
        } catch {
            ClaimbLogger.warning(
                "Failed to retrieve timeline data, proceeding without it",
                service: "OpenAIService",
                metadata: ["matchId": matchId, "error": error.localizedDescription]
            )
            return nil
        }
    }

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

    // MARK: - Legacy Helper Methods (kept for backward compatibility)

    private func prepareMatchSummary(
        matches: [Match],
        summoner: Summoner,
        primaryRole: String
    ) -> String {
        let recentMatches = Array(matches.prefix(10))

        var summary = "Recent Performance Summary:\n"
        summary += "Role: \(primaryRole)\n"
        summary += "Total Matches: \(recentMatches.count)\n"

        // Calculate win rate
        let wins = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })?.win
        }.filter { $0 }.count

        let winRate = recentMatches.isEmpty ? 0.0 : Double(wins) / Double(recentMatches.count)
        summary += "Win Rate: \(String(format: "%.1f", winRate * 100))%\n\n"

        // Add match details
        summary += "Match Details:\n"
        for (index, match) in recentMatches.enumerated() {
            if let participant = MatchStatsCalculator.findParticipant(summoner: summoner, in: match)
            {
                let result = participant.win ? "Victory" : "Defeat"
                let kda = "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
                let cs = MatchStatsCalculator.calculateTotalCS(participant: participant)

                summary += "Match \(index + 1): \(result) - KDA: \(kda) - CS: \(cs)\n"
            }
        }

        return summary
    }

    private func createLegacyCoachingPrompt(
        summoner: Summoner,
        matchSummary: String,
        primaryRole: String
    ) -> String {
        let rankContext = CoachingPromptBuilder.createRankContext(summoner: summoner)

        return """
            You are a League of Legends coach. Analyze this player's performance and provide concise coaching insights.

            **Player:** \(summoner.gameName)#\(summoner.tagLine) | **Role:** \(primaryRole)\(rankContext)

            \(matchSummary)

            **Response Format (JSON only):**
            {
              "analysis": {
                "strengths": ["string", "string"],
                "improvements": ["string", "string"],
                "actionableTips": ["string", "string"],
                "championAdvice": "string",
                "nextSteps": ["string", "string"],
                "overallScore": 7,
                "priorityFocus": "string"
              },
              "summary": "Brief 2-sentence summary"
            }

            **Focus:** Role-specific advice for \(primaryRole). Keep tips actionable. Score 1-10.
            Respond ONLY with valid JSON.
            """
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
