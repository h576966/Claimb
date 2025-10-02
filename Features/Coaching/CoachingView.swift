//
//  CoachingView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import Observation
import SwiftData
import SwiftUI

// MARK: - Coaching Tab Enum

enum CoachingTab: String, CaseIterable {
    case postGame = "Post-Game"
    case summary = "Summary"

    var title: String {
        switch self {
        case .postGame:
            return "Post-Game"
        case .summary:
            return "Summary"
        }
    }
}

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
    var coachingResponse: CoachingResponse?
    var coachingError: String = ""
    var matchState: UIState<[Match]> = .idle

    // MARK: - New Dual-Focused Coaching State
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

    func analyzePerformance(primaryRole: String) async {
        guard case .loaded(let matches) = matchState, !matches.isEmpty else {
            coachingError = "No matches available for analysis"
            return
        }

        isAnalyzing = true
        coachingResponse = nil
        coachingError = ""

        do {
            let recentMatches = Array(matches.prefix(20))

            ClaimbLogger.info(
                "Starting coaching analysis", service: "CoachingViewModel",
                metadata: [
                    "summoner": summoner.gameName,
                    "role": primaryRole,
                    "matchCount": String(recentMatches.count),
                ])

            // Generate enhanced coaching insights with personal baselines
            let response = try await openAIService.generateCoachingInsights(
                summoner: summoner,
                matches: recentMatches,
                primaryRole: primaryRole,
                kpiService: kpiService
            )

            coachingResponse = response

            ClaimbLogger.info(
                "Coaching analysis completed", service: "CoachingViewModel",
                metadata: [
                    "overallScore": String(response.analysis.overallScore),
                    "priorityFocus": response.analysis.priorityFocus,
                ])

        } catch {
            coachingError = ErrorHandler.userFriendlyMessage(for: error)
            ClaimbLogger.error(
                "Coaching analysis failed", service: "CoachingViewModel",
                error: error)
        }

        isAnalyzing = false
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

            await generatePerformanceSummary(matches: recentMatches)
        }
    }

    /// Generates post-game analysis for a specific match
    func generatePostGameAnalysis(for match: Match) async {
        let matchId = String(describing: match.id)

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
                    "championName": analysis.championName,
                    "gameResult": analysis.gameResult,
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
                    "championName": analysis.championName,
                    "gameResult": analysis.gameResult,
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

        // Check cache first - show immediately if available
        if let cachedSummary = try? await dataManager.getCachedPerformanceSummary(
            for: summoner
        ) {
            performanceSummary = cachedSummary
            showCachedDataWarning = true
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
                for: summoner
            )

            performanceSummary = summary
            showCachedDataWarning = false

            ClaimbLogger.info(
                "Performance summary completed", service: "CoachingViewModel",
                metadata: [
                    "trendsCount": String(summary.keyTrends.count),
                    "gameCount": String(recentMatches.count),
                ])

        } catch {
            performanceSummaryError = ErrorHandler.userFriendlyMessage(for: error)
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
                for: summoner
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
}

struct CoachingView: View {
    let summoner: Summoner
    let userSession: UserSession
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CoachingViewModel?

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView

                Spacer()
                    .frame(height: DesignSystem.Spacing.md)

