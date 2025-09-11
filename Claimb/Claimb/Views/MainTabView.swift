//
//  MainTabView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-10.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showLogoutConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    let summoner: Summoner
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Champion View
            ChampionView(summoner: summoner)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Champion")
                }
                .tag(0)
            
            // Performance View
            PerformanceView(summoner: summoner)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Performance")
                }
                .tag(1)
            
            // Coaching View
            CoachingView(summoner: summoner)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Coaching")
                }
                .tag(2)
        }
        .accentColor(DesignSystem.Colors.primary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Logout") {
                    showLogoutConfirmation = true
                }
                .foregroundColor(DesignSystem.Colors.secondary)
            }
        }
        .alert("Logout", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }
    
    private func logout() {
        // Clear user data and return to login
        UserDefaults.standard.removeObject(forKey: "summonerName")
        UserDefaults.standard.removeObject(forKey: "tagline")
        UserDefaults.standard.removeObject(forKey: "region")
        
        // Dismiss the current view to return to login
        dismiss()
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
    
    return MainTabView(summoner: summoner)
        .modelContainer(for: [Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self])
}
