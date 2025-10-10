//
//  CoachingModels.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-09.
//

import Foundation

// MARK: - Response Models

/// Structured coaching analysis response
public struct CoachingAnalysis: Codable {
    public let strengths: [String]
    public let improvements: [String]
    public let actionableTips: [String]
    public let championAdvice: String
    public let nextSteps: [String]
    public let overallScore: Int  // 1-10 scale
    public let priorityFocus: String

    public init(
        strengths: [String],
        improvements: [String],
        actionableTips: [String],
        championAdvice: String,
        nextSteps: [String],
        overallScore: Int,
        priorityFocus: String
    ) {
        self.strengths = strengths
        self.improvements = improvements
        self.actionableTips = actionableTips
        self.championAdvice = championAdvice
        self.nextSteps = nextSteps
        self.overallScore = overallScore
        self.priorityFocus = priorityFocus
    }
}

/// Performance comparison against personal baselines
public struct PerformanceComparison: Codable {
    public let csPerMinute: ComparisonResult
    public let deathsPerGame: ComparisonResult
    public let visionScore: ComparisonResult
    public let killParticipation: ComparisonResult

    public init(
        csPerMinute: ComparisonResult,
        deathsPerGame: ComparisonResult,
        visionScore: ComparisonResult,
        killParticipation: ComparisonResult
    ) {
        self.csPerMinute = csPerMinute
        self.deathsPerGame = deathsPerGame
        self.visionScore = visionScore
        self.killParticipation = killParticipation
    }
}

/// Individual metric comparison result
public struct ComparisonResult: Codable {
    public let current: Double
    public let average: Double
    public let trend: String  // "above", "below", "similar"
    public let significance: String  // "high", "medium", "low"

    public init(current: Double, average: Double, trend: String, significance: String) {
        self.current = current
        self.average = average
        self.trend = trend
        self.significance = significance
    }
}

/// Complete coaching response
public struct CoachingResponse: Codable {
    public let analysis: CoachingAnalysis
    public let summary: String

    public init(analysis: CoachingAnalysis, summary: String) {
        self.analysis = analysis
        self.summary = summary
    }
}

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
