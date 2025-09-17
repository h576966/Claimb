//
//  MatchCardView.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import SwiftUI
import SwiftData

struct MatchCardView: View {
    let match: Match
    let summoner: Summoner
    @State private var playerParticipant: Participant?
    @State private var champion: Champion?
    
    var body: some View {
        VStack(spacing: 0) {
            // Match Header
            HStack {
                // Win/Loss indicator
                Circle()
                    .fill(winColor)
                    .frame(width: 12, height: 12)
                
                // Queue Type
                Text(match.queueName)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Game Duration
                Text(formatDuration(match.gameDuration))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                // Game Date
                Text(match.gameDate, style: .relative)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)
            
            // Match Content
            HStack(spacing: DesignSystem.Spacing.md) {
                // Champion Icon
                AsyncImage(url: URL(string: champion?.iconURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(DesignSystem.Colors.cardBorder)
                        .overlay(
                            Image(systemName: "questionmark")
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        )
                }
                .frame(width: 50, height: 50)
                .cornerRadius(DesignSystem.CornerRadius.small)
                
                // Match Stats
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Champion Name
                    Text(champion?.name ?? "Unknown Champion")
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fontWeight(.semibold)
                    
                    // KDA
                    if let participant = playerParticipant {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text("\(participant.kills)/\(participant.deaths)/\(participant.assists)")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("KDA")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        
                        // CS and Gold
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Text("\(Int(participant.csPerMinute)) CS/min")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            
                            Text("\(Int(participant.goldPerMinute)) G/min")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // Win/Loss Badge
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(winText)
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(winColor)
                    
                    if let participant = playerParticipant {
                        Text("\(Int(participant.kda * 10) / 10)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.md)
            
            // Match Footer (if ranked)
            if match.isRanked {
                HStack {
                    Text("Ranked Game")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accent)
                    
                    Spacer()
                    
                    if let participant = playerParticipant {
                        Text("Vision: \(participant.visionScore)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
        }
        .claimbCard()
        .onAppear {
            loadParticipantData()
        }
    }
    
    // MARK: - Computed Properties
    
    private var winColor: Color {
        guard let participant = playerParticipant else { 
            return DesignSystem.Colors.textTertiary 
        }
        return participant.win ? DesignSystem.Colors.success : DesignSystem.Colors.error
    }
    
    private var winText: String {
        guard let participant = playerParticipant else { 
            return "Unknown" 
        }
        return participant.win ? "VICTORY" : "DEFEAT"
    }
    
    // MARK: - Methods
    
    private func loadParticipantData() {
        // Ensure we're on the main thread for SwiftData access
        Task { @MainActor in
            // Find the player's participant in this match
            playerParticipant = match.participants.first { $0.puuid == summoner.puuid }
            
            if let participant = playerParticipant {
                await loadChampion(for: participant.championId)
            }
        }
    }
    
    private func loadChampion(for championId: Int) async {
        // The champion should already be loaded by the DataManager
        // Just use the champion from the participant if available
        if let participant = playerParticipant, let participantChampion = participant.champion {
            self.champion = participantChampion
        }
    }
    
    private func formatDuration(_ durationSeconds: Int) -> String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    let summoner = Summoner(
        puuid: "test-puuid",
        gameName: "TestSummoner",
        tagLine: "1234",
        region: "euw1"
    )
    
    let match = Match(
        matchId: "test-match",
        gameCreation: Int(Date().timeIntervalSince1970 * 1000),
        gameDuration: 1800,
        gameMode: "CLASSIC",
        gameType: "MATCHED_GAME",
        gameVersion: "14.17.1",
        queueId: 420,
        mapId: 11, // Summoner's Rift
        gameStartTimestamp: Int(Date().timeIntervalSince1970 * 1000),
        gameEndTimestamp: Int(Date().timeIntervalSince1970 * 1000) + 1800
    )
    
    let participant = Participant(
        puuid: "test-puuid",
        championId: 103, // Ahri
        teamId: 100,
        lane: "MIDDLE",
        role: "SOLO",
        kills: 8,
        deaths: 3,
        assists: 12,
        win: true,
        largestMultiKill: 2,
        hadAfkTeammate: 0,
        gameEndedInSurrender: false,
        eligibleForProgression: true,
        totalMinionsKilled: 180,
        neutralMinionsKilled: 20,
        goldEarned: 12000,
        visionScore: 25,
        totalDamageDealt: 25000,
        totalDamageDealtToChampions: 20000,
        totalDamageTaken: 8000,
        dragonTakedowns: 1,
        riftHeraldTakedowns: 0,
        baronTakedowns: 1,
        hordeTakedowns: 0,
        atakhanTakedowns: 0
    )
    
    MatchCardView(match: match, summoner: summoner)
        .padding()
        .background(DesignSystem.Colors.background)
        .onAppear {
            match.participants = [participant]
        }
}
