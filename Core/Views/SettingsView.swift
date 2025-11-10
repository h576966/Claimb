//
//  SettingsView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-28.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Bindable var userSession: UserSession
    @Binding var isPresented: Bool
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Settings Content
                List {
                    // Game Type Filter Section
                    Section {
                        Picker("Match Filter", selection: Binding(
                            get: { userSession.gameTypeFilter },
                            set: { newValue in
                                userSession.updateGameTypeFilter(newValue)
                            }
                        )) {
                            ForEach(GameTypeFilter.allCases, id: \.self) { filter in
                                Text(filter.displayName)
                                    .tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Analysis Settings")
                    } footer: {
                        Text("Choose whether to analyze all games or ranked games only. This affects Champion Pool and Performance views.")
                            .font(DesignSystem.Typography.caption)
                    }
                    
                    // Account Section
                    Section {
                        Button(role: .destructive) {
                            showLogoutConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(DesignSystem.Colors.error)
                                Text("Logout")
                                    .foregroundColor(DesignSystem.Colors.error)
                            }
                        }
                    } header: {
                        Text("Account")
                    } footer: {
                        Text("You'll need to sign in again to access your data.")
                            .font(DesignSystem.Typography.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .alert("Logout", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    userSession.logout()
                    isPresented = false
                }
            } message: {
                Text("Are you sure you want to logout? You'll need to sign in again to access your data.")
            }
        }
    }
}

#Preview {
    let modelContainer = try! ModelContainer(
        for: Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self)
    let userSession = UserSession(modelContext: modelContainer.mainContext)
    
    return SettingsView(userSession: userSession, isPresented: .constant(true))
        .modelContainer(modelContainer)
}

