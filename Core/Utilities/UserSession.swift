//
//  UserSession.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-11.
//

import Foundation
import Observation
import SwiftData

/// User session related errors
public enum UserSessionError: Error, LocalizedError {
    case failedToRecreateSummoner

    public var errorDescription: String? {
        switch self {
        case .failedToRecreateSummoner:
            return "Failed to recreate summoner from stored credentials"
        }
    }
}

/// Game type filter for match analysis
public enum GameTypeFilter: String, CaseIterable {
    case allGames = "All Games"
    case rankedOnly = "Ranked Only"
    
    /// Display name for UI (same as rawValue)
    public var displayName: String {
        return rawValue
    }
}

/// Manages user session state and persistent login
@MainActor
@Observable
public class UserSession {
    public var isLoggedIn = false
    public var currentSummoner: Summoner?
    public var selectedPrimaryRole: String = "TOP"
    public var gameTypeFilter: GameTypeFilter = .allGames

    public var modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadStoredPrimaryRole()
        loadStoredGameTypeFilter()

        // Check for existing login asynchronously
        // ModelContext is ready immediately, no delay needed
        Task {
            self.checkExistingLogin()
        }
    }

    /// Checks if there's an existing login session
    private func checkExistingLogin() {
        ClaimbLogger.debug("Starting login check", service: "UserSession")

        // Check if we have stored login credentials
        guard let gameName = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.summonerName),
            let tagLine = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.tagline),
            let region = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.region)
        else {
            ClaimbLogger.debug("No stored credentials found", service: "UserSession")
            isLoggedIn = false
            return
        }

        ClaimbLogger.debug(
            "Found stored credentials", service: "UserSession",
            metadata: [
                "gameName": gameName,
                "tagLine": tagLine,
                "region": region,
            ])

        // Try to find the summoner in the database
        Task {
            do {
                let dataManager = DataManager.shared(with: modelContext)

                // Look for existing summoner by checking all summoners
                let allSummoners = try await dataManager.getAllSummoners()
                ClaimbLogger.debug(
                    "Found summoners in database", service: "UserSession",
                    metadata: [
                        "count": String(allSummoners.count)
                    ])

                if let summoner = allSummoners.first(where: {
                    $0.gameName == gameName && $0.tagLine == tagLine && $0.region == region
                }) {
                    ClaimbLogger.userAction("Found existing summoner", service: "UserSession")

                    // Refresh rank data for existing summoner if it's missing
                    if !summoner.hasAnyRank {
                        ClaimbLogger.info(
                            "Existing summoner has no rank data, refreshing",
                            service: "UserSession",
                            metadata: [
                                "summoner": summoner.gameName,
                                "puuid": summoner.puuid,
                            ])

                        let rankRefreshState = await dataManager.refreshSummonerRanks(for: summoner)
                        if case .loaded = rankRefreshState {
                            ClaimbLogger.info(
                                "Successfully refreshed rank data for existing summoner",
                                service: "UserSession",
                                metadata: [
                                    "summoner": summoner.gameName,
                                    "soloDuoRank": summoner.soloDuoRank ?? "Unranked",
                                    "flexRank": summoner.flexRank ?? "Unranked",
                                ])
                        } else {
                            ClaimbLogger.warning(
                                "Failed to refresh rank data for existing summoner",
                                service: "UserSession",
                                metadata: [
                                    "summoner": summoner.gameName,
                                    "error": "Rank refresh failed",
                                ])
                        }
                    }

                    // Already on MainActor (@MainActor class)
                    self.currentSummoner = summoner
                    self.isLoggedIn = true
                } else {
                    // Summoner not found in database, but we have credentials
                    // Try to recreate the summoner from stored credentials
                    ClaimbLogger.info(
                        "Summoner not found in database, recreating from stored credentials",
                        service: "UserSession")
                    try await recreateSummonerFromCredentials(
                        gameName: gameName, tagLine: tagLine, region: region)
                }
            } catch {
                ClaimbLogger.error("Error during login check", service: "UserSession", error: error)
                // If there's an error, clear credentials and show login
                clearStoredCredentials()
            }
        }
    }

    /// Recreates summoner from stored credentials when not found in database
    private func recreateSummonerFromCredentials(gameName: String, tagLine: String, region: String)
        async throws
    {
        let dataManager = DataManager.shared(with: modelContext)

        // Recreate the summoner
        let summonerState = await dataManager.createOrUpdateSummoner(
            gameName: gameName,
            tagLine: tagLine,
            region: region
        )

        // Handle summoner creation result
        guard case .loaded(let summoner) = summonerState else {
            let errorMessage =
                switch summonerState {
                case .error(let error):
                    "Failed to recreate summoner: \(error.localizedDescription)"
                case .loading:
                    "Summoner recreation is still loading"
                case .idle:
                    "Summoner recreation not started"
                case .empty(let message):
                    "Summoner recreation failed: \(message)"
                case .loaded(_):
                    "This case should not be reached"
                }

            ClaimbLogger.error(
                "Failed to recreate summoner from stored credentials", service: "UserSession",
                metadata: ["error": errorMessage])
            throw UserSessionError.failedToRecreateSummoner
        }

        // Load champion data if needed
        _ = await dataManager.loadChampions()

        // Already on MainActor (@MainActor class)
        self.currentSummoner = summoner
        self.isLoggedIn = true

        ClaimbLogger.info(
            "Successfully recreated summoner from stored credentials", service: "UserSession")
    }

    /// Saves login credentials and sets up the session
    public func login(summoner: Summoner) {
        ClaimbLogger.info(
            "Starting login process", service: "UserSession",
            metadata: [
                "gameName": summoner.gameName,
                "tagLine": summoner.tagLine,
            ])

        // Save credentials to UserDefaults
        UserDefaults.standard.set(summoner.gameName, forKey: AppConstants.UserDefaultsKeys.summonerName)
        UserDefaults.standard.set(summoner.tagLine, forKey: AppConstants.UserDefaultsKeys.tagline)
        UserDefaults.standard.set(summoner.region, forKey: AppConstants.UserDefaultsKeys.region)

        // Verify credentials were saved
        let savedGameName = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.summonerName)
        let savedTagLine = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.tagline)
        let savedRegion = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.region)
        ClaimbLogger.debug(
            "Credentials saved - gameName: \(savedGameName ?? "nil"), tagLine: \(savedTagLine ?? "nil"), region: \(savedRegion ?? "nil")",
            service: "UserSession",
            metadata: [
                "savedGameName": savedGameName ?? "nil",
                "savedTagLine": savedTagLine ?? "nil",
                "savedRegion": savedRegion ?? "nil",
            ]
        )

        // Update session state
        self.currentSummoner = summoner
        self.isLoggedIn = true

        ClaimbLogger.info(
            "Login completed", service: "UserSession",
            metadata: [
                "isLoggedIn": String(isLoggedIn),
                "summoner": summoner.gameName,
            ])

        // Post notification to trigger view updates
        NotificationCenter.default.post(name: AppConstants.Notifications.userSessionDidChange, object: nil)
    }

    /// Refreshes rank data if it's stale (older than 5 minutes)
    /// This consolidates rank refresh logic and prevents unnecessary API calls
    public func refreshRanksIfNeeded() async {
        guard let summoner = currentSummoner else {
            ClaimbLogger.debug("No summoner to refresh ranks for", service: "UserSession")
            return
        }

        // Only refresh if ranks are stale (> 5 minutes)
        let timeSinceLastUpdate = Date().timeIntervalSince(summoner.lastUpdated)
        let refreshThreshold: TimeInterval = 5 * 60  // 5 minutes

        guard timeSinceLastUpdate > refreshThreshold else {
            ClaimbLogger.debug(
                "Ranks are fresh, skipping refresh",
                service: "UserSession",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "threshold": String(Int(refreshThreshold)),
                ])
            return
        }

        ClaimbLogger.info(
            "Refreshing rank data",
            service: "UserSession",
            metadata: [
                "summoner": summoner.gameName,
                "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
            ])

        let dataManager = DataManager.shared(with: modelContext)
        let result = await dataManager.refreshSummonerRanks(for: summoner)

        switch result {
        case .loaded:
            ClaimbLogger.info(
                "Rank refresh completed successfully",
                service: "UserSession",
                metadata: [
                    "summoner": summoner.gameName,
                    "soloDuoRank": summoner.soloDuoRank ?? "Unranked",
                    "flexRank": summoner.flexRank ?? "Unranked",
                ])
        case .error(let error):
            ClaimbLogger.warning(
                "Rank refresh failed, using cached data",
                service: "UserSession",
                metadata: [
                    "summoner": summoner.gameName,
                    "error": error.localizedDescription,
                ])
        case .loading, .idle, .empty:
            break
        }
    }

    /// Logs out the user and clears all stored data
    public func logout() {
        ClaimbLogger.info("Logging out user", service: "UserSession")

        // Clear stored credentials
        clearStoredCredentials()

        // Update session state
        self.currentSummoner = nil
        self.isLoggedIn = false

        // Post notification to trigger view updates
        NotificationCenter.default.post(name: AppConstants.Notifications.userSessionDidChange, object: nil)
    }

    /// Checks if the user has previously logged in (has stored credentials)
    public var hasStoredCredentials: Bool {
        return UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.summonerName) != nil
            && UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.tagline) != nil
            && UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.region) != nil
    }

    /// Clears stored login credentials
    private func clearStoredCredentials() {
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.summonerName)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.tagline)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.region)
    }

    /// Refreshes the current summoner data
    public func refreshSummoner() async {
        guard let currentSummoner = currentSummoner else { return }

        let dataManager = DataManager.shared(with: modelContext)

        // Refresh summoner data
        let refreshedSummonerState = await dataManager.createOrUpdateSummoner(
            gameName: currentSummoner.gameName,
            tagLine: currentSummoner.tagLine,
            region: currentSummoner.region
        )

        // Handle summoner refresh result
        guard case .loaded(let refreshedSummoner) = refreshedSummonerState else {
            let errorMessage =
                switch refreshedSummonerState {
                case .error(let error):
                    "Failed to refresh summoner: \(error.localizedDescription)"
                case .loading:
                    "Summoner refresh is still loading"
                case .idle:
                    "Summoner refresh not started"
                case .empty(let message):
                    "Summoner refresh failed: \(message)"
                case .loaded(_):
                    "This case should not be reached"
                }

            ClaimbLogger.error(
                "Failed to refresh summoner", service: "UserSession",
                metadata: ["error": errorMessage])
            return
        }

        // Already on MainActor (@MainActor class)
        self.currentSummoner = refreshedSummoner
    }

    // MARK: - Primary Role Management

    /// Loads the stored primary role from UserDefaults
    private func loadStoredPrimaryRole() {
        if let storedRole = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.selectedPrimaryRole) {
            selectedPrimaryRole = storedRole
        }
    }
    
    /// Loads the stored game type filter from UserDefaults
    private func loadStoredGameTypeFilter() {
        if let storedFilter = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.rankedOnlyFilter),
           let filter = GameTypeFilter(rawValue: storedFilter) {
            gameTypeFilter = filter
        }
    }

    /// Updates the primary role and persists it
    public func updatePrimaryRole(_ role: String) {
        selectedPrimaryRole = role
        UserDefaults.standard.set(role, forKey: AppConstants.UserDefaultsKeys.selectedPrimaryRole)
        ClaimbLogger.info("Primary role updated", service: "UserSession", metadata: ["role": role])
    }

    /// Updates the game type filter and persists it
    public func updateGameTypeFilter(_ filter: GameTypeFilter) {
        gameTypeFilter = filter
        UserDefaults.standard.set(filter.rawValue, forKey: AppConstants.UserDefaultsKeys.rankedOnlyFilter)
        ClaimbLogger.info("Game type filter updated", service: "UserSession", metadata: ["filter": filter.displayName])
    }
    
    /// Sets the primary role based on most played role from match data
    /// Only auto-selects if no role has been manually selected before (not stored in UserDefaults)
    public func setPrimaryRoleFromMatchData(roleStats: [RoleStats]) {
        // Check if a role has been manually set by user (stored in UserDefaults)
        let hasManuallySelectedRole = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.selectedPrimaryRole) != nil
        
        // Only auto-select if user hasn't manually selected a role yet
        guard !hasManuallySelectedRole else {
            ClaimbLogger.debug(
                "Role already manually selected, skipping auto-selection",
                service: "UserSession",
                metadata: ["currentRole": selectedPrimaryRole]
            )
            return
        }
        
        // Find the most played role (roleStats is already sorted by totalGames descending)
        guard let mostPlayedRole = roleStats.first(where: { $0.totalGames > 0 }) else {
            ClaimbLogger.debug(
                "No role stats available for auto-selection",
                service: "UserSession"
            )
            return
        }
        
        ClaimbLogger.info(
            "Auto-selecting most played role as primary role",
            service: "UserSession",
            metadata: [
                "role": mostPlayedRole.role,
                "totalGames": String(mostPlayedRole.totalGames),
                "winRate": String(format: "%.2f", mostPlayedRole.winRate)
            ]
        )
        
        updatePrimaryRole(mostPlayedRole.role)
    }
}
