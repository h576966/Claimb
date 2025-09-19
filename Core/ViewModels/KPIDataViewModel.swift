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

    private let dataCoordinator: DataCoordinator?
    private let summoner: Summoner
    private let userSession: UserSession
    private let kpiCalculationService: KPICalculationService

    // MARK: - Initialization

    public init(dataCoordinator: DataCoordinator?, summoner: Summoner, userSession: UserSession) {
        self.dataCoordinator = dataCoordinator
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
        guard let dataCoordinator = dataCoordinator else {
            matchState = .error(DataCoordinatorError.notAvailable)
            return
        }

        matchState = .loading

        // Load baseline data first
        _ = await dataCoordinator.loadBaselineData()

        let result = await dataCoordinator.loadMatches(for: summoner)

        matchState = result

        // Update role stats and KPIs if we have matches
        if case .loaded(let matches) = result {
            roleStats = dataCoordinator.calculateRoleStats(from: matches, summoner: summoner)
            await calculateKPIs(matches: matches)
        }
    }

    /// Refreshes matches and recalculates KPIs
    public func refreshData() async {
        guard let dataCoordinator = dataCoordinator else { return }

        isRefreshing = true

        let result = await dataCoordinator.refreshMatches(for: summoner)

        matchState = result
        isRefreshing = false

        // Update role stats and KPIs if we have matches
        if case .loaded(let matches) = result {
            roleStats = dataCoordinator.calculateRoleStats(from: matches, summoner: summoner)
            await calculateKPIs(matches: matches)
        }
    }

    /// Calculates KPIs for the current role
    public func calculateKPIsForCurrentRole() async {
        guard let matches = matchState.data else { return }
        await calculateKPIs(matches: matches)
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
        guard dataCoordinator != nil else { return }

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

}
