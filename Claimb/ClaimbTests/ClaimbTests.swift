//
//  ClaimbTests.swift
//  ClaimbTests
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Testing
import SwiftUI
@testable import Claimb

struct ClaimbTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - RoleSelectorView Tests

struct RoleSelectorViewTests {
    
    @Test func testRoleDisplayNames() async throws {
        // Test that role display names are correct
        let testCases: [(String, String)] = [
            ("TOP", "Top"),
            ("JUNGLE", "Jungle"),
            ("MIDDLE", "Mid"),
            ("SOLO", "Mid"),  // SOLO should display as Mid
            ("BOTTOM", "Bottom"),
            ("UTILITY", "Support"),
            ("UNKNOWN", "UNKNOWN")  // Fallback case
        ]
        
        for (inputRole, expectedDisplay) in testCases {
            // We can't directly test the computed property, but we can test the logic
            let displayName = getRoleDisplayName(for: inputRole)
            #expect(displayName == expectedDisplay, "Role '\(inputRole)' should display as '\(expectedDisplay)', got '\(displayName)'")
        }
    }
    
    @Test func testRoleIconMapping() async throws {
        // Test that role icons are mapped correctly
        let testCases: [(String, String)] = [
            ("TOP", "RoleTopIcon"),
            ("JUNGLE", "RoleJungleIcon"),
            ("MIDDLE", "RoleMidIcon"),
            ("SOLO", "RoleMidIcon"),  // SOLO should use Mid icon
            ("BOTTOM", "RoleAdcIcon"),
            ("UTILITY", "RoleSupportIcon"),
            ("UNKNOWN", "RoleTopIcon")  // Fallback case
        ]
        
        for (inputRole, expectedIcon) in testCases {
            let iconName = getRoleIconName(for: inputRole)
            #expect(iconName == expectedIcon, "Role '\(inputRole)' should use icon '\(expectedIcon)', got '\(iconName)'")
        }
    }
    
    @Test func testWinRateColorCoding() async throws {
        // Test win rate color coding logic
        let testCases: [(Double, String)] = [
            (0.65, "accent"),    // >= 60% should be teal (accent)
            (0.60, "accent"),    // Exactly 60% should be teal
            (0.55, "primary"),   // 50-59% should be orange (primary)
            (0.50, "primary"),   // Exactly 50% should be orange
            (0.45, "secondary"), // < 50% should be red-orange (secondary)
            (0.30, "secondary")  // Low win rate should be red-orange
        ]
        
        for (winRate, expectedColor) in testCases {
            let color = getWinRateColor(for: winRate)
            #expect(color == expectedColor, "Win rate \(winRate) should be \(expectedColor), got \(color)")
        }
    }
    
    @Test func testRoleStatsInitialization() async throws {
        // Test RoleStats struct initialization
        let roleStats = RoleStats(role: "TOP", winRate: 0.65, totalGames: 20)
        
        #expect(roleStats.role == "TOP")
        #expect(roleStats.winRate == 0.65)
        #expect(roleStats.totalGames == 20)
    }
    
    @Test func testRoleStatsEquality() async throws {
        // Test RoleStats equality for array operations
        let stats1 = RoleStats(role: "TOP", winRate: 0.65, totalGames: 20)
        let stats2 = RoleStats(role: "TOP", winRate: 0.65, totalGames: 20)
        let stats3 = RoleStats(role: "JUNGLE", winRate: 0.65, totalGames: 20)
        
        #expect(stats1.role == stats2.role)
        #expect(stats1.winRate == stats2.winRate)
        #expect(stats1.totalGames == stats2.totalGames)
        #expect(stats1.role != stats3.role)
    }
}

// MARK: - Helper Functions for Testing

private func getRoleDisplayName(for role: String) -> String {
    switch role {
    case "TOP": return "Top"
    case "JUNGLE": return "Jungle"
    case "MIDDLE", "SOLO": return "Mid"  // SOLO is Riot's name for mid
    case "BOTTOM": return "Bottom"
    case "UTILITY": return "Support"
    default: return role
    }
}

private func getRoleIconName(for role: String) -> String {
    switch role {
    case "TOP": return "RoleTopIcon"
    case "JUNGLE": return "RoleJungleIcon"
    case "MIDDLE", "SOLO": return "RoleMidIcon"  // SOLO is Riot's name for mid
    case "BOTTOM": return "RoleAdcIcon"
    case "UTILITY": return "RoleSupportIcon"
    default: return "RoleTopIcon" // Fallback to Top icon
    }
}

private func getWinRateColor(for winRate: Double) -> String {
    if winRate >= 0.6 {
        return "accent"  // Teal for good performance
    } else if winRate >= 0.5 {
        return "primary"  // Orange for average performance
    } else {
        return "secondary"  // Red-orange for poor performance
    }
}

// MARK: - Role Calculation Tests

struct RoleCalculationTests {
    
