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
                Color.black.ignoresSafeArea()
                
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
        VStack(spacing: 15) {
            // Summoner Info
            VStack(spacing: 8) {
                Text(summoner.gameName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("#\(summoner.tagLine) • \(regionDisplayName)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let level = summoner.summonerLevel {
                    Text("Level \(level)")
                        .font(.caption)
                        .foregroundColor(.teal)
                }
            }
            
            // Refresh Button
            HStack {
                Button(action: {
                    Task { await refreshMatches() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Refresh")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.teal)
                    .cornerRadius(20)
                }
                .disabled(isRefreshing)
                
                // Clear Cache Button (for debugging)
                Button(action: {
                    Task { await clearCache() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Clear Cache")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(20)
                }
                .disabled(isRefreshing)
                
                // Test Baselines Button
                Button(action: {
                    showBaselineTest = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Test Baselines")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(20)
                }
                .disabled(isRefreshing)
                
                Spacer()
                
                // Last Refresh Time
                if let lastRefresh = lastRefreshTime {
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 15)
        .background(Color.black)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            GlowCSpinner(size: 80, speed: 1.5)
            
            Text("Loading your matches...")
                .foregroundColor(.white)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No matches found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Play some games and come back to see your match history")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task { await refreshMatches() }
            }) {
                Text("Refresh")
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.teal)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Match List View
    
    private var matchListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(matches, id: \.matchId) { match in
                    MatchCardView(match: match, summoner: summoner)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
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
