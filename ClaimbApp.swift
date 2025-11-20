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
    private let sharedModelContainer: ModelContainer
    @StateObject private var healthMonitor: AppHealthMonitor

    init() {
        let schema = Schema([
            Summoner.self,
            Match.self,
            Participant.self,
            Champion.self,
            Baseline.self,
            CoachingResponseCache.self,
        ])

        ClaimbApp.prepareDataStoreMetadata()
        sharedModelContainer = ClaimbApp.createModelContainer(with: schema)
        _healthMonitor = StateObject(wrappedValue: AppHealthMonitor.shared)
    }

    private static func prepareDataStoreMetadata() {
        let currentVersion = "2.0"  // Increment when making breaking model changes
        let lastVersion = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.dataVersion)

        ClaimbLogger.info(
            "Database version check", service: "ClaimbApp",
            metadata: [
                "current": currentVersion,
                "last": lastVersion ?? "nil",
            ])

        if lastVersion != currentVersion {
            ClaimbLogger.warning(
                "Version mismatch detected, performing selective migration", service: "ClaimbApp")
            let hasExistingData = UserDefaults.standard.string(
                forKey: AppConstants.UserDefaultsKeys.summonerName) != nil
            if hasExistingData {
                ClaimbLogger.warning(
                    "Migrating database with existing user data", service: "ClaimbApp")
            }
            ClaimbApp.performSelectiveMigration()
            UserDefaults.standard.set(currentVersion, forKey: AppConstants.UserDefaultsKeys.dataVersion)
        } else if lastVersion == nil {
            UserDefaults.standard.set(currentVersion, forKey: AppConstants.UserDefaultsKeys.dataVersion)
            ClaimbLogger.info(
                "Set initial database version", service: "ClaimbApp",
                metadata: [
                    "version": currentVersion
                ])
        } else {
            ClaimbLogger.debug("Database version matches, no clearing needed", service: "ClaimbApp")
        }
    }

    private static func createModelContainer(with schema: Schema) -> ModelContainer {
        let persistentConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [persistentConfig])
        } catch {
            ClaimbLogger.error(
                "Failed to create persistent ModelContainer", service: "ClaimbApp", error: error)
            clearDatabase()
            do {
                return try ModelContainer(for: schema, configurations: [persistentConfig])
            } catch {
                ClaimbLogger.error(
                    "Failed to recreate persistent ModelContainer after clearing database",
                    service: "ClaimbApp", error: error)
                AppHealthReporter.report(
                    LaunchIssue(
                        title: "Data Storage Unavailable",
                        message:
                            "Claimb could not access its local database. Your cached data will be unavailable in this session.",
                        severity: .critical))

                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                if let fallback = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
                    return fallback
                }

                // As a last resort, crash with context rather than silently failing
                fatalError("Could not create any ModelContainer instance")
            }
        }
    }

    private static func clearDatabase() {
        ClaimbLogger.info("Starting database clear", service: "ClaimbApp")

        // Preserve login credentials before clearing database
        let savedGameName = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.summonerName)
        let savedTagLine = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.tagline)
        let savedRegion = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.region)

        ClaimbLogger.info(
            "Preserving credentials", service: "ClaimbApp",
            metadata: [
                "gameName": savedGameName ?? "nil",
                "tagLine": savedTagLine ?? "nil",
                "region": savedRegion ?? "nil",
            ])

        // Clear all UserDefaults first
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            ClaimbLogger.info("UserDefaults cleared", service: "ClaimbApp")
        } else {
            ClaimbLogger.warning(
                "Unable to determine bundle identifier while clearing database", service: "ClaimbApp")
        }

        // Restore login credentials after clearing
        if let gameName = savedGameName {
            UserDefaults.standard.set(gameName, forKey: AppConstants.UserDefaultsKeys.summonerName)
            ClaimbLogger.debug(
                "Restored gameName", service: "ClaimbApp", metadata: ["gameName": gameName])
        }
        if let tagLine = savedTagLine {
            UserDefaults.standard.set(tagLine, forKey: AppConstants.UserDefaultsKeys.tagline)
            ClaimbLogger.debug(
                "Restored tagLine", service: "ClaimbApp", metadata: ["tagLine": tagLine])
        }
        if let region = savedRegion {
            UserDefaults.standard.set(region, forKey: AppConstants.UserDefaultsKeys.region)
            ClaimbLogger.debug(
                "Restored region", service: "ClaimbApp", metadata: ["region": region])
        }

        // Remove the database file to force recreation
        if let documentsPath = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first {
            let storeURL = documentsPath.appendingPathComponent("default.store")
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
        } else {
            ClaimbLogger.warning(
                "Unable to find documents directory when clearing database", service: "ClaimbApp")
        }

        if let appSupportPath = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first {
            let appSupportStoreURL = appSupportPath.appendingPathComponent("default.store")
            try? FileManager.default.removeItem(at: appSupportStoreURL)
            try? FileManager.default.removeItem(at: appSupportStoreURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: appSupportStoreURL.appendingPathExtension("shm"))
        } else {
            ClaimbLogger.warning(
                "Unable to find application support directory when clearing database",
                service: "ClaimbApp")
        }

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
                .environmentObject(healthMonitor)
        }
        .modelContainer(sharedModelContainer)
    }
}
