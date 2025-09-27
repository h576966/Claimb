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
@Observable
public class DataManager {
    private let modelContext: ModelContext
    private let riotClient: RiotClient
    private let dataDragonService: DataDragonServiceProtocol

    // Cache limits
    private let maxMatchesPerSummoner = 100  // Increased from 50 to 100
    private let maxGameAgeInDays = 365  // Filter out games older than 1 year

    // Request deduplication
    private var activeRequests: Set<String> = []
    private var requestQueue: [String: Task<UIState<[Match]>, Never>] = [:]
    private var championRequestQueue: [String: Task<UIState<[Champion]>, Never>] = [:]
    private var summonerRequestQueue: [String: Task<UIState<Summoner>, Never>] = [:]
    private var baselineRequestQueue: [String: Task<UIState<Void>, Never>] = [:]

    public var isLoading = false
    public var lastRefreshTime: Date?
    public var errorMessage: String?

    public init(
        modelContext: ModelContext, riotClient: RiotClient,
        dataDragonService: DataDragonServiceProtocol
    ) {
        self.modelContext = modelContext
        self.riotClient = riotClient
        self.dataDragonService = dataDragonService
    }

    // MARK: - Summoner Management

    /// Creates or updates a summoner with account data
    public func createOrUpdateSummonerInternal(gameName: String, tagLine: String, region: String)
        async throws -> Summoner
    {
        ClaimbLogger.info(
            "Creating/updating summoner", service: "DataManager",
            metadata: [
                "gameName": gameName,
                "tagLine": tagLine,
                "region": region,
            ])

        // Get account data from Riot API
        let accountResponse = try await riotClient.getAccountByRiotId(
            gameName: gameName,
            tagLine: tagLine,
            region: region
        )

        // Check if summoner already exists
        let existingSummoner = try await getSummoner(by: accountResponse.puuid)

        if let existing = existingSummoner {
            ClaimbLogger.debug("Updating existing summoner", service: "DataManager")
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
            ClaimbLogger.debug("Creating new summoner", service: "DataManager")
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

    /// Forces a refresh of matches (bypasses cache)
    public func forceRefreshMatches(for summoner: Summoner) async -> UIState<[Match]> {
        ClaimbLogger.info(
            "Force refreshing matches", service: "DataManager",
            metadata: ["summoner": summoner.gameName])

        do {
            try await refreshMatchesInternal(for: summoner)
            let refreshedMatches = try await getMatches(for: summoner)
            return .loaded(refreshedMatches)
        } catch {
            ClaimbLogger.error(
                "Failed to force refresh matches", service: "DataManager", error: error)
            return .error(error)
        }
    }

    /// Refreshes match data for a summoner with efficient incremental fetching
    public func refreshMatchesInternal(for summoner: Summoner) async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Get existing matches to determine how many new ones to fetch
            let existingMatches = try await getMatches(for: summoner)
            let existingMatchIds = Set(existingMatches.map { $0.matchId })

            // Efficient incremental fetching strategy
            let targetCount = maxMatchesPerSummoner
            let currentCount = existingMatches.count

            // Only fetch if we're below target or if matches are very old
            guard currentCount < targetCount else {
                ClaimbLogger.debug(
                    "Already at target match count, skipping refresh", service: "DataManager",
                    metadata: [
                        "currentCount": String(currentCount),
                        "targetCount": String(targetCount),
                    ])
                return
            }

            // Calculate how many new matches to fetch
            let neededMatches = targetCount - currentCount
            let fetchCount = min(neededMatches, 20)  // Conservative: fetch max 20 new matches per refresh

            ClaimbLogger.debug(
                "Incremental fetch: need \(neededMatches), fetching \(fetchCount) new matches",
                service: "DataManager",
                metadata: [
                    "currentCount": String(currentCount),
                    "neededMatches": String(neededMatches),
                    "fetchCount": String(fetchCount),
                ]
            )

            let matchHistory = try await riotClient.getMatchHistory(
                puuid: summoner.puuid,
                region: summoner.region,
                count: fetchCount
            )

            var newMatchesCount = 0
            var skippedMatchesCount = 0
            for matchId in matchHistory.history {
                // Skip if we already have this match
                if existingMatchIds.contains(matchId) {
                    continue
                }

                do {
                    try await processMatch(
                        matchId: matchId, region: summoner.region, summoner: summoner)
                    newMatchesCount += 1
                } catch MatchFilterError.irrelevantMatch {
                    skippedMatchesCount += 1
                    // Continue processing other matches
                }
            }

            ClaimbLogger.dataOperation(
                "Added new matches", count: newMatchesCount, service: "DataManager")

            if skippedMatchesCount > 0 {
                ClaimbLogger.debug(
                    "Skipped irrelevant matches", service: "DataManager",
                    metadata: [
                        "skippedCount": String(skippedMatchesCount),
                        "addedCount": String(newMatchesCount),
                    ])
            }

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

    /// Loads initial match data for a summoner (bulk load for first time)
    public func loadInitialMatches(for summoner: Summoner) async throws {
        isLoading = true
        errorMessage = nil

        do {
            ClaimbLogger.info(
                "Bulk loading initial matches", service: "DataManager",
                metadata: [
                    "gameName": summoner.gameName,
                    "count": "100",  // API limit is 100 matches per request
                ])

            // Bulk fetch: get maximum matches in one request
            let matchHistory = try await riotClient.getMatchHistory(
                puuid: summoner.puuid,
                region: summoner.region,
                count: 100  // API limit: maximum 100 matches per request
            )

            var addedMatchesCount = 0
            var skippedMatchesCount = 0
            for matchId in matchHistory.history {
                do {
                    try await processMatch(
                        matchId: matchId, region: summoner.region, summoner: summoner)
                    addedMatchesCount += 1
                } catch MatchFilterError.irrelevantMatch {
                    skippedMatchesCount += 1
                    // Continue processing other matches
                }
            }

            summoner.lastUpdated = Date()
            lastRefreshTime = Date()
            try modelContext.save()

            ClaimbLogger.dataOperation(
                "Bulk loaded initial matches", count: addedMatchesCount, service: "DataManager")

            if skippedMatchesCount > 0 {
                ClaimbLogger.debug(
                    "Skipped irrelevant matches during bulk load", service: "DataManager",
                    metadata: [
                        "skippedCount": String(skippedMatchesCount),
                        "addedCount": String(addedMatchesCount),
                    ])
            }

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
            ClaimbLogger.cache(
                "Match already exists, skipping", key: matchId, service: "DataManager")
            return
        }

        ClaimbLogger.apiRequest("match/\(matchId)", service: "DataManager")

        do {
            let matchData = try await riotClient.getMatch(matchId: matchId, region: region)
            ClaimbLogger.debug(
                "Received match data", service: "DataManager",
                metadata: [
                    "matchId": matchId,
                    "bytes": String(matchData.count),
                ])

            do {
                let match = try await parseMatchData(
                    matchData, matchId: matchId, summoner: summoner)

                modelContext.insert(match)
                ClaimbLogger.debug(
                    "Inserted match \(matchId) with \(match.participants.count) participants",
                    service: "DataManager",
                    metadata: [
                        "matchId": matchId,
                        "participantCount": String(match.participants.count),
                    ]
                )
            } catch MatchFilterError.irrelevantMatch {
                // Skip irrelevant matches silently - this is expected behavior
                ClaimbLogger.debug(
                    "Skipped irrelevant match", service: "DataManager",
                    metadata: ["matchId": matchId])
                throw MatchFilterError.irrelevantMatch
            }
        } catch RiotAPIError.serverError(let statusCode) where statusCode == 400 {
            // Handle 400 errors gracefully - match might be invalid or unavailable
            ClaimbLogger.warning(
                "Match unavailable (400 error), skipping", service: "DataManager",
                metadata: [
                    "matchId": matchId,
                    "statusCode": String(statusCode),
                ])
            throw MatchFilterError.irrelevantMatch
        } catch RiotAPIError.notFound {
            // Handle 404 errors gracefully - match not found
            ClaimbLogger.warning(
                "Match not found (404 error), skipping", service: "DataManager",
                metadata: ["matchId": matchId])
            throw MatchFilterError.irrelevantMatch
        } catch {
            // Log other errors but continue processing
            ClaimbLogger.error(
                "Failed to fetch match details, skipping", service: "DataManager",
                error: error,
                metadata: ["matchId": matchId])
            throw MatchFilterError.irrelevantMatch
        }
    }

    /// Checks if a match is relevant for analysis (Ranked, Draft, Summoner's Rift only, within 1 year, minimum 10 minutes)
    private func isRelevantMatch(
        gameMode: String, gameType: String, queueId: Int, mapId: Int, gameCreation: Int,
        gameDuration: Int
    ) -> Bool {
        // Must be on Summoner's Rift (mapId 11)
        guard mapId == 11 else { return false }

        // Must be a classic matched game
        guard gameMode.uppercased() == "CLASSIC" && gameType.uppercased() == "MATCHED_GAME" else {
            return false
        }

        // Must be a relevant queue type
        let relevantQueues = [420, 440, 400]  // Ranked Solo/Duo, Ranked Flex, Normal Draft
        guard relevantQueues.contains(queueId) else { return false }

        // Must be within the last year (filter out old games)
        let gameDate = Date(timeIntervalSince1970: TimeInterval(gameCreation) / 1000.0)
        let oneYearAgo =
            Calendar.current.date(byAdding: .day, value: -maxGameAgeInDays, to: Date()) ?? Date()
        guard gameDate >= oneYearAgo else {
            ClaimbLogger.debug(
                "Skipping old match", service: "DataManager",
                metadata: [
                    "gameDate": gameDate.formatted(date: .abbreviated, time: .omitted),
                    "oneYearAgo": oneYearAgo.formatted(date: .abbreviated, time: .omitted),
                    "daysOld": String(
                        Calendar.current.dateComponents([.day], from: gameDate, to: Date()).day ?? 0
                    ),
                ])
            return false
        }

        // Must be at least 10 minutes long (filter out surrender games and remakes)
        let minimumDurationSeconds = 10 * 60  // 10 minutes in seconds
        guard gameDuration >= minimumDurationSeconds else {
            ClaimbLogger.debug(
                "Skipping short match", service: "DataManager",
                metadata: [
                    "gameDuration": String(gameDuration),
                    "minimumDuration": String(minimumDurationSeconds),
                    "durationMinutes": String(gameDuration / 60),
                ])
            return false
        }

        return true
    }

    /// Parses match data from Riot API response
    private func parseMatchData(_ data: Data, matchId: String, summoner: Summoner) async throws
        -> Match
    {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let matchJson = json else {
            throw RiotAPIError.decodingError(
                NSError(
                    domain: "DataManager", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"]))
        }

        // Extract match info from nested structure
        guard let info = matchJson["info"] as? [String: Any] else {
            throw RiotAPIError.decodingError(
                NSError(
                    domain: "DataManager", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'info' object in match response"]
                ))
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

        // Filter out irrelevant matches BEFORE creating Match object
        // This prevents storing ARAM, Swiftplay, old games, short games, and other non-relevant game types
        if !isRelevantMatch(
            gameMode: gameMode, gameType: gameType, queueId: queueId, mapId: mapId,
            gameCreation: gameCreation, gameDuration: gameDuration)
        {
            ClaimbLogger.debug(
                "Skipping irrelevant match", service: "DataManager",
                metadata: [
                    "matchId": matchId,
                    "gameMode": gameMode,
                    "gameType": gameType,
                    "queueId": String(queueId),
                    "mapId": String(mapId),
                    "gameCreation": String(gameCreation),
                ])
            // Throw a specific error that can be caught and handled gracefully
            throw MatchFilterError.irrelevantMatch
        }

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
            ClaimbLogger.debug(
                "Found \(participantsJson.count) participants in match \(matchId)",
                service: "DataManager",
                metadata: [
                    "matchId": matchId,
                    "participantCount": String(participantsJson.count),
                ]
            )
            for participantJson in participantsJson {
                let participant = try await parseParticipant(participantJson, match: match)
                match.participants.append(participant)
            }
            ClaimbLogger.debug(
                "Successfully parsed \(match.participants.count) participants for match \(matchId)",
                service: "DataManager",
                metadata: [
                    "matchId": matchId,
                    "parsedCount": String(match.participants.count),
                ]
            )
        } else {
            ClaimbLogger.warning(
                "No participants found in match", service: "DataManager",
                metadata: [
                    "matchId": matchId,
                    "availableKeys": Array(info.keys).joined(separator: ","),
                ])
        }

        return match
    }

    /// Parses a single participant from match data
    private func parseParticipant(_ participantJson: [String: Any], match: Match) async throws
        -> Participant
    {
        let puuid = participantJson["puuid"] as? String ?? ""
        let championId = participantJson["championId"] as? Int ?? 0
        let teamId = participantJson["teamId"] as? Int ?? 0
        let lane = participantJson["lane"] as? String ?? "UNKNOWN"
        let role = participantJson["role"] as? String ?? "UNKNOWN"
        let teamPosition = participantJson["teamPosition"] as? String ?? role

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
        let totalDamageDealtToChampions =
            participantJson["totalDamageDealtToChampions"] as? Int ?? 0
        let totalDamageTaken = participantJson["totalDamageTaken"] as? Int ?? 0

        // Challenge-based metrics
        let challenges = participantJson["challenges"] as? [String: Any] ?? [:]
        let dragonTakedowns = challenges["dragonTakedowns"] as? Int ?? 0
        let riftHeraldTakedowns = challenges["riftHeraldTakedowns"] as? Int ?? 0
        let baronTakedowns = challenges["baronTakedowns"] as? Int ?? 0
        let hordeTakedowns = challenges["hordeTakedowns"] as? Int ?? 0
        let atakhanTakedowns = challenges["atakhanTakedowns"] as? Int ?? 0

        // Debug logging for challenge data
        ClaimbLogger.debug(
            "Challenge data for participant", service: "DataManager",
            metadata: [
                "championId": String(championId),
                "challengeKeys": Array(challenges.keys).joined(separator: ", "),
                "teamDamagePercentage": String(challenges["teamDamagePercentage"] as? Double ?? -1),
                "killParticipation": String(challenges["killParticipation"] as? Double ?? -1),
                "damageTakenSharePercentage": String(
                    challenges["damageTakenSharePercentage"] as? Double ?? -1),
            ]
        )

        // Challenge-based percentage metrics - try different possible key names
        let killParticipationFromChallenges =
            challenges["killParticipation"] as? Double ?? challenges[
                "killParticipationFromChallenges"] as? Double
        let teamDamagePercentageFromChallenges =
            challenges["teamDamagePercentage"] as? Double ?? challenges[
                "teamDamagePercentageFromChallenges"] as? Double ?? challenges["teamDamageShare"]
            as? Double
        let damageTakenSharePercentageFromChallenges =
            challenges["damageTakenSharePercentage"] as? Double ?? challenges[
                "damageTakenSharePercentageFromChallenges"] as? Double ?? challenges[
                "damageTakenShare"] as? Double

        let participant = Participant(
            puuid: puuid,
            championId: championId,
            teamId: teamId,
            lane: lane,
            role: role,
            teamPosition: teamPosition,
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

        // Set challenge-based metrics after initialization
        participant.killParticipationFromChallenges = killParticipationFromChallenges
        participant.teamDamagePercentageFromChallenges = teamDamagePercentageFromChallenges
        participant.damageTakenSharePercentageFromChallenges =
            damageTakenSharePercentageFromChallenges

        participant.match = match

        // Try to load champion data
        await loadChampionForParticipant(participant)

        return participant
    }

    /// Loads champion data for a participant
    private func loadChampionForParticipant(_ participant: Participant) async {
        // Simple validation - if champion already exists, skip
        guard participant.champion == nil else {
            ClaimbLogger.debug("Champion already loaded for participant", service: "DataManager")
            return
        }

        do {
            let descriptor = FetchDescriptor<Champion>()
            let allChampions = try modelContext.fetch(descriptor)

            ClaimbLogger.debug(
                "Looking for champion with ID \(participant.championId) among \(allChampions.count) champions",
                service: "DataManager",
                metadata: [
                    "championId": String(participant.championId),
                    "totalChampions": String(allChampions.count),
                ]
            )

            // Try ID matching first, then key matching as fallback
            if let champion = allChampions.first(where: { $0.id == participant.championId }) {
                participant.champion = champion
                ClaimbLogger.debug(
                    "Found champion by ID: \(champion.name) (ID: \(champion.id), Key: \(champion.key))",
                    service: "DataManager",
                    metadata: [
                        "championName": champion.name,
                        "championId": String(champion.id),
                        "championKey": champion.key,
                    ]
                )
            } else if let champion = allChampions.first(where: {
                $0.key == String(participant.championId)
            }) {
                participant.champion = champion
                ClaimbLogger.debug(
                    "Found champion by key: \(champion.name) (ID: \(champion.id), Key: \(champion.key))",
                    service: "DataManager",
                    metadata: [
                        "championName": champion.name,
                        "championId": String(champion.id),
                        "championKey": champion.key,
                    ]
                )
            } else {
                let availableIds = allChampions.map { "\($0.id)" }.joined(separator: ", ")
                ClaimbLogger.warning(
                    "Champion not found for participant", service: "DataManager",
                    metadata: [
                        "championId": String(participant.championId),
                        "availableIds": availableIds,
                    ])
                // Don't fail the entire operation - just log and continue
            }

            // Save the context to ensure the relationship is persisted
            try modelContext.save()
        } catch {
            ClaimbLogger.error(
                "Error loading champion for participant", service: "DataManager", error: error)
            // Don't fail the entire operation - just log and continue
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
    public func getMatches(for summoner: Summoner, limit: Int = 100) async throws -> [Match] {
        // For now, get all matches and filter manually to avoid SwiftData predicate issues
        let descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\.gameCreation, order: .reverse)]
        )
        let allMatches = try modelContext.fetch(descriptor)

        // Filter matches for this summoner and apply role analysis filter
        let filteredMatches = allMatches.filter { match in
            match.summoner?.puuid == summoner.puuid && match.isIncludedInRoleAnalysis
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
            ClaimbLogger.debug(
                "Cleaned up \(matchesToDelete.count) old matches",
                service: "DataManager",
                metadata: [
                    "deletedCount": String(matchesToDelete.count)
                ]
            )
        }
    }

    // MARK: - Champion Management

    /// Loads champion data from Data Dragon and stores it locally
    public func loadChampionData() async throws {
        // Check if we already have champion data
        let existingChampions = try await getAllChampions()
        if !existingChampions.isEmpty {
            ClaimbLogger.debug(
                "Champion data already exists, skipping load", service: "DataManager")
            return
        }

        ClaimbLogger.info("Loading champion data from Data Dragon...", service: "DataManager")
        let version = try await dataDragonService.getLatestVersion()
        let champions = try await dataDragonService.getChampions(version: version)

        ClaimbLogger.info(
            "Loaded \(champions.count) champions for version \(version)",
            service: "DataManager",
            metadata: [
                "championCount": String(champions.count),
                "version": version,
            ]
        )

        for (_, championData) in champions {
            let existingChampion = try await getChampion(by: championData.key)

            if existingChampion == nil {
                let champion = try Champion(from: championData, version: version)
                ClaimbLogger.debug(
                    "Creating champion: \(champion.name) (ID: \(champion.id), Key: \(champion.key)) - Icon URL: \(champion.iconURL)",
                    service: "DataManager",
                    metadata: [
                        "championName": champion.name,
                        "championId": String(champion.id),
                        "championKey": champion.key,
                        "iconURL": champion.iconURL,
                    ]
                )
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

    /// Clears all cached data (for debugging/testing) - internal
    public func clearAllCacheInternal() async throws {
        ClaimbLogger.info("Starting cache clear...", service: "DataManager")

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

        // Champion class mappings are now loaded directly from JSON in Champion model

        try modelContext.save()

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Reset last refresh time
        lastRefreshTime = nil
        errorMessage = nil

        ClaimbLogger.info("Cache clear completed", service: "DataManager")
    }

    /// Clears only match data while preserving summoner and champion data
    public func clearMatchData() async throws {
        ClaimbLogger.info("Clearing match data...", service: "DataManager")

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

        ClaimbLogger.info("Match data cleared", service: "DataManager")
    }

    /// Clears only champion data
    public func clearChampionData() async throws {
        ClaimbLogger.info("Clearing champion data...", service: "DataManager")

        let championDescriptor = FetchDescriptor<Champion>()
        let allChampions = try modelContext.fetch(championDescriptor)
        for champion in allChampions {
            modelContext.delete(champion)
        }

        try modelContext.save()

        ClaimbLogger.info("Champion data cleared", service: "DataManager")
    }

    /// Clears only baseline data
    public func clearBaselineData() async throws {
        ClaimbLogger.info("Clearing baseline data...", service: "DataManager")

        let baselineDescriptor = FetchDescriptor<Baseline>()
        let allBaselines = try modelContext.fetch(baselineDescriptor)
        for baseline in allBaselines {
            modelContext.delete(baseline)
        }

        try modelContext.save()

        ClaimbLogger.info("Baseline data cleared", service: "DataManager")
    }

    /// Clears URL cache only
    public func clearURLCache() {
        ClaimbLogger.info("Clearing URL cache...", service: "DataManager")
        URLCache.shared.removeAllCachedResponses()
        ClaimbLogger.info("URL cache cleared", service: "DataManager")
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

    /// Gets match statistics with age filtering for a summoner
    public func getMatchStatisticsWithAgeFilter(for summoner: Summoner) async throws
        -> MatchStatisticsWithAge
    {
        let allMatches = try await getMatches(for: summoner, limit: 1000)  // Get more to analyze age distribution

        // Filter matches by age
        let oneYearAgo =
            Calendar.current.date(byAdding: .day, value: -maxGameAgeInDays, to: Date()) ?? Date()
        let recentMatches = allMatches.filter { match in
            let gameDate = Date(timeIntervalSince1970: TimeInterval(match.gameCreation) / 1000.0)
            return gameDate >= oneYearAgo
        }

        let totalMatches = recentMatches.count
        let wins = recentMatches.filter { match in
            match.participants.contains { $0.puuid == summoner.puuid && $0.win }
        }.count

        let winRate = totalMatches > 0 ? Double(wins) / Double(totalMatches) : 0.0

        // Calculate age distribution
        let oldMatchesCount = allMatches.count - recentMatches.count
        let oldestMatch = allMatches.last
        let newestMatch = allMatches.first

        return MatchStatisticsWithAge(
            totalMatches: totalMatches,
            wins: wins,
            losses: totalMatches - wins,
            winRate: winRate,
            oldMatchesFiltered: oldMatchesCount,
            oldestMatchDate: oldestMatch?.gameCreation,
            newestMatchDate: newestMatch?.gameCreation
        )
    }

    // MARK: - Baseline Management

    /// Saves a baseline to the database
    public func saveBaseline(_ baseline: Baseline) async throws {
        modelContext.insert(baseline)
        try modelContext.save()
    }

    /// Gets a baseline by role, class tag, and metric
    public func getBaseline(role: String, classTag: String, metric: String) async throws
        -> Baseline?
    {
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
    public func loadBaselineDataInternal() async throws {
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


    // MARK: - Private JSON Loading Methods

    private func loadBaselineJSON() async throws -> [BaselineData] {
        guard let url = Bundle.main.url(forResource: "baselines_clean", withExtension: "json")
        else {
            throw DataManagerError.missingResource("baselines_clean.json")
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([BaselineData].self, from: data)
    }


    // MARK: - Cache Management

    /// Determines if matches should be refreshed based on smart caching strategy
    private func shouldRefreshMatches(for summoner: Summoner) -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(summoner.lastUpdated)

        // Smart caching strategy:
        // - First time: always refresh
        // - Recent data (< 5 minutes): use cache
        // - Stale data (> 5 minutes): incremental refresh
        // - Very old data (> 1 hour): full refresh

        if timeSinceLastUpdate < 5 * 60 {  // Less than 5 minutes
            ClaimbLogger.debug(
                "Matches are fresh, using cache", service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "cache",
                ])
            return false
        } else if timeSinceLastUpdate < 60 * 60 {  // Less than 1 hour
            ClaimbLogger.debug(
                "Matches are stale, incremental refresh", service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "incremental",
                ])
            return true
        } else {  // More than 1 hour
            ClaimbLogger.debug(
                "Matches are very old, full refresh", service: "DataManager",
                metadata: [
                    "timeSinceLastUpdate": String(Int(timeSinceLastUpdate)),
                    "strategy": "full",
                ])
            return true
        }
    }

    // MARK: - Request Deduplication

    /// Loads matches with deduplication
    public func loadMatches(for summoner: Summoner, limit: Int = 100) async -> UIState<[Match]> {
        let requestKey = "matches_\(summoner.puuid)_\(limit)"

        // Check if request is already in progress
        if let existingTask = requestQueue[requestKey] {
            ClaimbLogger.debug(
                "Request already in progress, waiting for result", service: "DataManager",
                metadata: ["requestKey": requestKey])
            return await existingTask.value
        }

        // Create new task
        let task = Task<UIState<[Match]>, Never> {
            defer {
                // Clean up when task completes
                requestQueue.removeValue(forKey: requestKey)
                activeRequests.remove(requestKey)
            }

            ClaimbLogger.info(
                "Loading matches", service: "DataManager",
                metadata: [
                    "summoner": summoner.gameName,
                    "limit": String(limit),
                ])

            do {
                // Check if we have existing matches
                let existingMatches = try await getMatches(for: summoner)

                if existingMatches.isEmpty {
                    // Load initial matches
                    ClaimbLogger.info(
                        "No existing matches, loading initial batch", service: "DataManager")
                    try await loadInitialMatches(for: summoner)
                } else {
                    // Check if we need to refresh based on time
                    let shouldRefresh = shouldRefreshMatches(for: summoner)

                    if shouldRefresh {
                        ClaimbLogger.info(
                            "Found existing matches, refreshing with new data",
                            service: "DataManager",
                            metadata: [
                                "count": String(existingMatches.count),
                                "lastUpdated": summoner.lastUpdated.description,
                            ])
                        try await refreshMatchesInternal(for: summoner)
                    } else {
                        ClaimbLogger.info(
                            "Using cached matches (no refresh needed)", service: "DataManager",
                            metadata: [
                                "count": String(existingMatches.count),
                                "lastUpdated": summoner.lastUpdated.description,
                            ])
                    }
                }

                // Get all matches after loading
                let loadedMatches = try await getMatches(for: summoner, limit: limit)
                return .loaded(loadedMatches)

            } catch {
                ClaimbLogger.error(
                    "Failed to load matches", service: "DataManager", error: error)
                return .error(error)
            }
        }

        // Store task and return its result
        requestQueue[requestKey] = task
        activeRequests.insert(requestKey)
        return await task.value
    }

    /// Loads champions with deduplication
    public func loadChampions() async -> UIState<[Champion]> {
        let requestKey = "champions"

        if let existingTask = championRequestQueue[requestKey] {
            ClaimbLogger.debug(
                "Champion request already in progress, waiting for result",
                service: "DataManager",
                metadata: ["requestKey": requestKey])
            return await existingTask.value
        }

        let task = Task<UIState<[Champion]>, Never> {
            defer {
                championRequestQueue.removeValue(forKey: requestKey)
                activeRequests.remove(requestKey)
            }

            ClaimbLogger.info("Loading champions", service: "DataManager")

            do {
                try await loadChampionData()
                let champions = try await getAllChampions()

                ClaimbLogger.info(
                    "Successfully loaded \(champions.count) champions",
                    service: "DataManager",
                    metadata: ["championCount": String(champions.count)]
                )

                return .loaded(champions)
            } catch {
                ClaimbLogger.error("Failed to load champions", service: "DataManager", error: error)
                return .error(error)
            }
        }

        championRequestQueue[requestKey] = task
        activeRequests.insert(requestKey)
        return await task.value
    }

    /// Creates or updates summoner with deduplication
    public func createOrUpdateSummoner(gameName: String, tagLine: String, region: String) async
        -> UIState<Summoner>
    {
        let requestKey = "summoner_\(gameName)_\(tagLine)_\(region)"

        if let existingTask = summonerRequestQueue[requestKey] {
            ClaimbLogger.debug(
                "Summoner request already in progress, waiting for result",
                service: "DataManager",
                metadata: ["requestKey": requestKey])
            return await existingTask.value
        }

        let task = Task<UIState<Summoner>, Never> {
            defer {
                summonerRequestQueue.removeValue(forKey: requestKey)
                activeRequests.remove(requestKey)
            }

            ClaimbLogger.info(
                "Creating/updating summoner", service: "DataManager",
                metadata: [
                    "gameName": gameName,
                    "tagLine": tagLine,
                    "region": region,
                ])

            do {
                let summoner = try await self.createOrUpdateSummonerInternal(
                    gameName: gameName,
                    tagLine: tagLine,
                    region: region
                )

                try await loadChampionData()
                try await refreshMatches(for: summoner)

                return .loaded(summoner)
            } catch {
                ClaimbLogger.error(
                    "Failed to create/update summoner", service: "DataManager", error: error)
                return .error(error)
            }
        }

        summonerRequestQueue[requestKey] = task
        activeRequests.insert(requestKey)
        return await task.value
    }

    /// Loads baseline data with deduplication
    public func loadBaselineData() async -> UIState<Void> {
        let requestKey = "baseline_data"

        if let existingTask = baselineRequestQueue[requestKey] {
            ClaimbLogger.debug(
                "Baseline data request already in progress, waiting for result",
                service: "DataManager",
                metadata: ["requestKey": requestKey])
            return await existingTask.value
        }

        let task = Task<UIState<Void>, Never> {
            defer {
                baselineRequestQueue.removeValue(forKey: requestKey)
                activeRequests.remove(requestKey)
            }

            ClaimbLogger.info("Loading baseline data", service: "DataManager")

            do {
                try await self.loadBaselineDataInternal()
                return .loaded(())
            } catch {
                ClaimbLogger.error(
                    "Failed to load baseline data", service: "DataManager", error: error)
                return .error(error)
            }
        }

        baselineRequestQueue[requestKey] = task
        activeRequests.insert(requestKey)
        return await task.value
    }

    /// Refreshes matches with deduplication
    public func refreshMatches(for summoner: Summoner) async -> UIState<[Match]> {
        ClaimbLogger.info(
            "Refreshing matches", service: "DataManager",
            metadata: [
                "summoner": summoner.gameName
            ])

        do {
            try await self.refreshMatchesInternal(for: summoner)
            let refreshedMatches = try await getMatches(for: summoner)
            return .loaded(refreshedMatches)
        } catch {
            ClaimbLogger.error(
                "Failed to refresh matches", service: "DataManager", error: error)
            return .error(error)
        }
    }

    /// Clears all cached data with deduplication
    public func clearAllCache() async -> UIState<Void> {
        ClaimbLogger.info("Clearing all cache", service: "DataManager")

        do {
            try await clearAllCacheInternal()
            return .loaded(())
        } catch {
            ClaimbLogger.error("Failed to clear cache", service: "DataManager", error: error)
            return .error(error)
        }
    }

    /// Cancels all pending requests (useful for cleanup)
    public func cancelAllRequests() {
        // Cancel all match requests
        for task in requestQueue.values {
            task.cancel()
        }
        requestQueue.removeAll()

        // Cancel all champion requests
        for task in championRequestQueue.values {
            task.cancel()
        }
        championRequestQueue.removeAll()

        // Cancel all summoner requests
        for task in summonerRequestQueue.values {
            task.cancel()
        }
        summonerRequestQueue.removeAll()

        // Cancel all baseline requests
        for task in baselineRequestQueue.values {
            task.cancel()
        }
        baselineRequestQueue.removeAll()

        // Clear active requests
        activeRequests.removeAll()

        ClaimbLogger.info("Cancelled all pending requests", service: "DataManager")
    }
}

// MARK: - Supporting Types

public struct MatchStatistics {
    public let totalMatches: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double
}

public struct MatchStatisticsWithAge {
    public let totalMatches: Int
    public let wins: Int
    public let losses: Int
    public let winRate: Double
    public let oldMatchesFiltered: Int
    public let oldestMatchDate: Int?
    public let newestMatchDate: Int?
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


// MARK: - DataManager Errors

public enum DataManagerError: Error, LocalizedError {
    case notAvailable
    case missingResource(String)
    case invalidData(String)
    case databaseError(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "DataManager is not available"
        case .missingResource(let resource):
            return "Missing resource: \(resource)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}

/// Errors for match filtering
enum MatchFilterError: Error, LocalizedError {
    case irrelevantMatch

    var errorDescription: String? {
        switch self {
        case .irrelevantMatch:
            return "Match is not relevant for analysis (ARAM, Swiftplay, short games, etc.)"
        }
    }
}
