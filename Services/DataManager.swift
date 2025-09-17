//
//  DataManager.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import Foundation
import SwiftData
import SwiftUI

/// Manages SwiftData operations with cache-first offline strategy
@MainActor
public class DataManager: ObservableObject {
    private let modelContext: ModelContext
    private let riotClient: RiotClient
    private let dataDragonService: DataDragonService
    
    // Cache limits
    private let maxMatchesPerSummoner = 50
    
    @Published public var isLoading = false
    @Published public var lastRefreshTime: Date?
    @Published public var errorMessage: String?
    
    public init(modelContext: ModelContext, riotClient: RiotClient, dataDragonService: DataDragonService) {
        self.modelContext = modelContext
        self.riotClient = riotClient
        self.dataDragonService = dataDragonService
    }
    
    // MARK: - Summoner Management
    
    /// Creates or updates a summoner with account data
    public func createOrUpdateSummoner(gameName: String, tagLine: String, region: String) async throws -> Summoner {
        print("📊 [DataManager] Creating/updating summoner: \(gameName)#\(tagLine) (\(region))")
        
        // Get account data from Riot API
        let accountResponse = try await riotClient.getAccountByRiotId(
            gameName: gameName,
            tagLine: tagLine,
            region: region
        )
        
        // Check if summoner already exists
        let existingSummoner = try await getSummoner(by: accountResponse.puuid)
        
        if let existing = existingSummoner {
            print("📊 [DataManager] Updating existing summoner")
            existing.gameName = gameName
            existing.tagLine = tagLine
            existing.region = region
            existing.lastUpdated = Date()
            
            // Get updated summoner data
            let summonerResponse = try await riotClient.getSummonerByPuuid(
                puuid: accountResponse.puuid,
                region: region
            )
            
            existing.summonerId = summonerResponse.id
            existing.accountId = summonerResponse.accountId
            existing.profileIconId = summonerResponse.profileIconId
            existing.summonerLevel = summonerResponse.summonerLevel
            
            try modelContext.save()
            return existing
        } else {
            print("📊 [DataManager] Creating new summoner")
            let newSummoner = Summoner(
                puuid: accountResponse.puuid,
                gameName: gameName,
                tagLine: tagLine,
                region: region
            )
            
            // Get summoner data
            let summonerResponse = try await riotClient.getSummonerByPuuid(
                puuid: accountResponse.puuid,
                region: region
            )
            
            newSummoner.summonerId = summonerResponse.id
            newSummoner.accountId = summonerResponse.accountId
            newSummoner.profileIconId = summonerResponse.profileIconId
            newSummoner.summonerLevel = summonerResponse.summonerLevel
            
            modelContext.insert(newSummoner)
            try modelContext.save()
            return newSummoner
        }
    }
    
