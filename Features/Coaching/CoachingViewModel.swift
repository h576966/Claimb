//
//  CoachingViewModel.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

// Import required types for coaching functionality
// Note: These types are available through the main app module

// MARK: - CoachingViewModel

@MainActor
@Observable
class CoachingViewModel {
    private let dataManager: DataManager
    private let openAIService: OpenAIService
    private let kpiService: KPICalculationService
    private let summoner: Summoner
    private let primaryRole: String

    // MARK: - State
    var isAnalyzing = false
    var matchState: UIState<[Match]> = .idle

    // MARK: - Dual-Focused Coaching State
    var postGameAnalysis: PostGameAnalysis?
    var performanceSummary: PerformanceSummary?
    var postGameError: String = ""
    var performanceSummaryError: String = ""
    var lastAnalyzedMatchId: PersistentIdentifier?
    var selectedCoachingTab: CoachingTab = .postGame

    // MARK: - Background Refresh State
    var isRefreshingInBackground = false
    var showCachedDataWarning = false
    var isGeneratingPerformanceSummary = false

    // MARK: - Goals System Integration
    var showGoalSetupModal = false

    init(dataManager: DataManager, summoner: Summoner, primaryRole: String) {
        self.dataManager = dataManager
        self.summoner = summoner
        self.openAIService = OpenAIService()
        self.kpiService = KPICalculationService(dataManager: dataManager)
        self.primaryRole = primaryRole
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

            // Pre-calculate KPIs for goal selection to avoid empty modal
            await calculateKPIsForGoals(matches: matches)

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

    /// Checks if performance summary needs updating based on Friday cycle and goals
    private func checkPerformanceSummaryUpdate(matches: [Match]) async {
        let recentMatches = Array(matches.prefix(10))

        // Check if we should show Friday modal or generate summary
        let shouldUpdate = UserGoals.shouldShowFridayModal() || !UserGoals.hasActiveGoal()

        if shouldUpdate {
            ClaimbLogger.info(
                "Triggering goal-based performance summary update", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "hasActiveGoal": String(UserGoals.hasActiveGoal()),
                    "needsGoalUpdate": String(UserGoals.needsGoalUpdate()),
                ])

            // If no goal is set, show modal immediately
            if !UserGoals.hasActiveGoal() {
                showGoalSetupModal = true
            }
            // If it's time for weekly check-in, show modal
            else if UserGoals.shouldShowFridayModal() {
                showGoalSetupModal = true
            }
            // If we have an active goal but performance summary is missing, generate it
            else if UserGoals.hasActiveGoal() && performanceSummary == nil {
                Task {
                    await generatePerformanceSummary(matches: recentMatches)
                }
            }
        }
    }

    /// Shows the goal setup modal (triggered from header button)
    func showGoalsModal() {
        showGoalSetupModal = true
        ClaimbLogger.info("Goal setup modal triggered from header", service: "CoachingViewModel")
    }

    /// Gets the top 3 KPIs that need improvement for goal selection
    func getTopKPIsForGoals() -> [KPIMetric] {
        guard case .loaded(let matches) = matchState, !matches.isEmpty else {
            ClaimbLogger.warning(
                "No matches available for KPI goal selection", service: "CoachingViewModel")
            return createFallbackKPIs()
        }

        // Calculate KPIs using the same service and logic as MatchDataViewModel
        Task {
            await calculateKPIsForGoals(matches: matches)
        }

        // Return cached KPIs if available, otherwise fallback
        return cachedKPIs.isEmpty ? createFallbackKPIs() : Array(cachedKPIs.prefix(3))
    }

    // MARK: - KPI Calculation for Goals

    /// Cached KPI metrics for goal selection
    private var cachedKPIs: [KPIMetric] = []

