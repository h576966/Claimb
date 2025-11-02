//
//  MatchRepository.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-10.
//

import Foundation
import SwiftData

/// Manages match data operations including fetching, parsing, and caching
@MainActor
public class MatchRepository {
    private let modelContext: ModelContext
    private let riotClient: RiotClient
    private let matchParser: MatchParser
    private let maxMatchesPerSummoner: Int

    public init(
        modelContext: ModelContext,
        riotClient: RiotClient,
        matchParser: MatchParser,
        maxMatchesPerSummoner: Int = 100
    ) {
        self.modelContext = modelContext
        self.riotClient = riotClient
        self.matchParser = matchParser
        self.maxMatchesPerSummoner = maxMatchesPerSummoner
    }

    // MARK: - Match Retrieval

    /// Gets a match by ID
    public func getMatch(by matchId: String) async throws -> Match? {
        let descriptor = FetchDescriptor<Match>(
            predicate: #Predicate { $0.matchId == matchId }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets matches for a summoner
    public func getMatches(for summoner: Summoner, limit: Int = 50) async throws -> [Match] {
        let descriptor = FetchDescriptor<Match>(
            sortBy: [SortDescriptor(\.gameCreation, order: .reverse)]
        )
        let allMatches = try modelContext.fetch(descriptor)

        // Filter matches for this summoner and apply role analysis filter
        // Materialize relationships while context is active to avoid faults after context becomes stale
        let summonerPuuid = summoner.puuid
        let filteredMatches = allMatches.compactMap { match -> Match? in
            // Safely access relationship properties while context is active
            guard let matchSummonerPuuid = match.summoner?.puuid else {
                return nil
            }
            guard matchSummonerPuuid == summonerPuuid else {
                return nil
            }
            // Materialize isIncludedInRoleAnalysis property while context is active
            guard match.isIncludedInRoleAnalysis else {
                return nil
            }
            return match
        }

        return Array(filteredMatches.prefix(limit))
    }

    // MARK: - Match Loading

    /// Loads initial match data for a summoner using smart fetching strategy
    public func loadInitialMatches(for summoner: Summoner) async throws {
        ClaimbLogger.info(
            "Smart loading initial matches",
            service: "MatchRepository",
            metadata: [
                "gameName": summoner.gameName,
                "strategy": "ranked-first-with-fallback",
            ])

        // Smart fetching strategy
        let smartResult = try await performInitialBulkFetch(for: summoner)

        // Process matches in batch
        let (addedCount, skippedCount) = try await processBatchMatches(
            matchIds: smartResult.matchIds,
            summoner: summoner
        )

        summoner.lastUpdated = Date()
        try modelContext.save()

        let finalMatchCount = try await getMatches(for: summoner).count

        ClaimbLogger.info(
            "Smart fetch completed",
            service: "MatchRepository",
            metadata: [
                "strategy": String(describing: smartResult.strategy),
                "totalFetched": String(smartResult.totalFetched),
                "addedCount": String(addedCount),
                "skippedCount": String(skippedCount),
                "finalDatabaseCount": String(finalMatchCount),
            ])
    }

    /// Refreshes match data for a summoner with efficient incremental fetching
    public func refreshMatches(for summoner: Summoner) async throws {
        // Get existing matches
        let existingMatches = try await getMatches(for: summoner)
        let existingMatchIds = Set(existingMatches.map { $0.matchId })

        let currentCount = existingMatches.count

        ClaimbLogger.info(
            "Refreshing matches: fetching recent matches",
            service: "MatchRepository",
            metadata: [
                "currentCount": String(currentCount),
                "strategy": "recent-matches-only",
            ])

        // Always fetch recent matches to catch any new games
        let recentResult = try await performRecentMatchesFetch(for: summoner)

        // Filter out matches we already have
        let newMatchIds = recentResult.matchIds.filter { !existingMatchIds.contains($0) }

        ClaimbLogger.info(
            "Found new matches to process",
            service: "MatchRepository",
            metadata: [
                "totalRecentMatches": String(recentResult.matchIds.count),
                "newMatches": String(newMatchIds.count),
                "alreadyHave": String(recentResult.matchIds.count - newMatchIds.count),
            ])

        // Process new matches if any
        if !newMatchIds.isEmpty {
            let (addedCount, skippedCount) = try await processBatchMatches(
                matchIds: newMatchIds,
                summoner: summoner
            )

            ClaimbLogger.dataOperation(
                "Added new matches from refresh",
                count: addedCount,
                service: "MatchRepository"
            )

            if skippedCount > 0 {
                ClaimbLogger.info(
                    "Skipped matches during refresh",
                    service: "MatchRepository",
                    metadata: [
                        "skippedCount": String(skippedCount),
                        "reason": "already_processed_or_irrelevant",
                    ])
            }
        } else {
            ClaimbLogger.info(
                "No new matches found during refresh",
                service: "MatchRepository",
                metadata: [
                    "totalRecentMatches": String(recentResult.matchIds.count),
                    "currentDatabaseCount": String(currentCount),
                ])
        }

        try await cleanupOldMatches(for: summoner)
        summoner.lastUpdated = Date()
        try modelContext.save()

        let finalMatchCount = try await getMatches(for: summoner).count

        ClaimbLogger.info(
            "Refresh completed",
            service: "MatchRepository",
            metadata: [
                "strategy": "recent-matches-only",
                "totalFetched": String(recentResult.totalFetched),
                "newMatchesAdded": String(newMatchIds.count),
                "finalDatabaseCount": String(finalMatchCount),
            ])
    }

    // MARK: - Match Processing

    /// Processes multiple matches in batch (eliminates code duplication)
    private func processBatchMatches(
        matchIds: [String],
        summoner: Summoner
    ) async throws -> (added: Int, skipped: Int) {
        var addedCount = 0
        var skippedCount = 0

        for matchId in matchIds {
            do {
                try await processMatch(
                    matchId: matchId,
                    region: summoner.region,
                    summoner: summoner
                )
                addedCount += 1
            } catch MatchFilterError.irrelevantMatch {
                skippedCount += 1
            }
        }

        return (addedCount, skippedCount)
    }

    /// Processes a single match and stores it in the database
    private func processMatch(
        matchId: String,
        region: String,
        summoner: Summoner
    ) async throws {
        // Check if match already exists
        if try await getMatch(by: matchId) != nil {
            ClaimbLogger.cache(
                "Match already exists, skipping",
                key: matchId,
                service: "MatchRepository"
            )
            return
        }

        ClaimbLogger.apiRequest("match/\(matchId)", service: "MatchRepository")

        do {
            let matchData = try await riotClient.getMatch(matchId: matchId, region: region)
            ClaimbLogger.debug(
                "Received match data",
                service: "MatchRepository",
                metadata: [
                    "matchId": matchId,
                    "bytes": String(matchData.count),
                ])

            do {
                let match = try await matchParser.parseMatchData(
                    matchData,
                    matchId: matchId,
                    summoner: summoner
                )

                modelContext.insert(match)
                ClaimbLogger.debug(
                    "Inserted match \(matchId) with \(match.participants.count) participants",
                    service: "MatchRepository",
                    metadata: [
                        "matchId": matchId,
                        "participantCount": String(match.participants.count),
                    ])
            } catch MatchFilterError.irrelevantMatch {
                ClaimbLogger.debug(
                    "Skipped irrelevant match",
                    service: "MatchRepository",
                    metadata: ["matchId": matchId]
                )
                throw MatchFilterError.irrelevantMatch
            }
        } catch RiotAPIError.serverError(let statusCode) where statusCode == 400 {
            ClaimbLogger.warning(
                "Match unavailable (400 error), skipping",
                service: "MatchRepository",
                metadata: [
                    "matchId": matchId,
                    "statusCode": String(statusCode),
                ])
            throw MatchFilterError.irrelevantMatch
        } catch RiotAPIError.notFound {
            ClaimbLogger.warning(
                "Match not found (404 error), skipping",
                service: "MatchRepository",
                metadata: ["matchId": matchId]
            )
            throw MatchFilterError.irrelevantMatch
        } catch {
            ClaimbLogger.error(
                "Failed to fetch match details, skipping",
                service: "MatchRepository",
                error: error,
                metadata: ["matchId": matchId]
            )
            throw MatchFilterError.irrelevantMatch
        }
    }

    // MARK: - Smart Fetching

    /// Performs initial bulk fetch for first-time users with progressive time windows
    public func performInitialBulkFetch(for summoner: Summoner) async throws -> SmartFetchResult {
        let targetCount = MatchFilteringUtils.targetInitialMatchCount
        var allMatchIds: [String] = []
        var totalFetched = 0
        var timeWindowUsed = MatchFilteringUtils.initialFetchTimeWindowDays

        let rankedQueues = [420, 440]  // Solo/Duo, Flex
        let normalQueue = 400  // Normal Draft

        ClaimbLogger.info(
            "Initial bulk fetch: trying 90-day window first",
            service: "MatchRepository",
            metadata: [
                "targetCount": String(targetCount),
                "minMatchesNeeded": String(MatchFilteringUtils.minMatchesForAnalysis),
                "strategy": "90-day-with-180-day-fallback",
            ])

        // Try 90-day window first
        let startTime90 = MatchFilteringUtils.daysAgoTimestamp(
            days: MatchFilteringUtils.initialFetchTimeWindowDays)
        let result90 = try await fetchMatchesInTimeWindow(
            summoner: summoner,
            startTime: startTime90,
            rankedQueues: rankedQueues,
            normalQueue: normalQueue,
            targetCount: targetCount
        )

        allMatchIds.append(contentsOf: result90.matchIds)
        totalFetched += result90.totalFetched

        // If we don't have enough matches, try 180-day window
        if allMatchIds.count < MatchFilteringUtils.minMatchesForAnalysis {
            ClaimbLogger.info(
                "Insufficient matches from 90-day window, trying 180-day window",
                service: "MatchRepository",
                metadata: [
                    "currentCount": String(allMatchIds.count),
                    "minNeeded": String(MatchFilteringUtils.minMatchesForAnalysis),
                ])

            let startTime180 = MatchFilteringUtils.daysAgoTimestamp(
                days: MatchFilteringUtils.extendedFetchTimeWindowDays)
            let result180 = try await fetchMatchesInTimeWindow(
                summoner: summoner,
                startTime: startTime180,
                rankedQueues: rankedQueues,
                normalQueue: normalQueue,
                targetCount: targetCount
            )

            allMatchIds.append(contentsOf: result180.matchIds)
            totalFetched += result180.totalFetched
            timeWindowUsed = MatchFilteringUtils.extendedFetchTimeWindowDays
        }

        // Remove duplicates and limit to target
        let uniqueMatchIds = Array(Set(allMatchIds))
        let finalMatchIds = Array(uniqueMatchIds.prefix(targetCount))

        ClaimbLogger.info(
            "Initial bulk fetch completed",
            service: "MatchRepository",
            metadata: [
                "timeWindowUsed": String(timeWindowUsed),
                "totalFetched": String(totalFetched),
                "uniqueCount": String(uniqueMatchIds.count),
                "finalCount": String(finalMatchIds.count),
                "targetCount": String(targetCount),
                "duplicatesRemoved": String(totalFetched - uniqueMatchIds.count),
            ])

        return SmartFetchResult(
            matchIds: finalMatchIds,
            strategy: .rankedFirst,
            totalFetched: totalFetched,
            relevantCount: finalMatchIds.count
        )
    }

    /// Performs recent matches fetch for refresh operations
    public func performRecentMatchesFetch(for summoner: Summoner) async throws -> SmartFetchResult {
        let startTime = MatchFilteringUtils.daysAgoTimestamp(
            days: MatchFilteringUtils.refreshTimeWindowDays)
        var allMatchIds: [String] = []
        var totalFetched = 0

        let allQueues = [420, 440, 400]  // Solo/Duo, Flex, Normal Draft

        ClaimbLogger.info(
            "Recent matches fetch: 90-day window",
            service: "MatchRepository",
            metadata: [
                "timeWindowDays": String(MatchFilteringUtils.refreshTimeWindowDays),
                "strategy": "recent-matches-only",
            ])

        // Fetch from all queues in recent time window
        for queueId in allQueues {
            do {
                let queueHistory = try await riotClient.getMatchHistory(
                    puuid: summoner.puuid,
                    region: summoner.region,
                    count: 30,  // Reasonable amount per queue for refresh
                    type: nil,
                    queue: queueId,
                    startTime: startTime,
                    endTime: nil
                )

                let queueCount = queueHistory.history.count
                totalFetched += queueCount
                allMatchIds.append(contentsOf: queueHistory.history)

                ClaimbLogger.info(
                    "Fetched recent matches from queue",
                    service: "MatchRepository",
                    metadata: [
                        "queueId": String(queueId),
                        "queueName": MatchFilteringUtils.queueDisplayName(queueId),
                        "receivedCount": String(queueCount),
                        "totalSoFar": String(allMatchIds.count),
                    ])
            } catch {
                ClaimbLogger.warning(
                    "Failed to fetch recent matches from queue",
                    service: "MatchRepository",
                    metadata: [
                        "queueId": String(queueId),
                        "queueName": MatchFilteringUtils.queueDisplayName(queueId),
                        "error": error.localizedDescription,
                    ])
            }
        }

        // Remove duplicates
        let uniqueMatchIds = Array(Set(allMatchIds))

        ClaimbLogger.info(
            "Recent matches fetch completed",
            service: "MatchRepository",
            metadata: [
                "totalFetched": String(totalFetched),
                "uniqueCount": String(uniqueMatchIds.count),
                "duplicatesRemoved": String(totalFetched - uniqueMatchIds.count),
            ])

        return SmartFetchResult(
            matchIds: uniqueMatchIds,
            strategy: .rankedFirst,
            totalFetched: totalFetched,
            relevantCount: uniqueMatchIds.count
        )
    }

    /// Helper method to fetch matches within a specific time window
    private func fetchMatchesInTimeWindow(
        summoner: Summoner,
        startTime: Int,
        rankedQueues: [Int],
        normalQueue: Int,
        targetCount: Int
    ) async throws -> (matchIds: [String], totalFetched: Int) {
        var allMatchIds: [String] = []
        var totalFetched = 0

        // Fetch from ranked queues first
        for queueId in rankedQueues {
            do {
                let queueHistory = try await riotClient.getMatchHistory(
                    puuid: summoner.puuid,
                    region: summoner.region,
                    count: 50,  // Max per queue for bulk fetch
                    type: nil,
                    queue: queueId,
                    startTime: startTime,
                    endTime: nil
                )

                let queueCount = queueHistory.history.count
                totalFetched += queueCount
                allMatchIds.append(contentsOf: queueHistory.history)

                ClaimbLogger.info(
                    "Fetched from ranked queue in time window",
                    service: "MatchRepository",
                    metadata: [
                        "queueId": String(queueId),
                        "queueName": MatchFilteringUtils.queueDisplayName(queueId),
                        "receivedCount": String(queueCount),
                        "totalSoFar": String(allMatchIds.count),
                    ])

                if allMatchIds.count >= targetCount {
                    ClaimbLogger.info(
                        "Target reached with ranked games, stopping",
                        service: "MatchRepository",
                        metadata: [
                            "currentCount": String(allMatchIds.count),
                            "targetCount": String(targetCount),
                        ])
                    break
                }
            } catch {
                ClaimbLogger.warning(
                    "Failed to fetch from ranked queue in time window",
                    service: "MatchRepository",
                    metadata: [
                        "queueId": String(queueId),
                        "queueName": MatchFilteringUtils.queueDisplayName(queueId),
                        "error": error.localizedDescription,
                    ])
            }
        }

        // Fetch from normal queue if still need more
        let currentCount = allMatchIds.count
        if currentCount < targetCount {
            let neededMatches = targetCount - currentCount
            let normalMatchesToFetch = min(neededMatches + 20, 50)

            ClaimbLogger.info(
                "Need more matches, fetching from normal draft",
                service: "MatchRepository",
                metadata: [
                    "currentCount": String(currentCount),
                    "neededMatches": String(neededMatches),
                    "normalMatchesToFetch": String(normalMatchesToFetch),
                ])

            do {
                let normalHistory = try await riotClient.getMatchHistory(
                    puuid: summoner.puuid,
                    region: summoner.region,
                    count: normalMatchesToFetch,
                    type: nil,
                    queue: normalQueue,
                    startTime: startTime,
                    endTime: nil
                )

                let normalCount = normalHistory.history.count
                totalFetched += normalCount
                allMatchIds.append(contentsOf: normalHistory.history)

                ClaimbLogger.info(
                    "Fetched from normal draft in time window",
                    service: "MatchRepository",
                    metadata: [
                        "queueId": String(normalQueue),
                        "queueName": MatchFilteringUtils.queueDisplayName(normalQueue),
                        "requestedCount": String(normalMatchesToFetch),
                        "receivedCount": String(normalCount),
                        "totalSoFar": String(allMatchIds.count),
                    ])
            } catch {
                ClaimbLogger.warning(
                    "Failed to fetch from normal draft in time window",
                    service: "MatchRepository",
                    metadata: [
                        "queueId": String(normalQueue),
                        "queueName": MatchFilteringUtils.queueDisplayName(normalQueue),
                        "error": error.localizedDescription,
                    ])
            }
        }

        return (matchIds: allMatchIds, totalFetched: totalFetched)
    }

    // MARK: - Cache Cleanup

    /// Cleans up old matches to maintain the cache limit
    public func cleanupOldMatches(for summoner: Summoner) async throws {
        let allMatches = try await getMatches(for: summoner, limit: maxMatchesPerSummoner + 10)

        if allMatches.count > maxMatchesPerSummoner {
            let matchesToDelete = Array(allMatches.dropFirst(maxMatchesPerSummoner))
            for match in matchesToDelete {
                modelContext.delete(match)
            }
            ClaimbLogger.debug(
                "Cleaned up \(matchesToDelete.count) old matches",
                service: "MatchRepository",
                metadata: [
                    "deletedCount": String(matchesToDelete.count)
                ])
        }
    }

    /// Clears all match data while preserving summoner and champion data
    public func clearMatchData() async throws {
        ClaimbLogger.info("Clearing match data...", service: "MatchRepository")

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
        ClaimbLogger.info("Match data cleared", service: "MatchRepository")
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
    public func getMatchStatisticsWithAgeFilter(
        for summoner: Summoner,
        maxGameAgeInDays: Int
    ) async throws -> MatchStatisticsWithAge {
        let allMatches = try await getMatches(for: summoner, limit: 1000)

        // Filter matches by age
        let oneYearAgo =
            Calendar.current.date(
                byAdding: .day,
                value: -maxGameAgeInDays,
                to: Date()
            ) ?? Date()

        let recentMatches = allMatches.filter { match in
            let gameDate = Date(timeIntervalSince1970: TimeInterval(match.gameCreation) / 1000.0)
            return gameDate >= oneYearAgo
        }

        let totalMatches = recentMatches.count
        let wins = recentMatches.filter { match in
            match.participants.contains { $0.puuid == summoner.puuid && $0.win }
        }.count

        let winRate = totalMatches > 0 ? Double(wins) / Double(totalMatches) : 0.0

        return MatchStatisticsWithAge(
            totalMatches: totalMatches,
            wins: wins,
            losses: totalMatches - wins,
            winRate: winRate,
            oldMatchesFiltered: allMatches.count - recentMatches.count,
            oldestMatchDate: allMatches.last?.gameCreation,
            newestMatchDate: allMatches.first?.gameCreation
        )
    }
}
