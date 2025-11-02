//
//  CoachingPromptBuilder.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-09.
//

import Foundation

/// Builds AI coaching prompts for different analysis types
public struct CoachingPromptBuilder {

    // MARK: - Post-Game Analysis Prompts

    /// Creates a comprehensive post-game analysis prompt with timeline data
    public static func createPostGamePrompt(
        match: Match,
        participant: Participant,
        summoner: Summoner,
        championName: String,
        role: String,
        timelineData: String?,
        laneOpponent: String?,
        teamContext: String,
        relativePerformanceContext: String? = nil,
        baselineContext: String? = nil
    ) -> String {
        let gameResult = participant.win ? "Victory" : "Defeat"
        let kda = "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
        let cs = MatchStatsCalculator.calculateTotalCS(participant: participant)
        let gameDuration = match.gameDuration / 60

        let rankContext = createRankContext(summoner: summoner)

        // Add critical performance metrics
        let csPerMin = participant.csPerMinute.oneDecimal
        let visionPerMin = participant.visionScorePerMinute.oneDecimal
        let killParticipation = participant.killParticipation.asPercentage
        let teamDamage = participant.teamDamagePercentage.asPercentage
        let goldPerMin = participant.goldPerMinute.asWholeNumber
        let objectiveParticipation = String(
            format: "%.0f%%", participant.objectiveParticipationPercentage)

        // Add queue context for coaching relevance
        let queueContext =
            match.isRanked
            ? " | Queue: \(match.queueName)" : " | Queue: \(match.queueName) (practice)"

        // Build system context with relative performance if available
        var systemContext =
            "You are a League of Legends coach analyzing a single game for immediate improvement."

        if let relativeContext = relativePerformanceContext {
            systemContext += """


                Context for your analysis (use naturally in your coaching, don't mention explicitly):
                \(relativeContext)

                Consider this when coaching: If player performed above team average despite a loss or faced fed enemies, be encouraging and acknowledge their effort. If player underperformed compared to teammates, be constructively critical. Adjust your tone and focus based on whether they carried, performed average, or were carried by their team.
                """
        }

        var prompt = """
            \(systemContext)

            **GAME CONTEXT:**
            Player: \(summoner.gameName) | Champion: \(championName) | Role: \(role)
            Result: \(gameResult) | KDA: \(kda) | Duration: \(gameDuration)min\(queueContext)\(rankContext)
            \(teamContext)

            **PERFORMANCE METRICS:**
            - CS: \(cs) total (\(csPerMin)/min)
            - Vision: \(visionPerMin)/min
            - Kill Participation: \(killParticipation)
            - Team Damage: \(teamDamage)
            - Gold/min: \(goldPerMin)
            - Objective Participation: \(objectiveParticipation)
            """

        // Add baseline context if available (simple, focused comparison)
        if let baseline = baselineContext {
            prompt += """

                **BASELINE COMPARISON:**
                \(baseline)
                Note: Use these targets as context for improvement areas, not as strict goals to mention.
                """
        }

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

                **TIMELINE:** \(timeline)
                Focus on: Specific timing mistakes, trading errors, power spikes, recalls.
                """
        }

        prompt += """

            **OUTPUT (JSON, max 100 words):**
            {
              "keyTakeaways": ["3 actionable insights, avoid stats and parentheses"],
              "championSpecificAdvice": "2 sentences: what worked, what didn't",
              "nextGameFocus": ["1 specific goal", "1 measurable target"]
            }

            CRITICAL: Respond with ONLY valid JSON. No markdown, no explanation, no text before or after.
            Focus on actionable advice, avoid technical stats and parentheses.
            Ensure all required fields are present and properly formatted.

            IMPORTANT: If this was a strong performance (Victory with good KDA or impressive stats), START your keyTakeaways with positive recognition and praise. Examples: "Excellent performance - you dominated your lane", "Great job securing the win with strong map awareness", "Well played - your champion mastery really showed".
            """

        return prompt
    }

    // MARK: - Performance Summary Prompts

    /// Streak data for prompt context
    public struct StreakData {
        public let losingStreak: Int
        public let winningStreak: Int
        public let recentWins: Int
        public let recentLosses: Int
        public let recentWinRate: Double

        public init(
            losingStreak: Int, winningStreak: Int, recentWins: Int, recentLosses: Int,
            recentWinRate: Double
        ) {
            self.losingStreak = losingStreak
            self.winningStreak = winningStreak
            self.recentWins = recentWins
            self.recentLosses = recentLosses
            self.recentWinRate = recentWinRate
        }
    }

    /// Creates a performance summary prompt for trend analysis
    public static func createPerformanceSummaryPrompt(
        matches: [Match],
        summoner: Summoner,
        primaryRole: String,
        bestPerformingChampions: [MatchStatsCalculator.ChampionStats],
        streakData: StreakData?
    ) -> String {
        let recentMatches = Array(matches.prefix(10))
        let wins = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })?.win
        }.filter { $0 }.count

        let winRate = recentMatches.isEmpty ? 0.0 : Double(wins) / Double(recentMatches.count)

        let rankContext = createRankContext(summoner: summoner)
        let streakContext = createStreakContext(
            primaryRole: primaryRole, streakData: streakData)
        let detailedContext = createDetailedMatchContext(
            matches: matches, summoner: summoner, primaryRole: primaryRole)
        let championPoolContext = createChampionPoolContext(
            bestPerformingChampions: bestPerformingChampions)

        return """
            You are a League of Legends coach analyzing performance trends to help the player climb in ranked.

            **Player:** \(summoner.gameName) | **Primary Role:** \(RoleUtils.displayName(for: primaryRole)) | **Overall Record:** \(wins)W-\(recentMatches.count - wins)L (\(String(format: "%.0f", winRate * 100))%)\(rankContext)\(streakContext)

            \(detailedContext)\(championPoolContext)


            **OUTPUT (JSON, max 120 words):**
            {
              "keyTrends": ["2 trends, avoid stats and parentheses"],
              "roleConsistency": "1 sentence about role focus",
              "championPoolAnalysis": "Focus on top 3 from BEST PERFORMING list. 2 sentences.",
              "areasOfImprovement": ["2 areas, concise and actionable"],
              "strengthsToMaintain": ["2 strengths, concise"],
              "climbingAdvice": "2 sentences - consistency with proven champions"
            }

            CRITICAL: Respond with ONLY valid JSON. No markdown, no explanation, no text before or after.
            Focus on actionable advice, avoid technical stats and parentheses.
            Ensure all required fields are present and properly formatted.
            """
    }

    // MARK: - Context Builders

    /// Creates rank context string for prompts
    public static func createRankContext(summoner: Summoner) -> String {
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

    /// Creates streak and recent performance context from pre-calculated data
    private static func createStreakContext(
        primaryRole: String,
        streakData: StreakData?
    ) -> String {
        guard let data = streakData else { return "" }

        var context = """

            **Current Streaks & Recent Performance:**
            - Primary Role: \(RoleUtils.displayName(for: primaryRole))
            - Recent \(primaryRole) Performance: \(data.recentWins)W-\(data.recentLosses)L (\(String(format: "%.1f", data.recentWinRate))% win rate)
            - Current Streak: \(data.winningStreak > 0 ? "\(data.winningStreak) wins" : data.losingStreak > 0 ? "\(data.losingStreak) losses" : "No active streak")
            """

        if data.losingStreak >= 3 {
            context +=
                "\n- ⚠️ WARNING: Player is on a \(data.losingStreak) game losing streak - suggest taking a break or playing normals"
        }
        if data.winningStreak >= 3 {
            context +=
                "\n- 🔥 Player is on a \(data.winningStreak) game winning streak - encourage maintaining momentum"
        }

        return context
    }

    /// Creates detailed match-by-match context with role and champion distribution
    private static func createDetailedMatchContext(
        matches: [Match],
        summoner: Summoner,
        primaryRole: String
    ) -> String {
        // Restrict diversity context to ranked only
        let recentMatches = Array(matches.filter { $0.isRanked }.prefix(10))

        var context = "**RECENT GAMES SUMMARY (Last 10 ranked matches):**\n"

        // Track role and champion distribution
        var roleDistribution: [String: Int] = [:]
        var championPerformance: [String: (wins: Int, losses: Int, games: Int)] = [:]

        for match in recentMatches {
            guard
                let participant = MatchStatsCalculator.findParticipant(
                    summoner: summoner, in: match)
            else { continue }

            let championName = participant.champion?.name ?? "Unknown"
            let role = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)

            // Track role distribution
            roleDistribution[role, default: 0] += 1

            // Track champion performance
            if championPerformance[championName] == nil {
                championPerformance[championName] = (
                    wins: 0, losses: 0, games: 0
                )
            }
            var perf = championPerformance[championName]!
            if participant.win {
                perf.wins += 1
            } else {
                perf.losses += 1
            }
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

        for (index, (champion, perf)) in sortedChampions.prefix(3).enumerated() {
            let result = perf.wins > perf.losses ? "positive" : "struggling"
            context +=
                "\(index + 1). \(champion) - \(result)\n"
        }

        if sortedChampions.count > 3 {
            context +=
                "⚠️ Playing \(sortedChampions.count) different champions - recommend focusing on 3 or fewer for consistency\n"
        }

        // Add KPI trends
        context += createKPITrendsContext(matches: recentMatches, summoner: summoner)

        return context
    }

    /// Creates champion pool context for performance summary prompts
    private static func createChampionPoolContext(
        bestPerformingChampions: [MatchStatsCalculator.ChampionStats]
    ) -> String {
        var context = ""

        if !bestPerformingChampions.isEmpty {
            context = "\n\n**BEST PERFORMING CHAMPIONS (Primary Role Only):**\n"
            for (index, champion) in bestPerformingChampions.prefix(3).enumerated() {
                context +=
                    "\(index + 1). \(champion.name) - performing well\n"
            }

            if bestPerformingChampions.count < 3 {
                context +=
                    "⚠️ Limited champion pool - consider expanding to 3+ champions for better consistency\n"
            }
        } else {
            context =
                "\n\n**CHAMPION POOL:** No qualifying champions found (need 3+ games with 50%+ win rate)\n"
        }

        return context
    }

    /// Creates KPI trends context comparing first half vs second half of recent games
    private static func createKPITrendsContext(matches: [Match], summoner: Summoner) -> String {
        var context = "\n**KPI TRENDS:**\n"
        let firstHalf = Array(matches.prefix(5))
        let secondHalf = Array(matches.suffix(5))

        let firstHalfAvgCS = calculateAverageCS(matches: firstHalf, summoner: summoner)
        let secondHalfAvgCS = calculateAverageCS(matches: secondHalf, summoner: summoner)

        if secondHalfAvgCS > firstHalfAvgCS {
            context += "- CS/min: improving\n"
        } else if secondHalfAvgCS < firstHalfAvgCS {
            context += "- CS/min: declining\n"
        } else {
            context += "- CS/min: stable\n"
        }

        let firstHalfAvgDeaths = calculateAverageDeaths(matches: firstHalf, summoner: summoner)
        let secondHalfAvgDeaths = calculateAverageDeaths(matches: secondHalf, summoner: summoner)

        if secondHalfAvgDeaths < firstHalfAvgDeaths {
            context += "- Deaths: improving\n"
        } else if secondHalfAvgDeaths > firstHalfAvgDeaths {
            context += "- Deaths: worsening\n"
        } else {
            context += "- Deaths: stable\n"
        }

        return context
    }

    // MARK: - Helper Methods

    private static func calculateAverageCS(matches: [Match], summoner: Summoner) -> Double {
        let values = matches.compactMap { match -> Double? in
            guard
                let participant = MatchStatsCalculator.findParticipant(
                    summoner: summoner, in: match)
            else { return nil }
            return participant.csPerMinute
        }
        return values.isEmpty ? 0.0 : values.reduce(0.0, +) / Double(values.count)
    }

    private static func calculateAverageDeaths(matches: [Match], summoner: Summoner) -> Double {
        let values = matches.compactMap { match -> Double? in
            guard
                let participant = MatchStatsCalculator.findParticipant(
                    summoner: summoner, in: match)
            else { return nil }
            return Double(participant.deaths)
        }
        return values.isEmpty ? 0.0 : values.reduce(0.0, +) / Double(values.count)
    }
}
