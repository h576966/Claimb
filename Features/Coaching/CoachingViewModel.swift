//
//  CoachingViewModel.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-28.
//

import Observation
import SwiftData
import SwiftUI

// MARK: - CoachingViewModel

@MainActor
@Observable
class CoachingViewModel {
    private let dataManager: DataManager
    private let openAIService: OpenAIService
    private let kpiService: KPICalculationService
    private let summoner: Summoner
    private let primaryRole: String
    private let userSession: UserSession?

    // MARK: - State
    var isAnalyzing = false
    var matchState: UIState<[Match]> = .idle

    // MARK: - Dual-Focused Coaching State
    var postGameAnalysis: PostGameAnalysis?
    var performanceSummary: PerformanceSummary?
    var postGameError: String = ""
    var performanceSummaryError: String = ""
    var lastAnalyzedMatchId: PersistentIdentifier?
    var performanceSummaryUpdateCounter: Int = 0
    var selectedCoachingTab: CoachingTab = .postGame

    // MARK: - Background Refresh State
    var isRefreshingInBackground = false
    var showCachedDataWarning = false
    var isGeneratingPerformanceSummary = false

    // MARK: - Performance Summary Update Logic
    private let performanceSummaryUpdateInterval = 5  // Update every 5 games

    init(
        dataManager: DataManager, summoner: Summoner, primaryRole: String,
        userSession: UserSession? = nil
    ) {
        self.dataManager = dataManager
        self.summoner = summoner
        self.openAIService = OpenAIService()
        self.kpiService = KPICalculationService(dataManager: dataManager)
        self.primaryRole = primaryRole
        self.userSession = userSession
    }

    // MARK: - Public Methods

