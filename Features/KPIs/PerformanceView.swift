//
//  PerformanceView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftData
import SwiftUI

// MARK: - KPI Data Structures

struct KPIMetric {
    let metric: String
    let value: Double
    let baseline: Baseline?
    let performanceLevel: PerformanceLevel
    let color: Color

    var displayName: String {
        switch metric {
        case "deaths_per_game": return "Deaths per Game"
        case "vision_score_per_min": return "Vision Score/min"
        case "kill_participation_pct": return "Kill Participation"
        case "cs_per_min": return "CS per Minute"
        case "objective_participation_pct": return "Objective Participation"
        case "team_damage_pct": return "Damage Share"
        case "damage_taken_share_pct": return "Damage Taken Share"
        case "primary_role_consistency": return "Role Consistency"
        case "champion_pool_size": return "Champion Pool Size"
        default: return metric
        }
    }

    var formattedValue: String {
        switch metric {
        case "kill_participation_pct", "objective_participation_pct", "team_damage_pct",
            "damage_taken_share_pct", "primary_role_consistency":
            return String(format: "%.1f%%", value)
        case "cs_per_min", "vision_score_per_min":
            return String(format: "%.1f", value)
        case "deaths_per_game":
            return String(format: "%.1f", value)
        case "champion_pool_size":
            return String(format: "%.0f", value)
        default:
            return String(format: "%.2f", value)
        }
    }
}

enum PerformanceLevel {
    case poor
    case belowMean
    case good
    case excellent
    case unknown
}

// MARK: - KPI Card View

struct KPICard: View {
    let kpi: KPIMetric

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text(kpi.displayName)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Text(kpi.formattedValue)
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(kpi.color)
            }

            if let baseline = kpi.baseline {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // For Deaths per Game, target is P40 (lower is better)
                    // For other metrics, target is P60 (higher is better)
                    let targetValue = kpi.metric == "deaths_per_game" ? baseline.p40 : baseline.p60
                    Text("Target: \(String(format: "%.1f", targetValue))")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("Average: \(String(format: "%.1f", baseline.mean))")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                // Custom targets for new KPIs without baseline data
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    if kpi.metric == "primary_role_consistency" {
                        Text("Target: 84%")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("Goal: Stay focused on your main role")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else if kpi.metric == "champion_pool_size" {
                        Text("Target: 2-3 champions")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("Goal: Master a few champions")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            // Performance indicator
            HStack {
                Circle()
                    .fill(kpi.color)
                    .frame(width: 8, height: 8)

                Text(performanceLevelText(kpi.performanceLevel))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(kpi.color)

                Spacer()
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

    private func performanceLevelText(_ level: PerformanceLevel) -> String {
        switch level {
        case .poor: return "Poor"
        case .belowMean: return "Below Average"
        case .good: return "Good"
        case .excellent: return "Excellent"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Performance View

struct PerformanceView: View {
    let summoner: Summoner
    let userSession: UserSession
    @Environment(\.dataCoordinator) private var dataCoordinator
    @State private var kpiDataViewModel: KPIDataViewModel?
    @State private var showRoleSelection = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView

                // Role Selector
                if let viewModel = kpiDataViewModel, !viewModel.roleStats.isEmpty {
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

                // Content
                if let viewModel = kpiDataViewModel {
                    ClaimbContentWrapper(
                        state: viewModel.matchState,
                        loadingMessage: "Loading performance data...",
                        emptyMessage: "No matches found for analysis",
                        retryAction: { Task { await viewModel.loadData() } }
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
                await kpiDataViewModel?.loadData()
            }
        }
        .onChange(of: userSession.selectedPrimaryRole) { _, _ in
            Task {
                await kpiDataViewModel?.calculateKPIsForCurrentRole()
            }
        }
        .sheet(isPresented: $showRoleSelection) {
            if let viewModel = kpiDataViewModel {
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
            title: "Performance",
            actionButton: SharedHeaderView.ActionButton(
                title: "Refresh",
                icon: "arrow.clockwise",
                action: { Task { await kpiDataViewModel?.refreshData() } },
                isLoading: kpiDataViewModel?.isRefreshing ?? false,
                isDisabled: false
            ),
            onLogout: {
                userSession.logout()
            }
        )
    }

    private func kpiListView(matches: [Match]) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // KPI Cards
                if let viewModel = kpiDataViewModel {
                    ForEach(viewModel.kpiMetrics, id: \.metric) { kpi in
                        KPICard(kpi: kpi)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func initializeViewModel() {
        if kpiDataViewModel == nil {
            kpiDataViewModel = KPIDataViewModel(
                dataCoordinator: dataCoordinator,
                summoner: summoner,
                userSession: userSession
            )
        }
    }
}

#Preview {
    let modelContainer = try! ModelContainer(
        for: Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self,
        ChampionClassMapping.self)
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
        }
}
