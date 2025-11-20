//
//  CoachingView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

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

struct CoachingView: View {
    let summoner: Summoner
    @Bindable var userSession: UserSession
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CoachingViewModel?
    @State private var refreshTrigger = 0
    @State private var isLastMatchExpanded = false

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
                        retryAction: {
                            refreshTrigger += 1
                        }
                    ) { matches in
                        coachingContentView(matches: matches)
                    }
                } else {
                    ClaimbLoadingView(message: "Initializing...")
                }
            }
            
            // Toast notifications overlay
            VStack {
                if viewModel?.showPostGameAnalysisToast == true {
                    ClaimbToast(
                        message: "New post-game analysis available!",
                        systemImage: "brain.head.profile",
                        isPresented: Binding(
                            get: { viewModel?.showPostGameAnalysisToast ?? false },
                            set: { viewModel?.showPostGameAnalysisToast = $0 }
                        )
                    )
                    .padding(.top, DesignSystem.Spacing.lg)
                }
                
                if viewModel?.showPerformanceSummaryToast == true {
                    ClaimbToast(
                        message: "New performance summary available!",
                        systemImage: "chart.bar.fill",
                        isPresented: Binding(
                            get: { viewModel?.showPerformanceSummaryToast ?? false },
                            set: { viewModel?.showPerformanceSummaryToast = $0 }
                        )
                    )
                    .padding(.top, viewModel?.showPostGameAnalysisToast == true ? 60 : DesignSystem.Spacing.lg)
                }
                
                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel?.showPostGameAnalysisToast)
            .animation(.easeInOut(duration: 0.3), value: viewModel?.showPerformanceSummaryToast)
        }
        .onAppear {
            if viewModel == nil {
                initializeViewModel()
            }
        }
        .task(id: refreshTrigger) {
            // This runs on first appear AND whenever refreshTrigger changes
            await viewModel?.loadMatches()
        }
    }

    private var headerView: some View {
        SharedHeaderView(
            summoner: summoner,
            actionButton: SharedHeaderView.ActionButton(
                title: "Refresh",
                icon: "arrow.clockwise",
                action: {
                    refreshTrigger += 1
                },
                isLoading: viewModel?.isAnalyzing ?? false,
                isDisabled: viewModel?.isAnalyzing ?? false
            ),
            userSession: userSession
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
                                ? DesignSystem.Colors.black
                                : DesignSystem.Colors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            viewModel?.selectedCoachingTab == tab
                                ? DesignSystem.Colors.accent
                                : DesignSystem.Colors.cardBackground
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
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .refreshable {
                await viewModel?.loadMatches()
                
                // Trigger analysis generation on pull-to-refresh
                if let matches = viewModel?.matchState.data, !matches.isEmpty {
                    let mostRecentMatch = matches[0]
                    await viewModel?.generatePostGameAnalysis(for: mostRecentMatch)
                    
                    // Check if performance summary should update
                    let recentMatches = Array(matches.prefix(10))
                    if recentMatches.count % 5 == 0 {
                        await viewModel?.generatePerformanceSummary(matches: recentMatches)
                    }
                }
            }
        }
    }

    private func lastGameSummaryCard(matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if matches.isEmpty {
                Text("No games played yet")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(DesignSystem.Spacing.lg)
            } else {
                let lastMatch = matches[0]
                if let participant = lastMatch.participants.first(where: {
                    $0.puuid == summoner.puuid
                }) {
                    // Main card content (always visible) - entire card is clickable
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLastMatchExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            lastGameSummaryContent(match: lastMatch, participant: participant)
                            
                            // Expand/Collapse indicator
                            Image(systemName: isLastMatchExpanded ? "chevron.up" : "chevron.down")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Expanded content (animated)
                    if isLastMatchExpanded {
                        expandedMatchKPISection(match: lastMatch, participant: participant)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } else {
                    Text("Unable to load last game data")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(DesignSystem.Spacing.lg)
                }
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    private func lastGameSummaryContent(match: Match, participant: Participant) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Champion Image - Larger and more prominent
            AsyncImage(url: URL(string: participant.champion?.iconURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(DesignSystem.Colors.cardBorder)
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.title)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    )
            }
            .frame(width: 90, height: 90)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(
                        participant.win
                            ? DesignSystem.Colors.accent : DesignSystem.Colors.error,
                        lineWidth: 2
                    )
            )

            // Champion Info - Simplified
            VStack(alignment: .leading, spacing: 4) {
                // Champion Name • Role
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(participant.champion?.name ?? "Unknown Champion")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    Text("•")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(
                        RoleUtils.displayName(
                            for: RoleUtils.normalizeRole(teamPosition: participant.teamPosition))
                    )
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Result • Duration
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(participant.win ? "Victory" : "Defeat")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
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

                // KDA only
                HStack(spacing: 2) {
                    Text("KDA:")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text("\(participant.kills)/\(participant.deaths)/\(participant.assists)")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Dual-Focused Coaching Cards

    private func postGameAnalysisCard() -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Post-Game Analysis")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()
            }

            if let analysis = viewModel?.postGameAnalysis {
                postGameAnalysisContent(analysis: analysis)
            } else if let error = viewModel?.postGameError, !error.isEmpty {
                postGameErrorContent(error: error)
            } else if viewModel?.isAnalyzing == true {
                postGameLoadingContent()
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
        .frame(maxWidth: .infinity)
    }

    private func postGameLoadingContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ClaimbSpinner()
                .frame(width: 24, height: 24)

            Text("Generating post-game analysis...")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
                Text("Performance Summary")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()
            }

            if let summary = viewModel?.performanceSummary {
                summaryContent(summary: summary)
            } else if let error = viewModel?.performanceSummaryError, !error.isEmpty {
                summaryErrorContent(error: error)
            } else if viewModel?.isGeneratingPerformanceSummary == true {
                summaryLoadingContent()
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
        .frame(maxWidth: .infinity)
    }

    private func summaryLoadingContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ClaimbSpinner()
                .frame(width: 24, height: 24)

            Text("Generating performance analysis...")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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

    private func initializeViewModel() {
        if viewModel == nil {
            let dataManager = DataManager.shared(with: modelContext)
            viewModel = CoachingViewModel(
                dataManager: dataManager,
                summoner: summoner,
                primaryRole: userSession.selectedPrimaryRole,
                userSession: userSession
            )
        }
    }

    // MARK: - Enhanced Coaching UI Components

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
    
    // MARK: - Expandable Match KPI Section
    
    private func expandedMatchKPISection(match: Match, participant: Participant) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Divider()
                .background(DesignSystem.Colors.cardBorder)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Section title
                HStack {
                    Text("Match Performance")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                }
                
                // KPI Grid
                let role = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)
                let kpis = getMatchKPIs(for: participant, match: match, role: role)
                
                if kpis.isEmpty {
                    Text("No KPI data available for this match")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: DesignSystem.Spacing.sm
                    ) {
                        ForEach(kpis, id: \.metric) { kpi in
                            let isFocused = userSession.focusedKPI == kpi.metric
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Text(kpi.value)
                                    .font(DesignSystem.Typography.bodyBold)
                                    .foregroundColor(kpi.color)
                                
                                Text(kpi.displayName)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .frame(maxWidth: .infinity)
                            .background(
                                isFocused
                                    ? DesignSystem.Colors.accent.opacity(0.1)
                                    : Color.clear
                            )
                            .cornerRadius(DesignSystem.CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .stroke(
                                        isFocused ? DesignSystem.Colors.accent : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
    }
    
    private func getMatchKPIs(for participant: Participant, match: Match, role: String) -> [ChampionKPIDisplay] {
        // Get role-specific key metrics
        let baselineRole = RoleUtils.normalizedRoleToBaselineRole(role)
        let keyMetrics = AppConstants.ChampionKPIs.keyMetricsByRole[baselineRole] ?? []
        
        // Get baseline cache from view model
        guard let baselineCache = viewModel?.matchDataViewModel?.baselineCache else {
            return []
        }
        
        return keyMetrics.compactMap { metric in
            // Calculate raw value for this single match
            let value = calculateSingleMatchMetricValue(
                metric: metric,
                participant: participant,
                match: match
            )
            
            // Get baseline
            let championClass = participant.champion?.championClass ?? "ALL"
            let baseline = getBaselineFromCache(
                role: baselineRole,
                classTag: championClass,
                metric: metric,
                cache: baselineCache
            ) ?? getBaselineFromCache(
                role: baselineRole,
                classTag: "ALL",
                metric: metric,
                cache: baselineCache
            )
            
            // Get performance level and color
            let (performanceLevel, color) = getPerformanceLevelWithBaseline(
                value: value,
                metric: metric,
                baseline: baseline
            )
            
            // Format value
            let formattedValue = KPIDisplayService.formatValue(value, for: metric)
            
            return ChampionKPIDisplay(
                metric: metric,
                value: formattedValue,
                performanceLevel: performanceLevel,
                color: color
            )
        }
    }
    
    private func calculateSingleMatchMetricValue(
        metric: String,
        participant: Participant,
        match: Match
    ) -> Double {
        let gameDurationMinutes = Double(match.gameDuration) / 60.0
        
        switch metric {
        case "cs_per_min":
            return gameDurationMinutes > 0
                ? Double(participant.totalMinionsKilled) / gameDurationMinutes
                : 0.0
            
        case "deaths_per_game":
            return Double(participant.deaths)
            
        case "kill_participation_pct":
            let teamKills = match.participants
                .filter { $0.teamId == participant.teamId }
                .reduce(0) { $0 + $1.kills }
            return teamKills > 0
                ? Double(participant.kills + participant.assists) / Double(teamKills)
                : 0.0
            
        case "vision_score_per_min":
            return participant.visionScorePerMinute
            
        case "team_damage_pct":
            if participant.teamDamagePercentage > 0 {
                return participant.teamDamagePercentage
            } else {
                let teamParticipants = match.participants.filter { $0.teamId == participant.teamId }
                let teamTotalDamage = teamParticipants.reduce(0) { $0 + $1.totalDamageDealtToChampions }
                return teamTotalDamage > 0
                    ? Double(participant.totalDamageDealtToChampions) / Double(teamTotalDamage)
                    : 0.0
            }
            
        case "objective_participation_pct":
            return participant.objectiveParticipationPercentage
            
        case "damage_taken_share_pct":
            return participant.damageTakenSharePercentage
            
        default:
            return 0.0
        }
    }
    
    private func getBaselineFromCache(
        role: String,
        classTag: String,
        metric: String,
        cache: [String: Baseline]
    ) -> Baseline? {
        let key = "\(role)_\(classTag)_\(metric)"
        return cache[key]
    }
    
    private func getPerformanceLevelWithBaseline(
        value: Double,
        metric: String,
        baseline: Baseline?
    ) -> (Baseline.PerformanceLevel, Color) {
        if let baseline = baseline {
            // Special handling for Deaths per Game - lower is better
            if metric == "deaths_per_game" {
                if value <= baseline.p40 * 0.9 {
                    return (.excellent, DesignSystem.Colors.accent)
                } else if value <= baseline.p60 {
                    return (.good, DesignSystem.Colors.white)
                } else if value <= baseline.p60 * 1.2 {
                    return (.needsImprovement, DesignSystem.Colors.warning)
                } else {
                    return (.poor, DesignSystem.Colors.secondary)
                }
            } else {
                // Standard logic for other metrics - higher is better
                if value >= baseline.p60 * 1.1 {
                    return (.excellent, DesignSystem.Colors.accent)
                } else if value >= baseline.p60 {
                    return (.good, DesignSystem.Colors.white)
                } else if value >= baseline.p40 {
                    return (.needsImprovement, DesignSystem.Colors.warning)
                } else {
                    return (.poor, DesignSystem.Colors.secondary)
                }
            }
        } else {
            // Fallback to basic performance levels
            return getBasicPerformanceLevel(value: value, metric: metric)
        }
    }
    
    private func getBasicPerformanceLevel(value: Double, metric: String) -> (
        Baseline.PerformanceLevel, Color
    ) {
        switch metric {
        case "deaths_per_game":
            if value <= 3.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value <= 5.0 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        case "kill_participation_pct", "objective_participation_pct", "team_damage_pct",
            "damage_taken_share_pct":
            if value >= 0.7 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value >= 0.5 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        case "cs_per_min", "vision_score_per_min":
            if value >= 8.0 {
                return (.excellent, DesignSystem.Colors.accent)
            } else if value >= 6.0 {
                return (.good, DesignSystem.Colors.white)
            } else {
                return (.needsImprovement, DesignSystem.Colors.warning)
            }
        default:
            return (.needsImprovement, DesignSystem.Colors.warning)
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
