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
    @Environment(\.dataCoordinator) private var dataCoordinator
    @Environment(\.riotClient) private var riotClient
    @Environment(\.dataDragonService) private var dataDragonService
    @State private var matchState: UIState<[Match]> = .idle
    @State private var roleStats: [RoleStats] = []
    @State private var kpiData: [KPIMetric] = []
    @State private var isRefreshing = false
    @State private var showRoleSelection = false

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

                // Content
                ClaimbContentWrapper(
                    state: matchState,
                    loadingMessage: "Loading performance data...",
                    emptyMessage: "No matches found for analysis",
                    retryAction: { Task { await loadData() } }
                ) { matches in
                    kpiListView(matches: matches)
                }
            }
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
        .onChange(of: userSession.selectedPrimaryRole) { _, _ in
            if case .loaded(let matches) = matchState {
                Task {
                    await calculateKPIs(matches: matches)
                }
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

    private func kpiListView(matches: [Match]) -> some View {
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
        guard let dataCoordinator = dataCoordinator else {
            await MainActor.run {
                self.matchState = .error(DataCoordinatorError.notAvailable)
            }
            return
        }

        await MainActor.run {
            self.matchState = .loading
        }

        let result = await dataCoordinator.loadMatches(for: summoner)

        await MainActor.run {
            self.matchState = result

            // Update role stats and KPIs if we have matches
            if case .loaded(let matches) = result {
                self.roleStats = dataCoordinator.calculateRoleStats(
                    from: matches, summoner: summoner)
                Task { await calculateKPIs(matches: matches) }
            }
        }
    }

    private func refreshData() async {
        guard let dataCoordinator = dataCoordinator else { return }

        await MainActor.run {
            self.isRefreshing = true
        }

        let result = await dataCoordinator.refreshMatches(for: summoner)

        await MainActor.run {
            self.matchState = result
            self.isRefreshing = false

            // Update role stats and KPIs if we have matches
            if case .loaded(let matches) = result {
                self.roleStats = dataCoordinator.calculateRoleStats(
                    from: matches, summoner: summoner)
                Task { await calculateKPIs(matches: matches) }
            }
        }
    }

    // MARK: - KPI Calculation

    private func calculateKPIs(matches: [Match]) async {
        do {
            guard let riotClient = riotClient, let dataDragonService = dataDragonService else {
                throw NSError(
                    domain: "PerformanceView", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Services not available"])
            }

            let dataManager = DataManager(
                modelContext: userSession.modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
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
                ClaimbLogger.error(
                    "Failed to calculate KPIs", service: "PerformanceView", error: error)
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
                matches: matches,
                classMappingService: classMappingService,
                modelContext: userSession.modelContext
            ))

        kpis.append(
            createKPIMetric(
                metric: "vision_score_per_min",
                value: visionScore,
                role: role,
                matches: matches,
                classMappingService: classMappingService,
                modelContext: userSession.modelContext
            ))

        kpis.append(
            createKPIMetric(
                metric: "kill_participation_pct",
                value: killParticipation,
                role: role,
                matches: matches,
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
                    matches: matches,
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
                    matches: matches,
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
                    matches: matches,
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
                    matches: matches,
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
        matches: [Match],
        classMappingService: ChampionClassMappingService,
        modelContext: ModelContext
    ) -> KPIMetric {
        // Get the most common class for this role from the matches
        let classTag = getMostCommonClassTag(
            for: role, matches: matches, classMappingService: classMappingService)

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
        for role: String, matches: [Match], classMappingService: ChampionClassMappingService
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
            ClaimbLogger.error(
                "Failed to fetch baseline", service: "PerformanceView", error: error,
                metadata: [
                    "role": role,
                    "classTag": classTag,
                    "metric": metric,
                ])
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
