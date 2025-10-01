//
//  Summoner.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation
import SwiftData

@Model
public class Summoner {
    @Attribute(.unique) public var puuid: String
    public var gameName: String
    public var tagLine: String
    public var region: String
    public var summonerId: String?
    public var accountId: String?
    public var profileIconId: Int?
    public var summonerLevel: Int?
    public var lastUpdated: Date
    
    // Rank information
    public var soloDuoRank: String?  // "GOLD IV"
    public var flexRank: String?     // "SILVER I"
    public var soloDuoLP: Int?       // 75
    public var flexLP: Int?          // 50
    public var soloDuoWins: Int?     // 15
    public var soloDuoLosses: Int?   // 10
    public var flexWins: Int?        // 8
    public var flexLosses: Int?      // 12
    
    // Relationships
    @Relationship(deleteRule: .cascade) public var matches: [Match] = []
    
    public init(puuid: String, gameName: String, tagLine: String, region: String) {
        self.puuid = puuid
        self.gameName = gameName
        self.tagLine = tagLine
        self.region = region
        self.lastUpdated = Date()
    }
    
    // Computed properties
    public var riotId: String {
        return "\(gameName)#\(tagLine)"
    }
    
    public var displayName: String {
        return gameName
    }
    
    // Rank display helpers
    public var soloDuoRankDisplay: String {
        guard let rank = soloDuoRank, let lp = soloDuoLP else { return "Unranked" }
        return "\(rank) \(lp) LP"
    }
    
    public var flexRankDisplay: String {
        guard let rank = flexRank, let lp = flexLP else { return "Unranked" }
        return "\(rank) \(lp) LP"
    }
    
    public var primaryRankDisplay: String {
        // Prefer Solo/Duo rank, fallback to Flex
        if soloDuoRank != nil {
            return soloDuoRankDisplay
        } else if flexRank != nil {
            return flexRankDisplay
        } else {
            return "Unranked"
        }
    }
    
    public var hasAnyRank: Bool {
        return soloDuoRank != nil || flexRank != nil
    }
}
