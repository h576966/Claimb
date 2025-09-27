//
//  BaselineDataLoader.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation
import SwiftData

/// Handles loading and management of baseline data from JSON files
public class BaselineDataLoader {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Loads baseline data from bundled JSON files
    public func loadBaselineDataInternal() async throws {
        // Check if we already have baseline data
        let existingBaselines = try await getAllBaselines()
        if !existingBaselines.isEmpty {
            return
        }

        // Load baseline data from JSON
        let baselineData = try await loadBaselineJSON()

        for item in baselineData {
            let baseline = Baseline(
                role: item.role,
                classTag: item.class_tag,
                metric: item.metric,
                mean: item.mean,
                median: item.median,
                p40: item.p40,
                p60: item.p60
            )
            try await saveBaseline(baseline)
        }
    }

    /// Saves a baseline to the database
    public func saveBaseline(_ baseline: Baseline) async throws {
        modelContext.insert(baseline)
        try modelContext.save()
    }

    /// Gets a baseline by role, class tag, and metric
    public func getBaseline(role: String, classTag: String, metric: String) async throws
        -> Baseline?
    {
        let descriptor = FetchDescriptor<Baseline>(
            predicate: #Predicate { baseline in
                baseline.role == role && baseline.classTag == classTag && baseline.metric == metric
            }
        )

        return try modelContext.fetch(descriptor).first
    }

    /// Gets all baselines for a specific role and class tag
    public func getBaselines(role: String, classTag: String) async throws -> [Baseline] {
        let descriptor = FetchDescriptor<Baseline>(
            predicate: #Predicate { baseline in
                baseline.role == role && baseline.classTag == classTag
            }
        )

        return try modelContext.fetch(descriptor)
    }

    /// Gets all baselines
    public func getAllBaselines() async throws -> [Baseline] {
        let descriptor = FetchDescriptor<Baseline>()
        return try modelContext.fetch(descriptor)
    }

    /// Clears all baselines (for debugging/testing)
    public func clearBaselines() async throws {
        let descriptor = FetchDescriptor<Baseline>()
        let baselines = try modelContext.fetch(descriptor)

        for baseline in baselines {
            modelContext.delete(baseline)
        }

        try modelContext.save()
    }

    /// Clears only baseline data
    public func clearBaselineData() async throws {
        ClaimbLogger.info("Clearing baseline data...", service: "BaselineDataLoader")

        let baselineDescriptor = FetchDescriptor<Baseline>()
        let allBaselines = try modelContext.fetch(baselineDescriptor)
        for baseline in allBaselines {
            modelContext.delete(baseline)
        }

        try modelContext.save()

        ClaimbLogger.info("Baseline data cleared", service: "BaselineDataLoader")
    }

    // MARK: - Private Methods

    /// Loads baseline data from JSON file
    private func loadBaselineJSON() async throws -> [BaselineData] {
        guard let url = Bundle.main.url(forResource: "baselines_clean", withExtension: "json")
        else {
            throw DataManagerError.missingResource("baselines_clean.json")
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([BaselineData].self, from: data)
    }
}

// MARK: - Supporting Types

/// JSON structure for baseline data
private struct BaselineData: Codable {
    let role: String
    let class_tag: String
    let metric: String
    let mean: Double
    let median: Double
    let p40: Double
    let p60: Double
}
