//
//  ProxyService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation
import UIKit

/// Proxy service for secure API calls through Supabase edge function
@MainActor
@Observable
public class ProxyService {
    
    // MARK: - Properties
    
    private let baseURL: URL
    
    // MARK: - Initialization
    
    public init() {
        self.baseURL = AppConfig.baseURL
    }
    
    // MARK: - Riot API Methods
    
    /// Fetches match IDs for a player
    public func riotMatches(puuid: String, region: String = "europe", count: Int = 10, start: Int = 0) async throws -> [String] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("riot/matches"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "puuid", value: puuid),
            .init(name: "region", value: region),
            .init(name: "count", value: String(count)),
            .init(name: "start", value: String(start)),
        ]
        
        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)
        
        ClaimbLogger.apiRequest("Proxy: riot/matches", method: "GET", service: "ProxyService")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }
        
        ClaimbLogger.apiResponse("Proxy: riot/matches", statusCode: httpResponse.statusCode, service: "ProxyService")
        
        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }
        
        struct Response: Decodable { 
            let ids: [String] 
        }
        
        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            ClaimbLogger.info("Proxy: Retrieved match IDs", service: "ProxyService", metadata: ["count": String(response.ids.count)])
            return response.ids
        } catch {
            ClaimbLogger.error("Proxy: Failed to decode match IDs response", service: "ProxyService", error: error)
            throw ProxyError.decodingError(error)
        }
    }
    
    /// Fetches detailed match data
    public func riotMatchDetails(matchId: String, region: String = "europe") async throws -> Data {
        var comps = URLComponents(url: baseURL.appendingPathComponent("riot/match"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "matchId", value: matchId),
            .init(name: "region", value: region),
        ]
        
        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)
        
        ClaimbLogger.apiRequest("Proxy: riot/match", method: "GET", service: "ProxyService")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }
        
        ClaimbLogger.apiResponse("Proxy: riot/match", statusCode: httpResponse.statusCode, service: "ProxyService")
        
        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }
        
        ClaimbLogger.info("Proxy: Retrieved match details", service: "ProxyService", metadata: ["matchId": matchId, "bytes": String(data.count)])
        return data
    }
    
    /// Fetches summoner data by PUUID
    public func riotSummoner(puuid: String, region: String = "europe") async throws -> Data {
        var comps = URLComponents(url: baseURL.appendingPathComponent("riot/summoner"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "puuid", value: puuid),
            .init(name: "region", value: region),
        ]
        
        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)
        
        ClaimbLogger.apiRequest("Proxy: riot/summoner", method: "GET", service: "ProxyService")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }
        
        ClaimbLogger.apiResponse("Proxy: riot/summoner", statusCode: httpResponse.statusCode, service: "ProxyService")
        
        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }
        
        ClaimbLogger.info("Proxy: Retrieved summoner data", service: "ProxyService", metadata: ["puuid": puuid, "bytes": String(data.count)])
        return data
    }
    
    // MARK: - OpenAI API Methods
    
    /// Generates AI coaching insights
    public func aiCoach(prompt: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("ai/coach"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        AppConfig.addAuthHeaders(&req)
        
        let requestBody = ["prompt": prompt]
        req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        ClaimbLogger.apiRequest("Proxy: ai/coach", method: "POST", service: "ProxyService")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }
        
        ClaimbLogger.apiResponse("Proxy: ai/coach", statusCode: httpResponse.statusCode, service: "ProxyService")
        
        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }
        
        struct Response: Decodable { 
            let text: String 
        }
        
        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            ClaimbLogger.info("Proxy: Retrieved AI coaching response", service: "ProxyService", metadata: ["responseLength": String(response.text.count)])
            return response.text
        } catch {
            ClaimbLogger.error("Proxy: Failed to decode AI coaching response", service: "ProxyService", error: error)
            throw ProxyError.decodingError(error)
        }
    }
    
    // MARK: - Private Methods
}

// MARK: - Proxy Errors

public enum ProxyError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from proxy service"
        case .httpError(let code):
            return "HTTP error \(code) from proxy service"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
