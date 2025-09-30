//
//  ProxyService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation
import Observation
import UIKit

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
            
            ClaimbLogger.info("Using simulator-optimized network configuration", service: "ProxyService", metadata: [
                "timeout": "60s",
                "connections": "2"
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
        comps.queryItems = [
            .init(name: "puuid", value: puuid),
            .init(name: "region", value: regionCode),
            .init(name: "count", value: String(count)),
            .init(name: "start", value: String(start)),
        ]

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
        return data
    }

    // MARK: - OpenAI API Methods

    /// Generates AI coaching insights with enhanced parameters
    public func aiCoach(
        prompt: String,
        model: String = "gpt-5-mini",
        maxOutputTokens: Int = 1000
    ) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("ai/coach"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        AppConfig.addAuthHeaders(&req)

        let requestBody: [String: Any] = [
            "prompt": prompt,
            "model": model,
            "max_output_tokens": maxOutputTokens,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        ClaimbLogger.apiRequest("Proxy: ai/coach", method: "POST", service: "ProxyService")

        // Log request details for debugging
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
            throw ProxyError.httpError(httpResponse.statusCode)
        }

        struct Response: Decodable {
            let text: String
            let model: String
        }

        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            ClaimbLogger.info(
                "Proxy: Retrieved AI coaching response", service: "ProxyService",
                metadata: ["responseLength": String(response.text.count), "model": response.model])
            return response.text
        } catch {
            ClaimbLogger.error(
                "Proxy: Failed to decode AI coaching response", service: "ProxyService",
                error: error)
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

