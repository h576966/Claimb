//
//  ProxyResponseModels.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-10.
//
//  Response models for Supabase edge function proxy endpoints
//  Extracted from ProxyService.swift to reduce file size
//

import Foundation

// MARK: - League Response Models

/// Response from league-entries endpoint
public struct LeagueEntriesResponse: Codable {
    public let entries: [LeagueEntry]
    public let claimbPlatform: String
    public let claimbRegion: String
    public let claimbPUUID: String

    enum CodingKeys: String, CodingKey {
        case entries
        case claimbPlatform = "claimb_platform"
        case claimbRegion = "claimb_region"
        case claimbPUUID = "claimb_puuid"
    }
}

/// Individual league entry (rank information)
public struct LeagueEntry: Codable {
    public let leagueId: String
    public let queueType: String
    public let tier: String
    public let rank: String
    public let puuid: String
    public let leaguePoints: Int
    public let wins: Int
    public let losses: Int
    public let summonerId: String?  // Optional - not returned by edge function
    public let summonerName: String?  // Optional - not returned by edge function
    public let hotStreak: Bool
    public let veteran: Bool
    public let freshBlood: Bool
    public let inactive: Bool
}
