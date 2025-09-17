//
//  ChampionService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData

/// Handles champion-related data operations
@MainActor
public class ChampionService {
    private let modelContext: ModelContext
    private let dataDragonService: DataDragonServiceProtocol

    public init(modelContext: ModelContext, dataDragonService: DataDragonServiceProtocol) {
        self.modelContext = modelContext
        self.dataDragonService = dataDragonService
    }

    // MARK: - Champion Management

    /// Loads champion data from Data Dragon
    public func loadChampionData() async throws {
        ClaimbLogger.info("Loading champion data", service: "ChampionService")

        // Check if champions already exist
        let existingChampions = try await getAllChampions()
        if !existingChampions.isEmpty {
            ClaimbLogger.debug("Champions already loaded", service: "ChampionService")
            return
        }

        // Get latest version
        let version = try await dataDragonService.getLatestVersion()
        ClaimbLogger.debug("Using Data Dragon version: \(version)", service: "ChampionService")

        // Fetch champions
        let championsData = try await dataDragonService.getChampions(version: version)

        // Create Champion entities
        for (key, championData) in championsData {
            let champion = Champion(
                id: Int(championData.id) ?? 0,  // Convert String to Int
                key: key,
                name: championData.name,
                title: championData.title,
                version: version
            )
            modelContext.insert(champion)
        }

        try modelContext.save()
        ClaimbLogger.dataOperation(
            "Loaded champions", count: championsData.count, service: "ChampionService")
    }

    /// Gets a champion by key
    public func getChampion(by key: String) async throws -> Champion? {
        let descriptor = FetchDescriptor<Champion>(
            predicate: #Predicate { $0.key == key }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets all champions
    public func getAllChampions() async throws -> [Champion] {
        let descriptor = FetchDescriptor<Champion>()
        return try modelContext.fetch(descriptor)
    }
}