    /// Gets a summoner by PUUID
    public func getSummoner(by puuid: String) async throws -> Summoner? {
        let descriptor = FetchDescriptor<Summoner>(
            predicate: #Predicate { $0.puuid == puuid }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Gets all summoners
    public func getAllSummoners() async throws -> [Summoner] {
        let descriptor = FetchDescriptor<Summoner>()
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Match Management
    
    /// Refreshes match data for a summoner with incremental fetching
    public func refreshMatches(for summoner: Summoner) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get existing matches to determine how many new ones to fetch
            let existingMatches = try await getMatches(for: summoner)
            let existingMatchIds = Set(existingMatches.map { $0.matchId })
            
            // Fetch more matches if we have less than the target
            let targetCount = maxMatchesPerSummoner
            let fetchCount = max(20, targetCount - existingMatches.count) // At least 20 new matches
            
            print("📊 [DataManager] Existing matches: \(existingMatches.count), fetching \(fetchCount) more")
            
            let matchHistory = try await riotClient.getMatchHistory(
                puuid: summoner.puuid,
                region: summoner.region,
                count: fetchCount
            )
            
            var newMatchesCount = 0
            for matchId in matchHistory.history {
                // Skip if we already have this match
                if existingMatchIds.contains(matchId) {
                    continue
                }
                
                try await processMatch(matchId: matchId, region: summoner.region, summoner: summoner)
                newMatchesCount += 1
            }
            
            print("📊 [DataManager] Added \(newMatchesCount) new matches")
            
            try await cleanupOldMatches(for: summoner)
            summoner.lastUpdated = Date()
            lastRefreshTime = Date()
            try modelContext.save()
            
        } catch {
            errorMessage = "Failed to refresh matches: \(error.localizedDescription)"
            throw error
        }
        
        isLoading = false
    }
    
    /// Loads initial match data for a summoner (40 games)
    public func loadInitialMatches(for summoner: Summoner) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            print("📊 [DataManager] Loading initial 40 matches for \(summoner.gameName)")
            
            let matchHistory = try await riotClient.getMatchHistory(
                puuid: summoner.puuid,
                region: summoner.region,
                count: 40
            )
            
            for matchId in matchHistory.history {
                try await processMatch(matchId: matchId, region: summoner.region, summoner: summoner)
            }
            
            summoner.lastUpdated = Date()
            lastRefreshTime = Date()
            try modelContext.save()
            
            print("📊 [DataManager] Loaded \(matchHistory.history.count) initial matches")
            
        } catch {
            errorMessage = "Failed to load initial matches: \(error.localizedDescription)"
            throw error
        }
        
