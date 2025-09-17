//
//  ChampionDataViewModel.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData
import SwiftUI

/// Shared view model for champion data loading and statistics
@MainActor
@Observable
public class ChampionDataViewModel {
    // MARK: - Published Properties

    public var championState: UIState<[Champion]> = .idle
    var championStats: [ChampionStats] = []
    public var roleStats: [RoleStats] = []

    // MARK: - Private Properties

    private let dataCoordinator: DataCoordinator?
    private let summoner: Summoner
    private let userSession: UserSession

    // MARK: - Initialization

    public init(dataCoordinator: DataCoordinator?, summoner: Summoner, userSession: UserSession) {
        self.dataCoordinator = dataCoordinator
        self.summoner = summoner
        self.userSession = userSession
    }

    // MARK: - Public Methods

    /// Loads champions and calculates role statistics
    public func loadData() async {
        guard let dataCoordinator = dataCoordinator else {
            championState = .error(DataCoordinatorError.notAvailable)
            return
        }

        championState = .loading

        // Load champions using DataCoordinator
        let championResult = await dataCoordinator.loadChampions()

        championState = championResult

        // Load matches and calculate role stats
        let matchResult = await dataCoordinator.loadMatches(for: summoner)

        switch matchResult {
        case .loaded(let matches):
            roleStats = dataCoordinator.calculateRoleStats(from: matches, summoner: summoner)

            // Load champion stats after setting role stats
            await loadChampionStats()
        case .error(let error):
            championState = .error(error)
        case .loading, .idle, .empty:
            break
        }
    }

    /// Loads champion statistics for the current role and filter
    public func loadChampionStats(role: String? = nil, filter: ChampionFilter = .all) async {
        guard let dataCoordinator = dataCoordinator else { return }

        let matchResult = await dataCoordinator.loadMatches(for: summoner)

        switch matchResult {
        case .loaded(let matches):
            let currentRole = role ?? userSession.selectedPrimaryRole
            let stats = calculateChampionStats(
                from: matches,
                role: currentRole,
                filter: filter
            )
            championStats = stats
        case .error, .loading, .idle, .empty:
            break
        }
    }

    /// Gets the current champions if loaded
    public var currentChampions: [Champion] {
        return championState.data ?? []
    }

    /// Checks if champions are currently loaded
    public var hasChampions: Bool {
        return championState.isLoaded && !currentChampions.isEmpty
    }

    /// Gets champions filtered by a specific role
    public func getChampionsForRole(_ role: String) -> [Champion] {
        return currentChampions.filter { champion in
            // This would need to be implemented based on your champion role mapping
            // For now, return all champions
            return true
        }
    }

    // MARK: - Private Methods

