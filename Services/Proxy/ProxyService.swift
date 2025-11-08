//
//  ProxyService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation
import Observation
import UIKit

// Note: Response models moved to Models/ProxyResponseModels.swift

/// Proxy service for secure API calls through Supabase edge function
@MainActor
@Observable
public class ProxyService {

    // MARK: - Properties

    private let baseURL: URL
    private let urlSession: URLSession
    private let fallbackUrlSession: URLSession

    // MARK: - Initialization

    public init() {
        self.baseURL = AppConfig.baseURL

        // Create a custom URLSession with optimized configuration for network reliability
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45.0  // 45 seconds timeout (increased for edge function)
        config.timeoutIntervalForResource = 90.0  // 90 seconds total timeout
        config.waitsForConnectivity = true  // Wait for network connectivity
        config.allowsCellularAccess = true
        config.httpMaximumConnectionsPerHost = 4  // Reduced for better stability
        config.urlCache = nil  // Disable caching for API calls
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Enhanced network resilience settings
        config.httpShouldUsePipelining = false  // Disable HTTP pipelining for better reliability
        config.httpShouldSetCookies = false  // Disable cookie handling for API calls
        config.httpCookieAcceptPolicy = .never  // Never accept cookies
        config.networkServiceType = .responsiveData  // Optimize for responsive data
        config.allowsConstrainedNetworkAccess = true  // Allow constrained network access
        config.allowsExpensiveNetworkAccess = true  // Allow expensive network access

        // Simulator-specific network configuration to avoid QUIC issues
        #if targetEnvironment(simulator)
            // Disable HTTP/3 (QUIC) for simulator to avoid connection issues
            // Note: We can't force HTTP/1.1 directly, but we can optimize for stability
            config.timeoutIntervalForRequest = 60.0  // Longer timeout for simulator
            config.timeoutIntervalForResource = 120.0
            config.httpMaximumConnectionsPerHost = 2  // Fewer connections for simulator
            config.multipathServiceType = .none  // Disable multipath TCP

            ClaimbLogger.info(
                "Using simulator-optimized network configuration", service: "ProxyService",
                metadata: [
                    "timeout": "60s",
                    "connections": "2",
                ])
        #else
            // Production configuration with HTTP/2 support
            config.timeoutIntervalForRequest = 45.0
            config.timeoutIntervalForResource = 90.0
            config.httpMaximumConnectionsPerHost = 4
        #endif

        // Additional connection settings for better reliability
        config.httpShouldUsePipelining = false  // Disable pipelining for better reliability
        config.httpCookieAcceptPolicy = .never  // Never accept cookies
        config.httpShouldSetCookies = false  // Disable cookie handling

        // Create URLSession with custom configuration
        self.urlSession = URLSession(configuration: config)

        // Create fallback URLSession with minimal configuration for simulator issues
        let fallbackConfig = URLSessionConfiguration.default
        fallbackConfig.timeoutIntervalForRequest = 20.0
        fallbackConfig.timeoutIntervalForResource = 40.0
        fallbackConfig.httpMaximumConnectionsPerHost = 1
        fallbackConfig.urlCache = nil
        fallbackConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        fallbackConfig.httpShouldUsePipelining = false
        fallbackConfig.httpShouldSetCookies = false
        fallbackConfig.httpCookieAcceptPolicy = .never

        #if targetEnvironment(simulator)
            // Use minimal configuration for fallback in simulator
            fallbackConfig.multipathServiceType = .none
        #endif

        self.fallbackUrlSession = URLSession(configuration: fallbackConfig)
    }

    // MARK: - Riot API Methods

    /// Fetches match IDs for a player
    public func riotMatches(
        puuid: String, region: String = "europe", count: Int = 10, start: Int = 0
    ) async throws -> [String] {
        return try await riotMatches(
            puuid: puuid, region: region, count: count, start: start,
            type: nil, queue: nil, startTime: nil, endTime: nil
        )
    }

