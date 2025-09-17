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
    @State private var expandedChampionIds: Set<Int> = []

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
                        ExpandableChampionStatsCard(
                            championStat: championStat,
                            filter: selectedFilter,
                            userSession: userSession,
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
    var averageDeaths: Double

    // Role-specific KPIs
    var averageGoldPerMin: Double
    var averageKillParticipation: Double
    var averageObjectiveParticipation: Double
    var averageTeamDamagePercent: Double
    var averageDamageTakenShare: Double
}

// MARK: - KPI Data Structure

struct RoleKPI {
    let title: String
    let value: String
    let color: Color
}

// MARK: - Role-Specific KPI Logic

private func getRoleSpecificKPIs(for championStat: ChampionStats, role: String) -> [RoleKPI] {
    ClaimbLogger.debug(
        "Getting role-specific KPIs", service: "ChampionView",
        metadata: [
            "role": role,
            "champion": championStat.champion.name,
        ])

    switch role.uppercased() {
    case "BOTTOM":
        return [
            RoleKPI(
                title: "CS/min",
                value: String(format: "%.1f", championStat.averageCS),
                color: getKPIColor(
                    value: championStat.averageCS, baseline: 6.84, higherIsBetter: true)
            ),
            RoleKPI(
                title: "Deaths",
                value: String(format: "%.1f", championStat.averageDeaths),
                color: getKPIColor(
                    value: championStat.averageDeaths, baseline: 5.39, higherIsBetter: false)
            ),
            RoleKPI(
                title: "Team DMG%",
                value: String(format: "%.1f%%", championStat.averageTeamDamagePercent * 100),
                color: getKPIColor(
                    value: championStat.averageTeamDamagePercent * 100, baseline: 22.0,
                    higherIsBetter: true)
            ),
        ]

    case "JUNGLE":
        return [
            RoleKPI(
                title: "Obj Part%",
                value: String(format: "%.0f%%", championStat.averageObjectiveParticipation * 100),
                color: getKPIColor(
                    value: championStat.averageObjectiveParticipation * 100, baseline: 75.0,
                    higherIsBetter: true)
            ),
            RoleKPI(
                title: "Vision/min",
                value: String(format: "%.1f", championStat.averageVisionScore),
                color: getKPIColor(
                    value: championStat.averageVisionScore, baseline: 0.75, higherIsBetter: true)
            ),
            RoleKPI(
                title: "Kill Part%",
                value: String(format: "%.0f%%", championStat.averageKillParticipation * 100),
                color: getKPIColor(
                    value: championStat.averageKillParticipation * 100, baseline: 50.0,
                    higherIsBetter: true)
            ),
        ]

    case "MID":
        return [
            RoleKPI(
                title: "CS/min",
                value: String(format: "%.1f", championStat.averageCS),
                color: getKPIColor(
                    value: championStat.averageCS, baseline: 6.46, higherIsBetter: true)
            ),
            RoleKPI(
                title: "Team DMG%",
                value: String(format: "%.1f%%", championStat.averageTeamDamagePercent * 100),
                color: getKPIColor(
                    value: championStat.averageTeamDamagePercent * 100, baseline: 22.0,
                    higherIsBetter: true)
            ),
            RoleKPI(
                title: "Deaths",
                value: String(format: "%.1f", championStat.averageDeaths),
                color: getKPIColor(
                    value: championStat.averageDeaths, baseline: 4.8, higherIsBetter: false)
            ),
        ]

    case "TOP":
        return [
            RoleKPI(
                title: "CS/min",
                value: String(format: "%.1f", championStat.averageCS),
                color: getKPIColor(
                    value: championStat.averageCS, baseline: 6.59, higherIsBetter: true)
            ),
            RoleKPI(
                title: "Dmg Taken%",
                value: String(format: "%.1f%%", championStat.averageDamageTakenShare * 100),
                color: getKPIColor(
                    value: championStat.averageDamageTakenShare * 100, baseline: 29.0,
                    higherIsBetter: true)
            ),
            RoleKPI(
                title: "Deaths",
                value: String(format: "%.1f", championStat.averageDeaths),
                color: getKPIColor(
                    value: championStat.averageDeaths, baseline: 4.78, higherIsBetter: false)
            ),
        ]

    case "UTILITY", "SUPPORT":
        return [
            RoleKPI(
                title: "Vision/min",
                value: String(format: "%.1f", championStat.averageVisionScore),
                color: getKPIColor(
                    value: championStat.averageVisionScore, baseline: 1.77, higherIsBetter: true)
            ),
            RoleKPI(
                title: "Kill Part%",
                value: String(format: "%.0f%%", championStat.averageKillParticipation * 100),
                color: getKPIColor(
                    value: championStat.averageKillParticipation * 100, baseline: 51.0,
                    higherIsBetter: true)
            ),
            RoleKPI(
                title: "Obj Part%",
                value: String(format: "%.0f%%", championStat.averageObjectiveParticipation * 100),
                color: getKPIColor(
                    value: championStat.averageObjectiveParticipation * 100, baseline: 41.0,
                    higherIsBetter: true)
            ),
        ]

    default:
        // Fallback to general metrics
        return [
            RoleKPI(
                title: "CS/min",
                value: String(format: "%.1f", championStat.averageCS),
                color: DesignSystem.Colors.textPrimary
            ),
            RoleKPI(
                title: "Deaths",
                value: String(format: "%.1f", championStat.averageDeaths),
                color: DesignSystem.Colors.textPrimary
            ),
            RoleKPI(
                title: "KDA",
                value: String(format: "%.1f", championStat.averageKDA),
                color: DesignSystem.Colors.textPrimary
            ),
        ]
    }
}

private func getKPIColor(value: Double, baseline: Double, higherIsBetter: Bool) -> Color {
    // Use the same performance calculation logic as KPICalculationService
    if higherIsBetter {
        // Standard logic for higher-is-better metrics
        if value >= baseline * 1.1 {
            return DesignSystem.Colors.accent  // Teal - excellent
        } else if value >= baseline {
            return DesignSystem.Colors.white  // White - good
        } else if value >= baseline * 0.8 {
            return DesignSystem.Colors.warning  // Orange - needs improvement
        } else {
            return DesignSystem.Colors.secondary  // Red - poor
        }
    } else {
        // Special handling for lower-is-better metrics (like deaths)
        if value <= baseline * 0.9 {
            return DesignSystem.Colors.accent  // Teal - excellent
        } else if value <= baseline {
            return DesignSystem.Colors.white  // White - good
        } else if value <= baseline * 1.2 {
            return DesignSystem.Colors.warning  // Orange - needs improvement
        } else {
            return DesignSystem.Colors.secondary  // Red - poor
        }
    }
}

// MARK: - Champion Card Views

struct ExpandableChampionStatsCard: View {
    let championStat: ChampionStats
    let filter: ChampionFilter
    let userSession: UserSession
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main card content (always visible)
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
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: DesignSystem.Spacing.sm
                ) {
                    ForEach(
                        getRoleSpecificKPIs(
                            for: championStat, role: userSession.selectedPrimaryRole), id: \.title
                    ) { kpi in
                        StatItemView(
                            title: kpi.title,
                            value: kpi.value,
                            color: kpi.color
                        )
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
