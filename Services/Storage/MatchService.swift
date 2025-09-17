//
//  MatchService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData

/// Errors that can occur in MatchService
public enum MatchServiceError: Error, LocalizedError {
    case invalidMatchData
    case championNotFound(String)
    case participantCreationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidMatchData:
            return "Invalid match data received from API"
        case .championNotFound(let championId):
            return "Champion not found: \(championId)"
        case .participantCreationFailed:
            return "Failed to create participant from match data"
        }
    }
}

/// Handles match-related data operations
@MainActor
public class MatchService {
    private let modelContext: ModelContext
    private let riotClient: RiotClient
    private let dataDragonService: DataDragonServiceProtocol

    // Cache limits
    private let maxMatchesPerSummoner = 50

    public init(
        modelContext: ModelContext,
        riotClient: RiotClient,
        dataDragonService: DataDragonServiceProtocol
    ) {
        self.modelContext = modelContext
        self.riotClient = riotClient
        self.dataDragonService = dataDragonService
    }

    // MARK: - Match Management

    /// Refreshes matches for a summoner from the API
    public func refreshMatches(for summoner: Summoner) async throws {
        ClaimbLogger.info(
            "Refreshing matches", service: "MatchService",
            metadata: [
                "summoner": summoner.gameName,
                "region": summoner.region,
            ])

        // Get existing matches to avoid duplicates
        let existingMatches = try await getMatches(for: summoner)
        let existingMatchIds = Set(existingMatches.map { $0.matchId })

        ClaimbLogger.debug(
            "Existing matches: \(existingMatches.count), fetching 20 more",
            service: "MatchService")

        // Fetch new matches from API
        let matchIds = try await riotClient.getMatchHistory(
            puuid: summoner.puuid, region: summoner.region, count: 20)

        // Filter out existing matches
        let newMatchIds = matchIds.history.filter { !existingMatchIds.contains($0) }

        if newMatchIds.isEmpty {
            ClaimbLogger.debug("No new matches to load", service: "MatchService")
            return
        }

        // Load new matches
        for matchId in newMatchIds {
            do {
                let matchData = try await riotClient.getMatch(
                    matchId: matchId, region: summoner.region)

                // Check if match already exists (race condition protection)
                let existingMatch = try await getMatch(by: matchId)
                if existingMatch != nil {
                    ClaimbLogger.cache(
                        "Match already exists, skipping",
                        key: matchId, service: "MatchService")
                    continue
                }

                // Create match and participants
                let match = try await createMatchFromData(matchData, summoner: summoner)
                modelContext.insert(match)

            } catch {
                ClaimbLogger.error(
                    "Failed to load match \(matchId)",
                    service: "MatchService", error: error)
                // Continue with other matches
            }
        }

        try modelContext.save()
        ClaimbLogger.dataOperation(
            "Added new matches", count: newMatchIds.count, service: "MatchService")
    }

    /// Loads initial matches for a summoner
    public func loadInitialMatches(for summoner: Summoner) async throws {
        ClaimbLogger.info(
            "Loading initial matches", service: "MatchService",
            metadata: [
                "summoner": summoner.gameName,
                "region": summoner.region,
            ])

        // Fetch match history
        let matchIds = try await riotClient.getMatchHistory(
            puuid: summoner.puuid, region: summoner.region, count: 40)

        // Load matches in batches to avoid overwhelming the API
        let batchSize = 5
        for i in stride(from: 0, to: matchIds.history.count, by: batchSize) {
            let batch = Array(matchIds.history[i..<min(i + batchSize, matchIds.history.count)])

            for matchId in batch {
                do {
                    let matchData = try await riotClient.getMatch(
                        matchId: matchId, region: summoner.region)

                    // Check if match already exists
                    let existingMatch = try await getMatch(by: matchId)
                    if existingMatch != nil {
                        continue
                    }

                    let match = try await createMatchFromData(matchData, summoner: summoner)
                    modelContext.insert(match)

                } catch {
                    ClaimbLogger.error(
                        "Failed to load match \(matchId)",
                        service: "MatchService", error: error)
                    // Continue with other matches
                }
            }

            // Save batch
            try modelContext.save()
        }

        ClaimbLogger.dataOperation(
            "Loaded initial matches", count: matchIds.history.count, service: "MatchService")
    }

