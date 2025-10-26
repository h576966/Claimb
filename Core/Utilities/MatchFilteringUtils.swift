//
//  MatchFilteringUtils.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Utility functions for match filtering and smart fetching strategies
public struct MatchFilteringUtils {

    // MARK: - Constants

    /// Relevant queue IDs for analysis
    public static let relevantQueueIds = [420, 440, 400]  // Solo/Duo, Flex, Normal Draft

    /// Maximum game age in days
    public static let maxGameAgeInDays = 365

    /// Minimum game duration in seconds
    public static let minGameDurationSeconds = 10 * 60  // 10 minutes

    /// Minimum matches needed before considering fallback to normal games
    public static let minRankedMatchesForFallback = 20

    /// Target total matches to fetch for initial load
    public static let targetInitialMatchCount = 100

    /// Maximum matches to fetch per request (API limit)
    public static let maxMatchesPerRequest = 100

    /// Time window for initial bulk fetch (in days) - try 90 days first, then 180 if needed
    public static let initialFetchTimeWindowDays = 90
    public static let extendedFetchTimeWindowDays = 180

    /// Minimum matches needed for meaningful analysis
    public static let minMatchesForAnalysis = 15

    /// Time window for refresh operations (recent matches)
    public static let refreshTimeWindowDays = 90

    // MARK: - Time Calculations

    /// Calculates start time for 1 year ago (in seconds since epoch)
    /// Edge function expects seconds, not milliseconds
    public static func oneYearAgoTimestamp() -> Int {
        let oneYearAgo =
            Calendar.current.date(byAdding: .day, value: -maxGameAgeInDays, to: Date()) ?? Date()
        return Int(oneYearAgo.timeIntervalSince1970)  // Keep as seconds for edge function
    }

    /// Calculates start time for a specific number of days ago (in seconds since epoch)
    public static func daysAgoTimestamp(days: Int) -> Int {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return Int(date.timeIntervalSince1970)  // Keep as seconds for edge function
    }

    // MARK: - Queue Type Helpers

    /// Gets the display name for a queue ID
    public static func queueDisplayName(_ queueId: Int) -> String {
        switch queueId {
        case 420: return "Ranked Solo/Duo"
        case 440: return "Ranked Flex"
        case 400: return "Normal Draft"
        case 430: return "Normal Blind"
        case 450: return "ARAM"
        case 700: return "Clash"
        case 1700: return "Swiftplay"
        default: return "Unknown Queue"
        }
    }

    /// Checks if a queue ID is relevant for analysis
    public static func isRelevantQueue(_ queueId: Int) -> Bool {
        return relevantQueueIds.contains(queueId)
    }
}

// MARK: - Supporting Types

/// Fetching strategies for match data
public enum FetchStrategy {
    case rankedFirst  // Try ranked games first, fallback to normal if needed
}

/// Result of a smart fetch operation
public struct SmartFetchResult {
    public let matchIds: [String]
    public let strategy: FetchStrategy
    public let totalFetched: Int
    public let relevantCount: Int

    public init(matchIds: [String], strategy: FetchStrategy, totalFetched: Int, relevantCount: Int)
    {
        self.matchIds = matchIds
        self.strategy = strategy
        self.totalFetched = totalFetched
        self.relevantCount = relevantCount
    }
}
