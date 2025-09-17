//
//  Match.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation
import SwiftData

@Model
public class Match {
    @Attribute(.unique) public var matchId: String
    public var gameCreation: Int
    public var gameDuration: Int
    public var gameMode: String
    public var gameType: String
    public var gameVersion: String
    public var queueId: Int
    public var mapId: Int
    public var gameStartTimestamp: Int
    public var gameEndTimestamp: Int
    public var lastUpdated: Date

    // Relationships
    @Relationship(deleteRule: .cascade) public var participants: [Participant] = []
    @Relationship public var summoner: Summoner?

    public init(
        matchId: String, gameCreation: Int, gameDuration: Int, gameMode: String,
        gameType: String, gameVersion: String, queueId: Int, mapId: Int,
        gameStartTimestamp: Int, gameEndTimestamp: Int
    ) {
        self.matchId = matchId
        self.gameCreation = gameCreation
        self.gameDuration = gameDuration
        self.gameMode = gameMode
        self.gameType = gameType
        self.gameVersion = gameVersion
        self.queueId = queueId
        self.mapId = mapId
        self.gameStartTimestamp = gameStartTimestamp
        self.gameEndTimestamp = gameEndTimestamp
        self.lastUpdated = Date()
    }

    // Computed properties
    public var gameDurationMinutes: Double {
        return Double(gameDuration) / 60.0
    }

    public var gameDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(gameCreation / 1000))
    }

    public var isRanked: Bool {
        return queueId == 420 || queueId == 440  // Ranked Solo/Duo or Ranked Flex
    }

    public var queueName: String {
        switch queueId {
        case 420: return "Ranked Solo/Duo"
        case 440: return "Ranked Flex"
        case 400: return "Normal Draft"
        case 450: return "ARAM"
        case 700: return "Clash"
        case 1700: return "Swiftplay"
        default: return "Unknown"
        }
    }

    /// Checks if this match should be included in role statistics analysis
    public var isIncludedInRoleAnalysis: Bool {
        return isStandardRiftGame && isRelevantGameMode
    }

    /// Checks if this is a game on Summoner's Rift
    public var isStandardRiftGame: Bool {
        // Summoner's Rift games have mapId 11, gameMode "CLASSIC", and gameType "MATCHED_GAME"
        // We also exclude ARAM (queueId 450) and Swiftplay (queueId 1700) which are not on Summoner's Rift
        return mapId == 11  // Summoner's Rift
            && gameMode.uppercased() == "CLASSIC" && gameType.uppercased() == "MATCHED_GAME"
            && queueId != 450  // ARAM
            && queueId != 1700  // Swiftplay
    }

    /// Checks if this is a relevant game mode for role analysis
    public var isRelevantGameMode: Bool {
        // Include Ranked Solo/Duo, Ranked Flex, and Normal Draft games
        // Note: Normal Blind (430) has been replaced by Swiftplay (1700) and is excluded
        return queueId == 420  // Ranked Solo/Duo
            || queueId == 440  // Ranked Flex
            || queueId == 400  // Normal Draft
    }

    // Helper method to calculate team objectives
    public func getTeamObjectives(teamId: Int) -> Int {
        let teamParticipants = participants.filter { $0.teamId == teamId }

        let dragonKills = teamParticipants.reduce(0) { $0 + $1.dragonTakedowns }
        let riftHeraldKills = teamParticipants.reduce(0) { $0 + $1.riftHeraldTakedowns }
        let baronKills = teamParticipants.reduce(0) { $0 + $1.baronTakedowns }
        let hordeKills = teamParticipants.reduce(0) { $0 + $1.hordeTakedowns }
        let atakhanKills = teamParticipants.reduce(0) { $0 + $1.atakhanTakedowns }

        return dragonKills + riftHeraldKills + baronKills + hordeKills + atakhanKills
    }
}
