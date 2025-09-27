//
//  LoginView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import SwiftData
import SwiftUI

struct LoginView: View {
    let userSession: UserSession
    @State private var gameName = ""
    @State private var tagLine = "8778"
    @State private var selectedRegion = "euw1"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let regions = [
        ("euw1", "Europe West"),
        ("na1", "North America"),
        ("eun1", "Europe Nordic & East"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Black background
                DesignSystem.Colors.background.ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.xl) {
                    // App Icon and Title
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // App Icon
                        Image(systemName: "gamecontroller.fill")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 80, height: 80)
                            .background(DesignSystem.Colors.cardBackground)
                            .cornerRadius(DesignSystem.CornerRadius.medium)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text("Claimb")
                                .font(DesignSystem.Typography.largeTitle)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Text("League of Legends Coaching")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.xxl)

                    // Login Form
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Game Name Input
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Summoner Name")
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .font(DesignSystem.Typography.title3)

                            TextField("Enter your summoner name", text: $gameName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .accentColor(DesignSystem.Colors.primary)
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.cardBackground)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                        .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                                )
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        // Tag Line Input
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Tag Line")
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .font(DesignSystem.Typography.title3)

                            TextField("Enter your tag", text: $tagLine)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .accentColor(DesignSystem.Colors.primary)
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.cardBackground)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                        .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                                )
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        // Region Selection
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Region")
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .font(DesignSystem.Typography.title3)

                            Picker("Region", selection: $selectedRegion) {
                                ForEach(regions, id: \.0) { region in
                                    Text(region.1).tag(region.0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .accentColor(DesignSystem.Colors.primary)
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.cardBackground)
                            .cornerRadius(DesignSystem.CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                            )
                        }

                        // Login Button
                        Button(action: {
                            Task { await login() }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(
                                                tint: DesignSystem.Colors.white)
                                        )
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Login")
                                        .font(DesignSystem.Typography.bodyBold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .claimbButton(variant: .primary, size: .large)
                        .disabled(!isValidInput || isLoading)

                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(DesignSystem.Colors.error)
                                .font(DesignSystem.Typography.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)

                    Spacer()

                    // Footer
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Supported Regions: EUW, NA, EUNE")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)

                        Text("Data is cached locally for offline use")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isValidInput: Bool {
        !gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !tagLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Methods

    private func login() async {
        guard isValidInput else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Create DataManager
            let dataManager = DataManager.create(with: userSession.modelContext)

            // Create or update summoner
            let summonerState = await dataManager.createOrUpdateSummoner(
                gameName: gameName.trimmingCharacters(in: .whitespacesAndNewlines),
                tagLine: tagLine.trimmingCharacters(in: .whitespacesAndNewlines),
                region: selectedRegion
            )

            // Handle summoner creation result
            guard case .loaded(let summoner) = summonerState else {
                let errorMessage =
                    switch summonerState {
                    case .error(let error):
                        "Failed to create summoner: \(error.localizedDescription)"
                    case .loading:
                        "Summoner creation is still loading"
                    case .idle:
                        "Summoner creation not started"
                    case .empty(let message):
                        "Summoner creation failed: \(message)"
                    case .loaded(_):
                        "This case should not be reached"
                    }

                await MainActor.run {
                    self.errorMessage = errorMessage
                    self.isLoading = false
                }
                return
            }

            // Load champion data if needed
            try await dataManager.loadChampionData()

            // Refresh matches - continue even if some matches fail
            let refreshState = await dataManager.refreshMatches(for: summoner)
            if case .error(let error) = refreshState {
                // Log the error but don't fail login if only match loading fails
                ClaimbLogger.error(
                    "Failed to load some matches during login, continuing anyway",
                    service: "LoginView",
                    error: error
                )
                // Still allow login to proceed
            }

            // Login the user
            await MainActor.run {
                ClaimbLogger.debug("About to call userSession.login()", service: "LoginView")
                userSession.login(summoner: summoner)
                ClaimbLogger.debug(
                    "userSession.login() completed", service: "LoginView",
                    metadata: [
                        "isLoggedIn": String(userSession.isLoggedIn)
                    ])
                self.isLoading = false
                ClaimbLogger.debug(
                    "Login process finished, isLoading set to false", service: "LoginView")
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Login failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

#Preview {
    let modelContainer = try! ModelContainer(
        for: Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self)
    let userSession = UserSession(modelContext: modelContainer.mainContext)
    LoginView(userSession: userSession)
        .modelContainer(modelContainer)
}
