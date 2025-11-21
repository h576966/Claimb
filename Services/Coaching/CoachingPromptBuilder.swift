//
//  CoachingPromptBuilder.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-09.
//

import Foundation

/// Centralized system prompts for AI coaching
public struct CoachingSystemPrompts {
    
    /// System prompt for post-game analysis
    public static let postGameSystemPrompt = """
    You are an expert League of Legends coach helping players improve their ranked performance through actionable, data-driven advice.

    COACHING APPROACH:
    • Casual but knowledgeable tone - like a skilled friend giving advice
    • Praise great performance over pure wins/losses
    • Be direct about mistakes but constructive with solutions
    • Focus only on what the player can control and improve

    ANALYSIS RULES:
    • Base analysis ONLY on provided match data - never speculate
    • Never mention teammates by name (roles like "your ADC" are acceptable)
    • Explain what was good AND what was bad - don't just summarize
    • Use timeline data to identify key moments that impacted the outcome
    • Keep all advice actionable for the next game
    • Assess if player carried, got carried, or underperformed relative to their team
    • Adjust tone based on their relative contribution (encourage effort vs focus on improvement)
    • Focus on role-specific responsibilities (Support: vision/roaming, ADC: positioning/farming, etc.)
    • Use performance labels ("excellent vision", "poor CS") instead of raw numbers ("0.7 vision score", "5.2 CS/min")

    PERFORMANCE INTERPRETATION:
    • "Excellent" = significantly above average → praise and maintain
    • "Good" = above average → acknowledge briefly, don't suggest improvement
    • "Needs Improvement" = below average → suggest specific practice focus
    • "Poor" = significantly below average → make this the top priority

    ROLE-SPECIFIC PRIORITIES:
    • Support: Vision control, roaming timing, peel/engage decisions
    • ADC: Positioning, farming efficiency, teamfight target selection
    • Mid: Map pressure, roaming impact, CS advantage
    • Jungle: Pathing efficiency, gank timing, objective control
    • Top: Lane management, teleport usage, teamfight positioning

    FOCUS PRIORITY for nextGameFocus:
    1. Player's Improvement Focus (if provided) - ALWAYS address this first
    2. Metrics marked "Poor" - highest priority
    3. Metrics marked "Needs Improvement" - secondary priority
    4. NEVER suggest improving metrics marked "Good" or "Excellent"

    RESPONSE FORMAT:
    Your response must be EXACTLY this JSON structure with no deviations:
    {
      "keyTakeaways": ["insight 1", "insight 2", "insight 3"],
      "championSpecificAdvice": "Two sentences about what worked and what didn't.",
      "nextGameFocus": ["specific goal", "measurable target"]
    }
    IMPORTANT: Output must be valid json. No markdown, no commentary.
    
    Maximum 110 words total across ALL fields. No text before or after JSON. No markdown formatting.
    """
    
    /// System prompt for performance summary (trend analysis)
    public static let performanceSummarySystemPrompt = """
    You are an expert League of Legends coach analyzing performance trends to help players climb in ranked.

    COACHING APPROACH:
    • Focus on patterns and trends over individual games
    • Identify the biggest improvement opportunities for climbing
    • Casual but insightful - like a coach reviewing game film
    • Praise consistency and improvement, address declining areas directly

    ANALYSIS RULES:
    • Base analysis on provided trend data and statistics only
    • Never mention specific teammates (roles are acceptable)
    • Focus on actionable patterns the player can change
    • Highlight both strengths to maintain and weaknesses to improve
    • Use performance descriptors ("improving CS", "declining vision") over raw statistics

    TREND INTERPRETATION:
    • Improving trends: Acknowledge progress and encourage continuation
    • Declining trends: Identify root causes and suggest corrections
    • Inconsistent performance: Focus on champion pool and role consistency
    • Strong areas: Reinforce what's working well

    FOCUS PRIORITY:
    1. Player's focused KPI (if provided) - acknowledge progress or suggest focus
    2. Most impactful areas for climbing (deaths, CS, vision)
    3. Champion pool optimization for consistency
    4. Role consistency for better matchmaking

    RESPONSE FORMAT:
    Your response must be EXACTLY this JSON structure with no deviations:
    {
      "keyTrends": ["trend insight", "trend insight"],
      "roleConsistency": "Two sentences on role performance consistency.",
      "championPoolAnalysis": "Two sentences on champion pool strengths and risks.",
      "areasOfImprovement": ["area", "area"],
      "strengthsToMaintain": ["strength", "strength"],
      "climbingAdvice": "Two actionable sentences on how to improve rank."
    }
    IMPORTANT: Output must be valid json. No markdown, no commentary.
    
    Maximum 140 words total across ALL fields. No text before or after JSON. No markdown formatting.
    """
}

