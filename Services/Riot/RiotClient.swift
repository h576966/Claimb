//
//  RiotClient.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation

// MARK: - Data Models for API Responses

public struct RiotAccountResponse: Codable {
    public let puuid: String
    public let gameName: String
    public let tagLine: String

    public init(puuid: String, gameName: String, tagLine: String) {
        self.puuid = puuid
        self.gameName = gameName
        self.tagLine = tagLine
    }
}

public struct RiotSummonerResponse: Codable {
    public let id: String
    public let accountId: String
    public let puuid: String
    public let name: String
    public let profileIconId: Int
    public let revisionDate: Int
    public let summonerLevel: Int

    public init(
        id: String, accountId: String, puuid: String, name: String,
        profileIconId: Int, revisionDate: Int, summonerLevel: Int
    ) {
        self.id = id
        self.accountId = accountId
        self.puuid = puuid
        self.name = name
        self.profileIconId = profileIconId
        self.revisionDate = revisionDate
        self.summonerLevel = summonerLevel
    }

    // Custom decoder to handle missing fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode required fields, use empty string if missing
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.accountId = try container.decodeIfPresent(String.self, forKey: .accountId) ?? ""
        self.puuid = try container.decodeIfPresent(String.self, forKey: .puuid) ?? ""
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.profileIconId = try container.decodeIfPresent(Int.self, forKey: .profileIconId) ?? 0
        self.revisionDate = try container.decodeIfPresent(Int.self, forKey: .revisionDate) ?? 0
        self.summonerLevel = try container.decodeIfPresent(Int.self, forKey: .summonerLevel) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, accountId, puuid, name, profileIconId, revisionDate, summonerLevel
    }
}

public struct RiotMatchHistoryResponse: Codable {
    public let puuid: String
    public let history: [String]

    public init(puuid: String, history: [String]) {
        self.puuid = puuid
        self.history = history
    }

    // Custom decoder to handle array response from API
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let matchIds = try container.decode([String].self)

        // We need to get the puuid from the context, but since we can't access it here,
        // we'll use a placeholder and set it in the HTTP client
        self.puuid = ""
        self.history = matchIds
    }
}

public struct RiotLeagueEntriesResponse: Codable {
    public let entries: [RiotLeagueEntry]
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

public struct RiotLeagueEntry: Codable {
    public let leagueId: String
    public let queueType: String
    public let tier: String
    public let rank: String
    public let puuid: String
    public let leaguePoints: Int
    public let wins: Int
    public let losses: Int
    public let summonerId: String
    public let summonerName: String
    public let hotStreak: Bool
    public let veteran: Bool
    public let freshBlood: Bool
    public let inactive: Bool
}

// MARK: - RiotClient Protocol

public protocol RiotClient {
    /// Get account information by Riot ID
    func getAccountByRiotId(gameName: String, tagLine: String, region: String) async throws
        -> RiotAccountResponse

    /// Get summoner information by PUUID
    func getSummonerByPuuid(puuid: String, region: String) async throws -> RiotSummonerResponse

    /// Get match history for a summoner
    func getMatchHistory(puuid: String, region: String, count: Int) async throws
        -> RiotMatchHistoryResponse

    /// Get match history with advanced filtering options
    func getMatchHistory(
        puuid: String,
        region: String,
        count: Int,
        type: String?,
        queue: Int?,
        startTime: Int?,
        endTime: Int?
    ) async throws -> RiotMatchHistoryResponse

    /// Get detailed match information
    func getMatch(matchId: String, region: String) async throws -> Data

    /// Get league entries (rank data) by summoner ID
    func getLeagueEntries(summonerId: String, region: String) async throws
        -> RiotLeagueEntriesResponse

    /// Get league entries (rank data) by PUUID
    func getLeagueEntriesByPUUID(puuid: String, region: String) async throws
        -> RiotLeagueEntriesResponse
}

// MARK: - Riot API Errors

public enum RiotAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case rateLimitExceeded
    case unauthorized
    case notFound
    case serverError(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .unauthorized:
            return "Unauthorized - check API key"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
