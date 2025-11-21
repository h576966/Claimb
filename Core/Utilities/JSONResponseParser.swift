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
            // Log the cleaned text to help diagnose parsing issues
            let cleanedPreview = cleanText.count > 1000 ? String(cleanText.prefix(1000)) + "..." : cleanText
            let lastChars = cleanText.count > 100 ? String(cleanText.suffix(100)) : cleanText
            
            ClaimbLogger.error(
                "Failed to parse JSON response",
                service: "JSONResponseParser",
                metadata: [
                    "error": error.localizedDescription,
                    "responseLength": String(responseText.count),
                    "cleanedLength": String(cleanText.count),
                    "expectedType": String(describing: T.self),
                    "firstChars": String(cleanText.prefix(200)),
                    "lastChars": lastChars,
                    "fullCleanedPreview": cleanedPreview,
                ]
            )
            throw OpenAIError.invalidResponse
        }
    }
}
