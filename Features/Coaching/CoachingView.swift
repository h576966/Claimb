//
//  CoachingView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
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

    // MARK: - State
    var isAnalyzing = false
    var coachingResponse: CoachingResponse?
    var coachingError: String = ""
    var matchState: UIState<[Match]> = .idle

    init(dataManager: DataManager, summoner: Summoner) {
        self.dataManager = dataManager
        self.summoner = summoner
        self.openAIService = OpenAIService()
        self.kpiService = KPICalculationService(dataManager: dataManager)
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

    var recentMatches: [Match] {
        if case .loaded(let matches) = matchState {
            return Array(matches.prefix(5))
        }
        return []
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
                title: viewModel?.isAnalyzing == true ? "Analyzing..." : "Analyze",
                icon: "brain.head.profile",
                action: { Task { await analyzePerformance() } },
                isLoading: viewModel?.isAnalyzing ?? false,
                isDisabled: !(viewModel?.hasMatches ?? false)
            ),
            onLogout: {
                userSession.logout()
            }
        )
    }

    private func coachingContentView(matches: [Match]) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Recent Matches Summary
                recentMatchesCard(matches: matches)

                // Enhanced Coaching Insights
                if let response = viewModel?.coachingResponse {
                    enhancedCoachingInsightsCard(response: response)
                } else if let error = viewModel?.coachingError, !error.isEmpty {
                    coachingErrorCard
                } else {
                    generateInsightsCard
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func recentMatchesCard(matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Recent Performance")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            let recentMatches = viewModel?.recentMatches ?? Array(matches.prefix(5))

            if recentMatches.isEmpty {
                Text("No recent matches found")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(recentMatches, id: \.matchId) { match in
                        HStack {
                            // Match Result
                            Circle()
                                .fill(
                                    match.participants.first(where: { $0.puuid == summoner.puuid })?
                                        .win == true
                                        ? DesignSystem.Colors.accent : DesignSystem.Colors.secondary
                                )
                                .frame(width: 8, height: 8)

                            // Champion (placeholder)
                            Text("Champion")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            Spacer()

                            // KDA
                            if let participant = match.participants.first(where: {
                                $0.puuid == summoner.puuid
                            }) {
                                Text(
                                    "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func enhancedCoachingInsightsCard(response: CoachingResponse) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header with Overall Score
            HStack {
                Text("AI Coaching Analysis")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                // Overall Score
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("\(response.analysis.overallScore)/10")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(scoreColor(response.analysis.overallScore))
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

            // Performance Comparison
            performanceComparisonCard(comparison: response.analysis.performanceComparison)

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
                summoner: summoner
            )
        }
    }

    // MARK: - Enhanced Coaching UI Components

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return DesignSystem.Colors.accent
        case 6...7: return DesignSystem.Colors.primary
        case 4...5: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }

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
                Text("\(String(format: "%.1f", current))\(suffix)")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // Trend indicator
                Image(systemName: trendIcon(trend: trend, reverse: reverse))
                    .font(.caption)
                    .foregroundColor(trendColor(trend: trend, reverse: reverse))

                Text("vs \(String(format: "%.1f", average))\(suffix)")
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
