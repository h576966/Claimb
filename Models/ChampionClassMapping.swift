//
//  ChampionClassMapping.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-13.
//

import Foundation
import SwiftData

@Model
public class ChampionClassMapping {
    @Attribute(.unique) public var championId: String
    public var championName: String
    public var primaryClass: String

    public init(championId: String, championName: String, primaryClass: String) {
        self.championId = championId
        self.championName = championName
        self.primaryClass = primaryClass
    }
}

// MARK: - Champion Class Mapping Service

public class ChampionClassMappingService {
    private var mappingCache: [String: String] = [:]
    private var isLoaded = false

    public init() {}

    public func loadChampionClassMapping(modelContext: ModelContext) async {
        guard !isLoaded else { return }

        do {
            // Check if data already exists in SwiftData
            let descriptor = FetchDescriptor<ChampionClassMapping>()
            let existingMappings = try modelContext.fetch(descriptor)

            if !existingMappings.isEmpty {
                // Load from SwiftData
                for mapping in existingMappings {
                    mappingCache[mapping.championId] = mapping.primaryClass
                }
                isLoaded = true
                return
            }

            // Load from JSON file if not in SwiftData
            guard
                let url = Bundle.main.url(
                    forResource: "champion_class_mapping_clean", withExtension: "json")
            else {
                ClaimbLogger.error(
                    "Could not find champion_class_mapping_clean.json",
                    service: "ChampionClassMappingService")
                return
            }

            let data = try Data(contentsOf: url)
            let mappings = try JSONDecoder().decode([ChampionClassMappingData].self, from: data)

            // Save to SwiftData and build cache
            for mappingData in mappings {
                let mapping = ChampionClassMapping(
                    championId: mappingData.champion_id,
                    championName: mappingData.champion_name,
                    primaryClass: mappingData.primary_class
                )
                modelContext.insert(mapping)
                mappingCache[mappingData.champion_id] = mappingData.primary_class
            }

            try modelContext.save()
            isLoaded = true

            ClaimbLogger.info(
                "Loaded champion class mappings", service: "ChampionClassMappingService",
                metadata: [
                    "count": String(mappings.count)
                ])

        } catch {
            ClaimbLogger.error(
                "Failed to load champion class mapping", service: "ChampionClassMappingService",
                error: error)
        }
    }

    public func getClassTag(for championId: String) -> String? {
        return mappingCache[championId]
    }

    public func getClassTag(for champion: Champion) -> String? {
        return getClassTag(for: champion.key)
    }
}

// MARK: - JSON Data Structure

private struct ChampionClassMappingData: Codable {
    let champion_id: String
    let champion_name: String
    let primary_class: String
}
