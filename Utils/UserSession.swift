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
        print("🔐 [UserSession] Starting login check...")

        // Check if we have stored login credentials
        guard let gameName = UserDefaults.standard.string(forKey: "summonerName"),
            let tagLine = UserDefaults.standard.string(forKey: "tagline"),
            let region = UserDefaults.standard.string(forKey: "region")
        else {
            print("🔐 [UserSession] No stored credentials found")
            isLoggedIn = false
            return
        }

        print("🔐 [UserSession] Found stored credentials: \(gameName)#\(tagLine) (\(region))")

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
                print("🔐 [UserSession] Found \(allSummoners.count) summoners in database")

                if let summoner = allSummoners.first(where: {
                    $0.gameName == gameName && $0.tagLine == tagLine && $0.region == region
                }) {
                    print(
                        "🔐 [UserSession] Found existing summoner in database: \(summoner.gameName)#\(summoner.tagLine)"
                    )
                    await MainActor.run {
                        self.currentSummoner = summoner
                        self.isLoggedIn = true
                    }
                } else {
                    // Summoner not found in database, but we have credentials
                    // Try to recreate the summoner from stored credentials
                    print(
                        "🔐 [UserSession] Summoner not found in database, recreating from stored credentials"
                    )
                    try await recreateSummonerFromCredentials(
                        gameName: gameName, tagLine: tagLine, region: region)
                }
            } catch {
                print("🔐 [UserSession] Error during login check: \(error)")
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

        print("🔐 [UserSession] Successfully recreated summoner from stored credentials")
    }

    /// Saves login credentials and sets up the session
    public func login(summoner: Summoner) {
        print("🔐 [UserSession] Starting login process for \(summoner.gameName)#\(summoner.tagLine)")

        // Save credentials to UserDefaults
        UserDefaults.standard.set(summoner.gameName, forKey: "summonerName")
        UserDefaults.standard.set(summoner.tagLine, forKey: "tagline")
        UserDefaults.standard.set(summoner.region, forKey: "region")

        // Verify credentials were saved
        let savedGameName = UserDefaults.standard.string(forKey: "summonerName")
        let savedTagLine = UserDefaults.standard.string(forKey: "tagline")
        let savedRegion = UserDefaults.standard.string(forKey: "region")
        print(
            "🔐 [UserSession] Credentials saved - gameName: \(savedGameName ?? "nil"), tagLine: \(savedTagLine ?? "nil"), region: \(savedRegion ?? "nil")"
        )

        // Update session state
        self.currentSummoner = summoner
        self.isLoggedIn = true

        print(
            "🔐 [UserSession] Login completed - isLoggedIn: \(isLoggedIn), summoner: \(summoner.gameName)"
        )

        // Post notification to trigger view updates
        NotificationCenter.default.post(name: .init("UserSessionDidChange"), object: nil)
    }

    /// Logs out the user and clears all stored data
    public func logout() {
        print("🔐 [UserSession] Logging out user")

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
            print("Failed to refresh summoner: \(error)")
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
        print("🎯 [UserSession] Primary role updated to: \(role)")
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