                // Content
                if let viewModel = viewModel {
                    ClaimbContentWrapper(
                        state: viewModel.matchState,
                        loadingMessage: "Loading coaching data...",
                        emptyMessage: "No matches found for analysis",
                        retryAction: { Task { await viewModel.loadMatches() } }
                    ) { matches in
                        coachingContentView(matches: matches)
                    }
                } else {
                    ClaimbLoadingView(message: "Initializing...")
                }
            }
        }
        .onAppear {
            initializeViewModel()
            Task {
                await viewModel?.loadMatches()
            }
        }
    }

    private var headerView: some View {
        SharedHeaderView(
            summoner: summoner,
            title: "Coaching",
            actionButton: SharedHeaderView.ActionButton(
                title: "Refresh",
                icon: "arrow.clockwise",
                action: { Task { await viewModel?.loadMatches() } },
                isLoading: viewModel?.isAnalyzing ?? false,
                isDisabled: false
            ),
            onLogout: {
                userSession.logout()
            }
        )
    }

    private var coachingTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CoachingTab.allCases, id: \.self) { tab in
                Button(action: {
                    viewModel?.selectedCoachingTab = tab
                }) {
                    Text(tab.title)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(
                            viewModel?.selectedCoachingTab == tab
                                ? DesignSystem.Colors.textPrimary
                                : DesignSystem.Colors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            viewModel?.selectedCoachingTab == tab
                                ? DesignSystem.Colors.cardBackground
                                : Color.clear
                        )
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(
                                    viewModel?.selectedCoachingTab == tab
                                        ? DesignSystem.Colors.primary
                                        : Color.clear
                                ),
                            alignment: .bottom
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(DesignSystem.Colors.background)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .padding(.horizontal, 0)
        .padding(.top, 0)
        .padding(.bottom, 0)
    }

    private func coachingContentView(matches: [Match]) -> some View {
        VStack(spacing: 0) {
            // Background refresh indicator
            if let viewModel = viewModel, viewModel.isRefreshingInBackground {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: DesignSystem.Colors.accent)
                        )
                        .scaleEffect(0.6)

                    Text("Updating insights...")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
                .transition(.opacity)
            }

            // Content based on selected tab
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Last Game Summary
                    lastGameSummaryCard(matches: matches)

                    // Coaching Tab Selector - Moved here
                    coachingTabSelector

                    // Selected coaching content
                    if viewModel?.selectedCoachingTab == .postGame {
                        postGameAnalysisCard()
                    } else {
                        summaryCard()
                    }

                    // Legacy coaching insights (for backward compatibility)
                    if let response = viewModel?.coachingResponse {
                        legacyCoachingInsightsCard(response: response)
                    } else if let error = viewModel?.coachingError, !error.isEmpty {
                        coachingErrorCard
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
    }

    private func lastGameSummaryCard(matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if matches.isEmpty {
                Text("No games played yet")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                let lastMatch = matches[0]
                if let participant = lastMatch.participants.first(where: {
                    $0.puuid == summoner.puuid
                }) {
                    lastGameSummaryContent(match: lastMatch, participant: participant)
                } else {
                    Text("Unable to load last game data")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    private func lastGameSummaryContent(match: Match, participant: Participant) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Champion Image
            AsyncImage(url: URL(string: participant.champion?.iconURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(DesignSystem.Colors.cardBorder)
                    .overlay(
                        Image(systemName: "questionmark")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    )
            }
            .frame(width: 60, height: 60)
            .cornerRadius(DesignSystem.CornerRadius.small)

            // Champion Info - Simplified
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.champion?.name ?? "Unknown Champion")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    // Role
                    Text(
                        RoleUtils.displayName(
                            for: RoleUtils.normalizeRole(teamPosition: participant.teamPosition))
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("•")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    // Win/Loss indicator
                    Circle()
                        .fill(
                            participant.win
                                ? DesignSystem.Colors.accent : DesignSystem.Colors.error
                        )
                        .frame(width: 6, height: 6)

                    Text(participant.win ? "Victory" : "Defeat")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(
                            participant.win
                                ? DesignSystem.Colors.accent : DesignSystem.Colors.error
                        )

                    Text("•")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("\(match.gameDuration / 60) min")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // KDA
                Text("KDA: \(participant.kills)/\(participant.deaths)/\(participant.assists)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
    }

    private func legacyCoachingInsightsCard(response: CoachingResponse) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header with Overall Score
            HStack {
                Text("AI Coaching Analysis")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                // Overall Score (legacy)
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("\(response.analysis.overallScore)/10")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("Score")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            // Summary
            Text(response.summary)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Strengths & Improvements
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if !response.analysis.strengths.isEmpty {
                    strengthsSection(strengths: response.analysis.strengths)
                }

                if !response.analysis.improvements.isEmpty {
                    improvementsSection(improvements: response.analysis.improvements)
                }
            }

            // Actionable Tips
            if !response.analysis.actionableTips.isEmpty {
                actionableTipsSection(tips: response.analysis.actionableTips)
            }

            // Priority Focus
            if !response.analysis.priorityFocus.isEmpty {
                priorityFocusSection(focus: response.analysis.priorityFocus)
            }

            // Champion Advice
            if !response.analysis.championAdvice.isEmpty {
                championAdviceSection(advice: response.analysis.championAdvice)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - New Dual-Focused Coaching Cards

    private func postGameAnalysisCard() -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Post-Game Analysis")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if viewModel?.isAnalyzing == true {
                    GlowCSpinner(size: 20)
                }
            }

            if let analysis = viewModel?.postGameAnalysis {
                postGameAnalysisContent(analysis: analysis)
            } else if let error = viewModel?.postGameError, !error.isEmpty {
                postGameErrorContent(error: error)
            } else {
                postGameEmptyContent()
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    private func postGameAnalysisContent(analysis: PostGameAnalysis) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Key Takeaways
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Key Takeaways")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                ForEach(Array(analysis.keyTakeaways.enumerated()), id: \.offset) {
                    index, takeaway in
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Text("\(index + 1).")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 20, alignment: .leading)

                        Text(takeaway)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            // Champion-Specific Advice
            if !analysis.championSpecificAdvice.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Champion-Specific Advice")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(analysis.championSpecificAdvice)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            // Next Game Focus
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Next Game Focus")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)

                ForEach(Array(analysis.nextGameFocus.enumerated()), id: \.offset) { index, focus in
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "target")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .font(.body)

                        Text(focus)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }

    private func postGameErrorContent(error: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.error)

            Text("Analysis Failed")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(error)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func postGameEmptyContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "gamecontroller")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Play a game to get post-game analysis")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func summaryCard() -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Recent Trends (Last 10 Games)")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if viewModel?.isAnalyzing == true {
                    GlowCSpinner(size: 20)
                }
            }

            if let summary = viewModel?.performanceSummary {
                summaryContent(summary: summary)
            } else if let error = viewModel?.performanceSummaryError, !error.isEmpty {
                summaryErrorContent(error: error)
            } else {
                summaryEmptyContent()
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    private func summaryContent(summary: PerformanceSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Key Trends
            if !summary.keyTrends.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Key Trends")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    ForEach(Array(summary.keyTrends.enumerated()), id: \.offset) {
                        index, trend in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(DesignSystem.Colors.primary)
                                .font(.body)

                            Text(trend)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }

            // Role Consistency
            if !summary.roleConsistency.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Role Consistency")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(summary.roleConsistency)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            // Champion Pool Analysis
            if !summary.championPoolAnalysis.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Champion Pool")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(summary.championPoolAnalysis)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            // Strengths to Maintain
            if !summary.strengthsToMaintain.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Strengths to Maintain")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.accent)

                    ForEach(Array(summary.strengthsToMaintain.enumerated()), id: \.offset) {
                        index, strength in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.accent)
                                .font(.body)

                            Text(strength)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }

            // Areas of Improvement
            if !summary.areasOfImprovement.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Areas to Improve")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.secondary)

                    ForEach(Array(summary.areasOfImprovement.enumerated()), id: \.offset) {
                        index, area in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DesignSystem.Colors.secondary)
                                .font(.body)

                            Text(area)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }

            // Climbing Advice (highlighted)
            if !summary.climbingAdvice.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "target")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.body)

                        Text("Action Plan")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }

                    Text(summary.climbingAdvice)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.cardBorder.opacity(0.3))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
            }
        }
    }

    private func summaryErrorContent(error: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.error)

            Text("Summary Failed")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(error)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func summaryEmptyContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Play more games for trends summary")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var generateInsightsCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.primary)

            Text("Get AI Coaching Insights")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(
                "Tap 'Analyze' to get personalized coaching recommendations powered by OpenAI based on your recent performance"
            )
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    private var coachingErrorCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.error)

            Text("Analysis Failed")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(viewModel?.coachingError ?? "Unknown error")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await analyzePerformance() }
            }
            .buttonStyle(ClaimbButtonStyle())
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    private func analyzePerformance() async {
        guard let viewModel = viewModel else { return }

        let primaryRole = userSession.selectedPrimaryRole
        await viewModel.analyzePerformance(primaryRole: primaryRole)
    }

    private func initializeViewModel() {
        if viewModel == nil {
            let dataManager = DataManager.shared(with: modelContext)
            viewModel = CoachingViewModel(
                dataManager: dataManager,
                summoner: summoner,
                primaryRole: userSession.selectedPrimaryRole
            )
        }
    }

    // MARK: - Enhanced Coaching UI Components

    private func performanceComparisonCard(comparison: PerformanceComparison) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Performance vs Personal Average")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                performanceMetricRow(
                    title: "CS/Min",
                    current: comparison.csPerMinute.current,
                    average: comparison.csPerMinute.average,
                    trend: comparison.csPerMinute.trend
                )

                performanceMetricRow(
                    title: "Deaths/Game",
                    current: comparison.deathsPerGame.current,
                    average: comparison.deathsPerGame.average,
                    trend: comparison.deathsPerGame.trend,
                    reverse: true  // Lower is better
                )

                performanceMetricRow(
                    title: "Vision Score",
                    current: comparison.visionScore.current,
                    average: comparison.visionScore.average,
                    trend: comparison.visionScore.trend
                )

                performanceMetricRow(
                    title: "Kill Participation",
                    current: comparison.killParticipation.current * 100,  // Convert to percentage
                    average: comparison.killParticipation.average * 100,
                    trend: comparison.killParticipation.trend,
                    suffix: "%"
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
        .cornerRadius(DesignSystem.CornerRadius.small)
    }

    private func performanceMetricRow(
        title: String,
        current: Double,
        average: Double,
        trend: String,
        reverse: Bool = false,
        suffix: String = ""
    ) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("\(String(format: "%.1f", current.isNaN ? 0.0 : current))\(suffix)")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // Trend indicator
                Image(systemName: trendIcon(trend: trend, reverse: reverse))
                    .font(.caption)
                    .foregroundColor(trendColor(trend: trend, reverse: reverse))

                Text("vs \(String(format: "%.1f", average.isNaN ? 0.0 : average))\(suffix)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    private func trendIcon(trend: String, reverse: Bool) -> String {
        let isGood = reverse ? (trend == "below") : (trend == "above")
        return isGood ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private func trendColor(trend: String, reverse: Bool) -> Color {
        let isGood = reverse ? (trend == "below") : (trend == "above")
        return isGood ? DesignSystem.Colors.accent : DesignSystem.Colors.error
    }

    private func strengthsSection(strengths: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Strengths")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.accent)

            ForEach(strengths, id: \.self) { strength in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                        .font(.caption)
                        .padding(.top, 2)

                    Text(strength)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
        }
    }

    private func improvementsSection(improvements: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Areas for Improvement")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.warning)

            ForEach(improvements, id: \.self) { improvement in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.warning)
                        .font(.caption)
                        .padding(.top, 2)

                    Text(improvement)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
        }
    }

    private func actionableTipsSection(tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Actionable Tips")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.primary)

            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Text("\(index + 1).")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 20, alignment: .leading)

                    Text(tip)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
        }
    }

    private func priorityFocusSection(focus: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Priority Focus")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.secondary)

            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "target")
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .font(.caption)
                    .padding(.top, 2)

                Text(focus)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
    }

    private func championAdviceSection(advice: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Champion Advice")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.info)

            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(DesignSystem.Colors.info)
                    .font(.caption)
                    .padding(.top, 2)

                Text(advice)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
    }

}

#Preview {
    let modelContainer = try! ModelContainer(
        for: Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self)
    let userSession = UserSession(modelContext: modelContainer.mainContext)
    let summoner = Summoner(
        puuid: "test-puuid",
        gameName: "TestSummoner",
        tagLine: "1234",
        region: "euw1"
    )

    return CoachingView(summoner: summoner, userSession: userSession)
        .modelContainer(modelContainer)
        .onAppear {
            summoner.summonerLevel = 100
        }
}
