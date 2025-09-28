//
//  OpenAIService.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-27.
//

import Foundation
import Observation

// MARK: - Response Models

/// Structured coaching analysis response
struct CoachingAnalysis: Codable {
    let strengths: [String]
    let improvements: [String]
    let actionableTips: [String]
    let championAdvice: String
    let nextSteps: [String]
    let overallScore: Int  // 1-10 scale
    let priorityFocus: String
    let performanceComparison: PerformanceComparison
}

/// Performance comparison against personal baselines
struct PerformanceComparison: Codable {
    let csPerMinute: ComparisonResult
    let deathsPerGame: ComparisonResult
    let visionScore: ComparisonResult
    let killParticipation: ComparisonResult
}

/// Individual metric comparison result
struct ComparisonResult: Codable {
    let current: Double
    let average: Double
    let trend: String  // "above", "below", "similar"
    let significance: String  // "high", "medium", "low"
}

/// Complete coaching response
struct CoachingResponse: Codable {
    let analysis: CoachingAnalysis
    let summary: String
}

/// OpenAI API service for generating coaching insights
@MainActor
@Observable
public class OpenAIService {

    // MARK: - Initialization

    public init() {
        // No initialization needed - using ProxyService
    }

    // MARK: - Public Methods

    /// Generates coaching insights based on match data with personal baselines
    public func generateCoachingInsights(
        summoner: Summoner,
        matches: [Match],
        primaryRole: String,
        kpiService: KPICalculationService? = nil
    ) async throws -> CoachingResponse {

        // Validate proxy service availability
        guard !AppConfig.appToken.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        // Get personal baselines if KPI service is provided
        let personalBaselines = await getPersonalBaselines(
            summoner: summoner, 
            matches: matches, 
            role: primaryRole,
            kpiService: kpiService
        )

        // Prepare match data for analysis
        let matchSummary = prepareMatchSummary(
            matches: matches, summoner: summoner, primaryRole: primaryRole)

        // Create enhanced coaching prompt with personal baselines
        let prompt = createCoachingPrompt(
            summoner: summoner,
            matchSummary: matchSummary,
            primaryRole: primaryRole,
            personalBaselines: personalBaselines
        )

        // Make API request through proxy service with enhanced parameters
        let proxyService = ProxyService()
        let responseText = try await proxyService.aiCoach(
            prompt: prompt,
            temperature: 0.5,  // Balanced creativity/consistency
            model: "gpt-4-mini"  // As specified by user
        )

        // Parse structured JSON response
        return try parseCoachingResponse(responseText)
    }
    
    /// Legacy method for backward compatibility
    public func generateCoachingInsights(
        summoner: Summoner,
        matches: [Match],
        primaryRole: String
    ) async throws -> String {
        let response = try await generateCoachingInsights(
            summoner: summoner,
            matches: matches,
            primaryRole: primaryRole,
            kpiService: nil
        )
        return response.summary
    }

    // MARK: - Private Methods

    private func prepareMatchSummary(matches: [Match], summoner: Summoner, primaryRole: String)
        -> String
    {
        let recentMatches = Array(matches.prefix(10))  // Last 10 matches

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

    private func createCoachingPrompt(
        summoner: Summoner, 
        matchSummary: String, 
        primaryRole: String,
        personalBaselines: [String: Double] = [:]
    ) -> String {
        let baselineContext = personalBaselines.isEmpty ? "" : createBaselineContext(baselines: personalBaselines)
        
        return """
        You are an expert League of Legends coach specializing in data-driven analysis. Analyze the following player data and provide structured coaching insights.

        **CRITICAL INSTRUCTIONS:**
        - Use minimal reasoning - focus on direct analysis
        - Response MUST be valid JSON matching the exact schema below
        - Keep analysis concise but actionable
        - Compare current performance against personal averages when available
        - Prioritize the most impactful improvements

        **Player Data:**
        Player: \(summoner.gameName)#\(summoner.tagLine)
        Primary Role: \(primaryRole)
        \(baselineContext)
        \(matchSummary)

        **REQUIRED JSON RESPONSE SCHEMA:**
        {
          "analysis": {
            "strengths": ["string", "string"],
            "improvements": ["string", "string"],
            "actionableTips": ["string", "string", "string"],
            "championAdvice": "string",
            "nextSteps": ["string", "string"],
            "overallScore": 7,
            "priorityFocus": "string",
            "performanceComparison": {
              "csPerMinute": {
                "current": 6.5,
                "average": 6.2,
                "trend": "above",
                "significance": "medium"
              },
              "deathsPerGame": {
                "current": 4.2,
                "average": 3.8,
                "trend": "below",
                "significance": "high"
              },
              "visionScore": {
                "current": 0.6,
                "average": 0.8,
                "trend": "below",
                "significance": "high"
              },
              "killParticipation": {
                "current": 0.45,
                "average": 0.52,
                "trend": "below",
                "significance": "medium"
              }
            }
          },
          "summary": "Brief 2-3 sentence summary of key insights"
        }

        **ANALYSIS GUIDELINES:**
        - Focus on role-specific improvements for \(primaryRole)
        - Use personal averages as baselines when provided
        - Highlight trends: "above" = better than average, "below" = worse than average
        - Significance: "high" = major impact, "medium" = moderate impact, "low" = minor impact
        - Keep tips specific and immediately actionable
        - Overall score: 1-10 based on recent performance

        Respond ONLY with valid JSON. No additional text or explanations.
        """
    }
    
    private func createBaselineContext(baselines: [String: Double]) -> String {
        var context = "\n**Personal Performance Averages:**\n"
        for (metric, value) in baselines {
            context += "\(metric): \(String(format: "%.2f", value))\n"
        }
        return context
    }
    
    /// Gets personal performance baselines for the summoner
    private func getPersonalBaselines(
        summoner: Summoner,
        matches: [Match],
        role: String,
        kpiService: KPICalculationService?
    ) async -> [String: Double] {
        guard let kpiService = kpiService else { return [:] }
        
        do {
            let kpis = try await kpiService.calculateRoleKPIs(
                matches: matches,
                role: role,
                summoner: summoner
            )
            
            var baselines: [String: Double] = [:]
            for kpi in kpis {
                baselines[kpi.metricName] = kpi.value
            }
            
            ClaimbLogger.debug(
                "Retrieved personal baselines", service: "OpenAIService",
                metadata: [
                    "role": role,
                    "metrics": baselines.keys.joined(separator: ", "),
                    "count": String(baselines.count)
                ])
            
            return baselines
        } catch {
            ClaimbLogger.warning(
                "Failed to get personal baselines", service: "OpenAIService",
                metadata: ["error": error.localizedDescription])
            return [:]
        }
    }
    
    /// Parses the structured JSON response from OpenAI
    private func parseCoachingResponse(_ responseText: String) throws -> CoachingResponse {
        // Clean the response text (remove any markdown formatting)
        let cleanText = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanText.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }
        
        do {
            let response = try JSONDecoder().decode(CoachingResponse.self, from: data)
            ClaimbLogger.debug(
                "Successfully parsed coaching response", service: "OpenAIService",
                metadata: [
                    "overallScore": String(response.analysis.overallScore),
                    "priorityFocus": response.analysis.priorityFocus
                ])
            return response
        } catch {
            ClaimbLogger.error(
                "Failed to parse coaching response", service: "OpenAIService",
                metadata: [
                    "error": error.localizedDescription,
                    "responseLength": String(responseText.count)
                ])
            throw OpenAIError.invalidResponse
        }
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