    /// Gets a match by ID
    public func getMatch(by matchId: String) async throws -> Match? {
        let descriptor = FetchDescriptor<Match>(
            predicate: #Predicate { $0.matchId == matchId }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets matches for a summoner
    public func getMatches(for summoner: Summoner, limit: Int = 40) async throws -> [Match] {
        // Use a simpler approach to avoid Predicate issues with optional chaining
        let descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\.gameCreation, order: .reverse)]
        )
        let allMatches = try modelContext.fetch(descriptor)
        let filteredMatches = allMatches.filter { $0.summoner?.puuid == summoner.puuid }
        return Array(filteredMatches.prefix(limit))
    }

    // MARK: - Private Methods

    /// Creates a Match from Riot API data
    private func createMatchFromData(_ matchData: Data, summoner: Summoner) async throws
        -> Match
    {
        // Parse the JSON data to extract match information
        guard let jsonObject = try JSONSerialization.jsonObject(with: matchData) as? [String: Any],
            let metadata = jsonObject["metadata"] as? [String: Any],
            let matchId = metadata["matchId"] as? String,
            let info = jsonObject["info"] as? [String: Any],
            let gameCreation = info["gameCreation"] as? Int,
            let gameDuration = info["gameDuration"] as? Int,
            let gameMode = info["gameMode"] as? String,
            let gameType = info["gameType"] as? String,
            let gameVersion = info["gameVersion"] as? String,
            let mapId = info["mapId"] as? Int,
            let queueId = info["queueId"] as? Int,
            let gameStartTimestamp = info["gameStartTimestamp"] as? Int,
            let gameEndTimestamp = info["gameEndTimestamp"] as? Int
        else {
            throw MatchServiceError.invalidMatchData
        }

        let match = Match(
            matchId: matchId,
            gameCreation: gameCreation,
            gameDuration: gameDuration,
            gameMode: gameMode,
            gameType: gameType,
            gameVersion: gameVersion,
            queueId: queueId,
            mapId: mapId,
            gameStartTimestamp: gameStartTimestamp,
            gameEndTimestamp: gameEndTimestamp
        )

        // Set summoner relationship
        match.summoner = summoner

        // Create participants
        guard let participants = info["participants"] as? [[String: Any]] else {
            throw MatchServiceError.invalidMatchData
        }

        for participantData in participants {
            guard let puuid = participantData["puuid"] as? String,
                let championId = participantData["championId"] as? Int,
                let teamId = participantData["teamId"] as? Int,
                let win = participantData["win"] as? Bool,
                let kills = participantData["kills"] as? Int,
                let deaths = participantData["deaths"] as? Int,
                let assists = participantData["assists"] as? Int
            else {
                continue  // Skip invalid participant data
            }

            // Create participant with all required fields
            let participant = Participant(
                puuid: puuid,
                championId: championId,  // This is already an Int from the guard
                teamId: teamId,
                lane: participantData["lane"] as? String ?? "",
                role: participantData["role"] as? String ?? "",
                kills: kills,
                deaths: deaths,
                assists: assists,
                win: win,
                largestMultiKill: participantData["largestMultiKill"] as? Int ?? 0,
                hadAfkTeammate: participantData["hadAfkTeammate"] as? Int ?? 0,
                gameEndedInSurrender: participantData["gameEndedInSurrender"] as? Bool ?? false,
                eligibleForProgression: participantData["eligibleForProgression"] as? Bool ?? true,
                totalMinionsKilled: participantData["totalMinionsKilled"] as? Int ?? 0,
                neutralMinionsKilled: participantData["neutralMinionsKilled"] as? Int ?? 0,
                goldEarned: participantData["goldEarned"] as? Int ?? 0,
                visionScore: participantData["visionScore"] as? Int ?? 0,
                totalDamageDealt: participantData["totalDamageDealt"] as? Int ?? 0,
                totalDamageDealtToChampions: participantData["totalDamageDealtToChampions"] as? Int
                    ?? 0,
                totalDamageTaken: participantData["totalDamageTaken"] as? Int ?? 0,
                dragonTakedowns: participantData["dragonKills"] as? Int ?? 0,
                riftHeraldTakedowns: participantData["riftHeraldKills"] as? Int ?? 0,
                baronTakedowns: participantData["baronKills"] as? Int ?? 0,
                hordeTakedowns: 0,
                atakhanTakedowns: participantData["atakhanTakedowns"] as? Int ?? 0
            )

            // Load champion data if needed
            if let champion = try await loadChampionForParticipant(participant) {
                participant.champion = champion
            }

            match.participants.append(participant)
        }

        return match
    }

    /// Loads champion data for a participant
    private func loadChampionForParticipant(_ participant: Participant) async throws -> Champion? {
        do {
            // Try to get existing champion by championId
            let championId = participant.championId
            let descriptor = FetchDescriptor<Champion>(
                predicate: #Predicate { $0.id == championId }
            )
            if let existingChampion = try modelContext.fetch(descriptor).first {
                return existingChampion
            }

            // Load champion from Data Dragon using the championId as the key
            let championData = try await dataDragonService.getChampion(
                by: String(participant.championId), version: nil)
            guard let championData = championData else { return nil }

            let champion = Champion(
                id: participant.championId,  // Use the championId as the ID
                key: championData.id,  // Use championData.id as key for images/lookups
                name: championData.name,
                title: championData.title,
                version: "latest"
            )

            modelContext.insert(champion)
            return champion

        } catch {
            ClaimbLogger.error(
                "Error loading champion for participant",
                service: "MatchService", error: error)
            return nil
        }
    }
}
