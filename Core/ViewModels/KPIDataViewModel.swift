//
//  KPIDataViewModel.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftData
import SwiftUI

/// Shared view model for KPI calculations and performance metrics
@MainActor
@Observable
public class KPIDataViewModel {
    // MARK: - Published Properties

    public var matchState: UIState<[Match]> = .idle
    public var roleStats: [RoleStats] = []
    private var _kpiMetrics: [KPIMetric] = []
    public var isRefreshing = false

    /// Sorted KPI metrics with urgent attention items first
    /// Sorting order: Poor -> Needs Improvement -> Good -> Excellent
    var kpiMetrics: [KPIMetric] {
        return _kpiMetrics.sorted { lhs, rhs in
            return lhs.performanceLevel < rhs.performanceLevel
        }
    }

    // MARK: - Private Properties

    private let dataManager: DataManager?
    private let summoner: Summoner
    private let userSession: UserSession
    private let kpiCalculationService: KPICalculationService
    private var currentTask: Task<Void, Never>?
    nonisolated(unsafe) private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(dataManager: DataManager?, summoner: Summoner, userSession: UserSession) {
        self.dataManager = dataManager
        self.summoner = summoner
        self.userSession = userSession

        // Initialize KPI calculation service with a new DataManager instance
        // This is acceptable since it's only used for baseline lookups
        let dataManager = DataManager(
            modelContext: userSession.modelContext,
            riotClient: RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey),
            dataDragonService: DataDragonService()
        )
        self.kpiCalculationService = KPICalculationService(dataManager: dataManager)
    }

    // MARK: - Public Methods

    /// Loads matches and calculates KPIs
    public func loadData() async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataManager = dataManager else {
                matchState = .error(DataManagerError.notAvailable)
                return
            }

            matchState = .loading

            // Load baseline data first
            _ = await dataManager.loadBaselineData()

            let result = await dataManager.loadMatches(for: summoner)

            matchState = result

            // Update role stats and KPIs if we have matches
            if case .loaded(let matches) = result {
                roleStats = calculateRoleStats(from: matches, summoner: summoner)
                await calculateKPIs(matches: matches)
            }
        }

        // Store task for cleanup
        cleanupTask = currentTask

        await currentTask?.value
    }

    /// Refreshes matches and recalculates KPIs
    public func refreshData() async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let dataManager = dataManager else { return }

            isRefreshing = true

            let result = await dataManager.refreshMatches(for: summoner)

            matchState = result
            isRefreshing = false

            // Update role stats and KPIs if we have matches
            if case .loaded(let matches) = result {
                roleStats = calculateRoleStats(from: matches, summoner: summoner)
                await calculateKPIs(matches: matches)
            }
        }

        // Store task for cleanup
        cleanupTask = currentTask

        await currentTask?.value
    }

    /// Calculates KPIs for the current role
    public func calculateKPIsForCurrentRole() async {
        // Cancel any existing task
        currentTask?.cancel()

        currentTask = Task {
            guard let matches = matchState.data else { return }
            await calculateKPIs(matches: matches)
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

    /// Gets KPIs for a specific role
    func getKPIsForRole(_ role: String) -> [KPIMetric] {
        return _kpiMetrics.filter { $0.metric.contains(role.lowercased()) }
    }

    // MARK: - Private Methods

    private func calculateKPIs(matches: [Match]) async {
        guard dataManager != nil else { return }

        let role = userSession.selectedPrimaryRole

        do {
            let roleKPIs = try await kpiCalculationService.calculateRoleKPIs(
                matches: matches,
                role: role,
                summoner: summoner
            )

            _kpiMetrics = roleKPIs

        } catch {
            ClaimbLogger.error(
                "Failed to calculate KPIs", service: "KPIDataViewModel", error: error)
            _kpiMetrics = []
        }
    }

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
