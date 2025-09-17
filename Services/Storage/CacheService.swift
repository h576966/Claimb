//
//  CacheService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftData

/// Handles cache management operations
@MainActor
public class CacheService {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Cache Management

    /// Clears all cached data
    public func clearAllCache() async throws {
        ClaimbLogger.info("Clearing all cache", service: "CacheService")

        try await clearMatchData()
        try await clearChampionData()
        try await clearBaselineData()

        ClaimbLogger.info("All cache cleared", service: "CacheService")
    }

    /// Clears match data
    public func clearMatchData() async throws {
        ClaimbLogger.info("Clearing match data", service: "CacheService")

        // Delete all matches (participants will be deleted due to cascade)
        let matchDescriptor = FetchDescriptor<Match>()
        let matches = try modelContext.fetch(matchDescriptor)

        for match in matches {
            modelContext.delete(match)
        }

        try modelContext.save()
        ClaimbLogger.dataOperation(
            "Cleared match data", count: matches.count, service: "CacheService")
    }

    /// Clears champion data
    public func clearChampionData() async throws {
        ClaimbLogger.info("Clearing champion data", service: "CacheService")

        let championDescriptor = FetchDescriptor<Champion>()
        let champions = try modelContext.fetch(championDescriptor)

        for champion in champions {
            modelContext.delete(champion)
        }

        try modelContext.save()
        ClaimbLogger.dataOperation(
            "Cleared champion data", count: champions.count, service: "CacheService")
    }

    /// Clears baseline data
    public func clearBaselineData() async throws {
        ClaimbLogger.info("Clearing baseline data", service: "CacheService")

        let baselineDescriptor = FetchDescriptor<Baseline>()
        let baselines = try modelContext.fetch(baselineDescriptor)

        for baseline in baselines {
            modelContext.delete(baseline)
        }

        try modelContext.save()
        ClaimbLogger.dataOperation(
            "Cleared baseline data", count: baselines.count, service: "CacheService")
    }
}
