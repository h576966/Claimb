//
//  MainAppView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import SwiftData
import SwiftUI

struct MainAppView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var summoner: Summoner
    @State private var matchDataViewModel: MatchDataViewModel?
    @State private var showBaselineTest = false
    @State private var selectedRole: String = "TOP"
    @State private var showRoleSelection = false

    init(summoner: Summoner) {
        self._summoner = State(initialValue: summoner)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Black background
                DesignSystem.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Role Selector
                    if let viewModel = matchDataViewModel, !viewModel.roleStats.isEmpty {
                        RoleSelectorView(
                            selectedRole: $selectedRole,
                            roleStats: viewModel.roleStats,
                            onTap: {
                                showRoleSelection = true
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.md)
                    }

                    // Content
                    if let viewModel = matchDataViewModel {
                        ClaimbContentWrapper(
                            state: viewModel.matchState,
                            loadingMessage: "Loading matches...",
                            emptyMessage: "No matches found",
                            retryAction: { Task { await viewModel.loadMatches() } }
                        ) { matches in
                            matchListView(matches: matches)
                        }
                    } else {
                        ClaimbLoadingView(message: "Initializing...")
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            initializeViewModel()
            Task { await matchDataViewModel?.loadMatches() }
        }
        .refreshable {
            await matchDataViewModel?.refreshMatches()
        }
        .sheet(isPresented: $showBaselineTest) {
            BaselineTestView()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Summoner Info
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(summoner.gameName)
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("#\(summoner.tagLine) • \(regionDisplayName)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if let level = summoner.summonerLevel {
                    Text("Level \(level)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }

            // Action Buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: {
                    Task { await matchDataViewModel?.refreshMatches() }
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.clockwise")
                            .font(DesignSystem.Typography.callout)

                        Text("Refresh")
                            .font(DesignSystem.Typography.callout)
                    }
                }
                .claimbButton(variant: .primary, size: .small)
                .disabled(matchDataViewModel?.isRefreshing ?? false)

                // Clear Cache Button (for debugging)
                Button(action: {
                    Task { await matchDataViewModel?.clearCache() }
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "trash")
                            .font(DesignSystem.Typography.callout)

                        Text("Clear Cache")
                            .font(DesignSystem.Typography.callout)
                    }
                }
                .claimbButton(variant: .secondary, size: .small)
                .disabled(matchDataViewModel?.isRefreshing ?? false)

                // Test Baselines Button
                Button(action: {
                    showBaselineTest = true
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "chart.bar")
                            .font(DesignSystem.Typography.callout)

                        Text("Test Baselines")
                            .font(DesignSystem.Typography.callout)
                    }
                }
                .claimbButton(variant: .secondary, size: .small)
                .disabled(matchDataViewModel?.isRefreshing ?? false)

                Spacer()

            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            GlowCSpinner(size: 80, speed: 1.5)

            Text("Loading your matches...")
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .font(DesignSystem.Typography.title3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "gamecontroller")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("No matches found")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Play some games and come back to see your match history")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xxl)

            Button(action: {
                Task { await matchDataViewModel?.refreshMatches() }
            }) {
                Text("Refresh")
                    .font(DesignSystem.Typography.bodyBold)
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showRoleSelection) {
            if let viewModel = matchDataViewModel {
                RoleSelectorView(
                    selectedRole: $selectedRole,
                    roleStats: viewModel.roleStats,
                    onTap: {
                        showRoleSelection = false
                    },
                    showFullScreen: true
                )
            }
        }
    }

    // MARK: - Match List View

    private func matchListView(matches: [Match]) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(matches, id: \.matchId) { match in
                    MatchCardView(match: match, summoner: summoner)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Computed Properties

    private var regionDisplayName: String {
        switch summoner.region {
        case "euw1": return "EUW"
        case "na1": return "NA"
        case "eun1": return "EUNE"
        default: return summoner.region.uppercased()
        }
    }

    // MARK: - Methods

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
    let summoner = Summoner(
        puuid: "test-puuid",
        gameName: "TestSummoner",
        tagLine: "1234",
        region: "euw1"
    )

    return MainAppView(summoner: summoner)
        .modelContainer(for: [
            Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self,
        ])
        .onAppear {
            summoner.summonerLevel = 100
        }
}
