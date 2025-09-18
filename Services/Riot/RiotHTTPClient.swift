//
//  RiotHTTPClient.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation

public class RiotHTTPClient: RiotClient {
    private let apiKey: String
    private let session: URLSession
    private let rateLimiter: RateLimiter
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        self.rateLimiter = RateLimiter(requestsPerSecond: 20, requestsPerTwoMinutes: 100)
        
        // Configure URLSession with URLCache for automatic disk caching
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - RiotClient Implementation
    
    public func getAccountByRiotId(gameName: String, tagLine: String, region: String) async throws -> RiotAccountResponse {
        let url = try buildAccountURL(gameName: gameName, tagLine: tagLine, region: region)
        let data = try await performRequest(url: url)
        return try JSONDecoder().decode(RiotAccountResponse.self, from: data)
    }
    
    public func getSummonerByPuuid(puuid: String, region: String) async throws -> RiotSummonerResponse {
        let url = try buildSummonerURL(puuid: puuid, region: region)
        let data = try await performRequest(url: url)
        return try JSONDecoder().decode(RiotSummonerResponse.self, from: data)
    }
    
    public func getMatchHistory(puuid: String, region: String, count: Int = 40) async throws -> RiotMatchHistoryResponse {
        let url = try buildMatchHistoryURL(puuid: puuid, region: region, count: count)
        let data = try await performRequest(url: url)
        var response = try JSONDecoder().decode(RiotMatchHistoryResponse.self, from: data)
        // Set the puuid since the API only returns an array of match IDs
        response = RiotMatchHistoryResponse(puuid: puuid, history: response.history)
        return response
    }
    
    public func getMatch(matchId: String, region: String) async throws -> Data {
        let url = try buildMatchURL(matchId: matchId, region: region)
        return try await performRequest(url: url)
    }
    
    // MARK: - Private Methods
    
    private func performRequest(url: URL) async throws -> Data {
        try await rateLimiter.waitIfNeeded()
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Riot-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Debug logging for API requests
        ClaimbLogger.debug("Making API request", service: "RiotHTTPClient", metadata: [
            "url": url.absoluteString,
            "apiKey": String(apiKey.prefix(10)) + "...",
            "method": request.httpMethod ?? "GET"
        ])
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw RiotAPIError.unauthorized
                case 404:
                    throw RiotAPIError.notFound
                case 429:
                    // Handle rate limit with exponential backoff
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                    await rateLimiter.handleRateLimit(retryAfter: retryAfter)
                    throw RiotAPIError.rateLimitExceeded
                default:
                    throw RiotAPIError.serverError(httpResponse.statusCode)
                }
            }
            
            return data
            
        } catch {
            // Simple retry: wait 2 seconds and try once more
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw RiotAPIError.unauthorized
                case 404:
                    throw RiotAPIError.notFound
                case 429:
                    // Handle rate limit with exponential backoff
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                    await rateLimiter.handleRateLimit(retryAfter: retryAfter)
                    throw RiotAPIError.rateLimitExceeded
                default:
                    throw RiotAPIError.serverError(httpResponse.statusCode)
                }
            }
            
            return data
        }
    }
    
    // MARK: - URL Building
    
    private func buildAccountURL(gameName: String, tagLine: String, region: String) throws -> URL {
        let encodedGameName = gameName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? gameName
        let encodedTagLine = tagLine.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tagLine
        
        // Account-v1 uses different regional endpoints: europe, americas, asia
        let accountEndpoint = convertToAccountEndpoint(region)
        let urlString = "https://\(accountEndpoint).api.riotgames.com/riot/account/v1/accounts/by-riot-id/\(encodedGameName)/\(encodedTagLine)"
        guard let url = URL(string: urlString) else {
            throw RiotAPIError.invalidURL
        }
        return url
    }
    
    private func buildSummonerURL(puuid: String, region: String) throws -> URL {
        // Convert account region to regional endpoint for summoner-v4
        let regionalEndpoint = convertToRegionalEndpoint(region)
        let urlString = "https://\(regionalEndpoint).api.riotgames.com/lol/summoner/v4/summoners/by-puuid/\(puuid)"
        guard let url = URL(string: urlString) else {
            throw RiotAPIError.invalidURL
        }
        return url
    }
    
    private func buildMatchHistoryURL(puuid: String, region: String, count: Int) throws -> URL {
        // Match-v5 uses the same regional endpoints as Account-v1: europe, americas, asia
        let matchEndpoint = convertToAccountEndpoint(region)
        let urlString = "https://\(matchEndpoint).api.riotgames.com/lol/match/v5/matches/by-puuid/\(puuid)/ids?count=\(count)"
        guard let url = URL(string: urlString) else {
            throw RiotAPIError.invalidURL
        }
        return url
    }
    
    private func buildMatchURL(matchId: String, region: String) throws -> URL {
        // Match-v5 uses the same regional endpoints as Account-v1: europe, americas, asia
        let matchEndpoint = convertToAccountEndpoint(region)
        let urlString = "https://\(matchEndpoint).api.riotgames.com/lol/match/v5/matches/\(matchId)"
        guard let url = URL(string: urlString) else {
            throw RiotAPIError.invalidURL
        }
        return url
    }
    
    // MARK: - Region Conversion
    
    /// Converts account region (e.g., "asia") to regional endpoint (e.g., "kr")
    private func convertToRegionalEndpoint(_ region: String) -> String {
        switch region.lowercased() {
        case "asia":
            return "kr" // Korea is the default for Asia region
        case "euw1":
            return "euw1"
        case "na1":
            return "na1"
        case "eun1":
            return "eun1"
        case "br1":
            return "br1"
        case "jp1":
            return "jp1"
        case "kr":
            return "kr"
        case "la1", "la2":
            return region.lowercased()
        case "oc1":
            return "oc1"
        case "tr1":
            return "tr1"
        case "ru":
            return "ru"
        default:
            ClaimbLogger.warning("Unknown region, using default", service: "RiotAPI", metadata: [
                "region": region,
                "default": "na1"
            ])
            return "na1"
        }
    }
    
    private func convertToAccountEndpoint(_ region: String) -> String {
        switch region.lowercased() {
        case "euw1", "eun1", "tr1", "ru":
            return "europe"
        case "na1", "br1", "la1", "la2", "oc1":
            return "americas"
        case "asia", "kr", "jp1":
            return "asia"
        default:
            ClaimbLogger.warning("Unknown region for account endpoint, using default", service: "RiotAPI", metadata: [
                "region": region,
                "default": "americas"
            ])
            return "americas"
        }
    }
}
