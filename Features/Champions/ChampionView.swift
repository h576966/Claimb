//
//  ChampionView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftData
import SwiftUI

struct ChampionView: View {
    let summoner: Summoner
    let userSession: UserSession
    @Environment(\.dataCoordinator) private var dataCoordinator
    @State private var championDataViewModel: ChampionDataViewModel?
    @State private var selectedFilter: ChampionFilter = .all
    @State private var showRoleSelection = false


    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView

                // Role Selector
                if let viewModel = championDataViewModel, !viewModel.roleStats.isEmpty {
                    RoleSelectorView(
                        selectedRole: Binding(
                            get: { userSession.selectedPrimaryRole },
                            set: { userSession.selectedPrimaryRole = $0 }
                        ),
                        roleStats: viewModel.roleStats,
                        onTap: {
                            showRoleSelection = true
                        }
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
                }

                // Filter Options
                filterOptionsView

                // Content with UI State Management
                if let viewModel = championDataViewModel {
                    ClaimbContentWrapper(
                        state: viewModel.championState,
                        loadingMessage: "Loading champions...",
                        emptyMessage: "No champions found",
                        retryAction: {
                            Task { await viewModel.loadData() }
                        }
                    ) { champions in
                        if viewModel.championStats.isEmpty {
                            emptyStateView
                        } else {
                            championListView(champions: champions)
                        }
                    }
                } else {
                    ClaimbLoadingView(message: "Initializing...")
                }
            }
        }
        .onAppear {
            initializeViewModel()
            Task {
                await championDataViewModel?.loadData()
            }
        }
        .onChange(of: userSession.selectedPrimaryRole) { _, _ in
            Task {
                await championDataViewModel?.loadChampionStats(
                    role: userSession.selectedPrimaryRole, filter: selectedFilter)
            }
        }
        .onChange(of: selectedFilter) { _, _ in
            Task {
                await championDataViewModel?.loadChampionStats(
                    role: userSession.selectedPrimaryRole, filter: selectedFilter)
            }
        }
        .sheet(isPresented: $showRoleSelection) {
            if let viewModel = championDataViewModel {
                RoleSelectorView(
                    selectedRole: Binding(
                        get: { userSession.selectedPrimaryRole },
                        set: { userSession.selectedPrimaryRole = $0 }
                    ),
                    roleStats: viewModel.roleStats,
                    onTap: {
                        showRoleSelection = false
                    },
                    showFullScreen: true
                )
            }
        }
    }

    private var headerView: some View {
        SharedHeaderView(
            summoner: summoner,
            title: "Champion Pool",
            onLogout: {
                userSession.logout()
            }
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "person.3.fill")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("No Champions Found")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Champions will appear here once loaded")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Load Champions") {
                Task {
                    await championDataViewModel?.loadData()
                }
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterOptionsView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(ChampionFilter.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                }) {
                    Text(filter.rawValue)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(
                            selectedFilter == filter
                                ? DesignSystem.Colors.white : DesignSystem.Colors.textPrimary
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            selectedFilter == filter
                                ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBackground
                        )
                        .cornerRadius(DesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    private func championListView(champions: [Champion]) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                if let viewModel = championDataViewModel {
                    ForEach(viewModel.championStats, id: \.champion.id) { championStat in
                        ChampionStatsCard(championStat: championStat, filter: selectedFilter)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func initializeViewModel() {
        if championDataViewModel == nil {
            championDataViewModel = ChampionDataViewModel(
                dataCoordinator: dataCoordinator,
                summoner: summoner,
                userSession: userSession
            )
        }
    }
}

// MARK: - Data Structures

struct ChampionStats {
    let champion: Champion
    var gamesPlayed: Int
    var wins: Int
    var winRate: Double
    var averageKDA: Double
    var averageCS: Double
    var averageVisionScore: Double
}

// MARK: - Champion Card Views

struct ChampionStatsCard: View {
    let championStat: ChampionStats
    let filter: ChampionFilter

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Champion Icon
            AsyncImage(url: URL(string: championStat.champion.iconURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(DesignSystem.Colors.cardBorder)
                    .overlay(
                        Image(systemName: "person.circle")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    )
            }
            .frame(width: 50, height: 50)
            .cornerRadius(DesignSystem.CornerRadius.small)

            // Champion Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(championStat.champion.name)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("\(championStat.gamesPlayed) games")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                // Primary stat based on filter
                switch filter {
                case .all, .highGames:
                    Text("\(championStat.gamesPlayed) games")
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundColor(DesignSystem.Colors.primary)
                case .highWinRate:
                    Text("\(Int(championStat.winRate * 100))%")
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundColor(winRateColor)
                case .highKDA:
                    Text("\(String(format: "%.1f", championStat.averageKDA)) KDA")
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundColor(DesignSystem.Colors.primary)
                }

                // Secondary stats
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("\(String(format: "%.1f", championStat.averageKDA)) KDA")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("\(String(format: "%.1f", championStat.averageCS)) CS/min")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    private var winRateColor: Color {
        if championStat.winRate >= 0.6 {
            return DesignSystem.Colors.accent
        } else if championStat.winRate >= 0.5 {
            return DesignSystem.Colors.textSecondary
        } else {
            return DesignSystem.Colors.secondary
        }
    }
}

struct ChampionCard: View {
    let champion: Champion

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Champion Image Placeholder
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.cardBackground)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.circle")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                )

            // Champion Name
            Text(champion.name)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
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

    return ChampionView(summoner: summoner, userSession: userSession)
        .modelContainer(modelContainer)
        .onAppear {
            summoner.summonerLevel = 100
        }
}
