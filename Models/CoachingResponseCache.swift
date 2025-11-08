//
//  CoachingResponseCache.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-29.
//

import Foundation
import SwiftData

/// Caches AI coaching responses with automatic expiration
@Model
public class CoachingResponseCache {
    @Attribute(.unique) public var id: String
    public var summonerPuuid: String
    public var responseType: String  // "postGame", "performance", or "kpiTips"
    public var matchId: String?      // For post-game analysis (nil for performance summary)
    public var responseJSON: String  // Serialized response
    public var createdAt: Date
    public var expiresAt: Date

    public init(
        summonerPuuid: String,
        responseType: String,
        matchId: String? = nil,
        responseJSON: String,
        expirationHours: Int = 24
    ) {
        self.id = "\(summonerPuuid)_\(responseType)_\(matchId ?? "performance")"
        self.summonerPuuid = summonerPuuid
        self.responseType = responseType
        self.matchId = matchId
        self.responseJSON = responseJSON
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expirationHours * 3600))
    }

    /// Check if the cached response is still valid
    public var isValid: Bool {
        return Date() < expiresAt
    }

    /// Deserialize PostGameAnalysis from JSON
    public func getPostGameAnalysis() throws -> PostGameAnalysis? {
        guard responseType == "postGame" else { return nil }
        let data = responseJSON.data(using: .utf8) ?? Data()
        return try JSONDecoder().decode(PostGameAnalysis.self, from: data)
    }

    /// Deserialize PerformanceSummary from JSON
    public func getPerformanceSummary() throws -> PerformanceSummary? {
        guard responseType == "performance" else { return nil }
        let data = responseJSON.data(using: .utf8) ?? Data()
        return try JSONDecoder().decode(PerformanceSummary.self, from: data)
    }

    /// Deserialize KPIImprovementTips from JSON
    public func getKPIImprovementTips() throws -> KPIImprovementTips? {
        guard responseType == "kpiTips" else { return nil }
        let data = responseJSON.data(using: .utf8) ?? Data()
        return try JSONDecoder().decode(KPIImprovementTips.self, from: data)
    }
}
