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
    @State private var championState: UIState<[Champion]> = .idle
    @State private var championStats: [ChampionStats] = []
    @State private var selectedFilter: ChampionFilter = .mostPlayed
    @State private var roleStats: [RoleStats] = []
    @State private var showRoleSelection = false

    enum ChampionFilter: String, CaseIterable {
        case mostPlayed = "Most Played"
        case bestPerforming = "Best Performing"
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView

                // Role Selector
                if !roleStats.isEmpty {
                    RoleSelectorView(
                        selectedRole: Binding(
                            get: { userSession.selectedPrimaryRole },
                            set: { userSession.selectedPrimaryRole = $0 }
                        ),
                        roleStats: roleStats,
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
                ClaimbContentWrapper(
                    state: championState,
                    loadingMessage: "Loading champions...",
                    emptyMessage: "No champions found",
                    retryAction: {
                        Task { await loadData() }
                    }
                ) { champions in
                    if championStats.isEmpty {
                        emptyStateView
                    } else {
                        championListView(champions: champions)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
        .onChange(of: userSession.selectedPrimaryRole) { _, _ in
            Task {
                await loadChampionStats()
            }
        }
        .onChange(of: selectedFilter) { _, _ in
            Task {
                await loadChampionStats()
            }
        }
        .sheet(isPresented: $showRoleSelection) {
            RoleSelectorView(
                selectedRole: Binding(
                    get: { userSession.selectedPrimaryRole },
                    set: { userSession.selectedPrimaryRole = $0 }
                ),
                roleStats: roleStats,
                onTap: {
                    showRoleSelection = false
                },
                showFullScreen: true
            )
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
                    await loadData()
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
                ForEach(championStats, id: \.champion.id) { championStat in
                    ChampionStatsCard(championStat: championStat, filter: selectedFilter)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func loadData() async {
        guard let dataCoordinator = dataCoordinator else {
            championState = .failure(DataCoordinatorError.notAvailable)
            return
        }

        championState = .loading

        // Load champions using DataCoordinator
        let championResult = await dataCoordinator.loadChampions()

        await MainActor.run {
            self.championState = championResult
        }

        // Load matches and calculate role stats
        let matchResult = await dataCoordinator.loadMatches(for: summoner)

        switch matchResult {
        case .loaded(let matches):
            await MainActor.run {
                self.roleStats = dataCoordinator.calculateRoleStats(
                    from: matches, summoner: summoner)
            }

            // Load champion stats after setting role stats
            await loadChampionStats()
        case .error(let error):
            await MainActor.run {
                self.championState = .error(error)
            }
        case .loading, .idle, .empty:
            break
        }
    }

    private func loadChampionStats() async {
        guard let dataCoordinator = dataCoordinator else { return }

        let matchResult = await dataCoordinator.loadMatches(for: summoner)

        switch matchResult {
        case .loaded(let matches):
            let stats = calculateChampionStats(
                from: matches, role: userSession.selectedPrimaryRole, filter: selectedFilter)

            await MainActor.run {
                self.championStats = stats
            }
        case .error, .loading, .idle, .empty:
            break
        }
    }

    private func calculateRoleStats(from matches: [Match]) {
        var roleStats: [String: (wins: Int, total: Int)] = [:]

        // Initialize all 5 roles with 0 stats
        let allRoles = ["TOP", "JUNGLE", "MID", "BOTTOM", "SUPPORT"]
        for role in allRoles {
            roleStats[role] = (wins: 0, total: 0)
        }

        // Filter matches to only include relevant games for role analysis
        let filteredMatches = matches.filter { $0.isIncludedInRoleAnalysis }

        for match in filteredMatches {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                continue
            }

            let normalizedRole = RoleUtils.normalizeRole(participant.role, lane: participant.lane)
            roleStats[normalizedRole]?.total += 1
            if participant.win {
                roleStats[normalizedRole]?.wins += 1
            }
        }

        let finalStats = roleStats.map { role, stats in
            let winRate = stats.total > 0 ? Double(stats.wins) / Double(stats.total) : 0.0
            return RoleStats(role: role, winRate: winRate, totalGames: stats.total)
        }.sorted { $0.totalGames > $1.totalGames }

        self.roleStats = finalStats

        // Update primary role based on match data if needed
        userSession.setPrimaryRoleFromMatchData(roleStats: finalStats)
    }

    private func calculateChampionStats(from matches: [Match], role: String, filter: ChampionFilter)
        -> [ChampionStats]
    {
        var championStats: [String: ChampionStats] = [:]

        for match in matches {
            guard
                let participant = match.participants.first(where: {
                    $0.puuid == summoner.puuid
                        && RoleUtils.normalizeRole($0.role, lane: $0.lane) == role
                })
            else {
                continue
            }

            let championId = participant.championId
            let champion = championState.data?.first { $0.id == championId }

            guard let champion = champion else { continue }

            if championStats[champion.name] == nil {
                championStats[champion.name] = ChampionStats(
                    champion: champion,
                    gamesPlayed: 0,
                    wins: 0,
                    winRate: 0.0,
                    averageKDA: 0.0,
                    averageCS: 0.0,
                    averageVisionScore: 0.0
                )
            }

            championStats[champion.name]?.gamesPlayed += 1
            if participant.win {
                championStats[champion.name]?.wins += 1
            }

            // Update averages
            let current = championStats[champion.name]!
            let newKDA =
                (current.averageKDA * Double(current.gamesPlayed - 1) + participant.kda)
                / Double(current.gamesPlayed)
            let newCS =
                (current.averageCS * Double(current.gamesPlayed - 1) + participant.csPerMinute)
                / Double(current.gamesPlayed)
            let newVision =
                (current.averageVisionScore * Double(current.gamesPlayed - 1)
                    + participant.visionScorePerMinute) / Double(current.gamesPlayed)

            championStats[champion.name]?.averageKDA = newKDA
            championStats[champion.name]?.averageCS = newCS
            championStats[champion.name]?.averageVisionScore = newVision
        }

        // Filter champions with at least 3 games and calculate win rates
        let filteredStats = championStats.values
            .filter { $0.gamesPlayed >= 3 }
            .map { stat in
                var updatedStat = stat
                updatedStat.winRate = Double(stat.wins) / Double(stat.gamesPlayed)
                return updatedStat
            }

        // Sort based on selected filter
        switch filter {
        case .mostPlayed:
            return filteredStats.sorted { $0.gamesPlayed > $1.gamesPlayed }
        case .bestPerforming:
            return filteredStats.sorted { $0.winRate > $1.winRate }
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
    let filter: ChampionView.ChampionFilter

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
                if filter == .mostPlayed {
                    Text("\(championStat.gamesPlayed) games")
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundColor(DesignSystem.Colors.primary)
                } else {
                    Text("\(Int(championStat.winRate * 100))%")
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundColor(winRateColor)
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
