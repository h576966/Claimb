//
//  RateLimiter.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation

/// Simplified rate limiter for Riot API - focuses on bulk fetching efficiency
public actor RateLimiter {
    // Simple rate limiting for bulk operations
    private let requestsPerSecond: Int
    private var lastRequestTime: Date = Date.distantPast
    private var backoffUntil: Date?

    public init(requestsPerSecond: Int = 10) {
        self.requestsPerSecond = requestsPerSecond
    }

    /// Wait if necessary to respect rate limits - simplified for bulk operations
    public func waitIfNeeded() async throws {
        let now = Date()

        // Check if we're in backoff period
        if let backoffUntil = backoffUntil, now < backoffUntil {
            let waitTime = backoffUntil.timeIntervalSince(now)
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            return
        }

        // Simple rate limiting: ensure minimum time between requests
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        let minInterval = 1.0 / Double(requestsPerSecond)

        if timeSinceLastRequest < minInterval {
            let waitTime = minInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }

        lastRequestTime = Date()
    }

    /// Handle 429 rate limit response - simplified backoff
    public func handleRateLimit(retryAfter: TimeInterval? = nil) {
        let backoffTime = retryAfter ?? 5.0  // Simple 5-second default
        backoffUntil = Date().addingTimeInterval(backoffTime)
    }
}
