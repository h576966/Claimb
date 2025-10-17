//
//  RiotProxyClient.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation

/// Riot API client that uses Proxy service for secure API calls
@MainActor
public class RiotProxyClient: RiotClient {
    private let proxyService: ProxyService

    public init() {
        self.proxyService = ProxyService()
    }

    // MARK: - RiotClient Implementation

    public func getAccountByRiotId(gameName: String, tagLine: String, region: String) async throws
        -> RiotAccountResponse
    {
        let data = try await proxyService.riotAccount(
            gameName: gameName, tagLine: tagLine, region: region)
        return try JSONDecoder().decode(RiotAccountResponse.self, from: data)
    }

    public func getSummonerByPuuid(puuid: String, region: String) async throws
        -> RiotSummonerResponse
    {
        let data = try await proxyService.riotSummoner(puuid: puuid, region: region)
        return try JSONDecoder().decode(RiotSummonerResponse.self, from: data)
    }

    public func getMatchHistory(puuid: String, region: String, count: Int = 40) async throws
        -> RiotMatchHistoryResponse
    {
        let matchIds = try await proxyService.riotMatches(
            puuid: puuid, region: region, count: count)
        return RiotMatchHistoryResponse(puuid: puuid, history: matchIds)
    }

    public func getMatchHistory(
        puuid: String,
        region: String,
        count: Int,
        type: String? = nil,
        queue: Int? = nil,
        startTime: Int? = nil,
        endTime: Int? = nil
    ) async throws -> RiotMatchHistoryResponse {
        let matchIds = try await proxyService.riotMatches(
            puuid: puuid,
            region: region,
            count: count,
            type: type,
            queue: queue,
            startTime: startTime,
            endTime: endTime
        )
        return RiotMatchHistoryResponse(puuid: puuid, history: matchIds)
    }

    public func getMatch(matchId: String, region: String) async throws -> Data {
        return try await proxyService.riotMatchDetails(matchId: matchId, region: region)
    }

    public func getLeagueEntriesByPUUID(puuid: String, region: String) async throws
        -> RiotLeagueEntriesResponse
    {
        let response = try await proxyService.riotLeagueEntriesByPUUID(puuid: puuid, region: region)

        // Convert ProxyService models to RiotClient models
        let riotEntries = response.entries.map { entry in
            RiotLeagueEntry(
                leagueId: entry.leagueId,
                queueType: entry.queueType,
                tier: entry.tier,
                rank: entry.rank,
                puuid: entry.puuid,
                leaguePoints: entry.leaguePoints,
                wins: entry.wins,
                losses: entry.losses,
                summonerId: entry.summonerId,
                summonerName: entry.summonerName,
                hotStreak: entry.hotStreak,
                veteran: entry.veteran,
                freshBlood: entry.freshBlood,
                inactive: entry.inactive
            )
        }

        return RiotLeagueEntriesResponse(
            entries: riotEntries,
            claimbPlatform: response.claimbPlatform,
            claimbRegion: response.claimbRegion,
            claimbPUUID: response.claimbPUUID
        )
    }
}
