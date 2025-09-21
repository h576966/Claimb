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

    private let dataCoordinator: DataCoordinator?
    private let summoner: Summoner
    private var currentTask: Task<Void, Never>?
    nonisolated(unsafe) private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(dataCoordinator: DataCoordinator?, summoner: Summoner) {
        self.dataCoordinator = dataCoordinator
        self.summoner = summoner
    }

    // MARK: - Public Methods

    /// Loads matches and calculates role statistics
    public func loadMatches(limit: Int = 50) async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataCoordinator = dataCoordinator else {
                matchState = .error(DataCoordinatorError.notAvailable)
                return
            }

            matchState = .loading

            let result = await dataCoordinator.loadMatches(for: summoner, limit: limit)

            matchState = result

            // Update role stats if we have matches
            if case .loaded(let matches) = result {
                roleStats = dataCoordinator.calculateRoleStats(from: matches, summoner: summoner)
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
            guard let dataCoordinator = dataCoordinator else { return }

            isRefreshing = true

            let result = await dataCoordinator.refreshMatches(for: summoner)

            matchState = result
            isRefreshing = false

            // Update role stats if we have matches
            if case .loaded(let matches) = result {
                roleStats = dataCoordinator.calculateRoleStats(from: matches, summoner: summoner)
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
            guard let dataCoordinator = dataCoordinator else { return }

            isRefreshing = true

            let result = await dataCoordinator.clearAllCache()

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
}
