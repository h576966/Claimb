//
//  ClaimbApp.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct ClaimbApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Summoner.self,
            Match.self,
            Participant.self,
            Champion.self,
            Baseline.self,
            CoachingResponseCache.self,
        ])

        // Check if we need to clear the database due to model changes
        let currentVersion = "2.0"  // Increment when making breaking model changes
        let lastVersion = UserDefaults.standard.string(forKey: "ClaimbDataVersion")

        ClaimbLogger.info(
            "Database version check", service: "ClaimbApp",
            metadata: [
                "current": currentVersion,
                "last": lastVersion ?? "nil",
            ])

        if lastVersion != currentVersion {
            ClaimbLogger.warning(
                "Version mismatch detected, performing selective migration", service: "ClaimbApp")
            // Check if we have existing data before clearing
            let hasExistingData = UserDefaults.standard.string(forKey: "summonerName") != nil
            if hasExistingData {
                ClaimbLogger.warning(
                    "Migrating database with existing user data", service: "ClaimbApp")
            }
            // Perform selective migration instead of nuclear clearing
            ClaimbApp.performSelectiveMigration()
            UserDefaults.standard.set(currentVersion, forKey: "ClaimbDataVersion")
        } else {
            ClaimbLogger.debug("Database version matches, no clearing needed", service: "ClaimbApp")
            // Set the version if it doesn't exist (first run)
            if lastVersion == nil {
                UserDefaults.standard.set(currentVersion, forKey: "ClaimbDataVersion")
                ClaimbLogger.info(
                    "Set initial database version", service: "ClaimbApp",
                    metadata: [
                        "version": currentVersion
                    ])
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
        ClaimbLogger.info("Starting database clear", service: "ClaimbApp")

        // Preserve login credentials before clearing database
        let savedGameName = UserDefaults.standard.string(forKey: "summonerName")
        let savedTagLine = UserDefaults.standard.string(forKey: "tagline")
        let savedRegion = UserDefaults.standard.string(forKey: "region")

        ClaimbLogger.info(
            "Preserving credentials", service: "ClaimbApp",
            metadata: [
                "gameName": savedGameName ?? "nil",
                "tagLine": savedTagLine ?? "nil",
                "region": savedRegion ?? "nil",
            ])

        // Clear all UserDefaults first
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        ClaimbLogger.info("UserDefaults cleared", service: "ClaimbApp")

        // Restore login credentials after clearing
        if let gameName = savedGameName {
            UserDefaults.standard.set(gameName, forKey: "summonerName")
            ClaimbLogger.debug(
                "Restored gameName", service: "ClaimbApp", metadata: ["gameName": gameName])
        }
        if let tagLine = savedTagLine {
            UserDefaults.standard.set(tagLine, forKey: "tagline")
            ClaimbLogger.debug(
                "Restored tagLine", service: "ClaimbApp", metadata: ["tagLine": tagLine])
        }
        if let region = savedRegion {
            UserDefaults.standard.set(region, forKey: "region")
            ClaimbLogger.debug(
                "Restored region", service: "ClaimbApp", metadata: ["region": region])
        }

        // Remove the database file to force recreation
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        let storeURL = documentsPath.appendingPathComponent("default.store")

        // Remove all possible database files
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))

        // Also clear from Application Support directory (where SwiftData actually stores files)
        let appSupportPath = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let appSupportStoreURL = appSupportPath.appendingPathComponent("default.store")

        try? FileManager.default.removeItem(at: appSupportStoreURL)
        try? FileManager.default.removeItem(at: appSupportStoreURL.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: appSupportStoreURL.appendingPathExtension("shm"))

        ClaimbLogger.info(
            "Database cleared for migration, login credentials preserved", service: "ClaimbApp")
    }

    /// Performs selective migration instead of nuclear database clearing
    /// Preserves all user data (summoners, matches, participants, champions, baselines)
    private static func performSelectiveMigration() {
        ClaimbLogger.info(
            "Starting selective migration (preserving all user data)", service: "ClaimbApp")

        // For now, we don't need to clear anything since our models are stable
        // This method can be extended in the future if specific migrations are needed
        // For example: clearing specific fields, updating data formats, etc.

        ClaimbLogger.info(
            "Selective migration completed - all user data preserved", service: "ClaimbApp")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
