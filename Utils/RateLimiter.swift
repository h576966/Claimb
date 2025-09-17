//
//  RateLimiter.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation

/// Simple rate limiter to ensure we don't exceed Riot API limits
public actor RateLimiter {
    private let delay: TimeInterval
    private var lastRequestTime: Date = Date.distantPast
    
    public init(delay: TimeInterval = 1.2) {
        self.delay = delay
    }
    
    /// Wait if necessary to respect rate limits
    public func waitIfNeeded() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < delay {
            let waitTime = delay - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
}
