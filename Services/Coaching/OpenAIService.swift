//
//  OpenAIService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation

/// OpenAI API service for generating coaching insights
@MainActor
@Observable
public class OpenAIService {
    
    // MARK: - Properties
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-4o-mini" // Cost-effective model for coaching
    
    // MARK: - Initialization
    
    public init() {
        self.apiKey = APIKeyManager.openAIAPIKey
    }
    
    // MARK: - Public Methods
    
    /// Generates coaching insights based on match data
    public func generateCoachingInsights(
        summoner: Summoner,
        matches: [Match],
        primaryRole: String
    ) async throws -> String {
        
        // Validate API key
        guard APIKeyManager.hasValidOpenAIAPIKey else {
            throw OpenAIError.invalidAPIKey
        }
        
        // Prepare match data for analysis
        let matchSummary = prepareMatchSummary(matches: matches, summoner: summoner, primaryRole: primaryRole)
        
        // Create coaching prompt
        let prompt = createCoachingPrompt(
            summoner: summoner,
            matchSummary: matchSummary,
            primaryRole: primaryRole
        )
        
        // Make API request
        let response = try await makeAPIRequest(prompt: prompt)
        
        return response
    }
    
    // MARK: - Private Methods
    
    private func prepareMatchSummary(matches: [Match], summoner: Summoner, primaryRole: String) -> String {
        let recentMatches = Array(matches.prefix(10)) // Last 10 matches
        
        var summary = "Recent Performance Summary:\n"
        summary += "Role: \(primaryRole)\n"
        summary += "Total Matches: \(recentMatches.count)\n"
        
        // Calculate win rate
        let wins = recentMatches.compactMap { match in
            match.participants.first(where: { $0.puuid == summoner.puuid })?.win
        }.filter { $0 }.count
        
        let winRate = recentMatches.isEmpty ? 0.0 : Double(wins) / Double(recentMatches.count)
        summary += "Win Rate: \(String(format: "%.1f", winRate * 100))%\n\n"
        
        // Add match details
        summary += "Match Details:\n"
        for (index, match) in recentMatches.enumerated() {
            if let participant = match.participants.first(where: { $0.puuid == summoner.puuid }) {
                let result = participant.win ? "Victory" : "Defeat"
                let kda = "\(participant.kills)/\(participant.deaths)/\(participant.assists)"
                let cs = participant.totalMinionsKilled + participant.neutralMinionsKilled
                
                summary += "Match \(index + 1): \(result) - KDA: \(kda) - CS: \(cs)\n"
            }
        }
        
        return summary
    }
    
    private func createCoachingPrompt(summoner: Summoner, matchSummary: String, primaryRole: String) -> String {
        return """
        You are an expert League of Legends coach. Analyze the following player data and provide specific, actionable coaching advice.
        
        Player: \(summoner.gameName)#\(summoner.tagLine)
        Primary Role: \(primaryRole)
        
        \(matchSummary)
        
        Please provide:
        1. **Strengths**: What the player is doing well
        2. **Areas for Improvement**: Specific weaknesses to address
        3. **Actionable Tips**: 3-5 concrete steps to improve
        4. **Champion Pool Advice**: Recommendations for champion selection
        5. **Next Steps**: Priority focus areas for the next 5-10 games
        
        Keep the response concise (under 500 words) and focus on the most impactful improvements. Use a supportive but direct coaching tone.
        """
    }
    
    private func makeAPIRequest(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        ClaimbLogger.info("Making OpenAI API request", service: "OpenAIService")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        ClaimbLogger.apiResponse("OpenAI API", statusCode: httpResponse.statusCode, service: "OpenAIService")
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OpenAIError.apiError(message)
            } else {
                throw OpenAIError.httpError(httpResponse.statusCode)
            }
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        ClaimbLogger.info("OpenAI API request successful", service: "OpenAIService")
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error Types

public enum OpenAIError: Error, LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "OpenAI API key is not configured. Please check your API key settings."
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