        isLoading = false
    }
    
    /// Processes a single match and stores it in the database
    private func processMatch(matchId: String, region: String, summoner: Summoner) async throws {
        // Check if match already exists
        let existingMatch = try await getMatch(by: matchId)
        if existingMatch != nil {
            print("📊 [DataManager] Match \(matchId) already exists, skipping")
            return
        }
        
        print("📊 [DataManager] Fetching match data for \(matchId)")
        let matchData = try await riotClient.getMatch(matchId: matchId, region: region)
        print("📊 [DataManager] Received \(matchData.count) bytes of match data for \(matchId)")
        
        let match = try await parseMatchData(matchData, matchId: matchId, summoner: summoner)
        
        modelContext.insert(match)
        print("📊 [DataManager] Inserted match \(matchId) with \(match.participants.count) participants")
    }
    
    /// Parses match data from Riot API response
    private func parseMatchData(_ data: Data, matchId: String, summoner: Summoner) async throws -> Match {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let matchJson = json else {
            throw RiotAPIError.decodingError(NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"]))
        }
        
        // Extract match info from nested structure
        guard let info = matchJson["info"] as? [String: Any] else {
            throw RiotAPIError.decodingError(NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing 'info' object in match response"]))
        }
        
        let gameCreation = info["gameCreation"] as? Int ?? 0
        let gameDuration = info["gameDuration"] as? Int ?? 0
        let gameMode = info["gameMode"] as? String ?? "Unknown"
        let gameType = info["gameType"] as? String ?? "Unknown"
        let gameVersion = info["gameVersion"] as? String ?? "Unknown"
        let queueId = info["queueId"] as? Int ?? 0
        let mapId = info["mapId"] as? Int ?? 0
        let gameStartTimestamp = info["gameStartTimestamp"] as? Int ?? 0
        let gameEndTimestamp = info["gameEndTimestamp"] as? Int ?? 0
        
        let match = Match(
            matchId: matchId,
            gameCreation: gameCreation,
            gameDuration: gameDuration,
            gameMode: gameMode,
            gameType: gameType,
            gameVersion: gameVersion,
            queueId: queueId,
            mapId: mapId,
            gameStartTimestamp: gameStartTimestamp,
            gameEndTimestamp: gameEndTimestamp
        )
        
        match.summoner = summoner
        
        // Parse participants from the info object
        if let participantsJson = info["participants"] as? [[String: Any]] {
            print("📊 [DataManager] Found \(participantsJson.count) participants in match \(matchId)")
            for participantJson in participantsJson {
                let participant = try await parseParticipant(participantJson, match: match)
                match.participants.append(participant)
            }
            print("📊 [DataManager] Successfully parsed \(match.participants.count) participants for match \(matchId)")
        } else {
            print("⚠️ [DataManager] No participants found in match \(matchId)")
            print("📊 [DataManager] Available keys in info object: \(Array(info.keys))")
        }
        
        return match
    }
    
    /// Parses a single participant from match data
    private func parseParticipant(_ participantJson: [String: Any], match: Match) async throws -> Participant {
        let puuid = participantJson["puuid"] as? String ?? ""
        let championId = participantJson["championId"] as? Int ?? 0
        let teamId = participantJson["teamId"] as? Int ?? 0
        let lane = participantJson["lane"] as? String ?? "UNKNOWN"
        let role = participantJson["role"] as? String ?? "UNKNOWN"
        
        let kills = participantJson["kills"] as? Int ?? 0
        let deaths = participantJson["deaths"] as? Int ?? 0
        let assists = participantJson["assists"] as? Int ?? 0
        let win = participantJson["win"] as? Bool ?? false
        let largestMultiKill = participantJson["largestMultiKill"] as? Int ?? 0
        let hadAfkTeammate = participantJson["hadAfkTeammate"] as? Int ?? 0
        let gameEndedInSurrender = participantJson["gameEndedInSurrender"] as? Bool ?? false
        let eligibleForProgression = participantJson["eligibleForProgression"] as? Bool ?? true
        
        // Basic stats
        let totalMinionsKilled = participantJson["totalMinionsKilled"] as? Int ?? 0
        let neutralMinionsKilled = participantJson["neutralMinionsKilled"] as? Int ?? 0
        let goldEarned = participantJson["goldEarned"] as? Int ?? 0
        let visionScore = participantJson["visionScore"] as? Int ?? 0
        let totalDamageDealt = participantJson["totalDamageDealt"] as? Int ?? 0
        let totalDamageDealtToChampions = participantJson["totalDamageDealtToChampions"] as? Int ?? 0
        let totalDamageTaken = participantJson["totalDamageTaken"] as? Int ?? 0
        
        // Challenge-based metrics
        let challenges = participantJson["challenges"] as? [String: Any] ?? [:]
        let dragonTakedowns = challenges["dragonTakedowns"] as? Int ?? 0
        let riftHeraldTakedowns = challenges["riftHeraldTakedowns"] as? Int ?? 0
        let baronTakedowns = challenges["baronTakedowns"] as? Int ?? 0
        let hordeTakedowns = challenges["hordeTakedowns"] as? Int ?? 0
        let atakhanTakedowns = challenges["atakhanTakedowns"] as? Int ?? 0
        
        let participant = Participant(
            puuid: puuid,
            championId: championId,
            teamId: teamId,
            lane: lane,
            role: role,
            kills: kills,
            deaths: deaths,
            assists: assists,
            win: win,
            largestMultiKill: largestMultiKill,
            hadAfkTeammate: hadAfkTeammate,
            gameEndedInSurrender: gameEndedInSurrender,
            eligibleForProgression: eligibleForProgression,
            totalMinionsKilled: totalMinionsKilled,
            neutralMinionsKilled: neutralMinionsKilled,
            goldEarned: goldEarned,
            visionScore: visionScore,
            totalDamageDealt: totalDamageDealt,
            totalDamageDealtToChampions: totalDamageDealtToChampions,
            totalDamageTaken: totalDamageTaken,
            dragonTakedowns: dragonTakedowns,
            riftHeraldTakedowns: riftHeraldTakedowns,
            baronTakedowns: baronTakedowns,
            hordeTakedowns: hordeTakedowns,
            atakhanTakedowns: atakhanTakedowns
        )
        
        participant.match = match
        
        // Try to load champion data
        await loadChampionForParticipant(participant)
        
        return participant
    }
    
    /// Loads champion data for a participant
    private func loadChampionForParticipant(_ participant: Participant) async {
        do {
            let descriptor = FetchDescriptor<Champion>()
            let allChampions = try modelContext.fetch(descriptor)
            
            print("📊 [DataManager] Looking for champion with ID \(participant.championId) among \(allChampions.count) champions")
            
            // Try ID matching first, then key matching as fallback
            if let champion = allChampions.first(where: { $0.id == participant.championId }) {
                participant.champion = champion
                print("📊 [DataManager] Found champion by ID: \(champion.name) (ID: \(champion.id), Key: \(champion.key))")
            } else if let champion = allChampions.first(where: { $0.key == String(participant.championId) }) {
                participant.champion = champion
                print("📊 [DataManager] Found champion by key: \(champion.name) (ID: \(champion.id), Key: \(champion.key))")
            } else {
                print("📊 [DataManager] ❌ Champion not found for ID \(participant.championId)")
                // Log available champion IDs for debugging
                let availableIds = allChampions.map { "\($0.id)" }.joined(separator: ", ")
                print("📊 [DataManager] Available champion IDs: \(availableIds)")
            }
            
            // Save the context to ensure the relationship is persisted
            try modelContext.save()
        } catch {
            print("📊 [DataManager] ❌ Error loading champion for participant: \(error)")
        }
    }
    
    /// Gets a match by ID
    public func getMatch(by matchId: String) async throws -> Match? {
        let descriptor = FetchDescriptor<Match>(
            predicate: #Predicate { $0.matchId == matchId }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Gets matches for a summoner
    public func getMatches(for summoner: Summoner, limit: Int = 40) async throws -> [Match] {
        // For now, get all matches and filter manually to avoid SwiftData predicate issues
        let descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\.gameCreation, order: .reverse)]
        )
        let allMatches = try modelContext.fetch(descriptor)
        
        // Filter matches for this summoner
        let filteredMatches = allMatches.filter { match in
            match.summoner?.puuid == summoner.puuid
        }
        
        return Array(filteredMatches.prefix(limit))
    }
    
    /// Cleans up old matches to maintain the cache limit
    private func cleanupOldMatches(for summoner: Summoner) async throws {
        let allMatches = try await getMatches(for: summoner, limit: maxMatchesPerSummoner + 10)
        
        if allMatches.count > maxMatchesPerSummoner {
            let matchesToDelete = Array(allMatches.dropFirst(maxMatchesPerSummoner))
            for match in matchesToDelete {
                modelContext.delete(match)
            }
            print("📊 [DataManager] Cleaned up \(matchesToDelete.count) old matches")
        }
    }
    
    // MARK: - Champion Management
    
    /// Loads champion data from Data Dragon and stores it locally
    public func loadChampionData() async throws {
        // Check if we already have champion data
        let existingChampions = try await getAllChampions()
        if !existingChampions.isEmpty {
            print("📊 [DataManager] Champion data already exists, skipping load")
            return
        }
        
        print("📊 [DataManager] Loading champion data from Data Dragon...")
        let version = try await dataDragonService.getLatestVersion()
        let champions = try await dataDragonService.getChampions(version: version)
        
        print("📊 [DataManager] Loaded \(champions.count) champions for version \(version)")
        
        for (_, championData) in champions {
            let existingChampion = try await getChampion(by: championData.key)
            
            if existingChampion == nil {
                let champion = try Champion(from: championData, version: version)
                print("📊 [DataManager] Creating champion: \(champion.name) (ID: \(champion.id), Key: \(champion.key)) - Icon URL: \(champion.iconURL)")
                modelContext.insert(champion)
            }
        }
        
        try modelContext.save()
    }
    
    /// Gets a champion by key
    public func getChampion(by key: String) async throws -> Champion? {
        let descriptor = FetchDescriptor<Champion>(
            predicate: #Predicate { $0.key == key }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Gets all champions
    public func getAllChampions() async throws -> [Champion] {
        let descriptor = FetchDescriptor<Champion>()
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached data (for debugging/testing)
    public func clearAllCache() async throws {
        print("🗑️ [DataManager] Starting cache clear...")
        
        // Clear matches and participants
        let matchDescriptor = FetchDescriptor<Match>()
        let allMatches = try modelContext.fetch(matchDescriptor)
        for match in allMatches {
            modelContext.delete(match)
        }
        
        let participantDescriptor = FetchDescriptor<Participant>()
        let allParticipants = try modelContext.fetch(participantDescriptor)
        for participant in allParticipants {
            modelContext.delete(participant)
        }
        
        // Reset summoner lastUpdated timestamps
        let summonerDescriptor = FetchDescriptor<Summoner>()
        let allSummoners = try modelContext.fetch(summonerDescriptor)
        for summoner in allSummoners {
            summoner.lastUpdated = Date.distantPast
        }
        
        // Clear baselines
        let baselineDescriptor = FetchDescriptor<Baseline>()
        let allBaselines = try modelContext.fetch(baselineDescriptor)
        for baseline in allBaselines {
            modelContext.delete(baseline)
        }
        
        // Clear champion class mappings
        let mappingDescriptor = FetchDescriptor<ChampionClassMapping>()
        let allMappings = try modelContext.fetch(mappingDescriptor)
        for mapping in allMappings {
            modelContext.delete(mapping)
        }
        
        try modelContext.save()
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Reset last refresh time
        lastRefreshTime = nil
        errorMessage = nil
        
        print("🗑️ [DataManager] Cache clear completed")
    }
    
    /// Clears only match data while preserving summoner and champion data
    public func clearMatchData() async throws {
        print("🗑️ [DataManager] Clearing match data...")
        
        // Clear matches and participants
        let matchDescriptor = FetchDescriptor<Match>()
        let allMatches = try modelContext.fetch(matchDescriptor)
        for match in allMatches {
            modelContext.delete(match)
        }
        
        let participantDescriptor = FetchDescriptor<Participant>()
        let allParticipants = try modelContext.fetch(participantDescriptor)
        for participant in allParticipants {
            modelContext.delete(participant)
        }
        
        // Reset summoner lastUpdated timestamps
        let summonerDescriptor = FetchDescriptor<Summoner>()
        let allSummoners = try modelContext.fetch(summonerDescriptor)
        for summoner in allSummoners {
            summoner.lastUpdated = Date.distantPast
        }
        
        try modelContext.save()
        
        // Reset last refresh time
        lastRefreshTime = nil
        errorMessage = nil
        
        print("🗑️ [DataManager] Match data cleared")
    }
    
    /// Clears only champion data
    public func clearChampionData() async throws {
        print("🗑️ [DataManager] Clearing champion data...")
        
        let championDescriptor = FetchDescriptor<Champion>()
        let allChampions = try modelContext.fetch(championDescriptor)
        for champion in allChampions {
            modelContext.delete(champion)
        }
        
        try modelContext.save()
        
        print("🗑️ [DataManager] Champion data cleared")
    }
    
    /// Clears only baseline data
    public func clearBaselineData() async throws {
        print("🗑️ [DataManager] Clearing baseline data...")
        
        let baselineDescriptor = FetchDescriptor<Baseline>()
        let allBaselines = try modelContext.fetch(baselineDescriptor)
        for baseline in allBaselines {
            modelContext.delete(baseline)
        }
        
        try modelContext.save()
        
        print("🗑️ [DataManager] Baseline data cleared")
    }
    
    /// Clears URL cache only
    public func clearURLCache() {
        print("🗑️ [DataManager] Clearing URL cache...")
        URLCache.shared.removeAllCachedResponses()
        print("🗑️ [DataManager] URL cache cleared")
    }
    
    // MARK: - Statistics
    
    /// Gets match statistics for a summoner
    public func getMatchStatistics(for summoner: Summoner) async throws -> MatchStatistics {
        let matches = try await getMatches(for: summoner)
        
        let totalMatches = matches.count
        let wins = matches.filter { match in
            match.participants.contains { $0.puuid == summoner.puuid && $0.win }
        }.count
        
        let winRate = totalMatches > 0 ? Double(wins) / Double(totalMatches) : 0.0
        
        return MatchStatistics(
            totalMatches: totalMatches,
            wins: wins,
            losses: totalMatches - wins,
            winRate: winRate
        )
    }
    
    // MARK: - Baseline Management
    
    /// Saves a baseline to the database
    public func saveBaseline(_ baseline: Baseline) async throws {
        modelContext.insert(baseline)
        try modelContext.save()
    }
    
    /// Gets a baseline by role, class tag, and metric
    public func getBaseline(role: String, classTag: String, metric: String) async throws -> Baseline? {
        let descriptor = FetchDescriptor<Baseline>(
            predicate: #Predicate { baseline in
                baseline.role == role && baseline.classTag == classTag && baseline.metric == metric
            }
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    /// Gets all baselines for a specific role and class tag
    public func getBaselines(role: String, classTag: String) async throws -> [Baseline] {
        let descriptor = FetchDescriptor<Baseline>(
            predicate: #Predicate { baseline in
                baseline.role == role && baseline.classTag == classTag
            }
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Gets all baselines
    public func getAllBaselines() async throws -> [Baseline] {
        let descriptor = FetchDescriptor<Baseline>()
        return try modelContext.fetch(descriptor)
    }
    
    /// Clears all baselines (for debugging/testing)
    public func clearBaselines() async throws {
        let descriptor = FetchDescriptor<Baseline>()
        let baselines = try modelContext.fetch(descriptor)
        
        for baseline in baselines {
            modelContext.delete(baseline)
        }
        
        try modelContext.save()
    }
    
    /// Loads baseline data from bundled JSON files
    public func loadBaselineData() async throws {
        // Check if we already have baseline data
        let existingBaselines = try await getAllBaselines()
        if !existingBaselines.isEmpty {
            return
        }
        
        // Load baseline data from JSON
        let baselineData = try await loadBaselineJSON()
        
        for item in baselineData {
            let baseline = Baseline(
                role: item.role,
                classTag: item.class_tag,
                metric: item.metric,
                mean: item.mean,
                median: item.median,
                p40: item.p40,
                p60: item.p60
            )
            try await saveBaseline(baseline)
        }
    }
    
    /// Loads champion class mapping from bundled JSON file
    public func loadChampionClassMapping() async throws -> [String: String] {
        let mappingData = try await loadChampionClassMappingJSON()
        var mapping: [String: String] = [:]
        
        for item in mappingData {
            mapping[item.champion_name] = item.primary_class
        }
        
        return mapping
    }
    
    // MARK: - Private JSON Loading Methods
    
    private func loadBaselineJSON() async throws -> [BaselineData] {
        guard let url = Bundle.main.url(forResource: "baselines_clean", withExtension: "json") else {
            throw DataManagerError.missingResource("baselines_clean.json")
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([BaselineData].self, from: data)
    }
    
    private func loadChampionClassMappingJSON() async throws -> [ChampionClassMappingData] {
        guard let url = Bundle.main.url(forResource: "champion_class_mapping_clean", withExtension: "json") else {
            throw DataManagerError.missingResource("champion_class_mapping_clean.json")
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ChampionClassMappingData].self, from: data)
    }
}

// MARK: - Supporting Types

public struct MatchStatistics {
    public let totalMatches: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double
}

// MARK: - Data Transfer Objects

private struct BaselineData: Codable {
    let role: String
    let class_tag: String
    let metric: String
    let mean: Double
    let median: Double
    let p40: Double
    let p60: Double
}

private struct ChampionClassMappingData: Codable {
    let champion_name: String
    let primary_class: String
    let secondary_class: String?
}

// MARK: - DataManager Errors

public enum DataManagerError: Error, LocalizedError {
    case missingResource(String)
    case invalidData(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingResource(let resource):
            return "Missing resource: \(resource)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
