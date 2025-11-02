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
    @State private var showSettings = false
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(summoner.gameName)
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("#\(summoner.tagLine)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Open settings and account options")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(userSession: userSession, isPresented: $showSettings)
        }
        .onAppear {
            // Refresh rank data if stale (uses smart caching)
            Task {
                await userSession.refreshRanksIfNeeded()
            }
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
