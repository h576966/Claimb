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
    public var gameStartTimestamp: Int
    public var gameEndTimestamp: Int
    public var lastUpdated: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) public var participants: [Participant] = []
    @Relationship public var summoner: Summoner?
    
    public init(matchId: String, gameCreation: Int, gameDuration: Int, gameMode: String, 
                gameType: String, gameVersion: String, queueId: Int, 
                gameStartTimestamp: Int, gameEndTimestamp: Int) {
        self.matchId = matchId
        self.gameCreation = gameCreation
        self.gameDuration = gameDuration
        self.gameMode = gameMode
        self.gameType = gameType
        self.gameVersion = gameVersion
        self.queueId = queueId
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
        return queueId == 420 || queueId == 440 // Ranked Solo/Duo or Ranked Flex
    }
    
    public var queueName: String {
        switch queueId {
        case 420: return "Ranked Solo/Duo"
        case 440: return "Ranked Flex"
        case 400: return "Normal Draft"
        default: return "Unknown"
        }
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
