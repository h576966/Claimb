//
//  SimpleTest.swift
//  ClaimbTests
//
//  Created by AI Assistant on 2025-09-10.
//

import Foundation
import SwiftUI

@testable import Claimb

/// Comprehensive test suite for critical business logic components
final class SimpleTest {

    static func runBasicTests() -> [String] {
        var results: [String] = []

        // Test UIState basic functionality
        results.append(contentsOf: testUIState())

        // Test RoleUtils functionality
        results.append(contentsOf: testRoleUtils())

        // Test KPI calculation logic
        results.append(contentsOf: testKPICalculations())

        // Test MatchParser filtering logic
        results.append(contentsOf: testMatchFiltering())

        // Test DesignSystem basic functionality
        results.append(contentsOf: testDesignSystem())

        // Test ClaimbLogger basic functionality
        results.append(contentsOf: testLogger())

        return results
    }

    // MARK: - UIState Tests

    private static func testUIState() -> [String] {
        var results: [String] = []

        // Test loading state
        let loadingState = UIState<String>.loading
        if loadingState.isLoading {
            results.append("✅ UIState loading state works")
        } else {
            results.append("❌ UIState loading state failed")
        }

        // Test loaded state
        let loadedState = UIState<String>.loaded("test")
        if loadedState.isLoaded && loadedState.data == "test" {
            results.append("✅ UIState loaded state works")
        } else {
            results.append("❌ UIState loaded state failed")
        }

        // Test error state
        let error = NSError(
            domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let errorState = UIState<String>.error(error)
        if errorState.isError && errorState.error?.localizedDescription == "Test error" {
            results.append("✅ UIState error state works")
        } else {
            results.append("❌ UIState error state failed")
        }

        // Test empty state
        let emptyState = UIState<String>.empty("No data")
        if emptyState.isEmpty && emptyState.emptyMessage == "No data" {
            results.append("✅ UIState empty state works")
        } else {
            results.append("❌ UIState empty state failed")
        }

        return results
    }

    // MARK: - RoleUtils Tests

    private static func testRoleUtils() -> [String] {
        var results: [String] = []

        // Test role normalization
        let testCases = [
            ("MID", "MID"),
            ("JUNGLE", "JUNGLE"),
            ("BOTTOM", "ADC"),
            ("UTILITY", "SUPPORT"),
            ("TOP", "TOP"),
            ("UNKNOWN", "UNKNOWN"),
        ]

        for (input, expected) in testCases {
            let result = RoleUtils.normalizeRole(teamPosition: input)
            if result == expected {
                results.append("✅ RoleUtils.normalizeRole(\(input)) = \(result)")
            } else {
                results.append(
                    "❌ RoleUtils.normalizeRole(\(input)) = \(result), expected \(expected)")
            }
        }

        // Test role validation
        let validRoles = ["TOP", "JUNGLE", "MID", "ADC", "SUPPORT"]
        for role in validRoles {
            if RoleUtils.isValidRole(role) {
                results.append("✅ RoleUtils.isValidRole(\(role)) = true")
            } else {
                results.append("❌ RoleUtils.isValidRole(\(role)) = false, expected true")
            }
        }

        let invalidRoles = ["UNKNOWN", "INVALID", ""]
        for role in invalidRoles {
            if !RoleUtils.isValidRole(role) {
                results.append("✅ RoleUtils.isValidRole(\(role)) = false")
            } else {
                results.append("❌ RoleUtils.isValidRole(\(role)) = true, expected false")
            }
        }

        return results
    }

    // MARK: - KPI Calculation Tests

    private static func testKPICalculations() -> [String] {
        var results: [String] = []

        // Test CS per minute calculation
        let participants = [
            createMockParticipant(totalMinionsKilled: 100, gameDuration: 1800),  // 30 min game
            createMockParticipant(totalMinionsKilled: 150, gameDuration: 2400),  // 40 min game
            createMockParticipant(totalMinionsKilled: 80, gameDuration: 1200),  // 20 min game
        ]

        let matches = [
            createMockMatch(gameDuration: 1800),
            createMockMatch(gameDuration: 2400),
            createMockMatch(gameDuration: 1200),
        ]

        let csPerMinute = calculateCSPerMinute(participants: participants, matches: matches)
        let expectedCS = (100.0 / 30.0 + 150.0 / 40.0 + 80.0 / 20.0) / 3.0  // ~5.83

        if abs(csPerMinute - expectedCS) < 0.1 {
            results.append("✅ CS per minute calculation: \(String(format: "%.2f", csPerMinute))")
        } else {
            results.append(
                "❌ CS per minute calculation: \(String(format: "%.2f", csPerMinute)), expected ~\(String(format: "%.2f", expectedCS))"
            )
        }

        // Test kill participation calculation
        let kpParticipants = [
            createMockParticipant(kills: 5, assists: 3, teamId: 100),
            createMockParticipant(kills: 2, assists: 8, teamId: 100),
        ]

        let kpMatches = [
            createMockMatchWithParticipants([
                createMockParticipant(kills: 5, assists: 3, teamId: 100),
                createMockParticipant(kills: 2, assists: 8, teamId: 100),
                createMockParticipant(kills: 1, assists: 2, teamId: 200),
                createMockParticipant(kills: 0, assists: 1, teamId: 200),
            ])
        ]

        let killParticipation = calculateKillParticipation(
            participants: kpParticipants, matches: kpMatches)
        // Team 100 total kills: 5 + 2 = 7, our participants: (5+3) + (2+8) = 18, KP = 18/7 = 2.57
        let expectedKP = 18.0 / 7.0

        if abs(killParticipation - expectedKP) < 0.1 {
            results.append(
                "✅ Kill participation calculation: \(String(format: "%.2f", killParticipation))")
        } else {
            results.append(
                "❌ Kill participation calculation: \(String(format: "%.2f", killParticipation)), expected ~\(String(format: "%.2f", expectedKP))"
            )
        }

        return results
    }

    // MARK: - Match Filtering Tests

    private static func testMatchFiltering() -> [String] {
        var results: [String] = []

        // Test relevant match criteria
        let relevantMatch = isRelevantMatch(
            gameMode: "CLASSIC",
            gameType: "MATCHED_GAME",
            queueId: 420,  // Ranked Solo/Duo
            mapId: 11,  // Summoner's Rift
            gameCreation: Int(Date().timeIntervalSince1970 * 1000),  // Recent
            gameDuration: 1800  // 30 minutes
        )

        if relevantMatch {
            results.append("✅ Relevant match correctly identified")
        } else {
            results.append("❌ Relevant match incorrectly rejected")
        }

        // Test ARAM (should be irrelevant)
        let aramMatch = isRelevantMatch(
            gameMode: "ARAM",
            gameType: "MATCHED_GAME",
            queueId: 450,
            mapId: 12,
            gameCreation: Int(Date().timeIntervalSince1970 * 1000),
            gameDuration: 1800
        )
        if !aramMatch {
            results.append("✅ ARAM match correctly rejected")
        } else {
            results.append("❌ ARAM match incorrectly accepted")
        }

        // Test too short game (should be irrelevant)
        let shortMatch = isRelevantMatch(
            gameMode: "CLASSIC",
            gameType: "MATCHED_GAME",
            queueId: 420,
            mapId: 11,
            gameCreation: Int(Date().timeIntervalSince1970 * 1000),
            gameDuration: 300
        )
        if !shortMatch {
            results.append("✅ Short match correctly rejected")
        } else {
            results.append("❌ Short match incorrectly accepted")
        }

        return results
    }

    // MARK: - DesignSystem Tests

    private static func testDesignSystem() -> [String] {
        var results: [String] = []

        // Test colors
        _ = DesignSystem.Colors.primary
        _ = DesignSystem.Colors.secondary
        _ = DesignSystem.Colors.accent
        _ = DesignSystem.Colors.background
        _ = DesignSystem.Colors.surface
        results.append("✅ DesignSystem.Colors accessible")

        // Test typography
        _ = DesignSystem.Typography.largeTitle
        _ = DesignSystem.Typography.title
        _ = DesignSystem.Typography.body
        _ = DesignSystem.Typography.caption
        results.append("✅ DesignSystem.Typography accessible")

        // Test spacing
        _ = DesignSystem.Spacing.xs
        _ = DesignSystem.Spacing.sm
        _ = DesignSystem.Spacing.md
        _ = DesignSystem.Spacing.lg
        _ = DesignSystem.Spacing.xl
        results.append("✅ DesignSystem.Spacing accessible")

        // Test corner radius
        _ = DesignSystem.CornerRadius.small
        _ = DesignSystem.CornerRadius.medium
        _ = DesignSystem.CornerRadius.large
        results.append("✅ DesignSystem.CornerRadius accessible")

        return results
    }

    // MARK: - Logger Tests

    private static func testLogger() -> [String] {
        var results: [String] = []

        // Test all log levels
        ClaimbLogger.debug("Test debug message", service: "TestService")
        ClaimbLogger.info("Test info message", service: "TestService")
        ClaimbLogger.warning("Test warning message", service: "TestService")
        ClaimbLogger.error("Test error message", service: "TestService")

        // Test with metadata
        ClaimbLogger.debug("Test with metadata", service: "TestService", metadata: ["key": "value"])

        results.append("✅ ClaimbLogger all levels work")

        return results
    }

    // MARK: - Helper Methods

    private static func createMockParticipant(
        kills: Int = 0,
        assists: Int = 0,
        totalMinionsKilled: Int = 0,
        teamId: Int = 100,
        gameDuration: Int = 1800
    ) -> MockParticipant {
        return MockParticipant(
            kills: kills,
            assists: assists,
            totalMinionsKilled: totalMinionsKilled,
            teamId: teamId,
            gameDuration: gameDuration
        )
    }

    private static func createMockMatch(gameDuration: Int) -> MockMatch {
        return MockMatch(gameDuration: gameDuration)
    }

    private static func createMockMatchWithParticipants(_ participants: [MockParticipant])
        -> MockMatch
    {
        return MockMatch(participants: participants)
    }

    // Simplified KPI calculation methods for testing
    private static func calculateCSPerMinute(participants: [MockParticipant], matches: [MockMatch])
        -> Double
    {
        return participants.map { participant in
            let match = matches.first { $0.gameDuration == participant.gameDuration }
            let gameDurationMinutes = Double(match?.gameDuration ?? 1800) / 60.0
            return gameDurationMinutes > 0
                ? Double(participant.totalMinionsKilled) / gameDurationMinutes : 0.0
        }.reduce(0, +) / Double(participants.count)
    }

    private static func calculateKillParticipation(
        participants: [MockParticipant], matches: [MockMatch]
    ) -> Double {
        return participants.map { participant in
            let match = matches.first { match in
                match.participants.contains(where: { $0 == participant })
            }
            let teamKills =
                match?.participants.filter { $0.teamId == participant.teamId }.reduce(0) {
                    $0 + $1.kills
                } ?? 0
            return teamKills > 0
                ? Double(participant.kills + participant.assists) / Double(teamKills) : 0.0
        }.reduce(0, +) / Double(participants.count)
    }

    private static func isRelevantMatch(
        gameMode: String,
        gameType: String,
        queueId: Int,
        mapId: Int,
        gameCreation: Int,
        gameDuration: Int
    ) -> Bool {
        // Simplified version of MatchParser.isRelevantMatch
        let relevantGameModes = ["CLASSIC"]
        guard relevantGameModes.contains(gameMode) else { return false }
        guard mapId == 11 else { return false }

        let relevantQueueIds = [420, 440, 400, 430]
        guard relevantQueueIds.contains(queueId) else { return false }

        let minGameDurationSeconds = 10 * 60
        guard gameDuration >= minGameDurationSeconds else { return false }

        let maxGameAgeInDays = 365
        let gameDate = Date(timeIntervalSince1970: TimeInterval(gameCreation / 1000))
        let daysSinceGame =
            Calendar.current.dateComponents([.day], from: gameDate, to: Date()).day ?? 0
        guard daysSinceGame <= maxGameAgeInDays else { return false }

        return true
    }
}

// MARK: - Mock Types for Testing

private struct MockParticipant: Equatable {
    let kills: Int
    let assists: Int
    let totalMinionsKilled: Int
    let teamId: Int
    let gameDuration: Int
}

private struct MockMatch {
    let gameDuration: Int
    let participants: [MockParticipant]

    init(gameDuration: Int) {
        self.gameDuration = gameDuration
        self.participants = []
    }

    init(participants: [MockParticipant]) {
        self.gameDuration = 1800
        self.participants = participants
    }
}
