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
    @Environment(\.modelContext) private var modelContext
    @State private var matchDataViewModel: MatchDataViewModel?
    @State private var selectedFilter: ChampionFilter = .mostPlayed
    @State private var showRoleSelection = false
    @State private var expandedChampionIds: Set<Int> = []

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView

                // Role Selector
                if let viewModel = matchDataViewModel, !viewModel.roleStats.isEmpty {
                    RoleSelectorView(
                        selectedRole: Binding(
                            get: { userSession.selectedPrimaryRole },
                            set: { userSession.updatePrimaryRole($0) }
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
                if let viewModel = matchDataViewModel {
                    ClaimbContentWrapper(
                        state: viewModel.championState,
                        loadingMessage: "Loading champions...",
                        emptyMessage: "No champions found",
                        retryAction: {
                            Task { await viewModel.loadAllData() }
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
                await matchDataViewModel?.loadAllData()
            }
        }
        .onChange(of: userSession.selectedPrimaryRole) { _, _ in
            Task {
                await matchDataViewModel?.loadChampionStats(
                    role: userSession.selectedPrimaryRole, filter: selectedFilter)
            }
        }
        .onChange(of: selectedFilter) { _, _ in
            Task {
                await matchDataViewModel?.loadChampionStats(
                    role: userSession.selectedPrimaryRole, filter: selectedFilter)
            }
        }
        .sheet(isPresented: $showRoleSelection) {
            if let viewModel = matchDataViewModel {
                RoleSelectorView(
                    selectedRole: Binding(
                        get: { userSession.selectedPrimaryRole },
                        set: { userSession.updatePrimaryRole($0) }
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
                    await matchDataViewModel?.loadAllData()
                }
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterOptionsView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Filter buttons
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
                                    ? DesignSystem.Colors.primary
                                    : DesignSystem.Colors.cardBackground
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

            // Filter description
            Text(selectedFilter.description)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    private func championListView(champions: [Champion]) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                if let viewModel = matchDataViewModel {
                    ForEach(viewModel.championStats, id: \.champion.id) { championStat in
                        ExpandableChampionStatsCard(
                            championStat: championStat,
                            filter: selectedFilter,
                            userSession: userSession,
                            viewModel: viewModel,
                            isExpanded: expandedChampionIds.contains(championStat.champion.id),
                            onToggle: {
                                toggleExpansion(for: championStat.champion.id)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func toggleExpansion(for championId: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedChampionIds.contains(championId) {
                // If this card is already expanded, close it
                expandedChampionIds.remove(championId)
            } else {
                // Close all other cards and open this one
                expandedChampionIds.removeAll()
                expandedChampionIds.insert(championId)
            }
        }
    }

    private func initializeViewModel() {
        if matchDataViewModel == nil {
            let dataManager = DataManager.shared(with: modelContext)
            matchDataViewModel = MatchDataViewModel(
                dataManager: dataManager,
                summoner: summoner,
                userSession: userSession
            )
        }
    }
}

// MARK: - Data Structures
// Note: ChampionStats struct is now defined in MatchDataViewModel to avoid duplication

// MARK: - KPI Data Structure
// Note: RoleKPI struct is now defined in ChampionDataViewModel to avoid duplication

// MARK: - Role-Specific KPI Logic
// Note: KPI logic has been moved to ChampionDataViewModel to avoid duplication

// MARK: - Champion Card Views

struct ExpandableChampionStatsCard: View {
    let championStat: ChampionStats
    let filter: ChampionFilter
    let userSession: UserSession
    let viewModel: MatchDataViewModel
    let isExpanded: Bool
    let onToggle: () -> Void

    /// Cached KPI results to prevent recalculation on every render
    @State private var cachedKPIs: [ChampionKPIDisplay] = []
    @State private var lastCalculatedRole: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Main card content (always visible) - entire card is clickable
            Button(action: onToggle) {
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
                        // Primary stat - always show win rate
                        Text("\(Int(championStat.winRate * 100))%")
                            .font(DesignSystem.Typography.bodyBold)
                            .foregroundColor(winRateColor)
                    }

                    // Expand/Collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .padding(DesignSystem.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content (animated)
            if isExpanded {
                expandedContentView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
        .onAppear {
            calculateKPIsIfNeeded()
        }
        .onChange(of: userSession.selectedPrimaryRole) { _, _ in
            calculateKPIsIfNeeded()
        }
    }

    /// Calculate KPIs only when role changes or first time
    private func calculateKPIsIfNeeded() {
        let currentRole = userSession.selectedPrimaryRole
        if lastCalculatedRole != currentRole {
            lastCalculatedRole = currentRole
            cachedKPIs = viewModel.getChampionKPIDisplay(
                for: championStat,
                role: currentRole
            )
        }
    }

    private var expandedContentView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Divider()
                .background(DesignSystem.Colors.cardBorder)
                .padding(.horizontal, DesignSystem.Spacing.md)

            VStack(spacing: DesignSystem.Spacing.sm) {
                // Detailed stats section
                HStack {
                    Text("Detailed Performance")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                }

                // Role-specific KPIs
                if cachedKPIs.isEmpty {
                    Text("No KPI data available for this champion")
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
                        ForEach(cachedKPIs, id: \.metric) { kpi in
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
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
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

struct StatItemView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(value)
                .font(DesignSystem.Typography.bodyBold)
                .foregroundColor(color)

            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground.opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.small)
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