    /// Calculates KPIs specifically for goal selection
    private func calculateKPIsForGoals(matches: [Match]) async {
        do {
            // Use only the last 20 matches for KPI calculations (recent performance focus)
            let recentMatches = Array(matches.prefix(20))
            let roleKPIs = try await kpiService.calculateRoleKPIs(
                matches: recentMatches,
                role: primaryRole,
                summoner: summoner
            )

            // Sort KPIs by priority (worst performing first)
            cachedKPIs = roleKPIs.sorted { $0.sortPriority < $1.sortPriority }

            ClaimbLogger.info(
                "Calculated KPIs for goal selection", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "role": primaryRole,
                    "kpiCount": String(cachedKPIs.count),
                    "topKPI": cachedKPIs.first?.metric ?? "none",
                ])

        } catch {
            ClaimbLogger.error(
                "Failed to calculate KPIs for goals", service: "CoachingViewModel",
                error: error)
            cachedKPIs = createFallbackKPIs()
        }
    }

    /// Creates fallback KPIs when real data is unavailable
    private func createFallbackKPIs() -> [KPIMetric] {
        ClaimbLogger.debug("Using fallback KPIs for goal selection", service: "CoachingViewModel")

        return [
            KPIMetric(
                metric: "deaths_per_game",
                value: "5.0",
                baseline: nil,
                performanceLevel: .needsImprovement,
                color: DesignSystem.Colors.warning
            ),
            KPIMetric(
                metric: "cs_per_min",
                value: "6.2",
                baseline: nil,
                performanceLevel: .needsImprovement,
                color: DesignSystem.Colors.warning
            ),
            KPIMetric(
                metric: "vision_score_per_min",
                value: "1.5",
                baseline: nil,
                performanceLevel: .poor,
                color: DesignSystem.Colors.error
            ),
        ]
    }

    /// Handles goal completion and generates performance summary with goal context
    func onGoalCompleted() async {
        showGoalSetupModal = false

        // Get current matches to generate goal-aware performance summary
        if case .loaded(let matches) = matchState {
            let recentMatches = Array(matches.prefix(10))

            ClaimbLogger.info(
                "Generating performance summary after goal selection", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "goalKPI": UserGoals.getPrimaryGoal() ?? "unknown",
                    "focusType": UserGoals.getFocusType().rawValue,
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
            showCachedDataWarning = true
            ClaimbLogger.info(
                "Showing cached post-game analysis", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "matchId": matchId,
                ])

            // Try to refresh in background with fast timeout
            Task {
                await refreshPostGameAnalysisInBackground(for: match, matchId: matchId)
            }
            return
        }

        // No cache available - try with fast timeout first
        isAnalyzing = true
        postGameError = ""

        do {
            // Get current goal context
            let goalContext = GoalContext.current()

            // Generate new analysis with fast timeout (OpenAI call)
            let analysis = try await openAIService.generatePostGameAnalysis(
                match: match,
                summoner: summoner,
                kpiService: kpiService,
                goalContext: goalContext
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
            // Get current goal context
            let goalContext = GoalContext.current()

            // Generate fresh analysis
            let analysis = try await openAIService.generatePostGameAnalysis(
                match: match,
                summoner: summoner,
                kpiService: kpiService,
                goalContext: goalContext
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
            showCachedDataWarning = true
            isGeneratingPerformanceSummary = false
            ClaimbLogger.info(
                "Showing cached performance summary", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName
                ])

            // Try to refresh in background
            Task {
                await refreshPerformanceSummaryInBackground(matches: recentMatches)
            }
            return
        }

        // No cache available - generate fresh
        do {
            // Get current goal context
            let goalContext = GoalContext.current()

            let summary = try await openAIService.generatePerformanceSummary(
                matches: recentMatches,
                summoner: summoner,
                primaryRole: primaryRole,
                kpiService: kpiService,
                goalContext: goalContext
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
            // Get current goal context
            let goalContext = GoalContext.current()

            let summary = try await openAIService.generatePerformanceSummary(
                matches: matches,
                summoner: summoner,
                primaryRole: primaryRole,
                kpiService: kpiService,
                goalContext: goalContext
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
