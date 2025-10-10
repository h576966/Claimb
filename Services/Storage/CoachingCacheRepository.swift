//
//  CoachingCacheRepository.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-10.
//

import Foundation
import SwiftData

/// Manages coaching response caching with generic methods to eliminate duplication
@MainActor
public class CoachingCacheRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Generic Cache Operations

    /// Generic method to cache any Codable coaching response
    private func cacheResponse<T: Codable>(
        _ item: T,
        responseType: String,
        cacheKey: String,
        summonerPuuid: String,
        summonerName: String,
        expirationHours: Int = 24
    ) async throws {
        let jsonData = try JSONEncoder().encode(item)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

        // Remove any existing cache
        await removeExistingCache(cacheId: cacheKey)

        let cache = CoachingResponseCache(
            summonerPuuid: summonerPuuid,
            responseType: responseType,
            matchId: cacheKey.replacingOccurrences(
                of: "\(summonerPuuid)_\(responseType)_", with: ""),
            responseJSON: jsonString,
            expirationHours: expirationHours
        )

        modelContext.insert(cache)
        try modelContext.save()

        ClaimbLogger.debug(
            "Cached \(responseType) response",
            service: "CoachingCacheRepository",
            metadata: [
                "summoner": summonerName,
                "cacheKey": cacheKey,
            ]
        )
    }

    /// Generic method to retrieve cached coaching response
    private func getCachedResponse<T: Codable>(
        cacheId: String,
        responseType: String,
        summonerName: String,
        decoder: (CoachingResponseCache) throws -> T?
    ) async throws -> T? {
        let now = Date()
        let predicate = #Predicate<CoachingResponseCache> { cache in
            cache.id == cacheId && cache.expiresAt > now
        }
        let descriptor = FetchDescriptor<CoachingResponseCache>(predicate: predicate)
        let cached = try modelContext.fetch(descriptor).first

        if let cached = cached {
            ClaimbLogger.debug(
                "Cache hit for \(responseType)",
                service: "CoachingCacheRepository",
                metadata: [
                    "summoner": summonerName,
                    "cacheId": cacheId,
                    "expiresAt": cached.expiresAt.description,
                ]
            )
            return try decoder(cached)
        } else {
            ClaimbLogger.debug(
                "Cache miss for \(responseType)",
                service: "CoachingCacheRepository",
                metadata: [
                    "summoner": summonerName,
                    "cacheId": cacheId,
                ]
            )
            return nil
        }
    }

    /// Removes existing cache entry by ID
    private func removeExistingCache(cacheId: String) async {
        let predicate = #Predicate<CoachingResponseCache> { cache in
            cache.id == cacheId
        }
        let descriptor = FetchDescriptor<CoachingResponseCache>(predicate: predicate)

        do {
            let existingCaches = try modelContext.fetch(descriptor)
            for cache in existingCaches {
                modelContext.delete(cache)
            }
            if !existingCaches.isEmpty {
                try modelContext.save()
                ClaimbLogger.debug(
                    "Removed existing cache",
                    service: "CoachingCacheRepository",
                    metadata: [
                        "cacheId": cacheId,
                        "removedCount": String(existingCaches.count),
                    ]
                )
            }
        } catch {
            ClaimbLogger.warning(
                "Failed to remove existing cache",
                service: "CoachingCacheRepository",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    // MARK: - Public API

    /// Caches a PostGameAnalysis response
    public func cachePostGameAnalysis(
        _ analysis: PostGameAnalysis,
        for summoner: Summoner,
        matchId: String,
        expirationHours: Int = 24
    ) async throws {
        let cacheKey = "\(summoner.puuid)_postGame_\(matchId)"
        try await cacheResponse(
            analysis,
            responseType: "postGame",
            cacheKey: cacheKey,
            summonerPuuid: summoner.puuid,
            summonerName: summoner.gameName,
            expirationHours: expirationHours
        )
    }

    /// Caches a PerformanceSummary response
    public func cachePerformanceSummary(
        _ summary: PerformanceSummary,
        for summoner: Summoner,
        matchCount: Int,
        expirationHours: Int = 24
    ) async throws {
        let cacheKey = "\(summoner.puuid)_performance_\(matchCount)"
        try await cacheResponse(
            summary,
            responseType: "performance",
            cacheKey: cacheKey,
            summonerPuuid: summoner.puuid,
            summonerName: summoner.gameName,
            expirationHours: expirationHours
        )
    }

    /// Retrieves cached PostGameAnalysis for a specific match
    public func getCachedPostGameAnalysis(
        for summoner: Summoner,
        matchId: String
    ) async throws -> PostGameAnalysis? {
        let cacheId = "\(summoner.puuid)_postGame_\(matchId)"
        return try await getCachedResponse(
            cacheId: cacheId,
            responseType: "post-game analysis",
            summonerName: summoner.gameName,
            decoder: { try $0.getPostGameAnalysis() }
        )
    }

    /// Retrieves cached PerformanceSummary
    public func getCachedPerformanceSummary(
        for summoner: Summoner,
        matchCount: Int
    ) async throws -> PerformanceSummary? {
        let cacheId = "\(summoner.puuid)_performance_\(matchCount)"
        return try await getCachedResponse(
            cacheId: cacheId,
            responseType: "performance summary",
            summonerName: summoner.gameName,
            decoder: { try $0.getPerformanceSummary() }
        )
    }

    /// Cleans up expired coaching responses
    public func cleanupExpiredResponses() async throws {
        let now = Date()
        let predicate = #Predicate<CoachingResponseCache> { cache in
            cache.expiresAt < now
        }
        let descriptor = FetchDescriptor<CoachingResponseCache>(predicate: predicate)
        let expired = try modelContext.fetch(descriptor)

        for cache in expired {
            modelContext.delete(cache)
        }

        if !expired.isEmpty {
            try modelContext.save()
            ClaimbLogger.debug(
                "Cleaned up expired coaching responses",
                service: "CoachingCacheRepository",
                metadata: [
                    "expiredCount": String(expired.count)
                ]
            )
        }
    }
}

