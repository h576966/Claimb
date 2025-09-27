//
//  MatchParser.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation
import SwiftData

/// Handles parsing of match data from Riot API responses
@MainActor
public class MatchParser {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Parses match data from Riot API response
    public func parseMatchData(_ data: Data, matchId: String, summoner: Summoner) async throws
        -> Match
    {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let matchJson = json else {
            throw RiotAPIError.decodingError(
                NSError(
                    domain: "MatchParser", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Invalid JSON structure in match response"
                    ]
                ))
        }

        guard let info = matchJson["info"] as? [String: Any] else {
            throw RiotAPIError.decodingError(
                NSError(
                    domain: "MatchParser", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'info' object in match response"]
                ))
        }

        let gameCreation = info["gameCreation"] as? Int ?? 0
        let gameDuration = info["gameDuration"] as? Int ?? 0
        let gameMode = info["gameMode"] as? String ?? "Unknown"
        let gameType = info["gameType"] as? String ?? "Unknown"
        let gameVersion = info["gameVersion"] as? String ?? "Unknown"
        let queueId = info["queueId"] as? Int ?? 0
        let mapId = info["mapId"] as? Int ?? 0
        let gameStartTimestamp = info["gameStartTimestamp"] as? Int ?? 0
        let gameEndTimestamp = info["gameEndTimestamp"] as? Int ?? 0

        // Filter out irrelevant matches BEFORE creating Match object
        // This prevents storing ARAM, Swiftplay, old games, short games, and other non-relevant game types
        if !isRelevantMatch(
            gameMode: gameMode, gameType: gameType, queueId: queueId, mapId: mapId,
            gameCreation: gameCreation, gameDuration: gameDuration)
        {
            ClaimbLogger.debug(
                "Skipping irrelevant match", service: "MatchParser",
                metadata: [
                    "matchId": matchId,
                    "gameMode": gameMode,
                    "gameType": gameType,
                    "queueId": String(queueId),
                    "mapId": String(mapId),
                    "gameCreation": String(gameCreation),
                ])
            // Throw a specific error that can be caught and handled gracefully
            throw MatchFilterError.irrelevantMatch
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

        match.summoner = summoner

        // Parse participants from the info object
        if let participantsJson = info["participants"] as? [[String: Any]] {
            ClaimbLogger.debug(
                "Found \(participantsJson.count) participants in match \(matchId)",
                service: "MatchParser",
                metadata: [
                    "matchId": matchId,
                    "participantCount": String(participantsJson.count),
                ]
            )
            for participantJson in participantsJson {
                let participant = try await parseParticipant(participantJson, match: match)
                match.participants.append(participant)
            }
            ClaimbLogger.debug(
                "Successfully parsed \(match.participants.count) participants for match \(matchId)",
                service: "MatchParser",
                metadata: [
                    "matchId": matchId,
                    "parsedCount": String(match.participants.count),
                ]
            )
        } else {
            ClaimbLogger.warning(
                "No participants found in match", service: "MatchParser",
                metadata: [
                    "matchId": matchId,
                    "availableKeys": Array(info.keys).joined(separator: ","),
                ])
        }

        return match
    }

