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
    public let keyTrends: [String]  // Specific metrics improving/declining with numbers
    public let roleConsistency: String  // Feedback on role focus
    public let championPoolAnalysis: String  // Feedback on champion selection
    public let areasOfImprovement: [String]  // What to work on
    public let strengthsToMaintain: [String]  // What's working well
    public let climbingAdvice: String  // Actionable advice to improve rank

    public init(
        keyTrends: [String],
        roleConsistency: String,
        championPoolAnalysis: String,
        areasOfImprovement: [String],
        strengthsToMaintain: [String],
        climbingAdvice: String
    ) {
        self.keyTrends = keyTrends
        self.roleConsistency = roleConsistency
        self.championPoolAnalysis = championPoolAnalysis
        self.areasOfImprovement = areasOfImprovement
        self.strengthsToMaintain = strengthsToMaintain
        self.climbingAdvice = climbingAdvice
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
            model: "gpt-4o-mini",  // TODO: Upgrade to gpt-5-mini after edge function supports Responses API
            maxOutputTokens: 450  // Consistent token limit for concise responses
        )

        // Parse response
        return try parsePostGameResponse(responseText)
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

        // Get best performing champions data (aligned with ChampionView)
        let bestPerformingChampions = await getBestPerformingChampions(
            matches: matches,
            summoner: summoner,
            primaryRole: primaryRole
        )

        // Create performance summary prompt
        let prompt = createPerformanceSummaryPrompt(
            matches: matches,
            summoner: summoner,
            diversityMetrics: diversityMetrics,
            roleTrends: roleTrends,
            bestPerformingChampions: bestPerformingChampions,
            primaryRole: primaryRole,
            kpiService: kpiService
        )

        // Make API request
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            model: "gpt-4o-mini",  // TODO: Upgrade to gpt-5-mini after edge function supports Responses API
            maxOutputTokens: 450  // Consistent token limit for concise responses
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
            You are a League of Legends coach analyzing a single game for immediate improvement.

            **GAME CONTEXT:**
            Player: \(summoner.gameName) | Champion: \(championName) | Role: \(role)
            Result: \(gameResult) | KDA: \(kda) | CS: \(cs) | Duration: \(gameDuration)min\(rankContext)
            \(teamContext)
            """

        // Add lane opponent information if available
        if let opponent = laneOpponent {
            prompt += """

                **LANE MATCHUP:**
                \(championName) (\(role)) vs \(opponent)
                """
        }

        // Add timeline data if available
        if let timeline = timelineData {
            prompt += """

                **EARLY GAME TIMELINE:**
                \(timeline)

                **ANALYSIS FOCUS:**
                Using the timeline data, identify:
                1. Specific timing mistakes or missed opportunities (cite minute marks)
                2. Trading patterns and lane management errors
                3. Champion-specific power spike utilization
                4. Wave management and recall timings
                5. Early game objective participation

                """
        } else {
            prompt += """

                **ANALYSIS FOCUS:**
                Based on the game stats, provide:
                1. Champion-specific performance insights for \(championName) in \(role)
                2. Lane matchup considerations vs \(laneOpponent ?? "opponent")
                3. Role-specific fundamentals (csing, trading, positioning)

                """
        }

        prompt += """
            **IMPORTANT GUIDELINES:**
            - Focus ONLY on THIS game - no champion pool recommendations
            - Be specific and actionable (e.g., "At 6:30, you should have..." not "Try to farm better")
            - Reference actual game events when timeline data is available
            - Keep advice grounded in what happened in THIS match
            - Prioritize early game improvements (first 15 minutes)
            - Provide constructive feedback that helps improve next game performance

            **RESPONSE FORMAT (JSON only):**
            {
              "championName": "\(championName)",
              "gameResult": "\(gameResult)",
              "kda": "\(kda)",
              "keyTakeaways": [
                "Specific insight with timing when available (e.g., 'Strong first blood at 3:15 showed good aggression')",
                "Specific mistake with timing when available (e.g., 'Died at 7:40 while overextended without vision')",
                "Pattern observed in this game (e.g., 'Consistent CS advantage in first 10 minutes')"
              ],
              "championSpecificAdvice": "Detailed \(championName)-specific advice for \(role) based on this game's performance. Be specific about what worked and what didn't in THIS match. Include champion mechanics, power spikes, and matchup-specific tips.",
              "nextGameFocus": [
                "Specific, measurable improvement for next game",
                "Another specific, actionable focus point"
              ]
            }

            **REMEMBER:** Focus only on THIS game. No champion pool advice. Be specific and actionable.

            Answer in plain text JSON only. Respond ONLY with valid JSON. No explanations outside JSON.
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
                    "rawResponse": responseText.prefix(500)
                        + (responseText.count > 500 ? "..." : ""),
                ])
            throw OpenAIError.invalidResponse
        }
    }

    // MARK: - Performance Summary Helpers

    /// Gets best performing champions data aligned with ChampionView filtering logic
    private func getBestPerformingChampions(
        matches: [Match],
        summoner: Summoner,
        primaryRole: String
    ) async -> [String: Any] {
        let recentMatches = Array(matches.prefix(10))

        // Calculate champion performance statistics
        var championStats:
            [String: (games: Int, wins: Int, winRate: Double, avgCS: Double, avgKDA: Double)] = [:]

        for match in recentMatches {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid }),
                let championName = participant.champion?.name
            else { continue }

            let role = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)

            // Only include champions from primary role for consistency with ChampionView
            guard role == primaryRole else { continue }

            let cs = participant.totalMinionsKilled + participant.neutralMinionsKilled
            let kda =
                (Double(participant.kills) + Double(participant.assists))
                / max(Double(participant.deaths), 1.0)

            if championStats[championName] == nil {
                championStats[championName] = (
                    games: 0, wins: 0, winRate: 0.0, avgCS: 0.0, avgKDA: 0.0
                )
            }

            var stats = championStats[championName]!
            stats.games += 1
            if participant.win {
                stats.wins += 1
            }
            stats.avgCS = (stats.avgCS * Double(stats.games - 1) + Double(cs)) / Double(stats.games)
            stats.avgKDA = (stats.avgKDA * Double(stats.games - 1) + kda) / Double(stats.games)
            championStats[championName] = stats
        }

        // Calculate win rates and filter by minimum games
        var bestPerformers:
            [(name: String, games: Int, winRate: Double, avgCS: Double, avgKDA: Double)] = []

        for (champion, stats) in championStats {
            guard stats.games >= AppConstants.ChampionFiltering.minimumGamesForBestPerforming else {
                continue
            }

            let winRate = Double(stats.wins) / Double(stats.games)
            bestPerformers.append(
                (
                    name: champion,
                    games: stats.games,
                    winRate: winRate,
                    avgCS: stats.avgCS,
                    avgKDA: stats.avgKDA
                ))
        }

        // Sort by win rate (best performers first)
        bestPerformers.sort { $0.winRate > $1.winRate }

        // Filter by win rate threshold (same logic as ChampionView)
        let highPerformers = bestPerformers.filter {
            $0.winRate >= AppConstants.ChampionFiltering.defaultWinRateThreshold
        }

        let finalChampions =
            highPerformers.count >= AppConstants.ChampionFiltering.minimumChampionsForFallback
            ? highPerformers
            : bestPerformers.filter {
                $0.winRate >= AppConstants.ChampionFiltering.fallbackWinRateThreshold
            }

        ClaimbLogger.debug(
            "Calculated best performing champions for Summary prompt",
            service: "OpenAIService",
            metadata: [
                "primaryRole": primaryRole,
                "totalChampions": String(championStats.count),
                "bestPerformers": String(finalChampions.count),
                "champions": finalChampions.prefix(3).map {
                    "\($0.name) (\(Int($0.winRate * 100))%)"
                }.joined(separator: ", "),
            ]
        )

        return [
            "champions": finalChampions.map { champion in
                [
                    "name": champion.name,
                    "games": champion.games,
                    "winRate": champion.winRate,
                    "avgCS": champion.avgCS,
                    "avgKDA": champion.avgKDA,
                ]
            },
            "count": finalChampions.count,
            "primaryRole": primaryRole,
        ]
    }

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

    /// Prepares detailed match context with KPIs, role consistency, and champion performance
    private func prepareDetailedMatchContext(
        matches: [Match],
        summoner: Summoner,
        primaryRole: String
    ) -> String {
        let recentMatches = Array(matches.prefix(10))

        var context = "**GAME-BY-GAME BREAKDOWN (Last 10 matches):**\n"

        // Track role and champion distribution
        var roleDistribution: [String: Int] = [:]
        var championPerformance:
            [String: (wins: Int, losses: Int, totalCS: Int, totalDeaths: Int, games: Int)] = [:]

        for (index, match) in recentMatches.enumerated() {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else { continue }

            let championName = participant.champion?.name ?? "Unknown"
            let role = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)
            let result = participant.win ? "Win" : "Loss"
            let kda = "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
            let cs = participant.totalMinionsKilled + participant.neutralMinionsKilled
            let csPerMin = String(format: "%.1f", participant.csPerMinute)
            let vision = participant.visionScore

            context +=
                "Game \(index + 1): \(championName) (\(role)) - \(result) | KDA: \(kda) | CS/min: \(csPerMin) | Vision: \(vision)\n"

            // Track role distribution
            roleDistribution[role, default: 0] += 1

            // Track champion performance
            if championPerformance[championName] == nil {
                championPerformance[championName] = (
                    wins: 0, losses: 0, totalCS: 0, totalDeaths: 0, games: 0
                )
            }
            var perf = championPerformance[championName]!
            if participant.win {
                perf.wins += 1
            } else {
                perf.losses += 1
            }
            perf.totalCS += cs
            perf.totalDeaths += participant.deaths
            perf.games += 1
            championPerformance[championName] = perf
        }

        // Add role consistency analysis
        context += "\n**ROLE CONSISTENCY:**\n"
        let primaryRoleGames = roleDistribution[primaryRole, default: 0]
        let primaryRolePercent =
            recentMatches.isEmpty
            ? 0 : (Double(primaryRoleGames) / Double(recentMatches.count)) * 100
        context +=
            "- Primary Role (\(RoleUtils.displayName(for: primaryRole))): \(primaryRoleGames)/\(recentMatches.count) games (\(String(format: "%.0f", primaryRolePercent))%)\n"

        for (role, count) in roleDistribution.sorted(by: { $0.value > $1.value })
        where role != primaryRole {
            context += "- \(RoleUtils.displayName(for: role)): \(count) games\n"
        }

        if primaryRolePercent < 70 {
            context +=
                "⚠️ Low role consistency - recommend 80%+ games in primary role for improvement\n"
        }

        // Add champion pool analysis
        context += "\n**CHAMPION POOL ANALYSIS:**\n"
        let sortedChampions = championPerformance.sorted { $0.value.games > $1.value.games }

        for (index, (champion, perf)) in sortedChampions.prefix(5).enumerated() {
            let winRate = perf.games > 0 ? (Double(perf.wins) / Double(perf.games)) * 100 : 0
            let avgCS = perf.games > 0 ? perf.totalCS / perf.games : 0
            let avgDeaths = perf.games > 0 ? Double(perf.totalDeaths) / Double(perf.games) : 0
            context +=
                "\(index + 1). \(champion): \(perf.wins)-\(perf.losses) (\(String(format: "%.0f", winRate))% WR) - Avg \(avgCS) CS, \(String(format: "%.1f", avgDeaths)) deaths/game\n"
        }

        if sortedChampions.count > 3 {
            context +=
                "⚠️ Playing \(sortedChampions.count) different champions - recommend focusing on 3 or fewer for consistency\n"
        }

        // Add KPI trends
        context += "\n**KPI TRENDS:**\n"
        let firstHalf = recentMatches.prefix(5)
        let secondHalf = recentMatches.suffix(5)

        let firstHalfAvgCS =
            firstHalf.compactMap { match -> Double? in
                guard
                    let participant = match.participants.first(where: { $0.puuid == summoner.puuid }
                    )
                else { return nil }
                return participant.csPerMinute
            }.reduce(0.0, +) / Double(max(firstHalf.count, 1))

        let secondHalfAvgCS =
            secondHalf.compactMap { match -> Double? in
                guard
                    let participant = match.participants.first(where: { $0.puuid == summoner.puuid }
                    )
                else { return nil }
                return participant.csPerMinute
            }.reduce(0.0, +) / Double(max(secondHalf.count, 1))

        let firstHalfAvgDeaths =
            firstHalf.compactMap { match -> Double? in
                guard
                    let participant = match.participants.first(where: { $0.puuid == summoner.puuid }
                    )
                else { return nil }
                return Double(participant.deaths)
            }.reduce(0.0, +) / Double(max(firstHalf.count, 1))

        let secondHalfAvgDeaths =
            secondHalf.compactMap { match -> Double? in
                guard
                    let participant = match.participants.first(where: { $0.puuid == summoner.puuid }
                    )
                else { return nil }
                return Double(participant.deaths)
            }.reduce(0.0, +) / Double(max(secondHalf.count, 1))

        context +=
            "- CS/min: Games 1-5 avg \(String(format: "%.1f", firstHalfAvgCS)), Games 6-10 avg \(String(format: "%.1f", secondHalfAvgCS))"
        if secondHalfAvgCS > firstHalfAvgCS {
            context += " (↑ improving)\n"
        } else if secondHalfAvgCS < firstHalfAvgCS {
            context += " (↓ declining)\n"
        } else {
            context += " (→ stable)\n"
        }

        context +=
            "- Deaths: Games 1-5 avg \(String(format: "%.1f", firstHalfAvgDeaths)), Games 6-10 avg \(String(format: "%.1f", secondHalfAvgDeaths))"
        if secondHalfAvgDeaths < firstHalfAvgDeaths {
            context += " (↑ improving)\n"
        } else if secondHalfAvgDeaths > firstHalfAvgDeaths {
            context += " (↓ worsening)\n"
        } else {
            context += " (→ stable)\n"
        }

        return context
    }

    private func createPerformanceSummaryPrompt(
        matches: [Match],
        summoner: Summoner,
        diversityMetrics: (roleCount: Int, championCount: Int),
        roleTrends: [String: String],
        bestPerformingChampions: [String: Any],
        primaryRole: String,
        kpiService: KPICalculationService? = nil
    ) -> String {
        let recentMatches = Array(matches.prefix(10))
        let wins = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })?.win
        }.filter { $0 }.count

        let winRate = recentMatches.isEmpty ? 0.0 : Double(wins) / Double(recentMatches.count)

        // Get rank context
        let rankContext = createRankContext(summoner: summoner)

        // Add streak context if kpiService is available
        var streakContext = ""
        if let kpiService = kpiService {
            let losingStreak = kpiService.calculateLosingStreak(
                matches: matches, summoner: summoner, role: primaryRole)
            let winningStreak = kpiService.calculateWinningStreak(
                matches: matches, summoner: summoner, role: primaryRole)
            let recentPerformance = kpiService.calculateRecentWinRate(
                matches: matches, summoner: summoner, role: primaryRole)

            streakContext = """

                **Current Streaks & Recent Performance:**
                - Primary Role: \(RoleUtils.displayName(for: primaryRole))
                - Recent \(primaryRole) Performance: \(recentPerformance.wins)W-\(recentPerformance.losses)L (\(String(format: "%.1f", recentPerformance.winRate))% win rate)
                - Current Streak: \(winningStreak > 0 ? "\(winningStreak) wins" : losingStreak > 0 ? "\(losingStreak) losses" : "No active streak")
                """

            if losingStreak >= 3 {
                streakContext +=
                    "\n- ⚠️ WARNING: Player is on a \(losingStreak) game losing streak - suggest taking a break or playing normals"
            }
            if winningStreak >= 3 {
                streakContext +=
                    "\n- 🔥 Player is on a \(winningStreak) game winning streak - encourage maintaining momentum"
            }
        }

        // Prepare detailed match context
        let detailedContext = prepareDetailedMatchContext(
            matches: matches,
            summoner: summoner,
            primaryRole: primaryRole
        )

        // Format best performing champions data for the prompt
        let bestChampionsData = bestPerformingChampions["champions"] as? [[String: Any]] ?? []
        let bestChampionsCount = bestPerformingChampions["count"] as? Int ?? 0

        var championPoolContext = ""
        if bestChampionsCount > 0 {
            championPoolContext = "\n\n**BEST PERFORMING CHAMPIONS (Primary Role Only):**\n"
            for (index, champion) in bestChampionsData.prefix(5).enumerated() {
                let name = champion["name"] as? String ?? "Unknown"
                let games = champion["games"] as? Int ?? 0
                let winRate = champion["winRate"] as? Double ?? 0.0
                let avgCS = champion["avgCS"] as? Double ?? 0.0
                let avgKDA = champion["avgKDA"] as? Double ?? 0.0

                championPoolContext +=
                    "\(index + 1). \(name): \(games) games, \(String(format: "%.0f", winRate * 100))% WR, \(String(format: "%.0f", avgCS)) avg CS, \(String(format: "%.1f", avgKDA)) avg KDA\n"
            }

            if bestChampionsCount < 3 {
                championPoolContext +=
                    "⚠️ Limited champion pool - consider expanding to 3+ champions for better consistency\n"
            }
        } else {
            championPoolContext =
                "\n\n**CHAMPION POOL:** No qualifying champions found (need 3+ games with 50%+ win rate)\n"
        }

        return """
            You are a League of Legends coach analyzing performance trends to help the player climb in ranked.

            **Player:** \(summoner.gameName) | **Primary Role:** \(RoleUtils.displayName(for: primaryRole)) | **Overall Record:** \(wins)W-\(recentMatches.count - wins)L (\(String(format: "%.0f", winRate * 100))%)\(rankContext)\(streakContext)

            \(detailedContext)\(championPoolContext)

            **ANALYSIS GUIDELINES:**
            1. **Key Trends**: Identify 2-3 specific metrics that are improving or declining with actual numbers (e.g., "CS/min improved from 5.2 to 6.1") - DO NOT include game ranges like "(Games 1-5)" or "(Games 6-10)"
            2. **Role Consistency**: Give encouraging feedback on role focus with specific percentage. If 80%+, praise their consistency. If below 80%, gently suggest focusing more on primary role.
            3. **Champion Pool**: CRITICAL - Only recommend champions from the "BEST PERFORMING CHAMPIONS" list above. Focus on their top 3 performers. Do NOT suggest champions not in this list.
            4. **Areas of Improvement**: Specific, measurable areas to work on (with numbers when possible)
            5. **Strengths to Maintain**: What's working well that should be continued
            6. **Climbing Advice**: Actionable, specific advice to improve rank (not generic tips)

            **IMPORTANT CHAMPION POOL RULES:**
            - ONLY suggest champions from the "BEST PERFORMING CHAMPIONS" list above
            - Focus on their top 3 champions by win rate and games played
            - If they have <3 qualifying champions, encourage them to play more games with their best performers
            - NEVER suggest champions not in the best performing list
            - Emphasize consistency with proven performers over trying new champions

            **IMPORTANT:**
            - Focus on CONSISTENCY as the key to climbing (role focus + champion pool)
            - Use ACTUAL NUMBERS from the data provided
            - Be SPECIFIC and ACTIONABLE, not generic
            - Identify TRENDS (improving/declining) rather than single-game issues
            - Consider streaks and recent performance when giving advice
            - Be ENCOURAGING and POSITIVE - praise good habits and frame improvements as opportunities
            - For role consistency: If they're doing well (80%+), celebrate it. If not, encourage improvement without being critical

            **RESPONSE FORMAT (JSON only):**
            {
              "keyTrends": [
                "Specific metric with numbers showing improvement or decline",
                "Another specific trend with data"
              ],
              "roleConsistency": "Encouraging feedback on role focus with specific percentage. If 80%+, praise their consistency. If below 80%, gently suggest focusing more on primary role.",
              "championPoolAnalysis": "Specific feedback focusing ONLY on champions from the best performing list. Recommend sticking with top 3 performers and explain why these champions work well for them.",
              "areasOfImprovement": [
                "Specific, measurable area to work on",
                "Another specific area with context"
              ],
              "strengthsToMaintain": [
                "Specific strength with supporting data",
                "Another strength to continue"
              ],
              "climbingAdvice": "Specific, actionable advice for improving rank based on the data - focus on consistency and playing strengths. Emphasize sticking with proven champion performers."
            }

            Answer in plain text JSON only. Respond ONLY with valid JSON. No explanations outside JSON.
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
                    "trendsCount": String(response.keyTrends.count),
                    "improvementsCount": String(response.areasOfImprovement.count),
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
