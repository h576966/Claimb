//
//  DataCoordinator.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData
import SwiftUI

/// Errors specific to DataCoordinator
enum DataCoordinatorError: Error, LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "DataCoordinator is not available"
        }
    }
}

/// Centralized data loading coordinator to eliminate DataManager duplication
@MainActor
@Observable
public class DataCoordinator {
    private let dataManager: DataManager

    // Request deduplication
    private var activeRequests: Set<String> = []
    private var requestQueue: [String: Task<UIState<[Match]>, Never>] = [:]

    public init(
        modelContext: ModelContext, riotClient: RiotClient? = nil,
        dataDragonService: DataDragonServiceProtocol? = nil
    ) {
        let client = riotClient ?? RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey)
        let service = dataDragonService ?? DataDragonService()
        self.dataManager = DataManager(
            modelContext: modelContext,
            riotClient: client,
            dataDragonService: service
        )
    }

    deinit {
        // Cancel all pending tasks to prevent memory leaks
        // Note: We can't access @MainActor properties in deinit, so we'll just let them be cancelled naturally
        // The tasks will be cancelled when the DataCoordinator is deallocated
    }

    // MARK: - Match Loading

    /// Loads matches with the common pattern used across views
    public func loadMatches(for summoner: Summoner, limit: Int = 50) async -> UIState<[Match]> {
        let requestKey = "matches_\(summoner.puuid)_\(limit)"

        // Check if request is already in progress
        if let existingTask = requestQueue[requestKey] {
            ClaimbLogger.debug(
                "Request already in progress, waiting for result", service: "DataCoordinator",
                metadata: ["requestKey": requestKey])
            return await existingTask.value
        }

        // Create new task
        let task = Task<UIState<[Match]>, Never> {
            defer {
                // Clean up when task completes
                requestQueue.removeValue(forKey: requestKey)
                activeRequests.remove(requestKey)
            }

            ClaimbLogger.info(
                "Loading matches", service: "DataCoordinator",
                metadata: [
                    "summoner": summoner.gameName,
                    "limit": String(limit),
                ])

            do {
                // Check if we have existing matches
                let existingMatches = try await dataManager.getMatches(for: summoner)

                if existingMatches.isEmpty {
                    // Load initial matches
                    ClaimbLogger.info(
                        "No existing matches, loading initial batch", service: "DataCoordinator")
                    try await dataManager.loadInitialMatches(for: summoner)
                } else {
                    // Load any new matches incrementally
                    ClaimbLogger.info(
                        "Found existing matches, checking for new ones", service: "DataCoordinator",
                        metadata: [
                            "count": String(existingMatches.count)
                        ])
                    try await dataManager.refreshMatches(for: summoner)
                }

                // Get all matches after loading
                let loadedMatches = try await dataManager.getMatches(for: summoner, limit: limit)
                return .loaded(loadedMatches)

            } catch {
                ClaimbLogger.error(
                    "Failed to load matches", service: "DataCoordinator", error: error)
                return .error(error)
            }
        }

        // Store task and return its result
        requestQueue[requestKey] = task
        activeRequests.insert(requestKey)
        return await task.value
    }

    /// Refreshes matches from API
    public func refreshMatches(for summoner: Summoner) async -> UIState<[Match]> {
        ClaimbLogger.info(
            "Refreshing matches", service: "DataCoordinator",
            metadata: [
                "summoner": summoner.gameName
            ])

        do {
            try await dataManager.refreshMatches(for: summoner)
            let refreshedMatches = try await dataManager.getMatches(for: summoner)
            return .loaded(refreshedMatches)
        } catch {
            ClaimbLogger.error(
                "Failed to refresh matches", service: "DataCoordinator", error: error)
            return .error(error)
        }
    }

    // MARK: - Champion Loading

    /// Loads champions with the common pattern
    public func loadChampions() async -> UIState<[Champion]> {
        ClaimbLogger.info("Loading champions", service: "DataCoordinator")

        do {
            // Ensure champion data is loaded first
            try await dataManager.loadChampionData()
            let champions = try await dataManager.getAllChampions()

            ClaimbLogger.info(
                "Successfully loaded \(champions.count) champions",
                service: "DataCoordinator",
                metadata: ["championCount": String(champions.count)]
            )

            return .loaded(champions)
        } catch {
            ClaimbLogger.error("Failed to load champions", service: "DataCoordinator", error: error)
            return .error(error)
        }
    }

    // MARK: - Summoner Management

    /// Creates or updates a summoner (used in login)
    public func createOrUpdateSummoner(gameName: String, tagLine: String, region: String) async
        -> UIState<Summoner>
    {
        ClaimbLogger.info(
            "Creating/updating summoner", service: "DataCoordinator",
            metadata: [
                "gameName": gameName,
                "tagLine": tagLine,
                "region": region,
            ])

        do {
            let summoner = try await dataManager.createOrUpdateSummoner(
                gameName: gameName,
                tagLine: tagLine,
                region: region
            )

            // Load champion data if needed
            try await dataManager.loadChampionData()

            // Refresh matches
            try await dataManager.refreshMatches(for: summoner)

            return .loaded(summoner)
        } catch {
            ClaimbLogger.error(
                "Failed to create/update summoner", service: "DataCoordinator", error: error)
            return .error(error)
        }
    }

    // MARK: - Role Statistics

    /// Calculates role statistics from matches
    public func calculateRoleStats(from matches: [Match], summoner: Summoner) -> [RoleStats] {
        var roleStats: [String: (wins: Int, total: Int)] = [:]

        for match in matches {
            // Find the summoner's participant in this match
            guard let participant = match.participants.first(where: { $0.puuid == summoner.puuid })
            else {
                continue
            }

            let normalizedRole = RoleUtils.normalizeRole(participant.role, lane: participant.lane)
            let isWin = participant.win

            if roleStats[normalizedRole] == nil {
                roleStats[normalizedRole] = (wins: 0, total: 0)
            }

            roleStats[normalizedRole]?.total += 1
            if isWin {
                roleStats[normalizedRole]?.wins += 1
            }
        }

        // Convert to RoleStats array
        return roleStats.map { (role, stats) in
            let winRate = stats.total > 0 ? Double(stats.wins) / Double(stats.total) : 0.0
            return RoleStats(role: role, winRate: winRate, totalGames: stats.total)
        }.sorted { $0.totalGames > $1.totalGames }  // Sort by most played
    }

    // MARK: - Baseline Management

    /// Loads baseline data for KPI calculations
    public func loadBaselineData() async -> UIState<Void> {
        ClaimbLogger.info("Loading baseline data", service: "DataCoordinator")

        do {
            try await dataManager.loadBaselineData()
            return .loaded(())
        } catch {
            ClaimbLogger.error(
                "Failed to load baseline data", service: "DataCoordinator", error: error)
            return .error(error)
        }
    }

    // MARK: - Cache Management

    /// Clears all cached data
    public func clearAllCache() async -> UIState<Void> {
        ClaimbLogger.info("Clearing all cache", service: "DataCoordinator")

        do {
            try await dataManager.clearAllCache()
            return .loaded(())
        } catch {
            ClaimbLogger.error("Failed to clear cache", service: "DataCoordinator", error: error)
            return .error(error)
        }
    }
}
