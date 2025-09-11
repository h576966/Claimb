//
//  CoachingView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftUI
import SwiftData

struct CoachingView: View {
    let summoner: Summoner
    @ObservedObject var userSession: UserSession
    @State private var matches: [Match] = []
    @State private var selectedRole: String = "TOP"
    @State private var roleStats: [RoleStats] = []
    @State private var isLoading = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var coachingInsights: String = ""
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
                        coachingContentView
                    }
                }
            }
            .navigationTitle("Coaching")
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
                
                // Analyze Button
                Button(action: {
                    Task { await analyzePerformance() }
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        Text(isAnalyzing ? "Analyzing..." : "Analyze")
                            .font(DesignSystem.Typography.callout)
                    }
                }
                .claimbButton(variant: .primary, size: .small)
                .disabled(isAnalyzing || matches.isEmpty)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
            Text("Loading coaching data...")
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
            
            Text("Error Loading Data")
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
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text("No Data Available")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Load your match history to get personalized coaching insights")
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
    
    private var coachingContentView: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Recent Matches Summary
                recentMatchesCard
                
                // Coaching Insights
                if !coachingInsights.isEmpty {
                    coachingInsightsCard
                } else {
                    generateInsightsCard
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
    
    private var recentMatchesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Recent Performance")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            let recentMatches = Array(matches.prefix(5))
            
            if recentMatches.isEmpty {
                Text("No recent matches found")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(recentMatches, id: \.matchId) { match in
                        HStack {
                            // Match Result
                            Circle()
                                .fill(match.participants.first(where: { $0.puuid == summoner.puuid })?.win == true ? DesignSystem.Colors.accent : DesignSystem.Colors.secondary)
                                .frame(width: 8, height: 8)
                            
                            // Champion (placeholder)
                            Text("Champion")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Spacer()
                            
                            // KDA
                            if let participant = match.participants.first(where: { $0.puuid == summoner.puuid }) {
                                Text("\(participant.kills)/\(participant.deaths)/\(participant.assists)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    private var coachingInsightsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("AI Coaching Insights")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(coachingInsights)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    private var generateInsightsCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.primary)
            
            Text("Get Personalized Insights")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Tap 'Analyze' to get AI-powered coaching recommendations based on your recent performance")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
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
    
    private func analyzePerformance() async {
        isAnalyzing = true
        coachingInsights = ""
        
        // Simulate AI analysis
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Generate mock insights based on recent matches
        let recentMatches = Array(matches.prefix(10))
        let wins = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })?.win
        }.filter { $0 }.count
        
        let winRate = recentMatches.isEmpty ? 0.0 : Double(wins) / Double(recentMatches.count)
        
        await MainActor.run {
            if winRate >= 0.6 {
                self.coachingInsights = "Great performance! You're maintaining a strong win rate. Focus on consistency and consider expanding your champion pool to stay versatile."
            } else if winRate >= 0.4 {
                self.coachingInsights = "Solid foundation! Work on decision-making in team fights and focus on improving your CS to gain more gold advantage."
            } else {
                self.coachingInsights = "Room for improvement! Focus on fundamentals like last-hitting, map awareness, and positioning. Consider reviewing your recent games to identify patterns."
            }
            
            self.isAnalyzing = false
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
    summoner.summonerLevel = 100
    
    return CoachingView(summoner: summoner, userSession: userSession)
        .modelContainer(modelContainer)
}
