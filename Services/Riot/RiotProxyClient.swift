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
        // TODO: Remove this workaround once edge function supports /riot/account endpoint
        // For now, we'll use a mock PUUID for testing
        ClaimbLogger.warning(
            "Using mock account response - edge function missing /riot/account endpoint", 
            service: "RiotProxyClient",
            metadata: [
                "gameName": gameName,
                "tagLine": tagLine,
                "region": region
            ])
        
        // Create a mock response for testing
        // In production, this should be replaced with actual API call
        let mockPuuid = "ar2TadQSVp8G1WMy7p5r5vxtF93yop1_fnIivdfa4AikuvSJLCHIKrt1aKf7oa28-KWU1hJ1F_E6rQ"
        
        return RiotAccountResponse(
            puuid: mockPuuid,
            gameName: gameName,
            tagLine: tagLine
        )
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
