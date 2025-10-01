//
//  PerformanceView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import Foundation
import SwiftData
import SwiftUI

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
    let summoner: Summoner
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
        }
}
