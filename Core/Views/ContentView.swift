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
    
    var body: some View {
        Group {
            if let userSession = userSession {
                if userSession.isLoggedIn, let summoner = userSession.currentSummoner {
                    MainTabView(summoner: summoner, userSession: userSession)
                        .onAppear {
                            print("🏠 [ContentView] Showing MainTabView for \(summoner.gameName)")
                        }
                } else {
                    LoginView(userSession: userSession)
                        .onAppear {
                            print("🔐 [ContentView] Showing LoginView - isLoggedIn: \(userSession.isLoggedIn)")
                        }
                }
            } else {
                // Loading state while UserSession is being created
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                        .scaleEffect(1.2)
                    
                    Text("Checking for saved login...")
                        .font(DesignSystem.Typography.body)
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("UserSessionDidChange"))) { _ in
            print("🔄 [ContentView] Received UserSessionDidChange notification")
            refreshTrigger.toggle()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self])
}
