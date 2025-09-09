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
        
        if lastVersion != currentVersion {
            // Clear the database for breaking changes
            clearDatabase()
            UserDefaults.standard.set(currentVersion, forKey: "ClaimbDataVersion")
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
        
        print("🗑️ [ClaimbApp] Database cleared for migration")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
