//
//  TestDataCreator.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData

/// Service for creating test data for development and testing
@MainActor
public class TestDataCreator {
    private var modelContext: ModelContext?

    public init() {
        self.modelContext = nil
    }

    public func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Test Data Creation

    /// Creates test summoner data
    public func createTestSummoner() async throws -> Summoner {
        guard let modelContext = modelContext else {
            throw TestError.noData("ModelContext not set")
        }

        let summoner = Summoner(
            puuid: "test-puuid-123",
            gameName: "TestPlayer",
            tagLine: "1234",
            region: "euw1"
        )
        modelContext.insert(summoner)
        try modelContext.save()
        return summoner
    }

    /// Creates test match data
    public func createTestMatches(for summoner: Summoner, count: Int = 5) async throws -> [Match] {
        guard let modelContext = modelContext else {
            throw TestError.noData("ModelContext not set")
        }

        var matches: [Match] = []

        for i in 0..<count {
            let match = Match(
                matchId: "test-match-\(i)",
                gameCreation: Int(Date().timeIntervalSince1970) - (i * 3600),
                gameDuration: 1800 + (i * 100),
                gameMode: "CLASSIC",
                gameType: "MATCHED_GAME",
                gameVersion: "13.1.1",
                queueId: 420,
                mapId: 11,
                gameStartTimestamp: Int(Date().timeIntervalSince1970) - (i * 3600),
                gameEndTimestamp: Int(Date().timeIntervalSince1970) - (i * 3600) + 1800
            )

            match.summoner = summoner

            // Create test participant
            let participant = Participant(
                puuid: summoner.puuid,
                championId: i % 3 == 0 ? 1 : (i % 3 == 1 ? 2 : 3),
                teamId: i % 2 == 0 ? 100 : 200,
                lane: i % 2 == 0 ? "BOTTOM" : "TOP",
                role: i % 2 == 0 ? "DUO_CARRY" : "SOLO",
                teamPosition: i % 2 == 0 ? "BOTTOM" : "TOP",
                kills: 5 + (i % 5),
                deaths: 3 + (i % 4),
                assists: 8 + (i % 6),
                win: i % 3 != 0,
                largestMultiKill: 2,
                hadAfkTeammate: 0,
                gameEndedInSurrender: false,
                eligibleForProgression: true,
                totalMinionsKilled: 150 + (i * 10),
                neutralMinionsKilled: 5 + (i % 3),
                goldEarned: 10000 + (i * 1000),
                visionScore: 20 + (i % 10),
                totalDamageDealt: 50000 + (i * 2000),
                totalDamageDealtToChampions: 15000 + (i * 2000),
                totalDamageTaken: 20000 + (i * 1000),
                dragonTakedowns: i % 4 == 0 ? 1 : 0,
                riftHeraldTakedowns: i % 6 == 0 ? 1 : 0,
                baronTakedowns: i % 8 == 0 ? 1 : 0,
                hordeTakedowns: 0,
                atakhanTakedowns: 0
            )

            participant.match = match

            match.participants.append(participant)
            modelContext.insert(match)
            matches.append(match)
        }

        try modelContext.save()
        return matches
    }

    /// Creates test baseline data
    public func createTestBaselines() async throws -> [Baseline] {
        guard let modelContext = modelContext else {
            throw TestError.noData("ModelContext not set")
        }

        let baselineData = [
            BaselineData(role: "DUO_CARRY", metric: "kills", p40: 3.0, p60: 6.0, median: 4.5),
            BaselineData(role: "DUO_CARRY", metric: "deaths", p40: 2.0, p60: 4.0, median: 3.0),
            BaselineData(role: "DUO_CARRY", metric: "assists", p40: 4.0, p60: 8.0, median: 6.0),
            BaselineData(role: "SOLO", metric: "kills", p40: 2.0, p60: 5.0, median: 3.5),
            BaselineData(role: "SOLO", metric: "deaths", p40: 3.0, p60: 6.0, median: 4.5),
            BaselineData(role: "SOLO", metric: "assists", p40: 3.0, p60: 7.0, median: 5.0),
        ]

        var baselines: [Baseline] = []

        for data in baselineData {
            let baseline = Baseline(
                role: data.role,
                classTag: "Marksman",  // Default class tag
                metric: data.metric,
                mean: data.median ?? 0.0,
                median: data.median ?? 0.0,
                p40: data.p40,
                p60: data.p60
            )
            modelContext.insert(baseline)
            baselines.append(baseline)
        }

        try modelContext.save()
        return baselines
    }
}

// MARK: - Supporting Types

private struct BaselineData: Codable {
    let role: String
    let metric: String
    let p40: Double
    let p60: Double
    let median: Double?
}

enum TestError: Error, LocalizedError {
    case missingResource(String)
    case noData(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let resource):
            return "Missing resource: \(resource)"
        case .noData(let message):
            return "No data: \(message)"
        }
    }
}
