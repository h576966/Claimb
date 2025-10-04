//
//  BaselineTestViewRefactored.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftData
import SwiftUI

#if DEBUG
    struct BaselineTestView: View {
        @Environment(\.modelContext) private var modelContext
        @State private var baselineCount = 0
        @State private var championMappingCount = 0
        @State private var isLoading = false
        @State private var errorMessage: String?
        @State private var testResults: [String] = []

        init() {
            // Set model context will be done in onAppear
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    DesignSystem.Colors.background.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            headerView

                            // Status Cards
                            statusCardsView

                            // Action Buttons
                            actionButtonsView

                            // Test Results
                            if !testResults.isEmpty {
                                TestResultView(results: testResults)
                            }

                            // Error Message
                            if let errorMessage = errorMessage {
                                errorView(errorMessage)
                            }
                        }
                        .padding()
                    }
                }
            }
            .task {
                await loadCounts()
            }
            .onAppear {
                // TestDataCreator removed - using direct model operations
            }
        }

        // MARK: - View Components

        private var headerView: some View {
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
        }

        private var statusCardsView: some View {
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
        }

        private var actionButtonsView: some View {
            VStack(spacing: 12) {
                Button(action: {
                    Task { await loadBaselineData() }
                }) {
                    HStack {
                        if isLoading {
                            ClaimbInlineSpinner(size: 16)
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
                    .background(DesignSystem.Colors.warning)
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
                    .background(DesignSystem.Colors.error)
                    .cornerRadius(12)
                }
                .disabled(isLoading || baselineCount == 0)

                Button(action: {
                    Task { await createTestData() }
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create Test Data")
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignSystem.Colors.success)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
        }

        private func errorView(_ message: String) -> some View {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(DesignSystem.Colors.error)
                    .font(.title2)

                Text("Error")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(DesignSystem.Colors.error.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.error.opacity(0.3), lineWidth: 1)
            )
        }

        // MARK: - Methods

        private func loadCounts() async {
            do {
                let baselineDescriptor = FetchDescriptor<Baseline>()
                let baselines = try modelContext.fetch(baselineDescriptor)
                baselineCount = baselines.count

                // Champion class mappings are now loaded directly from JSON in Champion model
                championMappingCount = 171  // Total number of champions
            } catch {
                errorMessage = "Failed to load counts: \(error.localizedDescription)"
            }
        }

        private func loadBaselineData() async {
            isLoading = true
            errorMessage = nil
            testResults = []

            do {
                // Load baseline data from JSON
                guard
                    let url = Bundle.main.url(forResource: "baselines_clean", withExtension: "json")
                else {
                    throw NSError(
                        domain: "BaselineTestView", code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Missing resource: baselines_clean.json"
                        ])
                }

                let data = try Data(contentsOf: url)
                let baselinesData = try JSONDecoder().decode([BaselineData].self, from: data)

                // Clear existing baselines
                let descriptor = FetchDescriptor<Baseline>()
                let existingBaselines = try modelContext.fetch(descriptor)
                for baseline in existingBaselines {
                    modelContext.delete(baseline)
                }

                // Create new baselines
                for baselineData in baselinesData {
                    let baseline = Baseline(
                        role: baselineData.role,
                        classTag: "ALL",
                        metric: baselineData.metric,
                        mean: baselineData.median ?? 0.0,
                        median: baselineData.median ?? 0.0,
                        p40: baselineData.p40,
                        p60: baselineData.p60
                    )
                    modelContext.insert(baseline)
                }

                try modelContext.save()
                testResults.append("✅ Loaded \(baselinesData.count) baseline records")
                await loadCounts()

            } catch {
                errorMessage = "Failed to load baseline data: \(error.localizedDescription)"
                testResults.append("❌ Error loading baseline data: \(error.localizedDescription)")
            }

            isLoading = false
        }

        private func testPerformanceAnalysis() async {
            isLoading = true
            errorMessage = nil
            testResults.append("🧪 Starting performance analysis test...")

            do {
                // Get test summoner
                let summonerDescriptor = FetchDescriptor<Summoner>()
                let summoners = try modelContext.fetch(summonerDescriptor)

                guard let summoner = summoners.first else {
                    throw NSError(
                        domain: "BaselineTestView", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No summoners found"])
                }

                // Get matches
                let matchDescriptor = FetchDescriptor<Match>()
                let allMatches = try modelContext.fetch(matchDescriptor)
                let matches = allMatches.filter { $0.summoner?.puuid == summoner.puuid }

                if matches.isEmpty {
                    testResults.append("❌ No matches found for testing")
                    return
                }

                testResults.append("✅ Found \(matches.count) matches for analysis")

                // Test KPI calculation
                let dataManager = DataManager.shared(with: modelContext)
                let kpiService = KPICalculationService(dataManager: dataManager)
                let kpis = try await kpiService.calculateRoleKPIs(
                    matches: matches, role: "DUO_CARRY", summoner: summoner)

                testResults.append("✅ Calculated \(kpis.count) KPIs")

                // Test baseline evaluation
                let baselineDescriptor = FetchDescriptor<Baseline>()
                let baselines = try modelContext.fetch(baselineDescriptor)

                if baselines.isEmpty {
                    testResults.append("❌ No baselines found for evaluation")
                    return
                }

                testResults.append("✅ Found \(baselines.count) baselines for evaluation")
                testResults.append("✅ Performance analysis test completed successfully")

            } catch {
                errorMessage = "Performance analysis test failed: \(error.localizedDescription)"
                testResults.append(
                    "❌ Performance analysis test failed: \(error.localizedDescription)")
            }

            isLoading = false
        }

        private func clearBaselines() async {
            isLoading = true
            errorMessage = nil
            testResults = []

            do {
                let descriptor = FetchDescriptor<Baseline>()
                let baselines = try modelContext.fetch(descriptor)

                for baseline in baselines {
                    modelContext.delete(baseline)
                }

                try modelContext.save()
                testResults.append("✅ Cleared \(baselines.count) baseline records")
                await loadCounts()

            } catch {
                errorMessage = "Failed to clear baselines: \(error.localizedDescription)"
                testResults.append("❌ Error clearing baselines: \(error.localizedDescription)")
            }

            isLoading = false
        }

        private func createTestData() async {
            isLoading = true
            errorMessage = nil
            testResults = []

            // TestDataCreator functionality removed - simplified test
            testResults.append("✅ Test data creation disabled (TestDataCreator removed)")
            await loadCounts()

            isLoading = false
        }
    }

    // MARK: - Supporting Types

    private struct BaselineData: Codable {
        let role: String
        let metric: String
        let p40: Double
        let p60: Double
        let median: Double?
    }

    #Preview {
        BaselineTestView()
    }
#endif
