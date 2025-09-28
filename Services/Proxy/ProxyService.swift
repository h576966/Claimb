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

        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                // Check if it's a network error that we should retry
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        return (data, response)
                    case 500...599:
                        // Server errors - retry with backoff
                        if attempt < maxRetries {
                            let backoffTime = pow(2.0, Double(attempt))  // 1s, 2s, 4s
                            ClaimbLogger.warning(
                                "Server error \(httpResponse.statusCode), retrying in \(backoffTime)s",
                                service: "ProxyService",
                                metadata: [
                                    "attempt": String(attempt + 1),
                                    "maxRetries": String(maxRetries),
                                    "statusCode": String(httpResponse.statusCode),
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
                    .cannotConnectToHost:
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
