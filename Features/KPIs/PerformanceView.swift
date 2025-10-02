//
//  PerformanceView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Rank Badge View

struct RankBadge: View {
    let rank: String
    let lp: Int
    let queueType: String
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            VStack(alignment: .leading, spacing: 1) {
                Text(rank)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if lp > 0 {
                    Text("\(lp) LP")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Text(queueType)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.leading, DesignSystem.Spacing.xs)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(rankBackgroundColor)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(rankColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var rankColor: Color {
        let tier = rank.components(separatedBy: " ").first?.uppercased() ?? ""
        switch tier {
        case "UNRANKED": return DesignSystem.Colors.textSecondary
        case "IRON": return .gray
        case "BRONZE": return .orange
        case "SILVER": return .gray.opacity(0.7)
        case "GOLD": return .yellow
        case "PLATINUM": return .cyan
        case "EMERALD": return .green
        case "DIAMOND": return .blue
        case "MASTER": return .purple
        case "GRANDMASTER": return .red
        case "CHALLENGER": return .pink
        default: return DesignSystem.Colors.textSecondary
        }
    }

    private var rankBackgroundColor: Color {
        if isPrimary {
            return rankColor.opacity(0.1)
        } else {
            return DesignSystem.Colors.cardBackground
        }
    }
}

// MARK: - KPI Card View

struct KPICard: View {
    let kpi: KPIMetric

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Left side: Title and performance indicator
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(kpi.displayName)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Performance indicator - more compact
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(kpi.color)
                        .frame(width: 6, height: 6)

                    Text(performanceLevelText(kpi.performanceLevel))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(kpi.color)
                }
            }

            Spacer()