    /// Fetches match IDs for a player with advanced filtering
    public func riotMatches(
        puuid: String,
        region: String = "europe",
        count: Int = 10,
        start: Int = 0,
        type: String? = nil,
        queue: Int? = nil,
        startTime: Int? = nil,
        endTime: Int? = nil
    ) async throws -> [String] {
        // Convert platform code to region code for edge function
        let regionCode = platformToRegion(region)
        ClaimbLogger.debug(
            "Platform to region mapping for matches", service: "ProxyService",
            metadata: [
                "puuid": puuid,
                "platform": region,  // This is actually a platform code (euw1, na1, etc.)
                "regionCode": regionCode,  // Converted to region code (europe, americas)
                "count": String(count),
                "start": String(start),
                "note": "Match-V5 API requires region codes, not platform codes",
            ])

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/matches"), resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = [
            .init(name: "puuid", value: puuid),
            .init(name: "region", value: regionCode),
            .init(name: "count", value: String(count)),
            .init(name: "start", value: String(start)),
        ]

        // Add optional filtering parameters
        if let type = type {
            queryItems.append(.init(name: "type", value: type))
        }
        if let queue = queue {
            queryItems.append(.init(name: "queue", value: String(queue)))
        }
        if let startTime = startTime {
            queryItems.append(.init(name: "startTime", value: String(startTime)))
        }
        if let endTime = endTime {
            queryItems.append(.init(name: "endTime", value: String(endTime)))
        }

