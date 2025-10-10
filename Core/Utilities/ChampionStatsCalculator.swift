//
//  ChampionStatsCalculator.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-10.
//

import Foundation
import SwiftData

/// Calculates champion statistics from match data
/// Extracted from MatchDataViewModel to reduce file size and improve testability
public struct ChampionStatsCalculator {
    
    // MARK: - Champion Statistics Calculation
    
    /// Calculates champion statistics from matches and champions
    public static func calculateChampionStats(
        from matches: [Match],
        champions: [Champion],
        summoner: Summoner,
        role: String,
        filter: ChampionFilter
    ) -> [ChampionStats] {
        var championStats: [String: ChampionStats] = [:]
        
        for match in matches {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                continue
            }
            
            let championId = participant.championId
            let champion = champions.first { $0.id == championId }
            
            guard let champion = champion else { continue }
            
            let actualRole = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)
            
            // Skip games with unknown/invalid teamPosition
            if actualRole == "UNKNOWN" {
                continue
            }
            
            // Only include champions played in the selected role
            if actualRole != role {
                continue
            }
            
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
            
            // Update averages (simplified calculation)
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
                    + Double(participant.deaths)) / Double(current.gamesPlayed)
            championStats[champion.name]?.averageKDA = newKDA
            championStats[champion.name]?.averageCS = newCS
            championStats[champion.name]?.averageVisionScore = newVision
            championStats[champion.name]?.averageDeaths = newDeaths
        }
        
        // Filter champions with at least minimum games and calculate win rates
        let filteredStats = championStats.values.compactMap { stats -> ChampionStats? in
            guard stats.gamesPlayed >= AppConstants.ChampionFiltering.minimumGamesForBestPerforming
            else { return nil }
            
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
        
        // Apply sorting and filtering based on filter type
        switch filter {
        case .mostPlayed:
            return filteredStats.sorted { $0.gamesPlayed > $1.gamesPlayed }
        case .bestPerforming:
            return applyBestPerformingFilter(to: filteredStats)
        }
    }
    
    /// Applies smart filtering for Best Performing champions
    private static func applyBestPerformingFilter(to stats: [ChampionStats]) -> [ChampionStats] {
        // First try with default 50% win rate threshold
        let highPerformers = stats.filter {
            $0.winRate >= AppConstants.ChampionFiltering.defaultWinRateThreshold
        }
        
        // If we have enough champions, return them sorted by win rate
        if highPerformers.count >= AppConstants.ChampionFiltering.minimumChampionsForFallback {
            ClaimbLogger.debug(
                "Using default win rate threshold for Best Performing",
                service: "ChampionStatsCalculator",
                metadata: [
                    "threshold": String(AppConstants.ChampionFiltering.defaultWinRateThreshold),
                    "championCount": String(highPerformers.count),
                ]
            )
            return highPerformers.sorted { $0.winRate > $1.winRate }
        }
        
        // Fallback to 40% threshold if too few champions meet 50% criteria
        let fallbackPerformers = stats.filter {
            $0.winRate >= AppConstants.ChampionFiltering.fallbackWinRateThreshold
        }
        
        ClaimbLogger.debug(
            "Using fallback win rate threshold for Best Performing",
            service: "ChampionStatsCalculator",
            metadata: [
                "defaultThreshold": String(AppConstants.ChampionFiltering.defaultWinRateThreshold),
                "fallbackThreshold": String(
                    AppConstants.ChampionFiltering.fallbackWinRateThreshold),
                "defaultCount": String(highPerformers.count),
                "fallbackCount": String(fallbackPerformers.count),
            ]
        )
        
        return fallbackPerformers.sorted { $0.winRate > $1.winRate }
    }
    
    // MARK: - Champion Match Filtering
    
    /// Gets champion-specific matches for a role
    public static func getChampionMatches(
        for champion: Champion,
        role: String,
        summoner: Summoner,
        allMatches: [Match]
    ) -> [Match] {
        return allMatches.filter { match in
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                return false
            }
            let actualRole = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)
            return participant.championId == champion.id && actualRole == role
                && actualRole != "UNKNOWN"
        }
    }
}

