//
//  ChampionDataLoader.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation
import SwiftData

/// Handles loading and management of champion data from Data Dragon
public class ChampionDataLoader {
    private let modelContext: ModelContext
    private let dataDragonService: DataDragonServiceProtocol

    public init(modelContext: ModelContext, dataDragonService: DataDragonServiceProtocol) {
        self.modelContext = modelContext
        self.dataDragonService = dataDragonService
    }

    // MARK: - Public Methods

    /// Loads champion data from Data Dragon and stores it locally
    public func loadChampionData() async throws {
        // Check if we already have champion data
        let existingChampions = try await getAllChampions()
        if !existingChampions.isEmpty {
            ClaimbLogger.debug(
                "Champion data already exists, skipping load", service: "ChampionDataLoader")
            return
        }

        ClaimbLogger.info(
            "Loading champion data from Data Dragon...", service: "ChampionDataLoader")
        let version = try await dataDragonService.getLatestVersion()
        let champions = try await dataDragonService.getChampions(version: version)

        ClaimbLogger.info(
            "Loaded \(champions.count) champions for version \(version)",
            service: "ChampionDataLoader",
            metadata: [
                "championCount": String(champions.count),
                "version": version,
            ]
        )

        for (_, championData) in champions {
            let existingChampion = try await getChampion(by: championData.key)

            if existingChampion == nil {
                let champion = try Champion(from: championData, version: version)
                ClaimbLogger.debug(
                    "Creating champion: \(champion.name) (ID: \(champion.id), Key: \(champion.key)) - Icon URL: \(champion.iconURL)",
                    service: "ChampionDataLoader",
                    metadata: [
                        "championName": champion.name,
                        "championId": String(champion.id),
                        "championKey": champion.key,
                        "iconURL": champion.iconURL,
                    ]
                )
                modelContext.insert(champion)
            }
        }

        try modelContext.save()
    }

    /// Gets a champion by key
    public func getChampion(by key: String) async throws -> Champion? {
        let descriptor = FetchDescriptor<Champion>(
            predicate: #Predicate { $0.key == key }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets a champion by ID
    public func getChampion(by id: Int) async throws -> Champion? {
        let descriptor = FetchDescriptor<Champion>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets all champions
    public func getAllChampions() async throws -> [Champion] {
        let descriptor = FetchDescriptor<Champion>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Clears all champion data
    public func clearChampionData() async throws {
        ClaimbLogger.info("Clearing champion data...", service: "ChampionDataLoader")

        let descriptor = FetchDescriptor<Champion>()
        let allChampions = try modelContext.fetch(descriptor)
        for champion in allChampions {
            modelContext.delete(champion)
        }

        try modelContext.save()

        ClaimbLogger.info("Champion data cleared", service: "ChampionDataLoader")
    }
}
