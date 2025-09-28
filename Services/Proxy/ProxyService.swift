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
    private let urlSession: URLSession

    // MARK: - Initialization

    public init() {
        self.baseURL = AppConfig.baseURL
        
        // Create a custom URLSession with optimized configuration for network reliability
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45.0  // 45 seconds timeout (increased for edge function)
        config.timeoutIntervalForResource = 90.0  // 90 seconds total timeout
        config.waitsForConnectivity = true  // Wait for network connectivity
        config.allowsCellularAccess = true
        config.httpMaximumConnectionsPerHost = 6  // Allow multiple connections
        config.urlCache = nil  // Disable caching for API calls
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Enhanced network resilience settings
        config.httpShouldUsePipelining = false  // Disable HTTP pipelining for better reliability
        config.httpShouldSetCookies = false  // Disable cookie handling for API calls
        config.httpCookieAcceptPolicy = .never  // Never accept cookies
        config.httpMaximumConnectionsPerHost = 4  // Reduced for better stability
        config.networkServiceType = .responsiveData  // Optimize for responsive data
        config.allowsConstrainedNetworkAccess = true  // Allow constrained network access
        config.allowsExpensiveNetworkAccess = true  // Allow expensive network access
        
        // QUIC-specific optimizations for simulator
        #if DEBUG
        // In debug mode, add additional network debugging
        config.timeoutIntervalForRequest = 60.0  // Longer timeout for debugging
        config.timeoutIntervalForResource = 120.0  // Extended resource timeout
        #endif
        
        // Create URLSession with custom configuration
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Riot API Methods

    /// Fetches match IDs for a player
    public func riotMatches(
        puuid: String, region: String = "europe", count: Int = 10, start: Int = 0
    ) async throws -> [String] {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/matches"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "puuid", value: puuid),
            .init(name: "region", value: region),
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
            let response = try JSONDecoder().decode(Response.self, from: data)
            ClaimbLogger.info(
                "Proxy: Retrieved match IDs", service: "ProxyService",
                metadata: ["count": String(response.ids.count), "puuid": response.puuid])
            return response.ids
        } catch {
            ClaimbLogger.error(
                "Proxy: Failed to decode match IDs response", service: "ProxyService", error: error)
            throw ProxyError.decodingError(error)
        }
    }

    /// Fetches detailed match data
    public func riotMatchDetails(matchId: String, region: String = "europe") async throws -> Data {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/match"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "matchId", value: matchId),
            .init(name: "region", value: region),
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

    /// Fetches summoner data by PUUID
    public func riotSummoner(puuid: String, region: String = "europe") async throws -> Data {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("riot/summoner"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "puuid", value: puuid),
            .init(name: "region", value: region),
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

    /// Generates AI coaching insights
    public func aiCoach(prompt: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("ai/coach"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        AppConfig.addAuthHeaders(&req)

        let requestBody = ["prompt": prompt]
        req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        ClaimbLogger.apiRequest("Proxy: ai/coach", method: "POST", service: "ProxyService")

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

    // MARK: - Private Methods

    /// Performs a request with exponential backoff retry logic for network failures
    private func performRequestWithRetry(_ request: URLRequest, maxRetries: Int = 3) async throws
        -> (Data, URLResponse)
    {
        var lastError: Error?
        
        // Check network connectivity before making requests
        let isReachable = await isNetworkReachable()
        if !isReachable {
            ClaimbLogger.warning("Network not reachable, waiting for connectivity", service: "ProxyService")
            // Wait for network connectivity
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
        }

        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)

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
                            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let error = errorData["error"] as? String {
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
                            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let error = errorData["error"] as? String {
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
                        let backoffTime = pow(2.0, Double(attempt))  // 1s, 2s, 4s
                        ClaimbLogger.warning(
                            "Network error, retrying in \(backoffTime)s",
                            service: "ProxyService",
                            metadata: [
                                "error": error.localizedDescription,
                                "errorCode": String(error.code.rawValue),
                                "attempt": String(attempt + 1),
                                "maxRetries": String(maxRetries),
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
            let (_, response) = try await urlSession.data(for: URLRequest(url: url))
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return true
        } catch {
            return false
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
