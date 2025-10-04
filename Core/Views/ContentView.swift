//
//  ContentView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import SwiftData
import SwiftUI

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
                            ClaimbLogger.info(
                                "Showing MainTabView", service: "ContentView",
                                metadata: [
                                    "summoner": summoner.gameName
                                ])
                        }
                } else {
                    LoginView(userSession: userSession)
                        .onAppear {
                            ClaimbLogger.info(
                                "Showing LoginView", service: "ContentView",
                                metadata: [
                                    "isLoggedIn": String(userSession.isLoggedIn)
                                ])
                        }
                }
            } else {
                // Loading state while UserSession is being created
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ClaimbSpinner(size: 60)

                    Text("Checking for saved login...")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.background)
                .onAppear {
                    ClaimbLogger.debug("Showing loading state", service: "ContentView")
                }
            }
        }
        .id(refreshTrigger)  // Force view refresh when trigger changes
        .onAppear {
            if userSession == nil {
                ClaimbLogger.debug("Creating UserSession", service: "ContentView")
                userSession = UserSession(modelContext: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("UserSessionDidChange"))) { _ in
            ClaimbLogger.debug("Received UserSessionDidChange notification", service: "ContentView")
            refreshTrigger.toggle()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self,
        ])
}
