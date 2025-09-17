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
                    Image(systemName: "person.3.fill")
                    Text("Champion")
                }
                .tag(0)

            // Performance View
            PerformanceView(summoner: summoner, userSession: userSession)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Performance")
                }
                .tag(1)

            // Coaching View
            CoachingView(summoner: summoner, userSession: userSession)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Coaching")
                }
                .tag(2)
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
    }

    private func logout() {
        userSession.logout()
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