    /// Parses a single participant from match data
    public func parseParticipant(_ participantJson: [String: Any], match: Match) async throws
        -> Participant
    {
        let puuid = participantJson["puuid"] as? String ?? ""
        let championId = participantJson["championId"] as? Int ?? 0
        let teamId = participantJson["teamId"] as? Int ?? 0
        let lane = participantJson["lane"] as? String ?? "UNKNOWN"
        let role = participantJson["role"] as? String ?? "UNKNOWN"
        let teamPosition = participantJson["teamPosition"] as? String ?? role

        let kills = participantJson["kills"] as? Int ?? 0
        let deaths = participantJson["deaths"] as? Int ?? 0
        let assists = participantJson["assists"] as? Int ?? 0
        let totalDamageDealtToChampions =
            participantJson["totalDamageDealtToChampions"] as? Int ?? 0
        let totalMinionsKilled = participantJson["totalMinionsKilled"] as? Int ?? 0
        let neutralMinionsKilled = participantJson["neutralMinionsKilled"] as? Int ?? 0
        let goldEarned = participantJson["goldEarned"] as? Int ?? 0
        // Parse unused fields to avoid warnings - these might be used in future versions
        _ = participantJson["champLevel"] as? Int ?? 0
        _ = participantJson["item0"] as? Int ?? 0
        _ = participantJson["item1"] as? Int ?? 0
        _ = participantJson["item2"] as? Int ?? 0
        _ = participantJson["item3"] as? Int ?? 0
        _ = participantJson["item4"] as? Int ?? 0
        _ = participantJson["item5"] as? Int ?? 0
        _ = participantJson["item6"] as? Int ?? 0
        let win = participantJson["win"] as? Bool ?? false
        let visionScore = participantJson["visionScore"] as? Int ?? 0
        _ = participantJson["wardsPlaced"] as? Int ?? 0
        _ = participantJson["wardsKilled"] as? Int ?? 0
        _ = participantJson["firstBloodKill"] as? Bool ?? false
        _ = participantJson["firstTowerKill"] as? Bool ?? false

        // Parse challenges (optional) - these might be used in future versions
        if let challenges = participantJson["challenges"] as? [String: Any] {
            _ = challenges["kda"] as? Double ?? 0.0
            _ = challenges["killParticipation"] as? Double ?? 0.0
            _ = challenges["soloKills"] as? Int ?? 0
            _ = challenges["teamDamagePercentage"] as? Double ?? 0.0
        }

        let participant = Participant(
            puuid: puuid,
            championId: championId,
            teamId: teamId,
            lane: lane,
            role: role,
            teamPosition: teamPosition,
            kills: kills,
            deaths: deaths,
            assists: assists,
            win: win,
            largestMultiKill: 0,  // Not available in simplified version
            hadAfkTeammate: 0,  // Not available in simplified version
            gameEndedInSurrender: false,  // Not available in simplified version
            eligibleForProgression: true,  // Not available in simplified version
            totalMinionsKilled: totalMinionsKilled,
            neutralMinionsKilled: neutralMinionsKilled,
            goldEarned: goldEarned,
            visionScore: visionScore,
            totalDamageDealt: 0,  // Not available in simplified version
            totalDamageDealtToChampions: totalDamageDealtToChampions,
            totalDamageTaken: 0,  // Not available in simplified version
            dragonTakedowns: 0,  // Not available in simplified version
            riftHeraldTakedowns: 0,  // Not available in simplified version
            baronTakedowns: 0,  // Not available in simplified version
            hordeTakedowns: 0,  // Not available in simplified version
            atakhanTakedowns: 0  // Not available in simplified version
        )

        participant.match = match

        // Load champion data for this participant
        await loadChampionForParticipant(participant)

        return participant
    }

    // MARK: - Private Methods

    /// Determines if a match is relevant for analysis
    private func isRelevantMatch(
        gameMode: String, gameType: String, queueId: Int, mapId: Int,
        gameCreation: Int, gameDuration: Int
    ) -> Bool {
        // Filter by game mode - only include Summoner's Rift ranked and normal games
        let relevantGameModes = ["CLASSIC"]
        guard relevantGameModes.contains(gameMode) else {
            return false
        }

        // Filter by map - only Summoner's Rift (mapId 11)
        guard mapId == 11 else {
            return false
        }

        // Filter by queue type - include ranked and normal draft
        let relevantQueueIds = [
            420,  // Ranked Solo/Duo
            440,  // Ranked Flex
            400,  // Normal Draft
            430,  // Normal Blind (optional)
        ]
        guard relevantQueueIds.contains(queueId) else {
            return false
        }

        // Filter by game duration - exclude very short games (likely remakes or surrenders)
        let minGameDurationSeconds = 10 * 60  // 10 minutes
        guard gameDuration >= minGameDurationSeconds else {
            return false
        }

        // Filter by age - exclude games older than maxGameAgeInDays
        let maxGameAgeInDays = 365
        let gameDate = Date(timeIntervalSince1970: TimeInterval(gameCreation / 1000))
        let daysSinceGame =
            Calendar.current.dateComponents([.day], from: gameDate, to: Date()).day ?? 0
        guard daysSinceGame <= maxGameAgeInDays else {
            return false
        }

        return true
    }

    /// Loads champion data for a participant
    private func loadChampionForParticipant(_ participant: Participant) async {
        do {
            // Find champion by ID
            let descriptor = FetchDescriptor<Champion>()
            let allChampions = try modelContext.fetch(descriptor)

            if let champion = allChampions.first(where: { $0.id == participant.championId }) {
                participant.champion = champion
                ClaimbLogger.debug(
                    "Linked participant to champion", service: "MatchParser",
                    metadata: [
                        "championId": String(participant.championId),
                        "championName": champion.name,
                    ]
                )
            } else {
                let availableIds = allChampions.map { "\($0.id)" }.joined(separator: ", ")
                ClaimbLogger.warning(
                    "Champion not found for participant", service: "MatchParser",
                    metadata: [
                        "championId": String(participant.championId),
                        "availableIds": availableIds,
                    ])
                // Don't fail the entire operation - just log and continue
            }

            // Save the context to ensure the relationship is persisted
            try modelContext.save()
        } catch {
            ClaimbLogger.error(
                "Error loading champion for participant", service: "MatchParser", error: error)
            // Don't fail the entire operation - just log and continue
        }
    }
}

// MARK: - Supporting Types

/// Error types for match filtering
public enum MatchFilterError: Error {
    case irrelevantMatch
}
