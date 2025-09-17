//
//  ClaimbApp.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import SwiftUI
import SwiftData

@main
struct ClaimbApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Summoner.self,
            Match.self,
            Participant.self,
            Champion.self,
            Baseline.self
        ])
        
        // Check if we need to clear the database due to model changes
        let currentVersion = "2.0" // Increment when making breaking model changes
        let lastVersion = UserDefaults.standard.string(forKey: "ClaimbDataVersion")
        
        print("🗄️ [ClaimbApp] Database version check - Current: \(currentVersion), Last: \(lastVersion ?? "nil")")
        
        if lastVersion != currentVersion {
            print("🗄️ [ClaimbApp] Version mismatch detected, clearing database...")
            // Check if we have existing data before clearing
            let hasExistingData = UserDefaults.standard.string(forKey: "summonerName") != nil
            if hasExistingData {
                print("🗄️ [ClaimbApp] WARNING: Clearing database with existing user data!")
            }
            // Clear the database for breaking changes
            clearDatabase()
            UserDefaults.standard.set(currentVersion, forKey: "ClaimbDataVersion")
        } else {
            print("🗄️ [ClaimbApp] Database version matches, no clearing needed")
            // Set the version if it doesn't exist (first run)
            if lastVersion == nil {
                UserDefaults.standard.set(currentVersion, forKey: "ClaimbDataVersion")
                print("🗄️ [ClaimbApp] Set initial database version: \(currentVersion)")
            }
        }
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If still failing, try clearing and recreating
            clearDatabase()
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()
    
    private static func clearDatabase() {
        print("🗑️ [ClaimbApp] Starting database clear...")
        
        // Preserve login credentials before clearing database
        let savedGameName = UserDefaults.standard.string(forKey: "summonerName")
        let savedTagLine = UserDefaults.standard.string(forKey: "tagline")
        let savedRegion = UserDefaults.standard.string(forKey: "region")
        
        print("🗑️ [ClaimbApp] Preserving credentials: \(savedGameName ?? "nil")#\(savedTagLine ?? "nil") (\(savedRegion ?? "nil"))")
        
        // Clear all UserDefaults first
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        print("🗑️ [ClaimbApp] UserDefaults cleared")
        
        // Restore login credentials after clearing
        if let gameName = savedGameName {
            UserDefaults.standard.set(gameName, forKey: "summonerName")
            print("🗑️ [ClaimbApp] Restored gameName: \(gameName)")
        }
        if let tagLine = savedTagLine {
            UserDefaults.standard.set(tagLine, forKey: "tagline")
            print("🗑️ [ClaimbApp] Restored tagLine: \(tagLine)")
        }
        if let region = savedRegion {
            UserDefaults.standard.set(region, forKey: "region")
            print("🗑️ [ClaimbApp] Restored region: \(region)")
        }
        
        // Remove the database file to force recreation
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeURL = documentsPath.appendingPathComponent("default.store")
        
        // Remove all possible database files
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
        
        // Also clear from Application Support directory (where SwiftData actually stores files)
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appSupportStoreURL = appSupportPath.appendingPathComponent("default.store")
        
        try? FileManager.default.removeItem(at: appSupportStoreURL)
        try? FileManager.default.removeItem(at: appSupportStoreURL.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: appSupportStoreURL.appendingPathExtension("shm"))
        
        print("🗑️ [ClaimbApp] Database cleared for migration, login credentials preserved")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
