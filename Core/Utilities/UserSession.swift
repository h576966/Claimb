//
//  UserSession.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-11.
//

import Foundation
import SwiftData

/// Manages user session state and persistent login
@MainActor
@Observable
public class UserSession {
    public var isLoggedIn = false
    public var currentSummoner: Summoner?
    public var selectedPrimaryRole: String = "TOP"

    public var modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadStoredPrimaryRole()

        // Add a small delay to ensure database is ready
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            await MainActor.run {
                self.checkExistingLogin()
            }
        }
    }

    /// Checks if there's an existing login session
    private func checkExistingLogin() {
        ClaimbLogger.debug("Starting login check", service: "UserSession")

        // Check if we have stored login credentials
        guard let gameName = UserDefaults.standard.string(forKey: "summonerName"),
            let tagLine = UserDefaults.standard.string(forKey: "tagline"),
            let region = UserDefaults.standard.string(forKey: "region")
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
                let dataManager = DataManager(
                    modelContext: modelContext,
                    riotClient: RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey),
                    dataDragonService: DataDragonService()
                )

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
                    await MainActor.run {
                        self.currentSummoner = summoner
                        self.isLoggedIn = true
                    }
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
        let dataManager = DataManager(
            modelContext: modelContext,
            riotClient: RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey),
            dataDragonService: DataDragonService()
        )

        // Recreate the summoner
        let summoner = try await dataManager.createOrUpdateSummoner(
            gameName: gameName,
            tagLine: tagLine,
            region: region
        )

        // Load champion data if needed
        try await dataManager.loadChampionData()

        await MainActor.run {
            self.currentSummoner = summoner
            self.isLoggedIn = true
        }

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
        UserDefaults.standard.set(summoner.gameName, forKey: "summonerName")
        UserDefaults.standard.set(summoner.tagLine, forKey: "tagline")
        UserDefaults.standard.set(summoner.region, forKey: "region")

        // Verify credentials were saved
        let savedGameName = UserDefaults.standard.string(forKey: "summonerName")
        let savedTagLine = UserDefaults.standard.string(forKey: "tagline")
        let savedRegion = UserDefaults.standard.string(forKey: "region")
        ClaimbLogger.debug(
            "Credentials saved - gameName: \(savedGameName ?? "nil"), tagLine: \(savedTagLine ?? "nil"), region: \(savedRegion ?? "nil")",
            service: "UserSession",
            metadata: [
                "savedGameName": savedGameName ?? "nil",
                "savedTagLine": savedTagLine ?? "nil",
                "savedRegion": savedRegion ?? "nil"
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
        NotificationCenter.default.post(name: .init("UserSessionDidChange"), object: nil)
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
        NotificationCenter.default.post(name: .init("UserSessionDidChange"), object: nil)
    }

    /// Checks if the user has previously logged in (has stored credentials)
    public var hasStoredCredentials: Bool {
        return UserDefaults.standard.string(forKey: "summonerName") != nil
            && UserDefaults.standard.string(forKey: "tagline") != nil
            && UserDefaults.standard.string(forKey: "region") != nil
    }

    /// Clears stored login credentials
    private func clearStoredCredentials() {
        UserDefaults.standard.removeObject(forKey: "summonerName")
        UserDefaults.standard.removeObject(forKey: "tagline")
        UserDefaults.standard.removeObject(forKey: "region")
    }

    /// Refreshes the current summoner data
    public func refreshSummoner() async {
        guard let currentSummoner = currentSummoner else { return }

        do {
            let dataManager = DataManager(
                modelContext: modelContext,
                riotClient: RiotHTTPClient(apiKey: APIKeyManager.riotAPIKey),
                dataDragonService: DataDragonService()
            )

            // Refresh summoner data
            let refreshedSummoner = try await dataManager.createOrUpdateSummoner(
                gameName: currentSummoner.gameName,
                tagLine: currentSummoner.tagLine,
                region: currentSummoner.region
            )

            await MainActor.run {
                self.currentSummoner = refreshedSummoner
            }
        } catch {
            ClaimbLogger.error("Failed to refresh summoner", service: "UserSession", error: error)
        }
    }

    // MARK: - Primary Role Management

    /// Loads the stored primary role from UserDefaults
    private func loadStoredPrimaryRole() {
        if let storedRole = UserDefaults.standard.string(forKey: "selectedPrimaryRole") {
            selectedPrimaryRole = storedRole
        }
    }

    /// Updates the primary role and persists it
    public func updatePrimaryRole(_ role: String) {
        selectedPrimaryRole = role
        UserDefaults.standard.set(role, forKey: "selectedPrimaryRole")
        ClaimbLogger.info("Primary role updated", service: "UserSession", metadata: ["role": role])
    }

    /// Sets the primary role based on most played role from match data
    public func setPrimaryRoleFromMatchData(roleStats: [RoleStats]) {
        // Only update if we haven't set a role yet or if it's still the default
        if selectedPrimaryRole == "TOP" || selectedPrimaryRole.isEmpty {
            if let mostPlayedRole = roleStats.first(where: { $0.totalGames > 0 }) {
                updatePrimaryRole(mostPlayedRole.role)
            }
        }
    }
}
