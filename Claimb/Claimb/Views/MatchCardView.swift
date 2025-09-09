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
                    .font(.caption)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Game Duration
                Text(formatDuration(match.gameDuration))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Game Date
                Text(match.gameDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Match Content
            HStack(spacing: 16) {
                // Champion Icon
                AsyncImage(url: URL(string: champion?.iconURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "questionmark")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                
                // Match Stats
                VStack(alignment: .leading, spacing: 4) {
                    // Champion Name
                    Text(champion?.name ?? "Unknown Champion")
                        .font(.headline)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    
                    // KDA
                    if let participant = playerParticipant {
                        HStack(spacing: 8) {
                            Text("\(participant.kills)/\(participant.deaths)/\(participant.assists)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Text("KDA")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // CS and Gold
                        HStack(spacing: 16) {
                            Text("\(Int(participant.csPerMinute)) CS/min")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("\(Int(participant.goldPerMinute)) G/min")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                // Win/Loss Badge
                VStack(spacing: 4) {
                    Text(winText)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(winColor)
                    
                    if let participant = playerParticipant {
                        Text("\(Int(participant.kda * 10) / 10)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Match Footer (if ranked)
            if match.isRanked {
                HStack {
                    Text("Ranked Game")
                        .font(.caption)
                        .foregroundColor(.teal)
                    
                    Spacer()
                    
                    if let participant = playerParticipant {
                        Text("Vision: \(participant.visionScore)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(winColor.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            loadParticipantData()
        }
    }
    
    // MARK: - Computed Properties
    
    private var winColor: Color {
        guard let participant = playerParticipant else { 
            return .gray 
        }
        return participant.win ? .green : .red
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
        gameMode: "Classic",
        gameType: "MATCHED_GAME",
        gameVersion: "14.17.1",
        queueId: 420,
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
        totalDamageTaken: 8000,
        dragonTakedowns: 1,
        riftHeraldTakedowns: 0,
        baronTakedowns: 1,
        hordeTakedowns: 0,
        atakhanTakedowns: 0
    )
    
    match.participants = [participant]
    
    return MatchCardView(match: match, summoner: summoner)
        .padding()
        .background(Color.black)
}
