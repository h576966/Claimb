//
//  CacheManagementView.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftData
import SwiftUI

struct CacheManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.riotClient) private var riotClient
    @Environment(\.dataDragonService) private var dataDragonService
    @State private var isClearing = false
    @State private var clearMessage = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text("Cache Management")
                                .font(DesignSystem.Typography.title2)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Text("Clear cached data to free up space or resolve issues")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DesignSystem.Spacing.lg)

                        // Cache Options
                        VStack(spacing: DesignSystem.Spacing.md) {
                            // Clear All Cache
                            CacheOptionCard(
                                title: "Clear All Cache",
                                description:
                                    "Removes all cached data including matches, champions, and baselines",
                                icon: "trash.fill",
                                color: DesignSystem.Colors.error,
                                action: { await clearAllCache() }
                            )

                            // Clear Match Data
                            CacheOptionCard(
                                title: "Clear Match Data",
                                description:
                                    "Removes match history and participant data, keeps champions and baselines",
                                icon: "gamecontroller.fill",
                                color: DesignSystem.Colors.warning,
                                action: { await clearMatchData() }
                            )

                            // Clear Champion Data
                            CacheOptionCard(
                                title: "Clear Champion Data",
                                description:
                                    "Removes champion information, will be reloaded on next launch",
                                icon: "person.3.fill",
                                color: DesignSystem.Colors.info,
                                action: { await clearChampionData() }
                            )

                            // Clear Baseline Data
                            CacheOptionCard(
                                title: "Clear Baseline Data",
                                description:
                                    "Removes performance baseline data, will be reloaded on next launch",
                                icon: "chart.bar.fill",
                                color: DesignSystem.Colors.accent,
                                action: { await clearBaselineData() }
                            )

                            // Clear URL Cache
                            CacheOptionCard(
                                title: "Clear URL Cache",
                                description:
                                    "Clears network request cache, forces fresh data from Riot API",
                                icon: "network",
                                color: DesignSystem.Colors.primary,
                                action: { clearURLCache() }
                            )
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        // Status Message
                        if !clearMessage.isEmpty {
                            Text(clearMessage)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                        }

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss the view
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .alert("Cache Cleared", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Cache Clearing Methods

    private func clearAllCache() async {
        isClearing = true
        clearMessage = "Clearing all cache..."

        do {
            guard let riotClient = riotClient, let dataDragonService = dataDragonService else {
                throw NSError(
                    domain: "CacheManagementView", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Services not available"])
            }

            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            try await dataManager.clearAllCache()

            await MainActor.run {
                self.clearMessage = "All cache cleared successfully"
                self.alertMessage =
                    "All cached data has been removed. The app will reload data on next use."
                self.showAlert = true
                self.isClearing = false
            }
        } catch {
            await MainActor.run {
                self.clearMessage = "Error clearing cache: \(error.localizedDescription)"
                self.isClearing = false
            }
        }
    }

    private func clearMatchData() async {
        isClearing = true
        clearMessage = "Clearing match data..."

        do {
            guard let riotClient = riotClient, let dataDragonService = dataDragonService else {
                throw NSError(
                    domain: "CacheManagementView", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Services not available"])
            }

            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            try await dataManager.clearMatchData()

            await MainActor.run {
                self.clearMessage = "Match data cleared successfully"
                self.alertMessage =
                    "Match history has been cleared. Matches will be reloaded on next refresh."
                self.showAlert = true
                self.isClearing = false
            }
        } catch {
            await MainActor.run {
                self.clearMessage = "Error clearing match data: \(error.localizedDescription)"
                self.isClearing = false
            }
        }
    }

    private func clearChampionData() async {
        isClearing = true
        clearMessage = "Clearing champion data..."

        do {
            guard let riotClient = riotClient, let dataDragonService = dataDragonService else {
                throw NSError(
                    domain: "CacheManagementView", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Services not available"])
            }

            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            try await dataManager.clearChampionData()

            await MainActor.run {
                self.clearMessage = "Champion data cleared successfully"
                self.alertMessage =
                    "Champion data has been cleared. Champions will be reloaded on next launch."
                self.showAlert = true
                self.isClearing = false
            }
        } catch {
            await MainActor.run {
                self.clearMessage = "Error clearing champion data: \(error.localizedDescription)"
                self.isClearing = false
            }
        }
    }

    private func clearBaselineData() async {
        isClearing = true
        clearMessage = "Clearing baseline data..."

        do {
            guard let riotClient = riotClient, let dataDragonService = dataDragonService else {
                throw NSError(
                    domain: "CacheManagementView", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Services not available"])
            }

            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            try await dataManager.clearBaselineData()

            await MainActor.run {
                self.clearMessage = "Baseline data cleared successfully"
                self.alertMessage =
                    "Baseline data has been cleared. Baselines will be reloaded on next launch."
                self.showAlert = true
                self.isClearing = false
            }
        } catch {
            await MainActor.run {
                self.clearMessage = "Error clearing baseline data: \(error.localizedDescription)"
                self.isClearing = false
            }
        }
    }

    private func clearURLCache() {
        guard let riotClient = riotClient, let dataDragonService = dataDragonService else {
            clearMessage = "Services not available"
            return
        }

        let dataManager = DataManager(
            modelContext: modelContext,
            riotClient: riotClient,
            dataDragonService: dataDragonService
        )

        dataManager.clearURLCache()

        clearMessage = "URL cache cleared successfully"
        alertMessage = "Network cache has been cleared. Fresh data will be fetched from Riot API."
        showAlert = true
    }
}

// MARK: - Cache Option Card

struct CacheOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () async -> Void

    @State private var isExecuting = false

    var body: some View {
        Button(action: {
            Task {
                isExecuting = true
                await action()
                isExecuting = false
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.small)

                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Loading indicator or chevron
                if isExecuting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isExecuting)
    }
}

// MARK: - Preview

#Preview {
    CacheManagementView()
        .modelContainer(for: [
            Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self,
        ])
}