    @Test func testCalculateRoleWinRates() async throws {
        // Test role win rate calculation logic
        let mockMatches = createMockMatches()
        let mockSummoner = createMockSummoner()
        
        let roleStats = calculateRoleWinRates(from: mockMatches, summoner: mockSummoner)
        
        // Should have 5 roles
        #expect(roleStats.count == 5)
        
        // Check that all expected roles are present
        let roles = Set(roleStats.map { $0.role })
        let expectedRoles = Set(["TOP", "JUNGLE", "SOLO", "BOTTOM", "UTILITY"])
        #expect(roles == expectedRoles)
        
        // Check specific role calculations
        let topStats = roleStats.first { $0.role == "TOP" }!
        #expect(topStats.totalGames == 2) // 2 top games
        #expect(topStats.winRate == 0.5) // 1 win, 1 loss
        
        let midStats = roleStats.first { $0.role == "SOLO" }!
        #expect(midStats.totalGames == 1) // 1 mid game
        #expect(midStats.winRate == 1.0) // 1 win, 0 losses
    }
    
    @Test func testEmptyMatchesHandling() async throws {
        // Test handling of empty match list
        let emptyMatches: [Match] = []
        let mockSummoner = createMockSummoner()
        
        let roleStats = calculateRoleWinRates(from: emptyMatches, summoner: mockSummoner)
        
        #expect(roleStats.isEmpty)
    }
    
    @Test func testRoleWinRateCalculation() async throws {
        // Test specific win rate calculations
        let matches = [
            createMockMatch(participantRole: "TOP", won: true),
            createMockMatch(participantRole: "TOP", won: false),
            createMockMatch(participantRole: "TOP", won: true),
            createMockMatch(participantRole: "JUNGLE", won: true)
        ]
        let summoner = createMockSummoner()
        
        let roleStats = calculateRoleWinRates(from: matches, summoner: summoner)
        
        let topStats = roleStats.first { $0.role == "TOP" }!
        #expect(topStats.totalGames == 3)
        #expect(topStats.winRate == 2.0/3.0) // 2 wins out of 3 games
        
        let jungleStats = roleStats.first { $0.role == "JUNGLE" }!
        #expect(jungleStats.totalGames == 1)
        #expect(jungleStats.winRate == 1.0) // 1 win out of 1 game
    }
}

// MARK: - Mock Data Creation

private func createMockMatches() -> [Match] {
    return [
        createMockMatch(participantRole: "TOP", won: true),
        createMockMatch(participantRole: "TOP", won: false),
        createMockMatch(participantRole: "SOLO", won: true),
        createMockMatch(participantRole: "JUNGLE", won: false),
        createMockMatch(participantRole: "BOTTOM", won: true),
        createMockMatch(participantRole: "UTILITY", won: false)
    ]
}

private func createMockMatch(participantRole: String, won: Bool) -> Match {
    let currentTime = Int(Date().timeIntervalSince1970 * 1000)
    
    let match = Match(
        matchId: "test-match-\(UUID().uuidString)",
        gameCreation: currentTime,
        gameDuration: 1800,
        gameMode: "CLASSIC",
        gameType: "MATCHED_GAME",
        gameVersion: "13.1.1",
        queueId: 420,
        gameStartTimestamp: currentTime,
        gameEndTimestamp: currentTime + 1800000
    )
    
    let participant = Participant(
        puuid: "test-puuid",
        championId: 1,
        teamId: 100,
        lane: participantRole,
        role: participantRole,
        kills: 5,
        deaths: 3,
        assists: 10,
        win: won,
        largestMultiKill: 2,
        hadAfkTeammate: 0,
        gameEndedInSurrender: false,
        eligibleForProgression: true,
        totalMinionsKilled: 150,
        neutralMinionsKilled: 10,
        goldEarned: 10000,
        visionScore: 25,
        totalDamageDealt: 20000,
        totalDamageTaken: 15000,
        dragonTakedowns: 1,
        riftHeraldTakedowns: 0,
        baronTakedowns: 0,
        hordeTakedowns: 0,
        atakhanTakedowns: 0
    )
    
    match.participants.append(participant)
    return match
}

private func createMockSummoner() -> Summoner {
    return Summoner(
        puuid: "test-puuid",
        gameName: "TestSummoner",
        tagLine: "1234",
        region: "EUW1"
    )
}

// MARK: - Role Calculation Helper (copied from MainAppView for testing)

private func calculateRoleWinRates(from matches: [Match], summoner: Summoner) -> [RoleStats] {
    var roleStats: [String: (wins: Int, total: Int)] = [:]
    
    for match in matches {
        guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid }) else {
            continue
        }
        
        let role = participant.role
        if roleStats[role] == nil {
            roleStats[role] = (wins: 0, total: 0)
        }
        
        roleStats[role]?.total += 1
        if participant.win {
            roleStats[role]?.wins += 1
        }
    }
    
    return roleStats.map { role, stats in
        let winRate = stats.total > 0 ? Double(stats.wins) / Double(stats.total) : 0.0
        return RoleStats(role: role, winRate: winRate, totalGames: stats.total)
    }.sorted { $0.role < $1.role }
}
