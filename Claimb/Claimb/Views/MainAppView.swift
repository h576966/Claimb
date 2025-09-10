//
//  MainAppView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import SwiftUI
import SwiftData

struct MainAppView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var summoner: Summoner
    @State private var matches: [Match] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var lastRefreshTime: Date?
    @State private var showBaselineTest = false
    
    private let riotClient = RiotHTTPClient(apiKey: "RGAPI-2133e577-bec8-433b-b519-b3ba66331263")
    private let dataDragonService = DataDragonService()
    
    init(summoner: Summoner) {
        self._summoner = State(initialValue: summoner)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Black background
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Content
                    if isLoading && matches.isEmpty {
                        loadingView
                    } else if matches.isEmpty {
                        emptyStateView
                    } else {
                        matchListView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task { await loadMatches() }
        }
        .refreshable {
            await refreshMatches()
        }
        .sheet(isPresented: $showBaselineTest) {
            BaselineTestView()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Summoner Info
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(summoner.gameName)
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("#\(summoner.tagLine) • \(regionDisplayName)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                if let level = summoner.summonerLevel {
                    Text("Level \(level)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            
            // Action Buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
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
                
                // Clear Cache Button (for debugging)
                Button(action: {
                    Task { await clearCache() }
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Clear Cache")
                            .font(DesignSystem.Typography.callout)
                    }
                }
                .claimbButton(variant: .secondary, size: .small)
                .disabled(isRefreshing)
                
                // Test Baselines Button
                Button(action: {
                    showBaselineTest = true
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Test Baselines")
                            .font(DesignSystem.Typography.callout)
                    }
                }
                .claimbButton(variant: .secondary, size: .small)
                .disabled(isRefreshing)
                
                Spacer()
                
                // Last Refresh Time
                if let lastRefresh = lastRefreshTime {
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            GlowCSpinner(size: 80, speed: 1.5)
            
            Text("Loading your matches...")
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .font(DesignSystem.Typography.title3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Text("No matches found")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Play some games and come back to see your match history")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xxl)
            
            Button(action: {
                Task { await refreshMatches() }
            }) {
                Text("Refresh")
                    .font(DesignSystem.Typography.bodyBold)
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Match List View
    
    private var matchListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(matches, id: \.matchId) { match in
                    MatchCardView(match: match, summoner: summoner)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }
    
    // MARK: - Computed Properties
    
    private var regionDisplayName: String {
        switch summoner.region {
        case "euw1": return "EUW"
        case "na1": return "NA"
        case "eun1": return "EUNE"
        default: return summoner.region.uppercased()
        }
    }
    
    // MARK: - Methods
    
    private func loadMatches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )
            
            // Ensure champion data is loaded first
            try await dataManager.loadChampionData()
            
            let loadedMatches = try await dataManager.getMatches(for: summoner, limit: 5)
            
            await MainActor.run {
                self.matches = loadedMatches
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load matches: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func refreshMatches() async {
        isRefreshing = true
        errorMessage = nil
        
        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )
            
            // Ensure champion data is loaded first
            try await dataManager.loadChampionData()
            
            // Refresh matches from API
            try await dataManager.refreshMatches(for: summoner)
            
            // Reload matches from database
            let refreshedMatches = try await dataManager.getMatches(for: summoner, limit: 5)
            
            await MainActor.run {
                self.matches = refreshedMatches
                self.isRefreshing = false
                self.lastRefreshTime = Date()
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to refresh matches: \(error.localizedDescription)"
                self.isRefreshing = false
            }
        }
    }
    
    private func clearCache() async {
        isRefreshing = true
        errorMessage = nil
        
        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )
            
            // Clear all cached data
            try await dataManager.clearAllCache()
            
            // Refresh matches with fresh data
            try await dataManager.refreshMatches(for: summoner)
            
            // Reload matches from database
            let refreshedMatches = try await dataManager.getMatches(for: summoner, limit: 5)
            
            await MainActor.run {
                self.matches = refreshedMatches
                self.isRefreshing = false
                self.lastRefreshTime = Date()
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to clear cache: \(error.localizedDescription)"
                self.isRefreshing = false
            }
        }
    }
}

#Preview {
    let summoner = Summoner(
        puuid: "test-puuid",
        gameName: "TestSummoner",
        tagLine: "1234",
        region: "euw1"
    )
    summoner.summonerLevel = 100
    
    return MainAppView(summoner: summoner)
        .modelContainer(for: [Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self])
}
