//
//  SummonerRepository.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-10.
//

import Foundation
import SwiftData

/// Manages summoner data operations including creation, updates, and rank management
@MainActor
public class SummonerRepository {
    private let modelContext: ModelContext
    private let riotClient: RiotClient

    public init(modelContext: ModelContext, riotClient: RiotClient) {
        self.modelContext = modelContext
        self.riotClient = riotClient
    }

    // MARK: - CRUD Operations

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

    // MARK: - Create/Update Operations

    /// Creates or updates a summoner with account data and rank information
    public func createOrUpdate(
        gameName: String,
        tagLine: String,
        region: String
    ) async throws -> Summoner {
        ClaimbLogger.info(
            "Creating/updating summoner",
            service: "SummonerRepository",
            metadata: [
                "gameName": gameName,
                "tagLine": tagLine,
                "region": region,
            ])

        // Get account data from Riot API
        let accountResponse = try await riotClient.getAccountByRiotId(
            gameName: gameName,
            tagLine: tagLine,
            region: region
        )

        // Check if summoner already exists
        let existingSummoner = try await getSummoner(by: accountResponse.puuid)

        if let existing = existingSummoner {
            // Update existing summoner
            try await updateExistingSummoner(
                existing,
                gameName: gameName,
                tagLine: tagLine,
                region: region,
                accountResponse: accountResponse
            )
            return existing
        } else {
            // Create new summoner
            return try await createNewSummoner(
                gameName: gameName,
                tagLine: tagLine,
                region: region,
                accountResponse: accountResponse
            )
        }
    }

    /// Updates an existing summoner with fresh data
    private func updateExistingSummoner(
        _ existing: Summoner,
        gameName: String,
        tagLine: String,
        region: String,
        accountResponse: RiotAccountResponse
    ) async throws {
        ClaimbLogger.debug("Updating existing summoner", service: "SummonerRepository")

        existing.gameName = gameName
        existing.tagLine = tagLine
        existing.region = region
        existing.lastUpdated = Date()

        // Get updated summoner data
        let summonerResponse = try await riotClient.getSummonerByPuuid(
            puuid: accountResponse.puuid,
            region: region
        )

        ClaimbLogger.debug(
            "Received summoner response",
            service: "SummonerRepository",
            metadata: [
                "summoner": existing.gameName,
                "summonerId": summonerResponse.id,
                "summonerLevel": String(summonerResponse.summonerLevel),
            ])

        existing.summonerId = summonerResponse.id
        existing.accountId = summonerResponse.accountId
        existing.profileIconId = summonerResponse.profileIconId
        existing.summonerLevel = summonerResponse.summonerLevel

        // Fetch rank data
        try await updateRanks(existing, region: region)

        try modelContext.save()
    }

    /// Creates a new summoner with fresh data
    private func createNewSummoner(
        gameName: String,
        tagLine: String,
        region: String,
        accountResponse: RiotAccountResponse
    ) async throws -> Summoner {
        ClaimbLogger.debug("Creating new summoner", service: "SummonerRepository")

        let newSummoner = Summoner(
            puuid: accountResponse.puuid,
            gameName: gameName,
            tagLine: tagLine,
            region: region
        )

        // Get summoner data
        let summonerResponse = try await riotClient.getSummonerByPuuid(
            puuid: accountResponse.puuid,
            region: region
        )

        ClaimbLogger.debug(
            "Received summoner response",
            service: "SummonerRepository",
            metadata: [
                "summoner": newSummoner.gameName,
                "summonerId": summonerResponse.id,
                "summonerLevel": String(summonerResponse.summonerLevel),
            ])

        newSummoner.summonerId = summonerResponse.id
        newSummoner.accountId = summonerResponse.accountId
        newSummoner.profileIconId = summonerResponse.profileIconId
        newSummoner.summonerLevel = summonerResponse.summonerLevel

        // Fetch rank data
        try await updateRanks(newSummoner, region: region)

        modelContext.insert(newSummoner)
        try modelContext.save()
        return newSummoner
    }

    // MARK: - Rank Management

    /// Updates summoner rank data from league entries
    public func updateRanks(_ summoner: Summoner, region: String) async throws {
        do {
            ClaimbLogger.info(
                "Fetching rank data",
                service: "SummonerRepository",
                metadata: [
                    "summoner": summoner.gameName,
                    "puuid": summoner.puuid,
                    "region": region,
                ])

            let leagueResponse = try await riotClient.getLeagueEntriesByPUUID(
                puuid: summoner.puuid,
                region: region
            )

            ClaimbLogger.info(
                "Received league response",
                service: "SummonerRepository",
                metadata: [
                    "summoner": summoner.gameName,
                    "entryCount": String(leagueResponse.entries.count),
                    "entries": leagueResponse.entries.map {
                        "\($0.queueType): \($0.tier) \($0.rank)"
                    }.joined(separator: ", "),
                ])

            // Reset rank data
            summoner.soloDuoRank = nil
            summoner.flexRank = nil
            summoner.soloDuoLP = nil
            summoner.flexLP = nil
            summoner.soloDuoWins = nil
            summoner.soloDuoLosses = nil
            summoner.flexWins = nil
            summoner.flexLosses = nil

            // Process league entries
            for entry in leagueResponse.entries {
                switch entry.queueType {
                case "RANKED_SOLO_5x5":
                    summoner.soloDuoRank = "\(entry.tier) \(entry.rank)"
                    summoner.soloDuoLP = entry.leaguePoints
                    summoner.soloDuoWins = entry.wins
                    summoner.soloDuoLosses = entry.losses
                case "RANKED_FLEX_SR":
                    summoner.flexRank = "\(entry.tier) \(entry.rank)"
                    summoner.flexLP = entry.leaguePoints
                    summoner.flexWins = entry.wins
                    summoner.flexLosses = entry.losses
                default:
                    continue
                }
            }

            ClaimbLogger.info(
                "Updated summoner ranks",
                service: "SummonerRepository",
                metadata: [
                    "summoner": summoner.gameName,
                    "soloDuoRank": summoner.soloDuoRank ?? "Unranked",
                    "flexRank": summoner.flexRank ?? "Unranked",
                ])

        } catch {
            ClaimbLogger.warning(
                "Failed to fetch rank data, continuing without ranks",
                service: "SummonerRepository",
                metadata: [
                    "summoner": summoner.gameName,
                    "error": error.localizedDescription,
                ])
            // Don't throw - ranks are optional
        }
    }
}