    private func calculateChampionStats(from matches: [Match], role: String, filter: ChampionFilter)
        -> [ChampionStats]
    {
        var championStats: [String: ChampionStats] = [:]

        for match in matches {
            guard
                let participant = match.participants.first(where: {
                    $0.puuid == summoner.puuid
                })
            else {
                continue
            }

            let championId = participant.championId
            let champion = currentChampions.first { $0.id == championId }

            guard let champion = champion else { continue }
            
            // Debug logging for champion role investigation
            let actualRole = RoleUtils.normalizeRole(participant.role, lane: participant.lane)
            ClaimbLogger.debug(
                "Champion stats calculation", service: "ChampionDataViewModel",
                metadata: [
                    "champion": champion.name,
                    "actualRole": actualRole,
                    "selectedRole": role,
                    "championId": String(championId)
                ])

            if championStats[champion.name] == nil {
                championStats[champion.name] = ChampionStats(
                    champion: champion,
                    gamesPlayed: 0,
                    wins: 0,
                    winRate: 0.0,
                    averageKDA: 0.0,
                    averageCS: 0.0,
                    averageVisionScore: 0.0,
                    averageDeaths: 0.0,
                    averageGoldPerMin: 0.0,
                    averageKillParticipation: 0.0,
                    averageObjectiveParticipation: 0.0,
                    averageTeamDamagePercent: 0.0,
                    averageDamageTakenShare: 0.0
                )
            }

            championStats[champion.name]?.gamesPlayed += 1
            if participant.win {
                championStats[champion.name]?.wins += 1
            }

            // Update averages
            let current = championStats[champion.name]!
            let newKDA =
                (current.averageKDA * Double(current.gamesPlayed - 1) + participant.kda)
                / Double(current.gamesPlayed)
            let newCS =
                (current.averageCS * Double(current.gamesPlayed - 1) + participant.csPerMinute)
                / Double(current.gamesPlayed)
            let newVision =
                (current.averageVisionScore * Double(current.gamesPlayed - 1)
                    + participant.visionScorePerMinute) / Double(current.gamesPlayed)
            let newDeaths =
                (current.averageDeaths * Double(current.gamesPlayed - 1)
                    + Double(participant.deaths))
                / Double(current.gamesPlayed)

            // Calculate role-specific KPIs
            let newGoldPerMin =
                (current.averageGoldPerMin * Double(current.gamesPlayed - 1)
                    + participant.goldPerMinute) / Double(current.gamesPlayed)
            let newKillParticipation =
                (current.averageKillParticipation * Double(current.gamesPlayed - 1)
                    + participant.killParticipation) / Double(current.gamesPlayed)
            let newObjectiveParticipation =
                (current.averageObjectiveParticipation * Double(current.gamesPlayed - 1)
                    + participant.objectiveParticipationPercentage) / Double(current.gamesPlayed)
            let newTeamDamagePercent =
                (current.averageTeamDamagePercent * Double(current.gamesPlayed - 1)
                    + participant.teamDamagePercentage) / Double(current.gamesPlayed)
            let newDamageTakenShare =
                (current.averageDamageTakenShare * Double(current.gamesPlayed - 1)
                    + participant.damageTakenSharePercentage) / Double(current.gamesPlayed)

            championStats[champion.name]?.averageKDA = newKDA
            championStats[champion.name]?.averageCS = newCS
            championStats[champion.name]?.averageVisionScore = newVision
            championStats[champion.name]?.averageDeaths = newDeaths
            championStats[champion.name]?.averageGoldPerMin = newGoldPerMin
            championStats[champion.name]?.averageKillParticipation = newKillParticipation
            championStats[champion.name]?.averageObjectiveParticipation = newObjectiveParticipation
            championStats[champion.name]?.averageTeamDamagePercent = newTeamDamagePercent
            championStats[champion.name]?.averageDamageTakenShare = newDamageTakenShare
        }

        // Filter champions with at least 3 games and calculate win rates
        let filteredStats = championStats.values.compactMap { stats -> ChampionStats? in
            guard stats.gamesPlayed >= 3 else { return nil }

            let winRate =
                stats.gamesPlayed > 0 ? Double(stats.wins) / Double(stats.gamesPlayed) : 0.0

            return ChampionStats(
                champion: stats.champion,
                gamesPlayed: stats.gamesPlayed,
                wins: stats.wins,
                winRate: winRate,
                averageKDA: stats.averageKDA,
                averageCS: stats.averageCS,
                averageVisionScore: stats.averageVisionScore,
                averageDeaths: stats.averageDeaths,
                averageGoldPerMin: stats.averageGoldPerMin,
                averageKillParticipation: stats.averageKillParticipation,
                averageObjectiveParticipation: stats.averageObjectiveParticipation,
                averageTeamDamagePercent: stats.averageTeamDamagePercent,
                averageDamageTakenShare: stats.averageDamageTakenShare
            )
        }

        // Apply additional filtering based on the filter parameter
        let finalStats = filteredStats.filter { stats in
            switch filter {
            case .all:
                return true
            case .highWinRate:
                return stats.winRate >= 0.6
            case .highGames:
                return stats.gamesPlayed >= 10
            case .highKDA:
                return stats.averageKDA >= 2.0
            }
        }

        return finalStats.sorted { $0.gamesPlayed > $1.gamesPlayed }
    }
}

// MARK: - Champion Filter

public enum ChampionFilter: String, CaseIterable {
    case all = "All"
    case highWinRate = "High Win Rate"
    case highGames = "High Games"
    case highKDA = "High KDA"
}
