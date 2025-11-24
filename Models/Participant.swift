//
//  Participant.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation
import SwiftData

@Model
public class Participant {
    @Attribute(.unique) public var id: String
    public var puuid: String
    public var championId: Int
    public var teamId: Int
    public var lane: String
    public var role: String
    public var teamPosition: String
    public var kills: Int
    public var deaths: Int
    public var assists: Int
    public var win: Bool
    public var largestMultiKill: Int
    public var hadAfkTeammate: Int
    public var gameEndedInSurrender: Bool
    public var eligibleForProgression: Bool

    // Challenge-based metrics (from Riot's challenge system)
    public var killParticipationFromChallenges: Double?
    public var teamDamagePercentageFromChallenges: Double?
    public var damageTakenSharePercentageFromChallenges: Double?

    // Basic stats for calculations
    public var totalMinionsKilled: Int
    public var neutralMinionsKilled: Int
    public var goldEarned: Int
    public var visionScore: Int
    public var totalDamageDealt: Int
    public var totalDamageDealtToChampions: Int
    public var totalDamageTaken: Int

    // Objective takedowns
    public var dragonTakedowns: Int
    public var riftHeraldTakedowns: Int
    public var baronTakedowns: Int
    public var hordeTakedowns: Int
    public var atakhanTakedowns: Int

    // Relationships
    @Relationship public var match: Match?
    @Relationship public var champion: Champion?

    public init(
        puuid: String, championId: Int, teamId: Int, lane: String, role: String,
        teamPosition: String,
        kills: Int, deaths: Int, assists: Int, win: Bool, largestMultiKill: Int,
        hadAfkTeammate: Int, gameEndedInSurrender: Bool, eligibleForProgression: Bool,
        totalMinionsKilled: Int, neutralMinionsKilled: Int, goldEarned: Int,
        visionScore: Int, totalDamageDealt: Int, totalDamageDealtToChampions: Int,
        totalDamageTaken: Int,
        dragonTakedowns: Int, riftHeraldTakedowns: Int, baronTakedowns: Int,
        hordeTakedowns: Int, atakhanTakedowns: Int
    ) {
        self.id = "\(puuid)_\(championId)_\(Date().timeIntervalSince1970)"
        self.puuid = puuid
        self.championId = championId
        self.teamId = teamId
        self.lane = lane
        self.role = role
        self.teamPosition = teamPosition
        self.kills = kills
        self.deaths = deaths
        self.assists = assists
        self.win = win
        self.largestMultiKill = largestMultiKill
        self.hadAfkTeammate = hadAfkTeammate
        self.gameEndedInSurrender = gameEndedInSurrender
        self.eligibleForProgression = eligibleForProgression
        self.totalMinionsKilled = totalMinionsKilled
        self.neutralMinionsKilled = neutralMinionsKilled
        self.goldEarned = goldEarned
        self.visionScore = visionScore
        self.totalDamageDealt = totalDamageDealt
        self.totalDamageDealtToChampions = totalDamageDealtToChampions
        self.totalDamageTaken = totalDamageTaken
        self.dragonTakedowns = dragonTakedowns
        self.riftHeraldTakedowns = riftHeraldTakedowns
        self.baronTakedowns = baronTakedowns
        self.hordeTakedowns = hordeTakedowns
        self.atakhanTakedowns = atakhanTakedowns
    }

    // Computed properties
    public var kda: Double {
        if deaths == 0 {
            return Double(kills + assists)
        }
        let result = Double(kills + assists) / Double(deaths)
        return result.isNaN ? 0.0 : result
    }

    public var csPerMinute: Double {
        guard let match = match else { return 0.0 }
        let totalCS = totalMinionsKilled + neutralMinionsKilled
        let result = Double(totalCS) / match.gameDurationMinutes
        return result.isNaN ? 0.0 : result
    }

    public var goldPerMinute: Double {
        guard let match = match else { return 0.0 }
        let result = Double(goldEarned) / match.gameDurationMinutes
        return result.isNaN ? 0.0 : result
    }

    public var visionScorePerMinute: Double {
        guard let match = match else { return 0.0 }
        let result = Double(visionScore) / match.gameDurationMinutes
        return result.isNaN ? 0.0 : result
    }

    public var objectiveParticipationPercentage: Double {
        let totalParticipated =
            dragonTakedowns + riftHeraldTakedowns + baronTakedowns + hordeTakedowns
            + atakhanTakedowns

        // Get team objectives from match
        guard let match = match else { return 0.0 }
        let teamObjectives = match.getTeamObjectives(teamId: teamId)

        if teamObjectives == 0 {
            return 0.0
        }

        let result = Double(totalParticipated) / Double(teamObjectives)
        return result.isNaN ? 0.0 : result
    }

    // Challenge-based metrics with fallbacks
    public var killParticipation: Double {
        // Use challenge data if available (more accurate)
        if let challengeValue = killParticipationFromChallenges, challengeValue > 0 {
            return challengeValue
        }
        
        // Fallback: calculate from raw stats
        guard let match = match else { return 0.0 }
        let teamKills = match.participants
            .filter { $0.teamId == teamId }
            .reduce(0) { $0 + $1.kills }
        
        guard teamKills > 0 else { return 0.0 }
        let participation = Double(kills + assists) / Double(teamKills)
        return participation.isNaN ? 0.0 : participation
    }

    public var teamDamagePercentage: Double {
        // Use challenge data if available (more accurate)
        if let challengeValue = teamDamagePercentageFromChallenges, challengeValue > 0 {
            return challengeValue
        }
        
        // Fallback: calculate from raw stats
        guard let match = match else { return 0.0 }
        let teamParticipants = match.participants.filter { $0.teamId == teamId }
        let teamTotalDamage = teamParticipants.reduce(0) {
            $0 + $1.totalDamageDealtToChampions
        }
        
        guard teamTotalDamage > 0 else { return 0.0 }
        let damageShare = Double(totalDamageDealtToChampions) / Double(teamTotalDamage)
        return damageShare.isNaN ? 0.0 : damageShare
    }

    public var damageTakenSharePercentage: Double {
        return damageTakenSharePercentageFromChallenges ?? 0.0
    }
}
