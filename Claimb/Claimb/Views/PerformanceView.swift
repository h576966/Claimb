//
//  PerformanceView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftUI
import SwiftData

struct PerformanceView: View {
    let summoner: Summoner
    @ObservedObject var userSession: UserSession
    @State private var matches: [Match] = []
    @State private var selectedRole: String = "TOP"
    @State private var roleStats: [RoleStats] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showRoleSelection = false
    
    private let riotClient = RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey)
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Role Selector
                    if !roleStats.isEmpty {
                        RoleSelectorView(
                            selectedRole: $selectedRole,
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
                        matchListView
                    }
                }
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await loadMatches()
                }
            }
        .sheet(isPresented: $showRoleSelection) {
            RoleSelectorView(
                selectedRole: $selectedRole,
                roleStats: roleStats,
                onTap: {
                    showRoleSelection = false
                },
                showFullScreen: true
            )
        }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Summoner Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summoner.gameName)#\(summoner.tagLine)")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Level \(summoner.summonerLevel ?? 0)")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Refresh Button
                Button(action: {
                    Task { await refreshMatches() }
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Refresh")
                            .font(DesignSystem.Typography.callout)
                    }
                }
                .claimbButton(variant: .primary, size: .small)
                .disabled(isRefreshing)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
            Text("Loading matches...")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
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
                    await loadMatches()
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
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text("No Matches Found")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Your match history will appear here")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Load Matches") {
                Task {
                    await loadMatches()
                }
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var matchListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(matches, id: \.matchId) { match in
                    MatchCardView(match: match, summoner: summoner)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
    
    private func loadMatches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let dataManager = DataManager(
                modelContext: userSession.modelContext,
                riotClient: riotClient,
                dataDragonService: DataDragonService()
            )
            let loadedMatches = try await dataManager.getMatches(for: summoner)
            
            await MainActor.run {
                self.matches = loadedMatches
                self.isLoading = false
                self.calculateRoleStats()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func refreshMatches() async {
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
            selectedRole = "TOP"
            return
        }
        
        let calculatedStats = calculateRoleWinRates(from: matches, summoner: summoner)
        roleStats = calculatedStats
        
        // Set selected role to the one with the most games, or default to TOP
        if let mostPlayedRole = calculatedStats.max(by: { $0.totalGames < $1.totalGames }) {
            selectedRole = mostPlayedRole.role
        } else {
            selectedRole = "TOP"
        }
    }
    
    private func calculateRoleWinRates(from matches: [Match], summoner: Summoner) -> [RoleStats] {
        var roleStats: [String: (wins: Int, total: Int)] = [:]
        
        for match in matches {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid }) else {
                continue
            }
            
            let normalizedRole = RoleUtils.normalizeRole(participant.role)
            if roleStats[normalizedRole] == nil {
                roleStats[normalizedRole] = (wins: 0, total: 0)
            }
            
            roleStats[normalizedRole]?.total += 1
            if participant.win {
                roleStats[normalizedRole]?.wins += 1
            }
        }
        
        return roleStats.map { role, stats in
            let winRate = stats.total > 0 ? Double(stats.wins) / Double(stats.total) : 0.0
            return RoleStats(role: role, winRate: winRate, totalGames: stats.total)
        }.sorted { $0.totalGames > $1.totalGames }
    }
}

#Preview {
    let modelContainer = try! ModelContainer(for: Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self)
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
