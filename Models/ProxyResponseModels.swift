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

// MARK: - Timeline Response Models

/// Response from timeline-lite endpoint
struct TimelineLiteResponse: Codable {
    let matchId: String
    let region: String
    let puuid: String
    let participantId: Int
    let checkpoints: Checkpoints
    let timings: Timings
    let platesPre14: Int
}

/// Timeline checkpoints at specific time intervals
struct Checkpoints: Codable {
    let tenMin: Checkpoint
    let fifteenMin: Checkpoint

    enum CodingKeys: String, CodingKey {
        case tenMin = "10min"
        case fifteenMin = "15min"
    }
}

/// Individual checkpoint with player stats
struct Checkpoint: Codable {
    let cs: Int
    let gold: Int
    let xp: Int
    let kda: String
}

/// Early game timing events
struct Timings: Codable {
    let firstBackMin: Int?
    let firstKillMin: Int?
    let firstDeathMin: Int?
}

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
