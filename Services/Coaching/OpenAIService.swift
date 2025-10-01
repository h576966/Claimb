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

    public init(
        strengths: [String],
        improvements: [String],
        actionableTips: [String],
        championAdvice: String,
        nextSteps: [String],
        overallScore: Int,
        priorityFocus: String
    ) {
        self.strengths = strengths
        self.improvements = improvements
        self.actionableTips = actionableTips
        self.championAdvice = championAdvice
        self.nextSteps = nextSteps
        self.overallScore = overallScore
        self.priorityFocus = priorityFocus
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
            model: "gpt-4o-mini",  // Use valid GPT-4o Mini model
            maxOutputTokens: 1000  // Sufficient tokens for structured response
        )

        // Parse structured JSON response
        return try parseCoachingResponse(responseText)
    }

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
        guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
        else {
            throw OpenAIError.invalidResponse
        }

        // Get champion data
        let championName = participant.champion?.name ?? "Unknown Champion"
        let role = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)

        // Get lane opponent and team context
        let (laneOpponent, teamContext) = getLaneOpponentAndTeamContext(
            match: match,
            userParticipant: participant
        )

        // Try to get timeline data for enhanced analysis
        var timelineData: String? = nil
        do {
            let proxyService = ProxyService()
            timelineData = try await proxyService.riotTimelineLite(
                matchId: match.matchId,
                puuid: summoner.puuid,
                region: "europe"
            )
            ClaimbLogger.info(
                "Retrieved timeline data for post-game analysis", service: "OpenAIService",
                metadata: [
                    "matchId": match.matchId,
                    "championName": championName,
                    "timelineLength": String(timelineData?.count ?? 0),
                ])
        } catch {
            ClaimbLogger.warning(
                "Failed to retrieve timeline data, proceeding without it", service: "OpenAIService",
                metadata: ["matchId": match.matchId, "error": error.localizedDescription])
        }

        // Get champion-specific performance data
        let championPerformance = await getChampionPerformance(
            summoner: summoner,
            championId: participant.championId,
            role: role,
            kpiService: kpiService
        )

        // Create post-game analysis prompt with timeline data
        let prompt = createPostGamePromptWithTimeline(
            match: match,
            participant: participant,
            summoner: summoner,
            championName: championName,
            role: role,
            championPerformance: championPerformance,
            timelineData: timelineData,
            laneOpponent: laneOpponent,
            teamContext: teamContext
        )

        // Make API request
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            model: "gpt-4o-mini",
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
            model: "gpt-4o-mini",
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

    /// Extracts lane opponent and team context information
    private func getLaneOpponentAndTeamContext(
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

    private func createCoachingPrompt(
        summoner: Summoner,
        matchSummary: String,
        primaryRole: String,
        personalBaselines: [String: Double] = [:]
    ) -> String {
        let baselineContext =
            personalBaselines.isEmpty ? "" : createBaselineContext(baselines: personalBaselines)

        let rankContext = createRankContext(summoner: summoner)
        
        return """
            You are a League of Legends coach. Analyze this player's performance and provide concise coaching insights.

            **Player:** \(summoner.gameName)#\(summoner.tagLine) | **Role:** \(primaryRole)\(rankContext)
            \(baselineContext)
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

    private func createBaselineContext(baselines: [String: Double]) -> String {
        var context = "\n**Personal Performance Averages:**\n"
        for (metric, value) in baselines {
            context += "\(metric): \(String(format: "%.2f", value))\n"
        }
        return context
    }

    private func createRankContext(summoner: Summoner) -> String {
        guard summoner.hasAnyRank else { return "" }
        
        var context = " | **Rank:** "
        if let soloDuoRank = summoner.soloDuoRank {
            context += "Solo/Duo: \(soloDuoRank)"
            if let lp = summoner.soloDuoLP {
                context += " (\(lp) LP)"
            }
        }
        
        if let flexRank = summoner.flexRank {
            if summoner.soloDuoRank != nil {
                context += ", Flex: \(flexRank)"
            } else {
                context += "Flex: \(flexRank)"
            }
            if let lp = summoner.flexLP {
                context += " (\(lp) LP)"
            }
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
        // This should not be called anymore since we pass the actual champion data
        // But keeping as fallback
        return "Champion \(championId)"
    }

    private func getChampionPerformance(
        summoner: Summoner,
        championId: Int,
        role: String,
        kpiService: KPICalculationService
    ) async -> [String: Double] {
        // Get champion-specific performance data from recent matches
        // This integrates with the existing champion pool analysis system
        do {
            let kpis = try await kpiService.calculateRoleKPIs(
                matches: [],  // Would need to pass recent matches here
                role: role,
                summoner: summoner
            )

            var performance: [String: Double] = [:]
            for kpi in kpis {
                if let doubleValue = Double(kpi.value) {
                    performance[kpi.metric] = doubleValue
                }
            }
            return performance
        } catch {
            ClaimbLogger.warning(
                "Failed to get champion performance data", service: "OpenAIService",
                metadata: ["championId": String(championId), "error": error.localizedDescription])
            return [:]
        }
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

        let rankContext = createRankContext(summoner: summoner)
        
        return """
            League of Legends coach. Analyze this game and provide concise advice.

            **Game:** \(summoner.gameName) | \(championName) | \(role) | \(gameResult) | \(kda) | \(cs) CS | \(match.gameDuration / 60)min\(rankContext)

            **Response (JSON only):**
            {
              "championName": "\(championName)",
              "gameResult": "\(gameResult)",
              "kda": "\(kda)",
              "keyTakeaways": ["string", "string"],
              "championSpecificAdvice": "string",
              "championPoolAdvice": "string or null",
              "nextGameFocus": ["string", "string"]
            }

            **Focus:** Champion-specific advice for \(championName). Keep actionable.
            Respond ONLY with valid JSON.
            """
    }

    private func createPostGamePromptWithTimeline(
        match: Match,
        participant: Participant,
        summoner: Summoner,
        championName: String,
        role: String,
        championPerformance: [String: Double],
        timelineData: String?,
        laneOpponent: String?,
        teamContext: String
    ) -> String {
        let gameResult = participant.win ? "Victory" : "Defeat"
        let kda = "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
        let cs = participant.totalMinionsKilled + participant.neutralMinionsKilled
        let gameDuration = match.gameDuration / 60

        let rankContext = createRankContext(summoner: summoner)
        
        var prompt = """
            You are a League of Legends post-game analyst specializing in early game performance analysis.

            **GAME CONTEXT:**
            Player: \(summoner.gameName) | Champion: \(championName) | Role: \(role)
            Result: \(gameResult) | KDA: \(kda) | CS: \(cs) | Duration: \(gameDuration)min\(rankContext)
            \(teamContext)
            """

        // Add lane opponent information if available
        if let opponent = laneOpponent {
            prompt += """
                **LANE MATCHUP:**
                You played \(championName) (\(role)) vs \(opponent)

                """
        }

        // Add timeline data if available
        if let timeline = timelineData {
            prompt += """
                **EARLY GAME TIMELINE DATA:**
                \(timeline)

                **ANALYSIS APPROACH:**
                - Focus on early game fundamentals for \(championName) in \(role)
                - Use timeline data to identify specific timing issues
                - Provide actionable advice based on early game performance
                - Consider champion-specific power spikes and timings
                - Analyze lane matchup dynamics and trading patterns

                """
        } else {
            prompt += """
                **ANALYSIS APPROACH:**
                - Focus on champion-specific advice for \(championName) in \(role)
                - Provide actionable improvements for next game
                - Consider role-specific fundamentals
                - Analyze lane matchup dynamics and trading patterns

                """
        }

        prompt += """
            **RESPONSE FORMAT (JSON only):**
            {
              "championName": "\(championName)",
              "gameResult": "\(gameResult)",
              "kda": "\(kda)",
              "keyTakeaways": ["Specific early game insight 1", "Specific early game insight 2"],
              "championSpecificAdvice": "\(championName)-specific early game advice for \(role)",
              "championPoolAdvice": "Champion pool recommendation or null",
              "nextGameFocus": ["Early game improvement 1", "Early game improvement 2"]
            }

            **FOCUS:** Early game performance analysis with timeline context when available.
            Respond ONLY with valid JSON.
            """

        return prompt
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
        // Analyze role-based performance trends over last 10 games
        let recentMatches = Array(matches.prefix(10))
        var roleTrends: [String: String] = [:]

        // Get unique roles played
        let roles = Set(
            recentMatches.compactMap { match in
                match.participants.first(where: { $0.puuid == summoner.puuid })
                    .map { RoleUtils.normalizeRole(teamPosition: $0.teamPosition) }
            })

        for role in roles {
            do {
                let kpis = try await kpiService.calculateRoleKPIs(
                    matches: recentMatches,
                    role: role,
                    summoner: summoner
                )

                // Analyze trend based on KPI values
                let avgScore =
                    kpis.compactMap { Double($0.value) }.reduce(0, +) / Double(kpis.count)
                let trend = avgScore > 0.6 ? "improving" : avgScore > 0.4 ? "stable" : "declining"
                roleTrends[role] = trend
            } catch {
                ClaimbLogger.warning(
                    "Failed to analyze role trends for \(role)", service: "OpenAIService",
                    metadata: ["error": error.localizedDescription])
                roleTrends[role] = "unknown"
            }
        }

        return roleTrends
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
            League of Legends coach. Analyze performance trends over last 10 games.

            **Player:** \(summoner.gameName) | **Games:** \(recentMatches.count) | **Win Rate:** \(String(format: "%.1f", winRate * 100))% | **Roles:** \(diversityMetrics.roleCount) | **Champions:** \(diversityMetrics.championCount)

            **Response (JSON only):**
            {
              "overallScore": 7,
              "improvementsMade": ["string", "string"],
              "areasOfConcern": ["string", "string"],
              "roleDiversity": "string",
              "championDiversity": "string",
              "focusAreas": ["string", "string"],
              "progressionInsights": "string"
            }

            **Focus:** Role-based trends, improvements, concerns. Score 1-10.
            Respond ONLY with valid JSON.
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
