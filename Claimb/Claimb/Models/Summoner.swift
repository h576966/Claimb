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
}
