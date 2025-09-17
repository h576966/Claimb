//
//  SummonerService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData

/// Handles summoner-related data operations
@MainActor
public class SummonerService {
    private let modelContext: ModelContext
    private let riotClient: RiotClient

    public init(modelContext: ModelContext, riotClient: RiotClient) {
        self.modelContext = modelContext
        self.riotClient = riotClient
    }

    // MARK: - Summoner Management

    /// Creates or updates a summoner with account data
    public func createOrUpdateSummoner(gameName: String, tagLine: String, region: String)
        async throws -> Summoner
    {
        ClaimbLogger.info(
            "Creating/updating summoner", service: "SummonerService",
            metadata: [
                "gameName": gameName,
                "tagLine": tagLine,
                "region": region,
            ])

        // Get account data from Riot API
        let account = try await riotClient.getAccountByRiotId(
            gameName: gameName, tagLine: tagLine, region: region)

        // Check if summoner already exists
        let existingSummoner = try await getSummoner(by: account.puuid)

        if let existing = existingSummoner {
            ClaimbLogger.debug("Updating existing summoner", service: "SummonerService")
            // Update existing summoner
            existing.gameName = account.gameName
            existing.tagLine = account.tagLine
            existing.region = region
            existing.lastUpdated = Date()
            try modelContext.save()
            return existing
        } else {
            ClaimbLogger.debug("Creating new summoner", service: "SummonerService")
            // Create new summoner
            let summoner = Summoner(
                puuid: account.puuid,
                gameName: account.gameName,
                tagLine: account.tagLine,
                region: region
            )
            modelContext.insert(summoner)
            try modelContext.save()
            return summoner
        }
    }

    /// Gets a summoner by PUUID
    public func getSummoner(by puuid: String) async throws -> Summoner? {
        let descriptor = FetchDescriptor<Summoner>(
            predicate: #Predicate { $0.puuid == puuid }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets all summoners
    public func getAllSummoners() async throws -> [Summoner] {
        let descriptor = FetchDescriptor<Summoner>()
        return try modelContext.fetch(descriptor)
    }
}