/// Typealias for dual prompt structure
public typealias DualPrompt = (system: String, user: String)

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
        baselineContext: String? = nil,
        focusedKPIContext: String? = nil,
        killParticipationBaseline: Baseline? = nil,
        objectiveParticipationBaseline: Baseline? = nil,
        teamDamageBaseline: Baseline? = nil
    ) -> DualPrompt {
        let gameResult = participant.win ? "Victory" : "Defeat"
        let kda = "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
        let cs = MatchStatsCalculator.calculateTotalCS(participant: participant)
        let gameDuration = match.gameDuration / 60

        let rankContext = createRankContext(summoner: summoner)

        // Add critical performance metrics with descriptive labels (preferred over raw stats)
        let csPerMin = participant.csPerMinute.oneDecimal
        let visionPerMin = participant.visionScorePerMinute.oneDecimal
        let killParticipationLabel = formatParticipationLabel(
            value: participant.killParticipation,
            metric: "kill_participation_pct",
            baseline: killParticipationBaseline,
            labelPrefix: "Kill Participation"
        )
        let teamDamageLabel = formatParticipationLabel(
            value: participant.teamDamagePercentage,
            metric: "team_damage_pct",
            baseline: teamDamageBaseline,
            labelPrefix: "Damage Share"
        )
        let goldPerMin = participant.goldPerMinute.asWholeNumber
        let objectiveParticipationLabel = formatParticipationLabel(
            value: participant.objectiveParticipationPercentage,
            metric: "objective_participation_pct",
            baseline: objectiveParticipationBaseline,
            labelPrefix: "Objective Participation"
        )

        // Add queue context for coaching relevance
        let queueContext =
            match.isRanked
            ? " | Queue: \(match.queueName)" : " | Queue: \(match.queueName) (practice)"

        // Build user prompt with match data
        var userPrompt = """
            **GAME CONTEXT:**
            Player: \(summoner.gameName) | Champion: \(championName) | Role: \(role)
            Result: \(gameResult) | KDA: \(kda) | Duration: \(gameDuration)min\(queueContext)\(rankContext)
            \(teamContext)

            **PERFORMANCE METRICS:**
            - CS: \(cs) total (\(csPerMin)/min)
            - Vision: \(visionPerMin)/min
            - Kill Participation: \(killParticipationLabel)
            - Team Damage: \(teamDamageLabel)
            - Gold/min: \(goldPerMin)
            - Objective Participation: \(objectiveParticipationLabel)
            """

        // Add relative performance context if available
        if let relativeContext = relativePerformanceContext {
            userPrompt += """

            **RELATIVE PERFORMANCE:**
            \(relativeContext)
            """
        }

        // Add baseline context if available (uses performance level labels)
        if let baseline = baselineContext {
            userPrompt += """

            **BASELINE COMPARISON:**
            \(baseline)
            """
        }
        
        // Add focused KPI if player has one
        if let focusedKPI = focusedKPIContext {
            userPrompt += """

            **PLAYER'S IMPROVEMENT FOCUS:**
            \(focusedKPI)
            """
        }

        // Add lane opponent information if available
        if let opponent = laneOpponent {
            userPrompt += """

                **LANE MATCHUP:**
                \(championName) (\(role)) vs \(opponent)
                """
        }

        // Add timeline data if available (injected by edge function)
        if let timeline = timelineData {
            userPrompt += """

            **EARLY GAME TIMELINE SUMMARY:**
            \(timeline)
            """
        }

        // No explicit JSON template needed - system prompt handles format requirements

        return (
            system: CoachingSystemPrompts.postGameSystemPrompt,
            user: userPrompt
        )
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
        streakData: StreakData?,
        focusedKPI: String? = nil,
        focusedKPITrend: KPITrend? = nil
    ) -> DualPrompt {
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
        let focusedKPIContext = createFocusedKPIContext(
            focusedKPI: focusedKPI, focusedKPITrend: focusedKPITrend)

        let userPrompt = """
            **Player:** \(summoner.gameName) | **Primary Role:** \(RoleUtils.displayName(for: primaryRole)) | **Overall Record:** \(wins)W-\(recentMatches.count - wins)L (\(String(format: "%.0f", winRate * 100))%)\(rankContext)\(streakContext)

            \(detailedContext)\(championPoolContext)\(focusedKPIContext)
            """

        return (
            system: CoachingSystemPrompts.performanceSummarySystemPrompt,
            user: userPrompt
        )
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

    /// Creates focused KPI context for performance summary prompts
    private static func createFocusedKPIContext(
        focusedKPI: String?,
        focusedKPITrend: KPITrend?
    ) -> String {
        guard let kpi = focusedKPI, let trend = focusedKPITrend else {
            return ""
        }

        let displayName: String
        switch kpi {
        case "deaths_per_game": displayName = "Deaths per Game"
        case "vision_score_per_min": displayName = "Vision Score/min"
        case "kill_participation_pct": displayName = "Kill Participation"
        case "cs_per_min": displayName = "CS per Minute"
        case "objective_participation_pct": displayName = "Objective Participation"
        case "team_damage_pct": displayName = "Damage Share"
        case "damage_taken_share_pct": displayName = "Damage Taken Share"
        default: displayName = kpi
        }

        let progressStatus = trend.isImproving ? "improvement ↑" : "decline ↓"

        return """


            **FOCUSED KPI (Player is actively working on this):**
            \(displayName) - \(String(format: "%.1f%%", abs(trend.changePercentage))) \(progressStatus) over \(trend.matchesSince) games
            Current: \(String(format: "%.1f", trend.currentValue)) | Starting: \(String(format: "%.1f", trend.startingValue))

            IMPORTANT: Provide specific feedback on this focused area in your analysis. Acknowledge progress if improving, encourage continued focus if declining.
            """
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

    // MARK: - KPI Improvement Tips Prompt

    /// Creates a prompt for generating KPI improvement tips
    public static func createKPIImprovementPrompt(
        kpiMetric: String,
        displayName: String,
        currentValue: Double,
        targetValue: Double,
        role: String,
        rank: String,
        championPool: [String]
    ) -> String {
        // Format values based on metric type
        let formattedCurrent: String
        let formattedTarget: String

        switch kpiMetric {
        case "kill_participation_pct", "objective_participation_pct", "team_damage_pct",
            "damage_taken_share_pct":
            formattedCurrent = String(format: "%.0f%%", currentValue * 100)
            formattedTarget = String(format: "%.0f%%", targetValue * 100)
        case "cs_per_min", "vision_score_per_min":
            formattedCurrent = String(format: "%.1f", currentValue)
            formattedTarget = String(format: "%.1f", targetValue)
        case "deaths_per_game":
            formattedCurrent = String(format: "%.1f", currentValue)
            formattedTarget = String(format: "%.1f", targetValue)
        default:
            formattedCurrent = String(format: "%.1f", currentValue)
            formattedTarget = String(format: "%.1f", targetValue)
        }

        // Get top 3 champions
        let topChampions = championPool.prefix(3).joined(separator: ", ")
        let championContext = topChampions.isEmpty ? "" : " Your main champions: \(topChampions)."

        return """
            You are a League of Legends coach helping a mid-elo player improve.

            Player Context:
            - Role: \(role)
            - Rank: \(rank)\(championContext)

            Goal: Improve \(displayName)
            - Current: \(formattedCurrent)
            - Target: \(formattedTarget)

            Give exactly 2 simple, practical tips (max 35 words total) that a mid-elo player can immediately apply in their next game. Use clear language, avoid jargon. Focus on easy habits or patterns to practice. Start directly with the tips.
            """
    }

    // MARK: - Helper Methods
    
    /// Formats participation metrics as descriptive labels using baseline-based logic
    /// Uses the same logic as KPIDisplayService for consistency
    /// Falls back to basic thresholds if baseline is unavailable
    private static func formatParticipationLabel(
        value: Double,
        metric: String,
        baseline: Baseline?,
        labelPrefix: String
    ) -> String {
        let performanceLevel: Baseline.PerformanceLevel
        
        if let baseline = baseline {
            // Use baseline-based logic (same as KPIDisplayService)
            // Standard logic for participation metrics - higher is better
            if value >= baseline.p60 * 1.1 {
                performanceLevel = .excellent
            } else if value >= baseline.p60 {
                performanceLevel = .good
            } else if value >= baseline.p40 {
                performanceLevel = .needsImprovement
            } else {
                performanceLevel = .poor
            }
        } else {
            // Fallback to basic performance levels (same as KPIDisplayService.getBasicPerformanceLevel)
            if value >= 0.7 {
                performanceLevel = .excellent
            } else if value >= 0.5 {
                performanceLevel = .good
            } else {
                performanceLevel = .needsImprovement
            }
        }
        
        // Convert performance level to descriptive label
        switch performanceLevel {
        case .excellent:
            return "Excellent \(labelPrefix)"
        case .good:
            return "Good \(labelPrefix)"
        case .needsImprovement:
            return "Low \(labelPrefix)"
        case .poor:
            return "Very Low \(labelPrefix)"
        }
    }

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
