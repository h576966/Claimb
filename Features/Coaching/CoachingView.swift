//
//  CoachingView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftData
import SwiftUI

struct CoachingView: View {
    let summoner: Summoner
    let userSession: UserSession
    @Environment(\.modelContext) private var modelContext
    @State private var matchDataViewModel: MatchDataViewModel?
    @State private var openAIService = OpenAIService()
    @State private var isAnalyzing = false
    @State private var coachingInsights: String = ""
    @State private var coachingError: String = ""

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView

                // Content
                if let viewModel = matchDataViewModel {
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
                await matchDataViewModel?.loadMatches()
            }
        }
    }

    private var headerView: some View {
        SharedHeaderView(
            summoner: summoner,
            title: "Coaching",
            actionButton: SharedHeaderView.ActionButton(
                title: isAnalyzing ? "Analyzing..." : "Analyze",
                icon: "brain.head.profile",
                action: { Task { await analyzePerformance() } },
                isLoading: isAnalyzing,
                isDisabled: !(matchDataViewModel?.hasMatches ?? false)
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

                // Coaching Insights
                if !coachingInsights.isEmpty {
                    coachingInsightsCard
                } else if !coachingError.isEmpty {
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

            let recentMatches = Array(matches.prefix(5))

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

    private var coachingInsightsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("AI Coaching Insights")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(coachingInsights)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
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

            Text(coachingError)
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
        isAnalyzing = true
        coachingInsights = ""
        coachingError = ""

        do {
            guard let viewModel = matchDataViewModel else {
                throw OpenAIError.invalidResponse
            }
            
            let recentMatches = viewModel.getRecentMatches(limit: 20)
            let primaryRole = userSession.selectedPrimaryRole
            
            // Generate coaching insights using OpenAI
            let insights = try await openAIService.generateCoachingInsights(
                summoner: summoner,
                matches: recentMatches,
                primaryRole: primaryRole
            )
            
            await MainActor.run {
                self.coachingInsights = insights
                self.isAnalyzing = false
            }
            
        } catch {
            await MainActor.run {
                self.coachingError = ErrorHandler.userFriendlyMessage(for: error)
                self.isAnalyzing = false
            }
        }
    }

    private func initializeViewModel() {
        if matchDataViewModel == nil {
            let dataManager = DataManager.create(with: modelContext)
            matchDataViewModel = MatchDataViewModel(
                dataManager: dataManager,
                summoner: summoner
            )
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
