//
//  MatchStatsCalculator.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-09.
//

import Foundation

/// Utility for calculating champion and role statistics from match data
/// Eliminates code duplication between OpenAIService and MatchDataViewModel
public struct MatchStatsCalculator {

    // MARK: - Champion Statistics

    public struct ChampionStats {
        public let name: String
        public let games: Int
        public let wins: Int
        public let winRate: Double
        public let avgCS: Double
        public let avgKDA: Double
    }

    /// Calculates best performing champions for a specific role
    public static func calculateBestPerformingChampions(
        matches: [Match],
        summoner: Summoner,
        primaryRole: String
    ) -> [ChampionStats] {
        // Calculate champion performance statistics
        var championStats: [String: (games: Int, wins: Int, avgCS: Double, avgKDA: Double)] = [:]

        for match in matches {
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid }),
                let championName = participant.champion?.name
            else { continue }

            let role = RoleUtils.normalizeRole(teamPosition: participant.teamPosition)

            // Only include champions from primary role
            guard role == primaryRole else { continue }

            let cs = participant.totalMinionsKilled + participant.neutralMinionsKilled
            let kda =
                (Double(participant.kills) + Double(participant.assists))
                / max(Double(participant.deaths), 1.0)

            if championStats[championName] == nil {
                championStats[championName] = (
                    games: 0, wins: 0, avgCS: 0.0, avgKDA: 0.0
                )
            }

            var stats = championStats[championName]!
            stats.games += 1
            if participant.win {
                stats.wins += 1
            }
            stats.avgCS = (stats.avgCS * Double(stats.games - 1) + Double(cs)) / Double(stats.games)
            stats.avgKDA = (stats.avgKDA * Double(stats.games - 1) + kda) / Double(stats.games)
            championStats[championName] = stats
        }

        // Calculate win rates and filter by minimum games
        var bestPerformers: [ChampionStats] = []

        for (champion, stats) in championStats {
            guard stats.games >= AppConstants.ChampionFiltering.minimumGamesForBestPerforming else {
                continue
            }

            let winRate = Double(stats.wins) / Double(stats.games)
            bestPerformers.append(
                ChampionStats(
                    name: champion,
                    games: stats.games,
                    wins: stats.wins,
                    winRate: winRate,
                    avgCS: stats.avgCS,
                    avgKDA: stats.avgKDA
                ))
        }

        // Sort by win rate (best performers first)
        bestPerformers.sort { $0.winRate > $1.winRate }

        // Filter by win rate threshold (same logic as ChampionView)
        let highPerformers = bestPerformers.filter {
            $0.winRate >= AppConstants.ChampionFiltering.defaultWinRateThreshold
        }

        let finalChampions =
            highPerformers.count >= AppConstants.ChampionFiltering.minimumChampionsForFallback
            ? highPerformers
            : bestPerformers.filter {
                $0.winRate >= AppConstants.ChampionFiltering.fallbackWinRateThreshold
            }

        return finalChampions
    }

    // MARK: - Helper Methods

    /// Finds participant for summoner in a match
    public static func findParticipant(summoner: Summoner, in match: Match) -> Participant? {
        return match.participants.first(where: { $0.puuid == summoner.puuid })
    }

    /// Calculates total CS for a participant
    public static func calculateTotalCS(participant: Participant) -> Int {
        return participant.totalMinionsKilled + participant.neutralMinionsKilled
    }

    /// Calculates KDA ratio for a participant
    public static func calculateKDA(participant: Participant) -> Double {
        return (Double(participant.kills) + Double(participant.assists))
            / max(Double(participant.deaths), 1.0)
    }
}