        comps.queryItems = queryItems

        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)

        ClaimbLogger.apiRequest("Proxy: riot/matches", method: "GET", service: "ProxyService")

        let (data, resp) = try await performRequestWithRetry(req)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }

        ClaimbLogger.apiResponse(
            "Proxy: riot/matches", statusCode: httpResponse.statusCode, service: "ProxyService")

        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }

        struct Response: Decodable {
            let puuid: String
            let region: String
            let start: Int
            let count: Int
            let ids: [String]
            let history: [String]
        }

        do {
            // Try to decode as simple array first (new format from edge function)
            let matchIds = try JSONDecoder().decode([String].self, from: data)
            ClaimbLogger.info(
                "Proxy: Retrieved match IDs", service: "ProxyService",
                metadata: ["count": String(matchIds.count), "puuid": puuid])
            return matchIds
        } catch {
            // Fallback: try to decode as complex object (old format)
            do {
                let response = try JSONDecoder().decode(Response.self, from: data)
                ClaimbLogger.info(
                    "Proxy: Retrieved match IDs (legacy format)", service: "ProxyService",
                    metadata: ["count": String(response.ids.count), "puuid": response.puuid])
                return response.ids
            } catch {
                ClaimbLogger.error(
                    "Proxy: Failed to decode match IDs response", service: "ProxyService",
                    error: error)
                throw ProxyError.decodingError(error)
            }
        }
    }

    /// Fetches detailed match data
    public func riotMatchDetails(matchId: String, region: String = "europe") async throws -> Data {
        // Convert platform code to region code for edge function
        let regionCode = platformToRegion(region)
        ClaimbLogger.debug(
            "Platform to region mapping for match details", service: "ProxyService",
            metadata: [
                "matchId": matchId,
                "platform": region,  // This is actually a platform code (euw1, na1, etc.)
                "regionCode": regionCode,  // Converted to region code (europe, americas)
                "note": "Match-V5 API requires region codes, not platform codes",
            ])

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/match"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "matchId", value: matchId),
            .init(name: "region", value: regionCode),
        ]

        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)

        ClaimbLogger.apiRequest("Proxy: riot/match", method: "GET", service: "ProxyService")

        let (data, resp) = try await performRequestWithRetry(req)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }

        ClaimbLogger.apiResponse(
            "Proxy: riot/match", statusCode: httpResponse.statusCode, service: "ProxyService")

        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }

        ClaimbLogger.info(
            "Proxy: Retrieved match details", service: "ProxyService",
            metadata: ["matchId": matchId, "bytes": String(data.count)])
        return data
    }

    /// Maps platform codes to region codes for Riot API calls
    private func platformToRegion(_ platform: String) -> String {
        switch platform.lowercased() {
        case "euw1", "eun1": return "europe"
        case "na1": return "americas"
        default: return "europe"  // Default fallback
        }
    }

    /// Fetches account data by Riot ID (gameName + tagLine)
    public func riotAccount(gameName: String, tagLine: String, region: String = "europe")
        async throws -> Data
    {
        // Convert platform code to region code for edge function
        let regionCode = platformToRegion(region)
        ClaimbLogger.debug(
            "Platform to region mapping", service: "ProxyService",
            metadata: [
                "platform": region,
                "regionCode": regionCode,
                "gameName": gameName,
                "tagLine": tagLine,
            ])
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/account"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "gameName", value: gameName),
            .init(name: "tagLine", value: tagLine),
            .init(name: "region", value: regionCode),
        ]

        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)

        ClaimbLogger.apiRequest("Proxy: riot/account", method: "GET", service: "ProxyService")

        let (data, resp) = try await performRequestWithRetry(req)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }

        ClaimbLogger.apiResponse(
            "Proxy: riot/account", statusCode: httpResponse.statusCode, service: "ProxyService")

        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }

        ClaimbLogger.info(
            "Proxy: Retrieved account data", service: "ProxyService",
            metadata: ["gameName": gameName, "tagLine": tagLine, "bytes": String(data.count)])
        return data
    }

    /// Fetches summoner data by PUUID
    public func riotSummoner(puuid: String, region: String = "europe") async throws -> Data {
        ClaimbLogger.debug(
            "Platform parameter mapping for summoner", service: "ProxyService",
            metadata: [
                "puuid": puuid,
                "platform": region,  // This is actually a platform code (euw1, na1, etc.)
                "note": "Summoner-V4 API requires platform parameter, not region",
            ])

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/summoner"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "puuid", value: puuid),
            .init(name: "platform", value: region),  // Summoner-V4 needs platform, not region
        ]

        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)

        ClaimbLogger.apiRequest("Proxy: riot/summoner", method: "GET", service: "ProxyService")

        let (data, resp) = try await performRequestWithRetry(req)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }

        ClaimbLogger.apiResponse(
            "Proxy: riot/summoner", statusCode: httpResponse.statusCode, service: "ProxyService")

        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }

        ClaimbLogger.info(
            "Proxy: Retrieved summoner data", service: "ProxyService",
            metadata: ["puuid": puuid, "bytes": String(data.count)])

        // Debug: Log the actual response content
        if let responseString = String(data: data, encoding: .utf8) {
            ClaimbLogger.debug(
                "Proxy: Summoner response content", service: "ProxyService",
                metadata: [
                    "puuid": puuid,
                    "response": responseString,
                ])
        }

        return data
    }

    /// Fetches league entries (rank data) by summoner ID
    public func riotLeagueEntries(summonerId: String, region: String = "europe") async throws
        -> LeagueEntriesResponse
    {
        ClaimbLogger.debug(
            "Platform parameter mapping for league entries", service: "ProxyService",
            metadata: [
                "summonerId": summonerId,
                "platform": region,  // This is actually a platform code (euw1, na1, etc.)
                "note": "League-V4 API requires platform parameter, not region",
            ])

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/league-entries"),
            resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "summonerId", value: summonerId),
            .init(name: "platform", value: region),  // League-V4 needs platform, not region
        ]

        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)

        ClaimbLogger.apiRequest(
            "Proxy: riot/league-entries", method: "GET", service: "ProxyService")

        let (data, resp) = try await performRequestWithRetry(req)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }

        ClaimbLogger.apiResponse(
            "Proxy: riot/league-entries", statusCode: httpResponse.statusCode,
            service: "ProxyService")

        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }

        do {
            let response = try JSONDecoder().decode(LeagueEntriesResponse.self, from: data)
            ClaimbLogger.info(
                "Proxy: Retrieved league entries", service: "ProxyService",
                metadata: [
                    "summonerId": summonerId,
                    "entryCount": String(response.entries.count),
                    "platform": response.claimbPlatform,
                ])
            return response
        } catch {
            ClaimbLogger.error(
                "Proxy: Failed to decode league entries response", service: "ProxyService",
                error: error)
            throw ProxyError.decodingError(error)
        }
    }

    /// Fetches league entries (rank data) by PUUID
    public func riotLeagueEntriesByPUUID(puuid: String, region: String = "europe") async throws
        -> LeagueEntriesResponse
    {
        ClaimbLogger.debug(
            "Platform parameter mapping for league entries by PUUID", service: "ProxyService",
            metadata: [
                "puuid": puuid,
                "platform": region,  // This is actually a platform code (euw1, na1, etc.)
                "note": "League-V4 API requires platform parameter, not region",
            ])

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/league-entries-by-puuid"),
            resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "puuid", value: puuid),
            .init(name: "platform", value: region),  // League-V4 needs platform, not region
        ]

        var req = URLRequest(url: comps.url!)
        AppConfig.addAuthHeaders(&req)

        ClaimbLogger.apiRequest(
            "Proxy: riot/league-entries-by-puuid", method: "GET", service: "ProxyService")

        let (data, resp) = try await performRequestWithRetry(req)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }

        ClaimbLogger.apiResponse(
            "Proxy: riot/league-entries-by-puuid", statusCode: httpResponse.statusCode,
            service: "ProxyService")

        guard httpResponse.statusCode == 200 else {
            throw ProxyError.httpError(httpResponse.statusCode)
        }

        do {
            // Debug: Log the raw response data
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode as UTF-8"
            ClaimbLogger.debug(
                "Proxy: Raw league entries response", service: "ProxyService",
                metadata: [
                    "puuid": puuid,
                    "dataSize": String(data.count),
                    "response": responseString,
                ])

            // Check if data is empty
            if data.isEmpty {
                ClaimbLogger.warning(
                    "Proxy: Empty response from league entries API", service: "ProxyService",
                    metadata: ["puuid": puuid])
                // Return empty response instead of throwing error
                return LeagueEntriesResponse(
                    entries: [],
                    claimbPlatform: region,
                    claimbRegion: region,
                    claimbPUUID: puuid
                )
            }

            // Try to parse as JSON first to see what we're getting
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                ClaimbLogger.debug(
                    "Proxy: Successfully parsed JSON object", service: "ProxyService",
                    metadata: [
                        "puuid": puuid,
                        "jsonType": String(describing: type(of: jsonObject)),
                        "jsonKeys": jsonObject is [String: Any]
                            ? Array((jsonObject as! [String: Any]).keys).joined(separator: ",") : ""
                            ,
                    ]
                )
            } catch {
                ClaimbLogger.error(
                    "Proxy: Failed to parse as JSON", service: "ProxyService",
                    metadata: [
                        "puuid": puuid,
                        "jsonError": String(describing: error),
                    ]
                )
            }

            let response = try JSONDecoder().decode(LeagueEntriesResponse.self, from: data)
            ClaimbLogger.info(
                "Proxy: Retrieved league entries by PUUID", service: "ProxyService",
                metadata: [
                    "puuid": puuid,
                    "entryCount": String(response.entries.count),
                    "platform": response.claimbPlatform,
                ])
            return response
        } catch let decodingError as DecodingError {
            ClaimbLogger.error(
                "Proxy: Failed to decode league entries by PUUID response", service: "ProxyService",
                error: decodingError)

            // Log specific decoding error details
            switch decodingError {
            case .keyNotFound(let key, let context):
                ClaimbLogger.error(
                    "Proxy: Missing key in league entries response", service: "ProxyService",
                    metadata: [
                        "missingKey": key.stringValue,
                        "codingPath": context.codingPath.map { $0.stringValue }.joined(
                            separator: "."),
                        "debugDescription": context.debugDescription,
                    ])
            case .typeMismatch(let type, let context):
                ClaimbLogger.error(
                    "Proxy: Type mismatch in league entries response", service: "ProxyService",
                    metadata: [
                        "expectedType": String(describing: type),
                        "codingPath": context.codingPath.map { $0.stringValue }.joined(
                            separator: "."),
                        "debugDescription": context.debugDescription,
                    ])
            case .valueNotFound(let type, let context):
                ClaimbLogger.error(
                    "Proxy: Value not found in league entries response", service: "ProxyService",
                    metadata: [
                        "expectedType": String(describing: type),
                        "codingPath": context.codingPath.map { $0.stringValue }.joined(
                            separator: "."),
                        "debugDescription": context.debugDescription,
                    ])
            case .dataCorrupted(let context):
                ClaimbLogger.error(
                    "Proxy: Data corrupted in league entries response", service: "ProxyService",
                    metadata: [
                        "codingPath": context.codingPath.map { $0.stringValue }.joined(
                            separator: "."),
                        "debugDescription": context.debugDescription,
                    ])
            @unknown default:
                ClaimbLogger.error(
                    "Proxy: Unknown decoding error in league entries response",
                    service: "ProxyService",
                    error: decodingError)
            }

            throw ProxyError.decodingError(decodingError)
        } catch {
            ClaimbLogger.error(
                "Proxy: Failed to decode league entries by PUUID response", service: "ProxyService",
                error: error)
            throw ProxyError.decodingError(error)
        }
    }

    // MARK: - OpenAI API Methods

    /// Generates AI coaching insights with enhanced parameters
    public func aiCoach(
        prompt: String,
        model: String = "gpt-4o-mini",
        maxOutputTokens: Int = 1000,
        reasoningEffort: String? = nil,  // "minimal", "medium", or "heavy" for gpt-5 models
        textFormat: String? = "json",  // "json" for structured responses, "text" for plain text, nil to omit
        // Optional match metadata for timeline enhancement
        matchId: String? = nil,
        puuid: String? = nil,
        region: String? = nil
    ) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("ai/coach"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        AppConfig.addAuthHeaders(&req)

        var requestBody: [String: Any] = [
            "prompt": prompt,  // Edge function expects "prompt" and converts to "input" for OpenAI
            "model": model,
            "max_output_tokens": maxOutputTokens,
        ]
        
        // Add text_format if specified
        if let format = textFormat {
            requestBody["text_format"] = format
        }

        // Add reasoning effort for gpt-5 models (edge function accepts both formats)
        if let effort = reasoningEffort, model.contains("gpt-5") {
            requestBody["reasoning_effort"] = effort  // Flat field for edge function
            requestBody["reasoning"] = ["effort": effort]  // Nested format as backup
        }
        
        // Add match metadata for timeline enhancement (if provided)
        if let matchId = matchId {
            requestBody["matchId"] = matchId
        }
        if let puuid = puuid {
            requestBody["puuid"] = puuid
        }
        if let region = region {
            requestBody["region"] = region
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        ClaimbLogger.apiRequest("Proxy: ai/coach", method: "POST", service: "ProxyService")

        // Log request details for debugging
        #if DEBUG
            if let bodyData = req.httpBody,
                let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            {
                let promptText = bodyDict["prompt"] as? String ?? ""
                ClaimbLogger.debug(
                    "AI Coach request body (parsed back)", service: "ProxyService",
                    metadata: [
                        "model": bodyDict["model"] as? String ?? "missing",
                        "max_output_tokens": String(
                            describing: bodyDict["max_output_tokens"] ?? "missing"),
                        "modalities": String(describing: bodyDict["modalities"] ?? "missing"),
                        "reasoning_effort": bodyDict["reasoning_effort"] as? String ?? "missing",
                        "reasoning": String(describing: bodyDict["reasoning"] ?? "missing"),
                        "hasPrompt": String(!promptText.isEmpty),
                        "promptLength": String(promptText.count),
                        "bodyKeys": bodyDict.keys.sorted().joined(separator: ", "),
                    ]
                )
            }
        #endif

        ClaimbLogger.debug(
            "AI Coach request details", service: "ProxyService",
            metadata: [
                "url": req.url?.absoluteString ?? "unknown",
                "method": req.httpMethod ?? "unknown",
                "headers": req.allHTTPHeaderFields?.keys.joined(separator: ", ") ?? "none",
                "body_size": String(req.httpBody?.count ?? 0),
            ]
        )

        let (data, resp) = try await performRequestWithRetry(req)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }

        ClaimbLogger.apiResponse(
            "Proxy: ai/coach", statusCode: httpResponse.statusCode, service: "ProxyService")

        guard httpResponse.statusCode == 200 else {
            // Log the error response body for 400 errors
            if httpResponse.statusCode == 400 {
                if let errorBody = String(data: data, encoding: .utf8) {
                    ClaimbLogger.error(
                        "Proxy: AI coach returned 400 Bad Request",
                        service: "ProxyService",
                        metadata: [
                            "statusCode": "400",
                            "errorBody": errorBody,
                            "requestModel": model,
                            "requestTokens": String(maxOutputTokens),
                            "hasReasoningEffort": reasoningEffort != nil ? "true" : "false",
                        ]
                    )
                }
            }
            throw ProxyError.httpError(httpResponse.statusCode)
        }

        // Support both legacy format and Responses API format
        struct LegacyResponse: Decodable {
            let text: String
            let model: String
        }

        struct ResponsesAPIOutput: Decodable {
            let type: String
            let content: [ResponsesAPIContent]?
            let text: String?  // For reasoning items
        }

        struct ResponsesAPIContent: Decodable {
            let type: String
            let text: String
        }

        struct ResponsesAPIFormat: Decodable {
            let output: [ResponsesAPIOutput]?
            let output_text: String?  // Direct text field for Responses API
            let model: String
        }

        do {
            // First try Responses API format (for gpt-5-mini)
            if let responsesAPI = try? JSONDecoder().decode(ResponsesAPIFormat.self, from: data) {
                // Try direct output_text field first
                if let outputText = responsesAPI.output_text, !outputText.isEmpty {
                    ClaimbLogger.info(
                        "Proxy: Retrieved AI coaching response (Responses API - output_text)",
                        service: "ProxyService",
                        metadata: [
                            "responseLength": String(outputText.count), "model": responsesAPI.model,
                        ])
                    return outputText
                }

                // Fall back to parsing output array
                if let outputs = responsesAPI.output {
                    // Find message items and concatenate their content
                    var fullText = ""
                    for output in outputs {
                        if output.type == "message", let contents = output.content {
                            for content in contents where content.type == "text" {
                                fullText += content.text
                            }
                        }
                    }

                    if !fullText.isEmpty {
                        ClaimbLogger.info(
                            "Proxy: Retrieved AI coaching response (Responses API - output array)",
                            service: "ProxyService",
                            metadata: [
                                "responseLength": String(fullText.count),
                                "model": responsesAPI.model,
                            ])
                        return fullText
                    }
                }

                ClaimbLogger.warning(
                    "Proxy: Responses API format detected but no text found",
                    service: "ProxyService",
                    metadata: ["model": responsesAPI.model])
            }

            // Fall back to legacy format (for gpt-4o-mini)
            let response = try JSONDecoder().decode(LegacyResponse.self, from: data)
            ClaimbLogger.info(
                "Proxy: Retrieved AI coaching response (Legacy format)", service: "ProxyService",
                metadata: ["responseLength": String(response.text.count), "model": response.model])
            return response.text
        } catch {
            // Log the raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                ClaimbLogger.error(
                    "Proxy: Failed to decode AI coaching response", service: "ProxyService",
                    error: error,
                    metadata: ["rawResponse": String(rawResponse.prefix(500))])
            }
            throw ProxyError.decodingError(error)
        }
    }

    // MARK: - Network Diagnostics

    /// Performs network connectivity diagnostics
    public func performNetworkDiagnostics() async -> [String: Any] {
        var results: [String: Any] = [:]

        // Test basic connectivity
        let basicConnectivity = await isNetworkReachable()
        results["basic_connectivity"] = basicConnectivity

        // Test edge function connectivity
        do {
            let testRequest = URLRequest(url: baseURL)
            let (_, response) = try await urlSession.data(for: testRequest)
            if let httpResponse = response as? HTTPURLResponse {
                results["edge_function_primary"] = [
                    "status_code": httpResponse.statusCode,
                    "success": httpResponse.statusCode == 200,
                ]
            }
        } catch {
            results["edge_function_primary"] = [
                "error": error.localizedDescription,
                "success": false,
            ]
        }

        // Test fallback connectivity
        do {
            let testRequest = URLRequest(url: baseURL)
            let (_, response) = try await fallbackUrlSession.data(for: testRequest)
            if let httpResponse = response as? HTTPURLResponse {
                results["edge_function_fallback"] = [
                    "status_code": httpResponse.statusCode,
                    "success": httpResponse.statusCode == 200,
                ]
            }
        } catch {
            results["edge_function_fallback"] = [
                "error": error.localizedDescription,
                "success": false,
            ]
        }

        // Test AI coach endpoint specifically
        do {
            var testRequest = URLRequest(url: baseURL.appendingPathComponent("ai/coach"))
            testRequest.httpMethod = "POST"
            testRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            AppConfig.addAuthHeaders(&testRequest)

            let testBody: [String: Any] = [
                "prompt": "test", "model": "gpt-5-mini", "max_output_tokens": 10,
            ]
            testRequest.httpBody = try JSONSerialization.data(withJSONObject: testBody)

            let (_, response) = try await urlSession.data(for: testRequest)
            if let httpResponse = response as? HTTPURLResponse {
                results["ai_coach_endpoint"] = [
                    "status_code": httpResponse.statusCode,
                    "success": httpResponse.statusCode == 200,
                ]
            }
        } catch {
            results["ai_coach_endpoint"] = [
                "error": error.localizedDescription,
                "success": false,
            ]
        }

        return results
    }

    // MARK: - Private Methods

    /// Performs a request with exponential backoff retry logic for network failures
    private func performRequestWithRetry(_ request: URLRequest, maxRetries: Int = 3) async throws
        -> (Data, URLResponse)
    {
        var lastError: Error?

        // Check network connectivity before making requests
        let isReachable = await isNetworkReachable()
        if !isReachable {
            ClaimbLogger.warning(
                "Network not reachable, waiting for connectivity", service: "ProxyService")
            // Wait for network connectivity
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
        }

        for attempt in 0...maxRetries {
            do {
                // Use fallback URLSession for simulator after first failure
                let sessionToUse = attempt > 0 ? fallbackUrlSession : urlSession
                let (data, response) = try await sessionToUse.data(for: request)

                // Check if it's a network error that we should retry
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        return (data, response)
                    case 500...599:
                        // Server errors - retry with backoff
                        if attempt < maxRetries {
                            let backoffTime = pow(2.0, Double(attempt))  // 1s, 2s, 4s

                            // Try to parse error response from edge function
                            var errorDetails = ""
                            if let errorData = try? JSONSerialization.jsonObject(with: data)
                                as? [String: Any],
                                let error = errorData["error"] as? String
                            {
                                errorDetails = " - Edge function error: \(error)"
                            }

                            ClaimbLogger.warning(
                                "Server error \(httpResponse.statusCode), retrying in \(backoffTime)s\(errorDetails)",
                                service: "ProxyService",
                                metadata: [
                                    "attempt": String(attempt + 1),
                                    "maxRetries": String(maxRetries),
                                    "statusCode": String(httpResponse.statusCode),
                                    "errorDetails": errorDetails,
                                ]
                            )
                            try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                            continue
                        }
                    case 429:
                        // Rate limit - retry with longer backoff
                        if attempt < maxRetries {
                            let backoffTime = pow(3.0, Double(attempt))  // 1s, 3s, 9s
                            ClaimbLogger.warning(
                                "Rate limited, retrying in \(backoffTime)s",
                                service: "ProxyService",
                                metadata: [
                                    "attempt": String(attempt + 1),
                                    "maxRetries": String(maxRetries),
                                ]
                            )
                            try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                            continue
                        }
                    case 502:
                        // Bad Gateway - edge function issue, retry with backoff
                        if attempt < maxRetries {
                            let backoffTime = pow(2.0, Double(attempt))  // 1s, 2s, 4s

                            // Try to parse error response from edge function
                            var errorDetails = ""
                            if let errorData = try? JSONSerialization.jsonObject(with: data)
                                as? [String: Any],
                                let error = errorData["error"] as? String
                            {
                                errorDetails = " - Edge function error: \(error)"
                            }

                            ClaimbLogger.warning(
                                "Bad Gateway (502) - Edge function issue, retrying in \(backoffTime)s\(errorDetails)",
                                service: "ProxyService",
                                metadata: [
                                    "attempt": String(attempt + 1),
                                    "maxRetries": String(maxRetries),
                                    "errorDetails": errorDetails,
                                ]
                            )
                            try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                            continue
                        }
                    case 504:
                        // Gateway Timeout - edge function timeout, retry with backoff
                        if attempt < maxRetries {
                            let backoffTime = pow(3.0, Double(attempt))  // 3s, 9s, 27s
                            ClaimbLogger.warning(
                                "Gateway Timeout (504) - Edge function timeout, retrying in \(backoffTime)s",
                                service: "ProxyService",
                                metadata: [
                                    "attempt": String(attempt + 1),
                                    "maxRetries": String(maxRetries),
                                ]
                            )
                            try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                            continue
                        }
                    default:
                        // Client errors (4xx) - don't retry
                        return (data, response)
                    }
                } else {
                    return (data, response)
                }

            } catch let error as URLError {
                lastError = error

                // Check if it's a network error we should retry
                switch error.code {
                case .networkConnectionLost, .notConnectedToInternet, .timedOut,
                    .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                    .resourceUnavailable, .secureConnectionFailed, .serverCertificateUntrusted:
                    if attempt < maxRetries {
                        // More aggressive retry for connection lost errors
                        let backoffTime =
                            error.code == .networkConnectionLost
                            ? pow(1.5, Double(attempt))
                            :  // 1s, 1.5s, 2.25s for connection lost
                            pow(2.0, Double(attempt))  // 1s, 2s, 4s for other errors

                        ClaimbLogger.warning(
                            "Network error, retrying in \(backoffTime)s",
                            service: "ProxyService",
                            metadata: [
                                "error": error.localizedDescription,
                                "errorCode": String(error.code.rawValue),
                                "attempt": String(attempt + 1),
                                "maxRetries": String(maxRetries),
                                "backoffTime": String(backoffTime),
                                "url": request.url?.absoluteString ?? "unknown",
                                "usingFallback": attempt > 0 ? "true" : "false",
                            ]
                        )
                        try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                        continue
                    }
                default:
                    // Other URL errors - don't retry
                    throw ProxyError.networkError(error)
                }
            } catch {
                // Non-URL errors - don't retry
                throw ProxyError.networkError(error)
            }
        }

        // If we get here, all retries failed
        ClaimbLogger.error(
            "Request failed after \(maxRetries + 1) attempts",
            service: "ProxyService",
            metadata: [
                "maxRetries": String(maxRetries),
                "lastError": lastError?.localizedDescription ?? "Unknown error",
            ]
        )
        throw ProxyError.networkError(
            lastError
                ?? NSError(
                    domain: "ProxyService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Request failed after all retries"]))
    }

    /// Checks if network is reachable by attempting a simple connection
    private func isNetworkReachable() async -> Bool {
        guard let url = URL(string: "https://www.apple.com") else { return false }

        do {
            // Try primary session first
            let (_, response) = try await urlSession.data(for: URLRequest(url: url))
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return true
        } catch {
            // Try fallback session if primary fails
            do {
                let (_, response) = try await fallbackUrlSession.data(for: URLRequest(url: url))
                if let httpResponse = response as? HTTPURLResponse {
                    return httpResponse.statusCode == 200
                }
                return true
            } catch {
                return false
            }
        }
    }
}

// MARK: - Proxy Errors

public enum ProxyError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from proxy service"
        case .httpError(let code):
            return "HTTP error \(code) from proxy service"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
