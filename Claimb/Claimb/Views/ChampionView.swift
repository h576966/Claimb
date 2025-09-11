//
//  ChampionView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftUI
import SwiftData

struct ChampionView: View {
    let summoner: Summoner
    @Environment(\.modelContext) private var modelContext
    @State private var champions: [Champion] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let dataDragonService = DataDragonService()
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Content
                    if isLoading {
                        loadingView
                    } else if !(errorMessage?.isEmpty ?? true) {
                        errorView
                    } else if champions.isEmpty {
                        emptyStateView
                    } else {
                        championGridView
                    }
                }
            }
            .navigationTitle("Champion Pool")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await loadChampions()
                }
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
                
                Text(summoner.region.uppercased())
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
            Text("Loading champions...")
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
            
            Text("Error Loading Champions")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(errorMessage ?? "Unknown error occurred")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await loadChampions()
                }
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text("No Champions Found")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Champions will appear here once loaded")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Load Champions") {
                Task {
                    await loadChampions()
                }
            }
            .claimbButton(variant: .primary, size: .medium)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var championGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                ForEach(champions, id: \.id) { champion in
                    ChampionCard(champion: champion)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
    
    private func loadChampions() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let dataManager = DataManager(
                    modelContext: modelContext,
                    riotClient: RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey),
                    dataDragonService: DataDragonService()
                )
                let loadedChampions = try await dataManager.getAllChampions()
                
                await MainActor.run {
                    self.champions = loadedChampions
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct ChampionCard: View {
    let champion: Champion
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Champion Image Placeholder
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.cardBackground)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                )
            
            // Champion Name
            Text(champion.name)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
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
    
    return ChampionView(summoner: summoner)
        .modelContainer(for: [Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self])
}
