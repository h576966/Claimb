//
//  BaselineTestView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-09.
//

import SwiftData
import SwiftUI

struct BaselineTestView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var baselineCount = 0
    @State private var championMappingCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var testResults: [String] = []

    private let riotClient = RiotHTTPClient(apiKey: "RGAPI-2133e577-bec8-433b-b519-b3ba66331263")
    private let dataDragonService = DataDragonService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Text("Baseline System Test")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Test the baseline data loading and performance analysis")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Status Cards
                        VStack(spacing: 12) {
                            StatusCard(
                                title: "Baselines Loaded",
                                value: "\(baselineCount)",
                                color: .teal
                            )

                            StatusCard(
                                title: "Champion Mappings",
                                value: "\(championMappingCount)",
                                color: .orange
                            )
                        }

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                Task { await loadBaselineData() }
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(
                                                CircularProgressViewStyle(tint: .black)
                                            )
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                    }
                                    Text("Load Baseline Data")
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.teal)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)

                            Button(action: {
                                Task { await testPerformanceAnalysis() }
                            }) {
                                HStack {
                                    Image(systemName: "chart.bar")
                                    Text("Test Performance Analysis")
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading || baselineCount == 0)

                            Button(action: {
                                Task { await clearBaselines() }
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear Baselines")
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)

                            // Cache Management Buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task { await clearAllCache() }
                                }) {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Clear All Cache")
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading)

                                Button(action: {
                                    Task { await clearMatchData() }
                                }) {
                                    HStack {
                                        Image(systemName: "gamecontroller")
                                        Text("Clear Matches")
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading)
                            }
                        }

                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }

                        // Test Results
                        if !testResults.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Results")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                ForEach(testResults, id: \.self) { result in
                                    Text("• \(result)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task { await updateCounts() }
        }
    }

    // MARK: - Methods

    private func loadBaselineData() async {
        isLoading = true
        errorMessage = nil
        testResults = []

        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            try await dataManager.loadBaselineData()

            await MainActor.run {
                self.isLoading = false
                self.testResults.append("✅ Baseline data loaded successfully")
            }

            await updateCounts()

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load baseline data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func testPerformanceAnalysis() async {
        isLoading = true
        errorMessage = nil
        testResults = []

        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            let baselineService = BaselineService(dataManager: dataManager)
            try await baselineService.loadBaselineData()

            // Create a test participant and match
            let testMatch = createTestMatch()
            let testParticipant = createTestParticipant()
            let testChampion = createTestChampion()

            let analysis = try await baselineService.getPerformanceAnalysis(
                for: testParticipant,
                in: testMatch,
                champion: testChampion
            )

            await MainActor.run {
                self.isLoading = false
                self.testResults.append("✅ Performance analysis completed")
                self.testResults.append("Role: \(analysis.role)")
                self.testResults.append("Champion Class: \(analysis.championClass)")
                self.testResults.append(
                    "Overall Score: \(String(format: "%.1f", analysis.overallScore))")
                self.testResults.append("Summary: \(analysis.summary)")
                self.testResults.append("Analyses: \(analysis.analyses.count) KPIs")
            }

        } catch {
            await MainActor.run {
                self.errorMessage =
                    "Failed to test performance analysis: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func clearBaselines() async {
        isLoading = true
        errorMessage = nil
        testResults = []

        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            try await dataManager.clearBaselines()

            await MainActor.run {
                self.isLoading = false
                self.testResults.append("✅ Baselines cleared")
            }

            await updateCounts()

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to clear baselines: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func clearAllCache() async {
        isLoading = true
        errorMessage = nil
        testResults = []

        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            try await dataManager.clearAllCache()

            await MainActor.run {
                self.isLoading = false
                self.testResults.append("✅ All cache cleared")
            }

            await updateCounts()

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to clear all cache: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func clearMatchData() async {
        isLoading = true
        errorMessage = nil
        testResults = []

        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            try await dataManager.clearMatchData()

            await MainActor.run {
                self.isLoading = false
                self.testResults.append("✅ Match data cleared")
            }

            await updateCounts()

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to clear match data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func updateCounts() async {
        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: riotClient,
                dataDragonService: dataDragonService
            )

            let baselines = try await dataManager.getAllBaselines()
            let championMapping = try await dataManager.loadChampionClassMapping()

            await MainActor.run {
                self.baselineCount = baselines.count
                self.championMappingCount = championMapping.count
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update counts: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Test Data Creation

    private func createTestMatch() -> Match {
        return Match(
            matchId: "test-match",
            gameCreation: Int(Date().timeIntervalSince1970 * 1000),
            gameDuration: 1800,  // 30 minutes
            gameMode: "CLASSIC",
            gameType: "MATCHED_GAME",
            gameVersion: "14.17.1",
            queueId: 420,
            mapId: 11,  // Summoner's Rift
            gameStartTimestamp: Int(Date().timeIntervalSince1970 * 1000),
            gameEndTimestamp: Int(Date().timeIntervalSince1970 * 1000) + 1800
        )
    }

    private func createTestParticipant() -> Participant {
        return Participant(
            puuid: "test-puuid",
            championId: 103,  // Ahri
            teamId: 100,
            lane: "MIDDLE",
            role: "MIDDLE",
            kills: 8,
            deaths: 3,
            assists: 12,
            win: true,
            largestMultiKill: 2,
            hadAfkTeammate: 0,
            gameEndedInSurrender: false,
            eligibleForProgression: true,
            totalMinionsKilled: 180,
            neutralMinionsKilled: 20,
            goldEarned: 12000,
            visionScore: 25,
            totalDamageDealt: 25000,
            totalDamageDealtToChampions: 20000,
            totalDamageTaken: 8000,
            dragonTakedowns: 1,
            riftHeraldTakedowns: 0,
            baronTakedowns: 1,
            hordeTakedowns: 0,
            atakhanTakedowns: 0
        )
    }

    private func createTestChampion() -> Champion {
        return Champion(
            id: 103,
            key: "Ahri",
            name: "Ahri",
            title: "the Nine-Tailed Fox",
            version: "14.17.1"
        )
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Spacer()

            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    BaselineTestView()
        .modelContainer(for: [
            Summoner.self, Match.self, Participant.self, Champion.self, Baseline.self,
        ])
}
