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
        default: return metric
        }
    }

    var formattedValue: String {
        switch metric {
        case "kill_participation_pct", "objective_participation_pct", "team_damage_pct",
            "damage_taken_share_pct":
            return String(format: "%.1f%%", value * 100)
        case "cs_per_min", "vision_score_per_min":
            return String(format: "%.1f", value)
        case "deaths_per_game":
            return String(format: "%.1f", value)
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
                    Text("Target: \(String(format: "%.1f", baseline.p60))")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("Average: \(String(format: "%.1f", baseline.mean))")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
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
    @State private var matches: [Match] = []
    @State private var roleStats: [RoleStats] = []
    @State private var kpiData: [KPIMetric] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showRoleSelection = false

    private let riotClient = RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey)

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView

                // Role Selector
                if !roleStats.isEmpty {
                    RoleSelectorView(
                        selectedRole: $userSession.selectedPrimaryRole,
                        roleStats: roleStats,
                        onTap: {
                            showRoleSelection = true
                        }
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
                }

                // Content
                if isLoading {
                    loadingView
                } else if !(errorMessage?.isEmpty ?? true) {
                    errorView
                } else if matches.isEmpty {
                    emptyStateView
                } else {
                    kpiListView
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
                await calculateKPIs()
            }
        }
        .sheet(isPresented: $showRoleSelection) {
            RoleSelectorView(
                selectedRole: $userSession.selectedPrimaryRole,
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
            title: "Performance",
            actionButton: SharedHeaderView.ActionButton(
                title: "Refresh",
                icon: "arrow.clockwise",
                action: { Task { await refreshData() } },
                isLoading: isRefreshing,
                isDisabled: false
            ),
            onLogout: {
                userSession.logout()
            }
        )
    }

    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
            Text("Loading performance data...")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.error)

            Text("Error Loading Matches")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(errorMessage ?? "Unknown error occurred")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadData()
                }
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "chart.bar.fill")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("No Performance Data")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Your performance metrics will appear here")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Load Data") {
                Task {
                    await loadData()
                }
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var kpiListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // KPI Cards
                ForEach(kpiData, id: \.metric) { kpi in
                    KPICard(kpi: kpi)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let dataManager = DataManager(
                modelContext: userSession.modelContext,
                riotClient: riotClient,
                dataDragonService: DataDragonService()
            )

            // Check if we have existing matches
            let existingMatches = try await dataManager.getMatches(for: summoner)

            if existingMatches.isEmpty {
                // Load initial 40 matches
                print("📊 [PerformanceView] No existing matches, loading initial 40")
                try await dataManager.loadInitialMatches(for: summoner)
            } else {
                // Load any new matches incrementally
                print(
                    "📊 [PerformanceView] Found \(existingMatches.count) existing matches, checking for new ones"
                )
                try await dataManager.refreshMatches(for: summoner)
            }

            // Get all matches after loading
            let loadedMatches = try await dataManager.getMatches(for: summoner)

            await MainActor.run {
                self.matches = loadedMatches
                self.isLoading = false
                self.calculateRoleStats()
            }

            await calculateKPIs()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func refreshData() async {
        isRefreshing = true

        do {
            let dataManager = DataManager(
                modelContext: userSession.modelContext,
                riotClient: riotClient,
                dataDragonService: DataDragonService()
            )
            try await dataManager.refreshMatches(for: summoner)
            let loadedMatches = try await dataManager.getMatches(for: summoner)

            await MainActor.run {
                self.matches = loadedMatches
                self.isRefreshing = false
                self.calculateRoleStats()
            }

            await calculateKPIs()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isRefreshing = false
            }
        }
    }

    private func calculateRoleStats() {
        guard !matches.isEmpty else {
            roleStats = []
            return
        }

        let calculatedStats = calculateRoleWinRates(from: matches, summoner: summoner)
        roleStats = calculatedStats

        // Update primary role based on match data if needed
        userSession.setPrimaryRoleFromMatchData(roleStats: calculatedStats)
    }

    private func calculateRoleWinRates(from matches: [Match], summoner: Summoner) -> [RoleStats] {
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

        return finalStats
    }

    // MARK: - KPI Calculation

    private func calculateKPIs() async {
        do {
            let dataManager = DataManager(
                modelContext: userSession.modelContext,
                riotClient: riotClient,
                dataDragonService: DataDragonService()
            )

            let roleMatches = matches.filter { match in
                match.participants.contains {
                    $0.puuid == summoner.puuid
                        && RoleUtils.normalizeRole($0.role, lane: $0.lane)
                            == userSession.selectedPrimaryRole
                }
            }

            let kpis = try await calculateRoleKPIs(
                matches: roleMatches,
                role: userSession.selectedPrimaryRole,
                dataManager: dataManager
            )

            await MainActor.run {
                self.kpiData = kpis
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to calculate KPIs: \(error.localizedDescription)"
            }
        }
    }

    private func calculateRoleKPIs(
        matches: [Match],
        role: String,
        dataManager: DataManager
    ) async throws -> [KPIMetric] {
        guard !matches.isEmpty else { return [] }

        // Get role-specific participants
        let participants = matches.compactMap { match in
            match.participants.first(where: {
                $0.puuid == summoner.puuid && RoleUtils.normalizeRole($0.role) == role
            })
        }

        guard !participants.isEmpty else { return [] }

        // Load champion class mapping
        let classMappingService = ChampionClassMappingService()
        await classMappingService.loadChampionClassMapping(modelContext: userSession.modelContext)

        // Calculate basic KPIs
        let deathsPerGame =
            participants.map { Double($0.deaths) }.reduce(0, +) / Double(participants.count)
        let visionScore =
            participants.map { $0.visionScorePerMinute }.reduce(0, +) / Double(participants.count)
        let killParticipation =
            participants.map { participant in
                let match = matches.first { $0.participants.contains(participant) }
                let teamKills = match?.participants.reduce(0) { $0 + $1.kills } ?? 0
                return teamKills > 0
                    ? Double(participant.kills + participant.assists) / Double(teamKills) : 0.0
            }.reduce(0, +) / Double(participants.count)

        var kpis: [KPIMetric] = []

        // Create KPIs with baseline comparison
        kpis.append(
            createKPIMetric(
                metric: "deaths_per_game",
                value: deathsPerGame,
                role: role,
                classMappingService: classMappingService,
                modelContext: userSession.modelContext
            ))

        kpis.append(
            createKPIMetric(
                metric: "vision_score_per_min",
                value: visionScore,
                role: role,
                classMappingService: classMappingService,
                modelContext: userSession.modelContext
            ))

        kpis.append(
            createKPIMetric(
                metric: "kill_participation_pct",
                value: killParticipation,
                role: role,
                classMappingService: classMappingService,
                modelContext: userSession.modelContext
            ))

        // Add role-specific KPIs
        if role != "SUPPORT" {
            let csPerMin =
                participants.map { $0.csPerMinute }.reduce(0, +) / Double(participants.count)
            kpis.append(
                createKPIMetric(
                    metric: "cs_per_min",
                    value: csPerMin,
                    role: role,
                    classMappingService: classMappingService,
                    modelContext: userSession.modelContext
                ))
        }

        if role == "JUNGLE" || role == "SUPPORT" {
            let objectiveParticipation =
                participants.map { participant in
                    let match = matches.first { $0.participants.contains(participant) }
                    let totalParticipated =
                        participant.dragonTakedowns + participant.riftHeraldTakedowns
                        + participant.baronTakedowns + participant.hordeTakedowns
                        + participant.atakhanTakedowns
                    let teamObjectives = match?.getTeamObjectives(teamId: participant.teamId) ?? 0
                    return teamObjectives > 0
                        ? Double(totalParticipated) / Double(teamObjectives) : 0.0
                }.reduce(0, +) / Double(participants.count)

            kpis.append(
                createKPIMetric(
                    metric: "objective_participation_pct",
                    value: objectiveParticipation,
                    role: role,
                    classMappingService: classMappingService,
                    modelContext: userSession.modelContext
                ))
        }

        if role == "MID" || role == "BOTTOM" {
            let damageShare =
                participants.map { participant in
                    let match = matches.first { $0.participants.contains(participant) }
                    // Use totalDamageDealtToChampions for both player and team
                    let teamDamage =
                        match?.participants.reduce(0) { $0 + $1.totalDamageDealtToChampions } ?? 0
                    let playerDamage = participant.totalDamageDealtToChampions
                    let share = teamDamage > 0 ? Double(playerDamage) / Double(teamDamage) : 0.0

                    return share
                }.reduce(0, +) / Double(participants.count)

            kpis.append(
                createKPIMetric(
                    metric: "team_damage_pct",
                    value: damageShare,
                    role: role,
                    classMappingService: classMappingService,
                    modelContext: userSession.modelContext
                ))
        }

        if role == "TOP" {
            let damageTakenShare =
                participants.map { participant in
                    let match = matches.first { $0.participants.contains(participant) }
                    let teamDamageTaken =
                        match?.participants.reduce(0) { $0 + $1.totalDamageTaken } ?? 0
                    return teamDamageTaken > 0
                        ? Double(participant.totalDamageTaken) / Double(teamDamageTaken) : 0.0
                }.reduce(0, +) / Double(participants.count)

            kpis.append(
                createKPIMetric(
                    metric: "damage_taken_share_pct",
                    value: damageTakenShare,
                    role: role,
                    classMappingService: classMappingService,
                    modelContext: userSession.modelContext
                ))
        }

        return kpis
    }

    // MARK: - Helper Functions

    private func createKPIMetric(
        metric: String,
        value: Double,
        role: String,
        classMappingService: ChampionClassMappingService,
        modelContext: ModelContext
    ) -> KPIMetric {
        // Get the most common class for this role from the matches
        let classTag = getMostCommonClassTag(for: role, classMappingService: classMappingService)

        // Look up baseline data
        let baseline = findBaseline(
            metric: metric, role: role, classTag: classTag, modelContext: modelContext)

        // Calculate performance level and color
        let (performanceLevel, color) = calculatePerformanceLevel(value: value, baseline: baseline)

        return KPIMetric(
            metric: metric,
            value: value,
            baseline: baseline,
            performanceLevel: performanceLevel,
            color: color
        )
    }

    private func getMostCommonClassTag(
        for role: String, classMappingService: ChampionClassMappingService
    ) -> String? {
        // Get all champions played in this role
        let roleMatches = matches.filter { match in
            match.participants.contains {
                $0.puuid == summoner.puuid && RoleUtils.normalizeRole($0.role) == role
            }
        }

        let champions = roleMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })?.champion
        }

        // Count class occurrences
        var classCounts: [String: Int] = [:]
        for champion in champions {
            if let classTag = classMappingService.getClassTag(for: champion) {
                classCounts[classTag, default: 0] += 1
            }
        }

        // Return the most common class
        return classCounts.max(by: { $0.value < $1.value })?.key
    }

    private func findBaseline(
        metric: String, role: String, classTag: String?, modelContext: ModelContext
    ) -> Baseline? {
        guard let classTag = classTag else { return nil }

        do {
            let descriptor = FetchDescriptor<Baseline>(
                predicate: #Predicate { baseline in
                    baseline.role == role && baseline.classTag == classTag
                        && baseline.metric == metric
                }
            )
            let baselines = try modelContext.fetch(descriptor)
            return baselines.first
        } catch {
            print(
                "❌ [PerformanceView] Failed to fetch baseline for \(role)/\(classTag)/\(metric): \(error)"
            )
            return nil
        }
    }

    private func calculatePerformanceLevel(value: Double, baseline: Baseline?) -> (
        PerformanceLevel, Color
    ) {
        guard let baseline = baseline else {
            return (.unknown, DesignSystem.Colors.textSecondary)
        }

        if value < baseline.p40 {
            return (.poor, DesignSystem.Colors.secondary)  // Red-orange for poor
        } else if value < baseline.mean {
            return (.belowMean, DesignSystem.Colors.warning)  // Orange for below average
        } else if value < baseline.p60 {
            return (.good, DesignSystem.Colors.white)  // White for good
        } else {
            return (.excellent, DesignSystem.Colors.accent)  // Teal for excellent
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
