//
//  OpenAIService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation
import Observation

// MARK: - Response Models

/// Structured coaching analysis response
public struct CoachingAnalysis: Codable {
    public let strengths: [String]
    public let improvements: [String]
    public let actionableTips: [String]
    public let championAdvice: String
    public let nextSteps: [String]
    public let overallScore: Int  // 1-10 scale
    public let priorityFocus: String
    public let performanceComparison: PerformanceComparison

    public init(
        strengths: [String],
        improvements: [String],
        actionableTips: [String],
        championAdvice: String,
        nextSteps: [String],
        overallScore: Int,
        priorityFocus: String,
        performanceComparison: PerformanceComparison
    ) {
        self.strengths = strengths
        self.improvements = improvements
        self.actionableTips = actionableTips
        self.championAdvice = championAdvice
        self.nextSteps = nextSteps
        self.overallScore = overallScore
        self.priorityFocus = priorityFocus
        self.performanceComparison = performanceComparison
    }
}

/// Performance comparison against personal baselines
public struct PerformanceComparison: Codable {
    public let csPerMinute: ComparisonResult
    public let deathsPerGame: ComparisonResult
    public let visionScore: ComparisonResult
    public let killParticipation: ComparisonResult

    public init(
        csPerMinute: ComparisonResult,
        deathsPerGame: ComparisonResult,
        visionScore: ComparisonResult,
        killParticipation: ComparisonResult
    ) {
        self.csPerMinute = csPerMinute
        self.deathsPerGame = deathsPerGame
        self.visionScore = visionScore
        self.killParticipation = killParticipation
    }
}

/// Individual metric comparison result
public struct ComparisonResult: Codable {
    public let current: Double
    public let average: Double
    public let trend: String  // "above", "below", "similar"
    public let significance: String  // "high", "medium", "low"

    public init(current: Double, average: Double, trend: String, significance: String) {
        self.current = current
        self.average = average
        self.trend = trend
        self.significance = significance
    }
}

/// Complete coaching response
public struct CoachingResponse: Codable {
    public let analysis: CoachingAnalysis
    public let summary: String

    public init(analysis: CoachingAnalysis, summary: String) {
        self.analysis = analysis
        self.summary = summary
    }
}

/// Post-game analysis response focused on champion-specific advice
public struct PostGameAnalysis: Codable {
    public let championName: String
    public let gameResult: String
    public let kda: String
    public let keyTakeaways: [String]
    public let championSpecificAdvice: String
    public let championPoolAdvice: String?
    public let nextGameFocus: [String]

    public init(
        championName: String,
        gameResult: String,
        kda: String,
        keyTakeaways: [String],
        championSpecificAdvice: String,
        championPoolAdvice: String?,
        nextGameFocus: [String]
    ) {
        self.championName = championName
        self.gameResult = gameResult
        self.kda = kda
        self.keyTakeaways = keyTakeaways
        self.championSpecificAdvice = championSpecificAdvice
        self.championPoolAdvice = championPoolAdvice
        self.nextGameFocus = nextGameFocus
    }
}

/// Performance summary response focused on role-based trends
public struct PerformanceSummary: Codable {
    public let overallScore: Int
    public let improvementsMade: [String]
    public let areasOfConcern: [String]
    public let roleDiversity: String
    public let championDiversity: String
    public let focusAreas: [String]
    public let progressionInsights: String

    public init(
        overallScore: Int,
        improvementsMade: [String],
        areasOfConcern: [String],
        roleDiversity: String,
        championDiversity: String,
        focusAreas: [String],
        progressionInsights: String
    ) {
        self.overallScore = overallScore
        self.improvementsMade = improvementsMade
        self.areasOfConcern = areasOfConcern
        self.roleDiversity = roleDiversity
        self.championDiversity = championDiversity
        self.focusAreas = focusAreas
        self.progressionInsights = progressionInsights
    }
}

/// OpenAI API service for generating coaching insights
@MainActor
@Observable
public class OpenAIService {

    // MARK: - Initialization

    public init() {
        // No initialization needed - using ProxyService
    }

    // MARK: - Public Methods

