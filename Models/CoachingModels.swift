//
//  CoachingModels.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-09.
//

import Foundation

// MARK: - Response Models

/// Post-game analysis response focused on champion-specific advice
public struct PostGameAnalysis: Codable {
    public let keyTakeaways: [String]
    public let championSpecificAdvice: String
    public let nextGameFocus: [String]

    public init(
        keyTakeaways: [String],
        championSpecificAdvice: String,
        nextGameFocus: [String]
    ) {
        self.keyTakeaways = keyTakeaways
        self.championSpecificAdvice = championSpecificAdvice
        self.nextGameFocus = nextGameFocus
    }
}

/// Performance summary response focused on role-based trends
public struct PerformanceSummary: Codable {
    public let keyTrends: [String]  // Specific metrics improving/declining with numbers
    public let roleConsistency: String  // Feedback on role focus
    public let championPoolAnalysis: String  // Feedback on champion selection
    public let areasOfImprovement: [String]  // What to work on
    public let strengthsToMaintain: [String]  // What's working well
    public let climbingAdvice: String  // Actionable advice to improve rank

    public init(
        keyTrends: [String],
        roleConsistency: String,
        championPoolAnalysis: String,
        areasOfImprovement: [String],
        strengthsToMaintain: [String],
        climbingAdvice: String
    ) {
        self.keyTrends = keyTrends
        self.roleConsistency = roleConsistency
        self.championPoolAnalysis = championPoolAnalysis
        self.areasOfImprovement = areasOfImprovement
        self.strengthsToMaintain = strengthsToMaintain
        self.climbingAdvice = climbingAdvice
    }
}
