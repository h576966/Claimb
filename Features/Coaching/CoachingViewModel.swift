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
            // Generate new analysis with fast timeout (OpenAI call)
            let analysis = try await openAIService.generatePostGameAnalysis(
                match: match,
                summoner: summoner,
                kpiService: kpiService
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
                kpiService: kpiService
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
            let summary = try await openAIService.generatePerformanceSummary(
                matches: recentMatches,
                summoner: summoner,
                primaryRole: primaryRole,
                kpiService: kpiService
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
            let summary = try await openAIService.generatePerformanceSummary(
                matches: matches,
                summoner: summoner,
                primaryRole: primaryRole,
                kpiService: kpiService
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
