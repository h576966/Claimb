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
        let data = try await proxyService.riotAccount(gameName: gameName, tagLine: tagLine, region: region)
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
        let matchIds = try await proxyService.riotMatches(puuid: puuid, region: region, count: count)
        return RiotMatchHistoryResponse(puuid: puuid, history: matchIds)
    }
    
    public func getMatch(matchId: String, region: String) async throws -> Data {
        return try await proxyService.riotMatchDetails(matchId: matchId, region: region)
    }
}
