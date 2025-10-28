//
//  AppConstants.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Application-wide constants for consistent configuration
enum AppConstants {

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let dataVersion = "ClaimbDataVersion"
        static let championsLoadedVersion = "championsLoadedVersion"
        static let baselinesLoadedVersion = "baselinesLoadedVersion"
        static let kpiCachePrefix = "kpiCache_"
        
        // User Session
        static let summonerName = "summonerName"
        static let tagline = "tagline"
        static let region = "region"
        static let selectedPrimaryRole = "selectedPrimaryRole"
        
        // Onboarding
        static let hasSeenOnboarding = "hasSeenOnboarding"
        
        // Goals System
        static let primaryGoalKPI = "primaryGoalKPI"
        static let focusType = "focusType"
        static let learningChampion = "learningChampion"
        static let learningRole = "learningRole"
        static let goalSetDate = "goalSetDate"
    }

    // MARK: - Champion Filtering

    enum ChampionFiltering {
        static let minimumGamesForBestPerforming = 3
        static let defaultWinRateThreshold = 0.50  // 50%
        static let fallbackWinRateThreshold = 0.40  // 40%
        static let minimumChampionsForFallback = 3
    }

    // MARK: - Champion KPIs

    enum ChampionKPIs {
        /// Most important metrics by role (3 key metrics per role)
        static let keyMetricsByRole: [String: [String]] = [
            "BOTTOM": ["cs_per_min", "team_damage_pct", "deaths_per_game"],
            "MIDDLE": ["cs_per_min", "kill_participation_pct", "deaths_per_game"],
            "TOP": ["cs_per_min", "damage_taken_share_pct", "deaths_per_game"],
            "JUNGLE": ["objective_participation_pct", "kill_participation_pct", "deaths_per_game"],
            "UTILITY": ["vision_score_per_min", "kill_participation_pct", "deaths_per_game"],
        ]
    }

    // MARK: - Data Freshness

    enum Freshness {
        static let matchesMinRefreshIntervalSeconds: TimeInterval = 600  // 10 minutes
    }

    // MARK: - Logging Service Names

    enum LoggingServices {
        static let dataManager = "DataManager"
        static let matchDataViewModel = "MatchDataViewModel"
        static let championDataLoader = "ChampionDataLoader"
        static let baselineDataLoader = "BaselineDataLoader"
        static let matchParser = "MatchParser"
        static let proxyService = "ProxyService"
        static let riotProxyClient = "RiotProxyClient"
        static let roleUtils = "RoleUtils"
        static let claimbApp = "ClaimbApp"
    }
}
