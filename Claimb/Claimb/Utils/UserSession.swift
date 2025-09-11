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
public class UserSession: ObservableObject {
    @Published public var isLoggedIn = false
    @Published public var currentSummoner: Summoner?
    
    public var modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkExistingLogin()
    }
    
    /// Checks if there's an existing login session
    private func checkExistingLogin() {
        // Check if we have stored login credentials
        guard let gameName = UserDefaults.standard.string(forKey: "summonerName"),
              let tagLine = UserDefaults.standard.string(forKey: "tagline"),
              let region = UserDefaults.standard.string(forKey: "region") else {
            isLoggedIn = false
            return
        }
        
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
                if let summoner = allSummoners.first(where: { 
                    $0.gameName == gameName && $0.tagLine == tagLine && $0.region == region 
                }) {
                    await MainActor.run {
                        self.currentSummoner = summoner
                        self.isLoggedIn = true
                    }
                } else {
                    // Clear invalid credentials
                    clearStoredCredentials()
                }
            } catch {
                // If there's an error, clear credentials and show login
                clearStoredCredentials()
            }
        }
    }
    
    /// Saves login credentials and sets up the session
    public func login(summoner: Summoner) {
        // Save credentials to UserDefaults
        UserDefaults.standard.set(summoner.gameName, forKey: "summonerName")
        UserDefaults.standard.set(summoner.tagLine, forKey: "tagline")
        UserDefaults.standard.set(summoner.region, forKey: "region")
        
        // Update session state
        self.currentSummoner = summoner
        self.isLoggedIn = true
    }
    
    /// Logs out the user and clears all stored data
    public func logout() {
        // Clear stored credentials
        clearStoredCredentials()
        
        // Update session state
        self.currentSummoner = nil
        self.isLoggedIn = false
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
}