            // Right side: Values - more compact vertical layout
            VStack(alignment: .trailing, spacing: 2) {
                Text(kpi.formattedValue)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(kpi.color)

                // Target value with reduced spacing
                if let baseline = kpi.baseline {
                    let targetValue = kpi.metric == "deaths_per_game" ? baseline.p40 : baseline.p60
                    let formattedTarget = formatTargetValue(targetValue, for: kpi.metric)
                    Text("Target: \(formattedTarget)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + 2)  // Slightly more than sm for better touch target
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    private func performanceLevelText(_ level: Baseline.PerformanceLevel) -> String {
        switch level {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .needsImprovement: return "Needs Improvement"
        }
    }

    private func formatTargetValue(_ value: Double, for metric: String) -> String {
        switch metric {
        case "kill_participation_pct", "objective_participation_pct", "team_damage_pct",
            "damage_taken_share_pct":
            // Convert decimal to percentage (0.45 -> 45%)
            return String(format: "%.0f%%", value * 100)
        case "cs_per_min", "vision_score_per_min":
            return String(format: "%.1f", value)
        case "deaths_per_game":
            return String(format: "%.1f", value)
        default:
            return String(format: "%.1f", value)
        }
    }

}

// MARK: - Performance View

struct PerformanceView: View {
    @Bindable var summoner: Summoner
    let userSession: UserSession
    @Environment(\.modelContext) private var modelContext
    @State private var matchDataViewModel: MatchDataViewModel?
    @State private var showRoleSelection = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView

                Spacer()
                    .frame(height: DesignSystem.Spacing.md)

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

                // Rank Badges - Always show rank information
                rankBadgesView
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)

                // Streak Indicators
                if let viewModel = matchDataViewModel,
                    case .loaded(let matches) = viewModel.matchState
                {
                    streakIndicatorsView(matches: matches, role: userSession.selectedPrimaryRole)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.md)
                }

                // Content
                if let viewModel = matchDataViewModel {
                    ClaimbContentWrapper(
                        state: viewModel.matchState,
                        loadingMessage: "Loading performance data...",
                        emptyMessage: "No matches found for analysis",
                        retryAction: { Task { await viewModel.loadAllData() } }
                    ) { matches in
                        kpiListView(matches: matches)
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
                await refreshSummonerRanks()
            }
        }
        .onChange(of: userSession.selectedPrimaryRole) { _, _ in
            Task {
                await matchDataViewModel?.calculateKPIsForCurrentRole()
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
            title: "Performance",
            actionButton: SharedHeaderView.ActionButton(
                title: "Refresh",
                icon: "arrow.clockwise",
                action: { Task { await matchDataViewModel?.refreshMatches() } },
                isLoading: matchDataViewModel?.isRefreshing ?? false,
                isDisabled: false
            ),
            onLogout: {
                userSession.logout()
            }
        )
    }

    private var rankBadgesView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if summoner.hasAnyRank {
                // Solo/Duo Rank Badge
                if let soloDuoRank = summoner.soloDuoRank {
                    RankBadge(
                        rank: soloDuoRank,
                        lp: summoner.soloDuoLP ?? 0,
                        queueType: "Solo/Duo",
                        isPrimary: true
                    )
                }

                // Flex Rank Badge
                if let flexRank = summoner.flexRank {
                    RankBadge(
                        rank: flexRank,
                        lp: summoner.flexLP ?? 0,
                        queueType: "Flex",
                        isPrimary: false
                    )
                }
            } else {
                // Show "Unranked" when no ranks are available
                RankBadge(
                    rank: "Unranked",
                    lp: 0,
                    queueType: "No Rank",
                    isPrimary: true
                )
            }

            Spacer()
        }
    }

    private func streakIndicatorsView(matches: [Match], role: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if let kpiService = matchDataViewModel?.kpiCalculationService {
                let losingStreak = kpiService.calculateLosingStreak(
                    matches: matches, summoner: summoner, role: role)
                let winningStreak = kpiService.calculateWinningStreak(
                    matches: matches, summoner: summoner, role: role)
                let recentPerformance = kpiService.calculateRecentWinRate(
                    matches: matches, summoner: summoner, role: role)

                // Losing Streak Warning
                if losingStreak >= 3 {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .font(.caption)
                        Text("\(losingStreak) Loss Streak")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.secondary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.small)
                }

                // Winning Streak Indicator
                if winningStreak >= 3 {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.caption)
                        Text("\(winningStreak) Win Streak")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.small)
                }

                // Recent Performance
                if recentPerformance.wins + recentPerformance.losses >= 5 {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(
                                recentPerformance.winRate >= 50
                                    ? DesignSystem.Colors.primary
                                    : DesignSystem.Colors.textSecondary
                            )
                            .font(.caption)
                        Text("\(recentPerformance.wins)W-\(recentPerformance.losses)L")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                }

                Spacer()
            }
        }
    }

    private func kpiListView(matches: [Match]) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                // KPI Cards
                if let viewModel = matchDataViewModel {
                    ForEach(viewModel.kpiMetrics, id: \.metric) { kpi in
                        KPICard(kpi: kpi)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xl)
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

    private func refreshSummonerRanks() async {
        print("🔍 PerformanceView: refreshSummonerRanks called")
        ClaimbLogger.info("Starting rank refresh from PerformanceView", service: "PerformanceView")

        let dataManager = DataManager.shared(with: modelContext)
        let result = await dataManager.refreshSummonerRanks(for: summoner)

        switch result {
        case .loaded:
            print("🔍 PerformanceView: Rank refresh completed successfully")
            ClaimbLogger.info(
                "Successfully refreshed rank data", service: "PerformanceView",
                metadata: [
                    "soloDuoRank": summoner.soloDuoRank ?? "nil",
                    "flexRank": summoner.flexRank ?? "nil",
                ])
        case .error(let error):
            print("🔍 PerformanceView: Rank refresh failed: \(error)")
            ClaimbLogger.error(
                "Failed to refresh rank data", service: "PerformanceView", error: error)
        default:
            print("🔍 PerformanceView: Rank refresh returned unexpected state")
            break
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

    return PerformanceView(summoner: summoner, userSession: userSession)
        .modelContainer(modelContainer)
        .onAppear {
            summoner.summonerLevel = 100
            summoner.soloDuoRank = "GOLD IV"
            summoner.soloDuoLP = 75
            summoner.flexRank = "SILVER I"
            summoner.flexLP = 50
        }
}
