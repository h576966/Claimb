//
//  MainTabView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 2  // Default to CoachingView
    @State private var showLogoutConfirmation = false
    let summoner: Summoner
    let userSession: UserSession

    var body: some View {
        TabView(selection: $selectedTab) {
            // Champion View
            ChampionView(summoner: summoner, userSession: userSession)
                .tabItem {
                    Label("Champion", systemImage: "person.3.fill")
                }
                .tag(0)
                .accessibilityLabel("Champion Pool")
                .accessibilityHint("View your champion performance and pool analysis")

            // Performance View
            PerformanceView(summoner: summoner, userSession: userSession)
                .tabItem {
                    Label("Performance", systemImage: "chart.bar.fill")
                }
                .tag(1)
                .accessibilityLabel("Performance")
                .accessibilityHint("View your KPIs and performance metrics")

            // Coaching View
            CoachingView(summoner: summoner, userSession: userSession)
                .tabItem {
                    Label("Coaching", systemImage: "brain.head.profile")
                }
                .tag(2)
                .accessibilityLabel("Coaching")
                .accessibilityHint("Get AI-powered coaching insights and game analysis")
        }
        .accentColor(DesignSystem.Colors.primary)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showLogoutConfirmation = true
                }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summoner.gameName)
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("#\(summoner.tagLine)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Logout") {
                    showLogoutConfirmation = true
                }
                .foregroundColor(DesignSystem.Colors.secondary)
                .accessibilityLabel("Logout")
                .accessibilityHint("Sign out and return to login screen")
            }
        }
        .alert("Logout", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .onAppear {
            // Refresh rank data for existing summoner
            Task {
                await refreshSummonerRanks()
            }
        }
    }

    private func logout() {
        userSession.logout()
    }

    private func refreshSummonerRanks() async {
        let dataManager = DataManager.shared(with: userSession.modelContext)
        let result = await dataManager.refreshSummonerRanks(for: summoner)

        switch result {
        case .loaded:
            ClaimbLogger.info("Successfully refreshed rank data", service: "MainTabView")
        case .error(let error):
            ClaimbLogger.error("Failed to refresh rank data", service: "MainTabView", error: error)
        default:
            break
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

    return MainTabView(summoner: summoner, userSession: userSession)
        .modelContainer(modelContainer)
        .onAppear {
            summoner.summonerLevel = 100
        }
}