    /// Generates coaching insights based on match data with personal baselines
    public func generateCoachingInsights(
        summoner: Summoner,
        matches: [Match],
        primaryRole: String,
        kpiService: KPICalculationService? = nil
    ) async throws -> CoachingResponse {

        // Validate proxy service availability
        guard !AppConfig.appToken.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        // Get personal baselines if KPI service is provided
        let personalBaselines = await getPersonalBaselines(
            summoner: summoner,
            matches: matches,
            role: primaryRole,
            kpiService: kpiService
        )

        // Prepare match data for analysis
        let matchSummary = prepareMatchSummary(
            matches: matches, summoner: summoner, primaryRole: primaryRole)

        // Create enhanced coaching prompt with personal baselines
        let prompt = createCoachingPrompt(
            summoner: summoner,
            matchSummary: matchSummary,
            primaryRole: primaryRole,
            personalBaselines: personalBaselines
        )

        // Make API request through proxy service with enhanced parameters
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            model: "gpt-5-mini",  // Updated to use latest GPT-5 Mini model
            maxOutputTokens: 1000  // Sufficient tokens for structured response
        )

        // Parse structured JSON response
        return try parseCoachingResponse(responseText)
    }

    /// Generates post-game analysis focused on champion-specific advice
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
        guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
        else {
            throw OpenAIError.invalidResponse
        }

        // Get champion data
        let championName = getChampionName(for: participant.championId)
        let role = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)

        // Get champion-specific performance data
        let championPerformance = await getChampionPerformance(
            summoner: summoner,
            championId: participant.championId,
            role: role,
            kpiService: kpiService
        )

        // Create post-game analysis prompt
        let prompt = createPostGamePrompt(
            match: match,
            participant: participant,
            summoner: summoner,
            championName: championName,
            role: role,
            championPerformance: championPerformance
        )

        // Make API request
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            model: "gpt-5-mini",
            maxOutputTokens: 500  // Shorter response for post-game analysis
        )

        // Parse response
        return try parsePostGameResponse(responseText)
    }

    /// Generates performance summary focused on role-based trends
    public func generatePerformanceSummary(
        matches: [Match],
        summoner: Summoner,
        kpiService: KPICalculationService
    ) async throws -> PerformanceSummary {

        // Validate proxy service availability
        guard !AppConfig.appToken.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        // Get diversity metrics
        let diversityMetrics = kpiService.calculateDiversityMetrics(
            matches: matches,
            summoner: summoner
        )

        // Get role-based performance trends
        let roleTrends = await getRoleTrends(
            matches: matches,
            summoner: summoner,
            kpiService: kpiService
        )

        // Create performance summary prompt
        let prompt = createPerformanceSummaryPrompt(
            matches: matches,
            summoner: summoner,
            diversityMetrics: diversityMetrics,
            roleTrends: roleTrends
        )

        // Make API request
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            model: "gpt-5-mini",
            maxOutputTokens: 800  // Longer response for performance summary
        )

        // Parse response
        return try parsePerformanceSummaryResponse(responseText)
    }

    /// Legacy method for backward compatibility
    public func generateCoachingInsights(
        summoner: Summoner,
        matches: [Match],
        primaryRole: String
    ) async throws -> String {
        let response = try await generateCoachingInsights(
            summoner: summoner,
            matches: matches,
            primaryRole: primaryRole,
            kpiService: nil
        )
        return response.summary
    }

    // MARK: - Private Methods

    private func prepareMatchSummary(matches: [Match], summoner: Summoner, primaryRole: String)
        -> String
    {
        let recentMatches = Array(matches.prefix(10))  // Last 10 matches

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
            if let participant = match.participants.first(where: { $0.puuid == summoner.puuid }) {
                let result = participant.win ? "Victory" : "Defeat"
                let kda = "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
                let cs = participant.totalMinionsKilled + participant.neutralMinionsKilled

                summary += "Match \(index + 1): \(result) - KDA: \(kda) - CS: \(cs)\n"
            }
        }

        return summary
    }

    private func createCoachingPrompt(
        summoner: Summoner,
        matchSummary: String,
        primaryRole: String,
        personalBaselines: [String: Double] = [:]
    ) -> String {
        let baselineContext =
            personalBaselines.isEmpty ? "" : createBaselineContext(baselines: personalBaselines)

        return """
            You are an expert League of Legends coach specializing in data-driven analysis. Analyze the following player data and provide structured coaching insights.

            **CRITICAL INSTRUCTIONS:**
            - Use minimal reasoning - focus on direct analysis
            - Response MUST be valid JSON matching the exact schema below
            - Keep analysis concise but actionable
            - Compare current performance against personal averages when available
            - Prioritize the most impactful improvements

            **Player Data:**
            Player: \(summoner.gameName)#\(summoner.tagLine)
            Primary Role: \(primaryRole)
            \(baselineContext)
            \(matchSummary)

            **REQUIRED JSON RESPONSE SCHEMA:**
            {
              "analysis": {
                "strengths": ["string", "string"],
                "improvements": ["string", "string"],
                "actionableTips": ["string", "string", "string"],
                "championAdvice": "string",
                "nextSteps": ["string", "string"],
                "overallScore": 7,
                "priorityFocus": "string",
                "performanceComparison": {
                  "csPerMinute": {
                    "current": 6.5,
                    "average": 6.2,
                    "trend": "above",
                    "significance": "medium"
                  },
                  "deathsPerGame": {
                    "current": 4.2,
                    "average": 3.8,
                    "trend": "below",
                    "significance": "high"
                  },
                  "visionScore": {
                    "current": 0.6,
                    "average": 0.8,
                    "trend": "below",
                    "significance": "high"
                  },
                  "killParticipation": {
                    "current": 0.45,
                    "average": 0.52,
                    "trend": "below",
                    "significance": "medium"
                  }
                }
              },
              "summary": "Brief 2-3 sentence summary of key insights"
            }

            **ANALYSIS GUIDELINES:**
            - Focus on role-specific improvements for \(primaryRole)
            - Use personal averages as baselines when provided
            - Highlight trends: "above" = better than average, "below" = worse than average
            - Significance: "high" = major impact, "medium" = moderate impact, "low" = minor impact
            - Keep tips specific and immediately actionable
            - Overall score: 1-10 based on recent performance

            Respond ONLY with valid JSON. No additional text or explanations.
            """
    }

    private func createBaselineContext(baselines: [String: Double]) -> String {
        var context = "\n**Personal Performance Averages:**\n"
        for (metric, value) in baselines {
            context += "\(metric): \(String(format: "%.2f", value))\n"
        }
        return context
    }

    /// Gets personal performance baselines for the summoner
    private func getPersonalBaselines(
        summoner: Summoner,
        matches: [Match],
        role: String,
        kpiService: KPICalculationService?
    ) async -> [String: Double] {
        guard let kpiService = kpiService else { return [:] }

        do {
            let kpis = try await kpiService.calculateRoleKPIs(
                matches: matches,
                role: role,
                summoner: summoner
            )

            var baselines: [String: Double] = [:]
            for kpi in kpis {
                // Convert string value to double for personal baselines
                if let doubleValue = Double(kpi.value) {
                    baselines[kpi.metric] = doubleValue
                }
            }

            ClaimbLogger.debug(
                "Retrieved personal baselines", service: "OpenAIService",
                metadata: [
                    "role": role,
                    "metrics": baselines.keys.joined(separator: ", "),
                    "count": String(baselines.count),
                ])

            return baselines
        } catch {
            ClaimbLogger.warning(
                "Failed to get personal baselines", service: "OpenAIService",
                metadata: ["error": error.localizedDescription])
            return [:]
        }
    }

    /// Parses the structured JSON response from OpenAI
    private func parseCoachingResponse(_ responseText: String) throws -> CoachingResponse {
        // Clean the response text (remove any markdown formatting)
        let cleanText =
            responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanText.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        do {
            let response = try JSONDecoder().decode(CoachingResponse.self, from: data)
            ClaimbLogger.debug(
                "Successfully parsed coaching response", service: "OpenAIService",
                metadata: [
                    "overallScore": String(response.analysis.overallScore),
                    "priorityFocus": response.analysis.priorityFocus,
                ])
            return response
        } catch {
            ClaimbLogger.error(
                "Failed to parse coaching response", service: "OpenAIService",
                metadata: [
                    "error": error.localizedDescription,
                    "responseLength": String(responseText.count),
                ])
            throw OpenAIError.invalidResponse
        }
    }

    // MARK: - Post-Game Analysis Helpers

    private func getChampionName(for championId: Int) -> String {
        // TODO: Integrate with champion data from Champion section
        // For now, return a placeholder
        return "Champion \(championId)"
    }

    private func getChampionPerformance(
        summoner: Summoner,
        championId: Int,
        role: String,
        kpiService: KPICalculationService
    ) async -> [String: Double] {
        // TODO: Get champion-specific performance data
        // This would integrate with existing champion pool logic
        return [:]
    }

    private func createPostGamePrompt(
        match: Match,
        participant: Participant,
        summoner: Summoner,
        championName: String,
        role: String,
        championPerformance: [String: Double]
    ) -> String {
        let gameResult = participant.win ? "Victory" : "Defeat"
        let kda = "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
        let cs = participant.totalMinionsKilled + participant.neutralMinionsKilled

        return """
            You are an expert League of Legends coach. Provide a concise post-game analysis focused on the champion played and actionable advice for the next game.

            **CRITICAL INSTRUCTIONS:**
            - Response MUST be valid JSON matching the exact schema below
            - Focus on champion-specific advice
            - Keep analysis concise (500 tokens max)
            - Provide 2-3 specific things to focus on next game

            **Game Data:**
            Player: \(summoner.gameName)#\(summoner.tagLine)
            Champion: \(championName)
            Role: \(role)
            Result: \(gameResult)
            KDA: \(kda)
            CS: \(cs)
            Game Duration: \(match.gameDuration / 60) minutes

            **REQUIRED JSON RESPONSE SCHEMA:**
            {
              "championName": "\(championName)",
              "gameResult": "\(gameResult)",
              "kda": "\(kda)",
              "keyTakeaways": ["string", "string", "string"],
              "championSpecificAdvice": "string",
              "championPoolAdvice": "string or null",
              "nextGameFocus": ["string", "string"]
            }

            **ANALYSIS GUIDELINES:**
            - Champion-specific: Focus on how to play \(championName) better
            - Champion pool: Suggest avoiding low win-rate champions if applicable
            - Next game: 2 specific things to improve
            - Keep advice actionable and specific

            Respond ONLY with valid JSON. No additional text.
            """
    }

    private func parsePostGameResponse(_ responseText: String) throws -> PostGameAnalysis {
        let cleanText =
            responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanText.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        do {
            let response = try JSONDecoder().decode(PostGameAnalysis.self, from: data)
            ClaimbLogger.debug(
                "Successfully parsed post-game response", service: "OpenAIService",
                metadata: [
                    "championName": response.championName,
                    "gameResult": response.gameResult,
                ])
            return response
        } catch {
            ClaimbLogger.error(
                "Failed to parse post-game response", service: "OpenAIService",
                metadata: [
                    "error": error.localizedDescription,
                    "responseLength": String(responseText.count),
                ])
            throw OpenAIError.invalidResponse
        }
    }

    // MARK: - Performance Summary Helpers

    private func getRoleTrends(
        matches: [Match],
        summoner: Summoner,
        kpiService: KPICalculationService
    ) async -> [String: String] {
        // TODO: Analyze role-based performance trends over last 10 games
        return [:]
    }

    private func createPerformanceSummaryPrompt(
        matches: [Match],
        summoner: Summoner,
        diversityMetrics: (roleCount: Int, championCount: Int),
        roleTrends: [String: String]
    ) -> String {
        let recentMatches = Array(matches.prefix(10))
        let wins = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })?.win
        }.filter { $0 }.count

        let winRate = recentMatches.isEmpty ? 0.0 : Double(wins) / Double(recentMatches.count)

        return """
            You are an expert League of Legends coach. Analyze the player's performance over the last 10 games and provide role-focused insights.

            **CRITICAL INSTRUCTIONS:**
            - Response MUST be valid JSON matching the exact schema below
            - Focus on role-based trends and improvements
            - Include diversity context in analysis
            - Keep analysis concise but comprehensive

            **Performance Data:**
            Player: \(summoner.gameName)#\(summoner.tagLine)
            Games Analyzed: \(recentMatches.count)
            Win Rate: \(String(format: "%.1f", winRate * 100))%
            Roles Played: \(diversityMetrics.roleCount) different roles
            Champions Played: \(diversityMetrics.championCount) different champions

            **REQUIRED JSON RESPONSE SCHEMA:**
            {
              "overallScore": 7,
              "improvementsMade": ["string", "string"],
              "areasOfConcern": ["string", "string"],
              "roleDiversity": "string",
              "championDiversity": "string",
              "focusAreas": ["string", "string"],
              "progressionInsights": "string"
            }

            **ANALYSIS GUIDELINES:**
            - Overall score: 1-10 based on recent performance trends
            - Improvements: What's getting better over time
            - Concerns: What's declining or needs attention
            - Diversity: Comment on role/champion variety
            - Focus areas: 2-3 specific things to work on
            - Progression: Overall trend analysis

            Respond ONLY with valid JSON. No additional text.
            """
    }

    private func parsePerformanceSummaryResponse(_ responseText: String) throws
        -> PerformanceSummary
    {
        let cleanText =
            responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanText.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        do {
            let response = try JSONDecoder().decode(PerformanceSummary.self, from: data)
            ClaimbLogger.debug(
                "Successfully parsed performance summary response", service: "OpenAIService",
                metadata: [
                    "overallScore": String(response.overallScore)
                ])
            return response
        } catch {
            ClaimbLogger.error(
                "Failed to parse performance summary response", service: "OpenAIService",
                metadata: [
                    "error": error.localizedDescription,
                    "responseLength": String(responseText.count),
                ])
            throw OpenAIError.invalidResponse
        }
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
