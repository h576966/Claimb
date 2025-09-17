//
//  RateLimiter.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation

/// Token-bucket rate limiter for Riot API with dual-window support
public actor RateLimiter {
    // Dual-window rate limits (dev key limits)
    private let requestsPerSecond: Int
    private let requestsPerTwoMinutes: Int
    
    // Token buckets
    private var shortTermTokens: Int
    private var longTermTokens: Int
    
    // Last refill times
    private var lastShortTermRefill: Date = Date()
    private var lastLongTermRefill: Date = Date()
    
    // Backoff state
    private var backoffUntil: Date?
    private var consecutiveFailures: Int = 0
    
    public init(requestsPerSecond: Int = 20, requestsPerTwoMinutes: Int = 100) {
        self.requestsPerSecond = requestsPerSecond
        self.requestsPerTwoMinutes = requestsPerTwoMinutes
        self.shortTermTokens = requestsPerSecond
        self.longTermTokens = requestsPerTwoMinutes
    }
    
    /// Wait if necessary to respect rate limits
    public func waitIfNeeded() async throws {
        let now = Date()
        
        // Check if we're in backoff period
        if let backoffUntil = backoffUntil, now < backoffUntil {
            let waitTime = backoffUntil.timeIntervalSince(now)
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            return
        }
        
        // Refill tokens
        refillTokens(now: now)
        
        // Check if we have tokens available
        if shortTermTokens <= 0 || longTermTokens <= 0 {
            let shortTermWait = shortTermTokens <= 0 ? 1.0 : 0
            let longTermWait = longTermTokens <= 0 ? 120.0 : 0
            let waitTime = max(shortTermWait, longTermWait)
            
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            refillTokens(now: Date())
        }
        
        // Consume tokens
        shortTermTokens -= 1
        longTermTokens -= 1
        
        // Reset failure count on successful request
        consecutiveFailures = 0
    }
    
    /// Handle 429 rate limit response with exponential backoff
    public func handleRateLimit(retryAfter: TimeInterval? = nil) {
        consecutiveFailures += 1
        
        // Calculate backoff time with exponential backoff
        let baseBackoff = retryAfter ?? 1.0
        let exponentialBackoff = baseBackoff * pow(2.0, Double(consecutiveFailures - 1))
        let maxBackoff = 60.0 // Cap at 60 seconds
        let backoffTime = min(exponentialBackoff, maxBackoff)
        
        backoffUntil = Date().addingTimeInterval(backoffTime)
    }
    
    private func refillTokens(now: Date) {
        // Refill short-term tokens (per second)
        let shortTermElapsed = now.timeIntervalSince(lastShortTermRefill)
        if shortTermElapsed >= 1.0 {
            let tokensToAdd = Int(shortTermElapsed) * requestsPerSecond
            shortTermTokens = min(requestsPerSecond, shortTermTokens + tokensToAdd)
            lastShortTermRefill = now
        }
        
        // Refill long-term tokens (per 2 minutes)
        let longTermElapsed = now.timeIntervalSince(lastLongTermRefill)
        if longTermElapsed >= 120.0 {
            let tokensToAdd = Int(longTermElapsed / 120.0) * requestsPerTwoMinutes
            longTermTokens = min(requestsPerTwoMinutes, longTermTokens + tokensToAdd)
            lastLongTermRefill = now
        }
    }
}
