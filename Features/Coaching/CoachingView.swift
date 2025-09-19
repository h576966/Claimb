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
    @State private var isAnalyzing = false
    @State private var coachingInsights: String = ""

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

            Text("Get Personalized Insights")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(
                "Tap 'Analyze' to get AI-powered coaching recommendations based on your recent performance"
            )
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func analyzePerformance() async {
        isAnalyzing = true
        coachingInsights = ""

        // Simulate AI analysis
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Generate mock insights based on recent matches
        guard let viewModel = matchDataViewModel else { return }
        let recentMatches = viewModel.getRecentMatches(limit: 10)
        let wins = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })?.win
        }.filter { $0 }.count

        let winRate = recentMatches.isEmpty ? 0.0 : Double(wins) / Double(recentMatches.count)

        await MainActor.run {
            if winRate >= 0.6 {
                self.coachingInsights =
                    "Great performance! You're maintaining a strong win rate. Focus on consistency and consider expanding your champion pool to stay versatile."
            } else if winRate >= 0.4 {
                self.coachingInsights =
                    "Solid foundation! Work on decision-making in team fights and focus on improving your CS to gain more gold advantage."
            } else {
                self.coachingInsights =
                    "Room for improvement! Focus on fundamentals like last-hitting, map awareness, and positioning. Consider reviewing your recent games to identify patterns."
            }

            self.isAnalyzing = false
        }
    }

    private func initializeViewModel() {
        if matchDataViewModel == nil {
            let dataCoordinator = DataCoordinator(modelContext: modelContext)
            matchDataViewModel = MatchDataViewModel(
                dataCoordinator: dataCoordinator,
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
