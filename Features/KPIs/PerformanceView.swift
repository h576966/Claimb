//
//  PerformanceView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

// Import all required types and utilities
import Observation
import SwiftData
import SwiftUI

// MARK: - Rank Badge View

struct RankBadge: View {
    let rank: String
    let lp: Int
    let queueType: String
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rank)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(rankColor)

            HStack(spacing: DesignSystem.Spacing.sm) {
                if lp > 0 {
                    Text("\(lp) LP")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Text(queueType)
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
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
    let isFocused: Bool
    let trend: KPITrend?
    let onFocusToggle: () -> Void
    let userSession: UserSession
    let summoner: Summoner
    let role: String
    let championPool: [String]
    let openAIService: OpenAIService
    let cacheRepository: CoachingCacheRepository
    
    @State private var showConfirmation = false
    @State private var tips: KPIImprovementTips?
    @State private var isLoadingTips = false
    @State private var tipsError: String?
    @State private var showFirstTimeHelp = false

    var body: some View {
        VStack(spacing: 0) {
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
                
                // Focus toggle button
                Button(action: {
                    if isFocused {
                        onFocusToggle()
                    } else {
                        showConfirmation = true
                    }
                }) {
                    Image(systemName: isFocused ? "circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(isFocused ? .white : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Trend indicator (only shown when focused)
            if isFocused, let trend = trend {
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.xs)
                
                VStack(spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: trend.isImproving ? "arrow.up.right" : "arrow.down.right")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(trend.isImproving ? DesignSystem.Colors.accent : DesignSystem.Colors.error)
                        
                        Text(String(format: "%.1f%% %@ over %d games", 
                                   abs(trend.changePercentage),
                                   trend.isImproving ? "improvement" : "decline",
                                   trend.matchesSince))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                    }
                    
                    // Visual progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(DesignSystem.Colors.cardBorder)
                                .frame(height: 2)
                            
                            // Progress
                            Rectangle()
                                .fill(trend.isImproving ? DesignSystem.Colors.accent : DesignSystem.Colors.error)
                                .frame(width: min(geometry.size.width * (abs(trend.changePercentage) / 100.0), geometry.size.width), height: 2)
                        }
                    }
                    .frame(height: 2)
                }
            }
            
            // Tips display (only shown when focused and manually selected)
            if isFocused && (isLoadingTips || tips != nil || tipsError != nil || showFirstTimeHelp) {
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.xs)
                
                // First-time help message
                if showFirstTimeHelp && tips == nil && !isLoadingTips {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.accent)
                            .padding(.top, 2)
                        
                        Text("You'll get AI tips and track your progress on this metric")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                    }
                } else if isLoadingTips {
                    // Show shimmer while loading
                    ShimmerView(lines: 3)
                } else if let tips = tips {
                    // Show tips
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.accent)
                            .padding(.top, 2)
                        
                        Text(tips.tips)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                    }
                } else if let error = tipsError {
                    // Show error message
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.top, 2)
                        
                        Text(error)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .onChange(of: isFocused) { _, newValue in
            if newValue {
                // Show first-time help message if user hasn't seen it
                let hasSeenHelp = UserDefaults.standard.bool(forKey: "hasSeenKPIFocusHelp_\(kpi.metric)")
                if !hasSeenHelp && userSession.isFocusedKPIManuallySelected() {
                    showFirstTimeHelp = true
                    UserDefaults.standard.set(true, forKey: "hasSeenKPIFocusHelp_\(kpi.metric)")
                    // Hide help message after 3 seconds and load tips
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            showFirstTimeHelp = false
                        }
                        await loadTips()
                    }
                } else if userSession.isFocusedKPIManuallySelected() && tips == nil && !isLoadingTips {
                    // Load tips immediately if already seen help
                    Task {
                        await loadTips()
                    }
                }
            } else {
                // Clear tips state when unfocused
                tips = nil
                isLoadingTips = false
                tipsError = nil
                showFirstTimeHelp = false
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + 2)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(
                    isFocused ? .white : DesignSystem.Colors.cardBorder,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .alert("Change Focus Area?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Change Focus") {
                onFocusToggle()
            }
        } message: {
            Text("Changing your focus area will reset progress tracking. Your previous focus progress will be lost.")
        }
    }

    private func performanceLevelText(_ level: Baseline.PerformanceLevel) -> String {
        switch level {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .needsImprovement: return "Needs Improvement"
        case .poor: return "Poor"
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
    
    private func loadTips() async {
        guard let baseline = kpi.baseline else {
            ClaimbLogger.warning(
                "Cannot generate tips without baseline data",
                service: "PerformanceView",
                metadata: [
                    "metric": kpi.metric,
                    "displayName": kpi.displayName
                ]
            )
            // Show helpful message to user
            await MainActor.run {
                self.tipsError = "Baseline data not available yet. Tips will be available once baseline data is loaded."
            }
            return
        }
        
        isLoadingTips = true
        tipsError = nil
        
        do {
            let targetValue = kpi.metric == "deaths_per_game" ? baseline.p40 : baseline.p60
            
            // Parse the formatted value string back to Double
            // Handle percentage values (e.g., "45%" -> 0.45) vs regular values (e.g., "5.2" -> 5.2)
            let cleanedValue = kpi.value.replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard var currentValue = Double(cleanedValue) else {
                ClaimbLogger.warning(
                    "Failed to parse KPI value",
                    service: "PerformanceView",
                    metadata: [
                        "metric": kpi.metric,
                        "value": kpi.value
                    ]
                )
                isLoadingTips = false
                return
            }
            
            // Convert percentage values back to decimals to match baseline format
            // Percentage metrics store baselines as decimals (0.45), but display as percentages (45%)
            if kpi.metric.hasSuffix("_pct") && kpi.value.contains("%") {
                currentValue = currentValue / 100.0
            }
            
            let loadedTips = try await openAIService.generateKPIImprovementTips(
                kpiMetric: kpi.metric,
                displayName: kpi.displayName,
                currentValue: currentValue,
                targetValue: targetValue,
                summoner: summoner,
                role: role,
                championPool: championPool,
                cacheRepository: cacheRepository
            )
            
            // Update on main actor
            await MainActor.run {
                self.tips = loadedTips
                self.isLoadingTips = false
            }
        } catch {
            // Log error but fail gracefully
            ClaimbLogger.error(
                "Failed to load KPI tips",
                service: "PerformanceView",
                error: error,
                metadata: [
                    "metric": kpi.metric
                ]
            )
            
            await MainActor.run {
                self.tipsError = error.localizedDescription
                self.isLoadingTips = false
            }
        }
    }

}

// MARK: - Performance View

struct PerformanceView: View {
    @Bindable var summoner: Summoner
    @Bindable var userSession: UserSession
    @Environment(\.modelContext) private var modelContext
    @State private var matchDataViewModel: MatchDataViewModel?
    @State private var showRoleSelection = false
    @State private var refreshTrigger = 0

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
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.md)
                }

                // Combined Rank and Streak Card
                if let viewModel = matchDataViewModel,
                    case .loaded(let matches) = viewModel.matchState
                {
                    combinedRankAndStreakCard(
                        matches: matches, role: userSession.selectedPrimaryRole
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.md)
                } else {
                    // Show rank badges only while loading matches
                    combinedRankAndStreakCard(matches: [], role: userSession.selectedPrimaryRole)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.bottom, DesignSystem.Spacing.md)
                }

                // Content
                if let viewModel = matchDataViewModel {
                    ClaimbContentWrapper(
                        state: viewModel.matchState,
                        loadingMessage: "Loading performance data...",
                        emptyMessage: "No matches found for analysis",
                        retryAction: {
                            refreshTrigger += 1
                        }
                    ) { matches in
                        kpiListView(matches: matches)
                    }
                } else {
                    ClaimbLoadingView(message: "Initializing...")
                }
            }
        }
        .onAppear {
            if matchDataViewModel == nil {
                initializeViewModel()
            }
        }
        .task(id: refreshTrigger) {
            await matchDataViewModel?.loadAllData()
            await userSession.refreshRanksIfNeeded()
        }
        .onChange(of: userSession.selectedPrimaryRole) { _, _ in
            Task {
                await matchDataViewModel?.calculateKPIsForCurrentRole()
            }
        }
        .onChange(of: userSession.gameTypeFilter) { _, _ in
            Task {
                // Recalculate stats with existing matches (no need to reload from DB)
                guard let viewModel = matchDataViewModel else { return }
                if case .loaded = viewModel.matchState {
                    // Recalculate role stats, KPIs with current filter
                    viewModel.recalculateRoleStats()
                    await viewModel.calculateKPIsForCurrentRole()
                }
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
            actionButton: SharedHeaderView.ActionButton(
                title: "Refresh",
                icon: "arrow.clockwise",
                action: {
                    refreshTrigger += 1
                },
                isLoading: matchDataViewModel?.isRefreshing ?? false,
                isDisabled: matchDataViewModel?.isRefreshing ?? false
            ),
            userSession: userSession
        )
    }

    private func combinedRankAndStreakCard(matches: [Match], role: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Left side: Rank Badges
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
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
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            // Vertical Divider
            Rectangle()
                .fill(DesignSystem.Colors.cardBorder)
                .frame(width: 1)

            // Right side: Streak and Performance
            if let kpiService = matchDataViewModel?.kpiCalculationService, !matches.isEmpty {
                let losingStreak = kpiService.calculateLosingStreak(
                    matches: matches, summoner: summoner, role: role)
                let winningStreak = kpiService.calculateWinningStreak(
                    matches: matches, summoner: summoner, role: role)
                let recentPerformance = kpiService.calculateRecentWinRate(
                    matches: matches, summoner: summoner, role: role)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Winning Streak Indicator
                    if winningStreak >= 3 {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(DesignSystem.Colors.primary)
                                .font(.body)
                            Text("\(winningStreak) Win Streak")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }

                    // Losing Streak Warning
                    if losingStreak >= 3 {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DesignSystem.Colors.secondary)
                                .font(.body)
                            Text("\(losingStreak) Loss Streak")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                    }

                    // Recent Performance (always show if >= 5 games)
                    if recentPerformance.wins + recentPerformance.losses >= 5 {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(
                                    recentPerformance.winRate >= 50
                                        ? DesignSystem.Colors.primary
                                        : DesignSystem.Colors.textSecondary
                                )
                                .font(.body)
                            Text("\(recentPerformance.wins)W-\(recentPerformance.losses)L")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                // Empty state - just a spacer to maintain layout
                Color.clear
                    .frame(maxWidth: .infinity)
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

    private func kpiListView(matches: [Match]) -> some View {
        // Prepare dependencies OUTSIDE the view builder to avoid recreation
        let championPool = MatchStatsCalculator.calculateBestPerformingChampions(
            matches: Array(matches.prefix(10)),
            summoner: summoner,
            primaryRole: userSession.selectedPrimaryRole
        ).map { $0.name }
        
        let openAIService = OpenAIService()
        let cacheRepository = CoachingCacheRepository(modelContext: modelContext)
        
        return ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                // KPI Cards
                if let viewModel = matchDataViewModel {
                    ForEach(viewModel.kpiMetrics, id: \.metric) { kpi in
                        let isFocused = kpi.metric == userSession.focusedKPI
                        let trend = isFocused && userSession.focusedKPISince != nil
                            ? viewModel.calculateKPITrend(for: kpi.metric, since: userSession.focusedKPISince!)
                            : nil
                        
                        KPICard(
                            kpi: kpi,
                            isFocused: isFocused,
                            trend: trend,
                            onFocusToggle: {
                                if isFocused {
                                    userSession.clearFocusedKPI()
                                } else {
                                    userSession.setFocusedKPI(kpi.metric, isManualSelection: true)
                                }
                            },
                            userSession: userSession,
                            summoner: summoner,
                            role: userSession.selectedPrimaryRole,
                            championPool: championPool,
                            openAIService: openAIService,
                            cacheRepository: cacheRepository
                        )
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .onAppear {
            // Auto-select worst performing KPI if no focus set (not manual)
            if userSession.focusedKPI == nil,
               let viewModel = matchDataViewModel,
               let worstKPI = viewModel.kpiMetrics.first {
                userSession.setFocusedKPI(worstKPI.metric, isManualSelection: false)
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
