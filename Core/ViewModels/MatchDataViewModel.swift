//
//  MatchDataViewModel.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData
import SwiftUI

/// Shared view model for match data loading and role statistics
@MainActor
@Observable
public class MatchDataViewModel {
    // MARK: - Published Properties

    public var matchState: UIState<[Match]> = .idle
    public var roleStats: [RoleStats] = []
    public var isRefreshing = false

    // MARK: - Private Properties

    private let dataManager: DataManager?
    private let summoner: Summoner
    private var currentTask: Task<Void, Never>?
    nonisolated(unsafe) private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(dataManager: DataManager?, summoner: Summoner) {
        self.dataManager = dataManager
        self.summoner = summoner
    }

    // MARK: - Public Methods

    /// Loads matches and calculates role statistics
    public func loadMatches(limit: Int = 100) async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataManager = dataManager else {
                matchState = .error(DataManagerError.notAvailable)
                return
            }

            matchState = .loading

            let result = await dataManager.loadMatches(for: summoner, limit: limit)

            matchState = result

            // Update role stats if we have matches
            if case .loaded(let matches) = result {
                roleStats = calculateRoleStats(from: matches, summoner: summoner)
            }
        }

        // Store task for cleanup
        cleanupTask = currentTask

        await currentTask?.value
    }

    /// Refreshes matches from the API and recalculates role statistics
    public func refreshMatches() async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataManager = dataManager else { return }

            isRefreshing = true

            // Use force refresh to bypass cache for pull-to-refresh
            let result = await dataManager.forceRefreshMatches(for: summoner)

            matchState = result
            isRefreshing = false

            // Update role stats if we have matches
            if case .loaded(let matches) = result {
                roleStats = calculateRoleStats(from: matches, summoner: summoner)
            }
        }

        // Store task for cleanup
        cleanupTask = currentTask

        await currentTask?.value
    }

    /// Clears all cached data and reloads matches
    public func clearCache() async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataManager = dataManager else { return }

            isRefreshing = true

            let result = await dataManager.clearAllCache()

            isRefreshing = false

            if case .loaded = result {
                // Reload matches after clearing cache
                await loadMatches()
            }
        }

        // Store task for cleanup
        cleanupTask = currentTask

        await currentTask?.value
    }

    deinit {
        cleanupTask?.cancel()
    }

    /// Gets the current matches if loaded
    public var currentMatches: [Match] {
        return matchState.data ?? []
    }

    /// Checks if matches are currently loaded
    public var hasMatches: Bool {
        return matchState.isLoaded && !currentMatches.isEmpty
    }

    /// Gets the most recent matches up to a specified limit
    public func getRecentMatches(limit: Int = 5) -> [Match] {
        return Array(currentMatches.prefix(limit))
    }

    // MARK: - Private Methods

    /// Calculates role statistics from matches
    private func calculateRoleStats(from matches: [Match], summoner: Summoner) -> [RoleStats] {
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
}
