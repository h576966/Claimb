//
//  JSONResponseParser.swift
//  Claimb
//
//  Created by AI Assistant on 2025-10-09.
//

import Foundation

/// Utility for parsing JSON responses from AI services
public struct JSONResponseParser {

    /// Cleans JSON response text by removing markdown formatting
    public static func cleanJSONResponse(_ responseText: String) -> String {
        return
            responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses JSON response into a decodable type
    public static func parse<T: Decodable>(_ responseText: String) throws -> T {
        let cleanText = cleanJSONResponse(responseText)

        guard let data = cleanText.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            ClaimbLogger.error(
                "Failed to parse JSON response",
                service: "JSONResponseParser",
                metadata: [
                    "error": error.localizedDescription,
                    "responseLength": String(responseText.count),
                    "expectedType": String(describing: T.self),
                ]
            )
            throw OpenAIError.invalidResponse
        }
    }
}
