//
//  ContentView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var userSession: UserSession?
    @State private var refreshTrigger = false
    @State private var isLoggedIn = false
    @State private var currentSummoner: Summoner?
    
    var body: some View {
        Group {
            if let userSession = userSession {
                if isLoggedIn, let summoner = currentSummoner {
                    MainTabView(summoner: summoner, userSession: userSession)
                        .onAppear {
                            print("🏠 [ContentView] Showing MainTabView for \(summoner.gameName)")
                        }
                } else {
                    LoginView(userSession: userSession)
                        .onAppear {
                            print("🔐 [ContentView] Showing LoginView - isLoggedIn: \(isLoggedIn)")
                        }
                }
            } else {
                // Loading state while UserSession is being created
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                    Text("Loading...")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.background)
                .onAppear {
                    print("⏳ [ContentView] Showing loading state")
                }
            }
        }
        .id(refreshTrigger) // Force view refresh when trigger changes
        .onAppear {
            if userSession == nil {
                print("🔄 [ContentView] Creating UserSession")
                userSession = UserSession(modelContext: modelContext)
            } else {
                // Sync local state with UserSession
                isLoggedIn = userSession?.isLoggedIn ?? false
                currentSummoner = userSession?.currentSummoner
                print("🔄 [ContentView] Syncing state - isLoggedIn: \(isLoggedIn), summoner: \(currentSummoner?.gameName ?? "nil")")
            }
        }
        .onChange(of: userSession?.isLoggedIn) { oldValue, newValue in
            print("🔄 [ContentView] Login state changed: \(oldValue ?? false) -> \(newValue ?? false)")
            isLoggedIn = newValue ?? false
            refreshTrigger.toggle()
        }
        .onChange(of: userSession?.currentSummoner) { oldValue, newValue in
            print("🔄 [ContentView] Summoner changed: \(oldValue?.gameName ?? "nil") -> \(newValue?.gameName ?? "nil")")
            currentSummoner = newValue
            refreshTrigger.toggle()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self])
}