    func loadMatches() async {
        matchState = .loading

        do {
            let matches = try await dataManager.getMatches(for: summoner)
            matchState = .loaded(matches)

            ClaimbLogger.info(
                "Loaded matches for coaching", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "matchCount": String(matches.count),
                ])

            // Clean up expired coaching responses periodically
            await cleanupExpiredResponses()

            // Auto-trigger post-game analysis for most recent game
            await autoTriggerPostGameAnalysis(matches: matches)

            // Check if performance summary needs updating
            await checkPerformanceSummaryUpdate(matches: matches)

        } catch {
            matchState = .error(error)
            ClaimbLogger.error(
                "Failed to load matches for coaching", service: "CoachingViewModel",
                error: error)
        }
    }

    var hasMatches: Bool {
        if case .loaded(let matches) = matchState {
            return !matches.isEmpty
        }
        return false
    }

    // MARK: - New Dual-Focused Coaching Methods

    /// Auto-triggers post-game analysis for the most recent game
    private func autoTriggerPostGameAnalysis(matches: [Match]) async {
        guard !matches.isEmpty else { return }

        let mostRecentMatch = matches[0]

        // Only generate analysis if this is a new match
        if mostRecentMatch.id != lastAnalyzedMatchId {
            lastAnalyzedMatchId = mostRecentMatch.id

            ClaimbLogger.info(
                "Auto-triggering post-game analysis", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "matchId": String(describing: mostRecentMatch.id),
                    "championId": String(
                        mostRecentMatch.participants.first(where: { $0.puuid == summoner.puuid })?
                            .championId ?? 0),
                ])

            await generatePostGameAnalysis(for: mostRecentMatch)
        }
    }

    /// Checks if performance summary needs updating based on game count
    private func checkPerformanceSummaryUpdate(matches: [Match]) async {
        let recentMatches = Array(matches.prefix(10))

        // Update counter based on number of games
        let newCounter = recentMatches.count

        // Only update if we've crossed a 5-game boundary
        if newCounter != performanceSummaryUpdateCounter
            && newCounter % performanceSummaryUpdateInterval == 0
        {

            performanceSummaryUpdateCounter = newCounter

            ClaimbLogger.info(
                "Auto-updating performance summary", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "gameCount": String(newCounter),
                ])

            Task {
                await generatePerformanceSummary(matches: recentMatches)
            }
        }
    }

    /// Generates post-game analysis for a specific match
    func generatePostGameAnalysis(for match: Match) async {
        let matchId = match.matchId

        // Check cache first - show immediately if available
        if let cachedAnalysis = try? await dataManager.getCachedPostGameAnalysis(
            for: summoner,
            matchId: matchId
        ) {
            postGameAnalysis = cachedAnalysis
            showCachedDataWarning = false  // Valid cache doesn't need warning
            ClaimbLogger.info(
                "Showing cached post-game analysis", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "matchId": matchId,
                ])

            // Don't trigger background refresh for valid cache
            // Cache expiration is handled by getCachedPostGameAnalysis (24h default)
            // Only regenerate if cache is missing or expired (will happen naturally on next check)
            return
        }

        // No cache available - try with fast timeout first
        isAnalyzing = true
        postGameError = ""

        do {
            // Generate new analysis with fast timeout (OpenAI call)
            let analysis = try await openAIService.generatePostGameAnalysis(
                match: match,
                summoner: summoner,
                kpiService: kpiService,
                userSession: userSession
            )

            // Cache the response
            try await dataManager.cachePostGameAnalysis(
                analysis,
                for: summoner,
                matchId: matchId
            )

            postGameAnalysis = analysis
            showCachedDataWarning = false

            ClaimbLogger.info(
                "Post-game analysis completed", service: "CoachingViewModel",
                metadata: [
                    "championName": match.participants.first(where: { $0.puuid == summoner.puuid })?
                        .champion?.name ?? "Unknown",
                    "gameResult": match.participants.first(where: { $0.puuid == summoner.puuid })?
                        .win == true ? "Victory" : "Defeat",
                ])

        } catch {
            postGameError = ErrorHandler.userFriendlyMessage(for: error)
            ClaimbLogger.error(
                "Post-game analysis failed", service: "CoachingViewModel",
                error: error,
                metadata: [
                    "errorType": String(describing: type(of: error))
                ])
        }

        isAnalyzing = false
    }

    /// Refreshes post-game analysis in background without blocking UI
    private func refreshPostGameAnalysisInBackground(for match: Match, matchId: String) async {
        isRefreshingInBackground = true

        do {
            // Generate fresh analysis
            let analysis = try await openAIService.generatePostGameAnalysis(
                match: match,
                summoner: summoner,
                kpiService: kpiService,
                userSession: userSession
            )

            // Cache the response
            try await dataManager.cachePostGameAnalysis(
                analysis,
                for: summoner,
                matchId: matchId
            )

            // Update UI with fresh data
            postGameAnalysis = analysis
            showCachedDataWarning = false

            ClaimbLogger.info(
                "Background refresh completed", service: "CoachingViewModel",
                metadata: [
                    "championName": match.participants.first(where: { $0.puuid == summoner.puuid })?
                        .champion?.name ?? "Unknown",
                    "gameResult": match.participants.first(where: { $0.puuid == summoner.puuid })?
                        .win == true ? "Victory" : "Defeat",
                ])

        } catch {
            // Silently fail - user already has cached data
            ClaimbLogger.warning(
                "Background refresh failed (cached data still shown)", service: "CoachingViewModel",
                metadata: [
                    "error": error.localizedDescription
                ])
        }

        isRefreshingInBackground = false
    }

    /// Generates performance summary for last 10 games with optimistic caching
    func generatePerformanceSummary(matches: [Match]) async {
        let recentMatches = Array(matches.prefix(10))

        guard !recentMatches.isEmpty else {
            performanceSummaryError = "Not enough games for performance summary"
            return
        }

        // Set loading state
        isGeneratingPerformanceSummary = true
        performanceSummaryError = ""  // Clear any previous errors

        // Check cache first - show immediately if available
        if let cachedSummary = try? await dataManager.getCachedPerformanceSummary(
            for: summoner,
            matchCount: recentMatches.count
        ) {
            performanceSummary = cachedSummary
            showCachedDataWarning = false  // Valid cache doesn't need warning
            isGeneratingPerformanceSummary = false
            ClaimbLogger.info(
                "Showing cached performance summary", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName
                ])

            // Don't trigger background refresh for valid cache
            // Cache expiration is handled by getCachedPerformanceSummary (24h default)
            // Only regenerate if cache is missing or expired (will happen naturally on next check)
            return
        }

        // No cache available - generate fresh
        do {
            // Calculate focused KPI trend if available
            let focusedKPITrend: KPITrend?
            if let focusedKPI = userSession?.focusedKPI,
                let focusedKPISince = userSession?.focusedKPISince
            {
                focusedKPITrend = calculateKPITrendForSummary(
                    metric: focusedKPI,
                    since: focusedKPISince,
                    matches: recentMatches
                )
            } else {
                focusedKPITrend = nil
            }

            let summary = try await openAIService.generatePerformanceSummary(
                matches: recentMatches,
                summoner: summoner,
                primaryRole: primaryRole,
                kpiService: kpiService,
                focusedKPI: userSession?.focusedKPI,
                focusedKPITrend: focusedKPITrend
            )

            // Cache the response
            try await dataManager.cachePerformanceSummary(
                summary,
                for: summoner,
                matchCount: recentMatches.count
            )

            performanceSummary = summary
            showCachedDataWarning = false
            isGeneratingPerformanceSummary = false

            ClaimbLogger.info(
                "Performance summary completed", service: "CoachingViewModel",
                metadata: [
                    "trendsCount": String(summary.keyTrends.count),
                    "gameCount": String(recentMatches.count),
                ])

        } catch {
            performanceSummaryError = ErrorHandler.userFriendlyMessage(for: error)
            isGeneratingPerformanceSummary = false
            ClaimbLogger.error(
                "Performance summary failed", service: "CoachingViewModel",
                error: error,
                metadata: [
                    "errorType": String(describing: type(of: error))
                ])
        }
    }

    /// Refreshes performance summary in background without blocking UI
    private func refreshPerformanceSummaryInBackground(matches: [Match]) async {
        isRefreshingInBackground = true

        do {
            // Calculate focused KPI trend if available
            let focusedKPITrend: KPITrend?
            if let focusedKPI = userSession?.focusedKPI,
                let focusedKPISince = userSession?.focusedKPISince
            {
                focusedKPITrend = calculateKPITrendForSummary(
                    metric: focusedKPI,
                    since: focusedKPISince,
                    matches: matches
                )
            } else {
                focusedKPITrend = nil
            }

            let summary = try await openAIService.generatePerformanceSummary(
                matches: matches,
                summoner: summoner,
                primaryRole: primaryRole,
                kpiService: kpiService,
                focusedKPI: userSession?.focusedKPI,
                focusedKPITrend: focusedKPITrend
            )

            // Cache the response
            try await dataManager.cachePerformanceSummary(
                summary,
                for: summoner,
                matchCount: matches.count
            )

            // Update UI with fresh data
            performanceSummary = summary
            showCachedDataWarning = false

            ClaimbLogger.info(
                "Background refresh of performance summary completed", service: "CoachingViewModel",
                metadata: [
                    "trendsCount": String(summary.keyTrends.count),
                    "gameCount": String(matches.count),
                ])

        } catch {
            // Silently fail - user already has cached data
            ClaimbLogger.warning(
                "Background refresh of performance summary failed (cached data still shown)",
                service: "CoachingViewModel",
                metadata: [
                    "error": error.localizedDescription
                ])
        }

        isRefreshingInBackground = false
    }

    /// Calculates KPI trend for performance summary
    private func calculateKPITrendForSummary(
        metric: String,
        since: Date,
        matches: [Match]
    ) -> KPITrend? {
        // Filter matches by role
        let roleMatches = matches.filter { match in
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                return false
            }
            return RoleUtils.normalizeRole(teamPosition: participant.teamPosition) == primaryRole
        }

        guard !roleMatches.isEmpty else { return nil }

        // Split matches into before and since focus date
        let matchesSinceFocus = roleMatches.filter { $0.gameDate >= since }
        let matchesBeforeFocus = roleMatches.filter { $0.gameDate < since }

        guard !matchesSinceFocus.isEmpty else { return nil }

        // Calculate metric value for matches since focus
        let currentValue = calculateMetricValueForSummary(
            for: metric,
            matches: matchesSinceFocus
        )

        // Calculate starting value
        let startingValue: Double
        if !matchesBeforeFocus.isEmpty {
            let recentBeforeMatches = Array(matchesBeforeFocus.prefix(10))
            startingValue = calculateMetricValueForSummary(
                for: metric,
                matches: recentBeforeMatches
            )
        } else {
            startingValue = currentValue
        }

        // Calculate change percentage
        let changePercentage: Double
        if startingValue != 0 {
            changePercentage = ((currentValue - startingValue) / abs(startingValue)) * 100
        } else {
            changePercentage = 0
        }

        // Determine if improving
        let isImproving: Bool
        if metric == "deaths_per_game" {
            isImproving = currentValue < startingValue
        } else {
            isImproving = currentValue > startingValue
        }

        return KPITrend(
            matchesSince: matchesSinceFocus.count,
            currentValue: currentValue,
            startingValue: startingValue,
            changePercentage: changePercentage,
            isImproving: isImproving
        )
    }

    /// Calculates metric value for performance summary
    private func calculateMetricValueForSummary(
        for metric: String,
        matches: [Match]
    ) -> Double {
        let participants = matches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })
        }

        guard !participants.isEmpty else { return 0.0 }

        switch metric {
        case "deaths_per_game":
            let totalDeaths = participants.reduce(0) { $0 + $1.deaths }
            return Double(totalDeaths) / Double(participants.count)

        case "vision_score_per_min":
            let totalVision = participants.reduce(0.0) { $0 + $1.visionScorePerMinute }
            return totalVision / Double(participants.count)

        case "cs_per_min":
            let totalCS = participants.reduce(0.0) { $0 + $1.csPerMinute }
            return totalCS / Double(participants.count)

        case "kill_participation_pct":
            let totalKP = participants.reduce(0.0) { $0 + $1.killParticipation }
            return (totalKP / Double(participants.count)) * 100

        case "objective_participation_pct":
            let totalOP = participants.reduce(0.0) { $0 + $1.objectiveParticipationPercentage }
            return totalOP / Double(participants.count)

        case "team_damage_pct":
            let totalDmg = participants.reduce(0.0) { $0 + $1.teamDamagePercentage }
            return (totalDmg / Double(participants.count)) * 100

        default:
            return 0.0
        }
    }

    /// Cleans up expired coaching responses periodically
    private func cleanupExpiredResponses() async {
        do {
            try await dataManager.cleanupExpiredCoachingResponses()
        } catch {
            ClaimbLogger.warning(
                "Failed to cleanup expired coaching responses", service: "CoachingViewModel",
                metadata: ["error": error.localizedDescription]
            )
        }
    }
}
