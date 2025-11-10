//
//  DualPromptTest.swift
//  ClaimbTests
//
//  Test to verify dual prompt (system + user) structure works with edge function
//

import Foundation
@testable import Claimb

/// Tests for dual prompt structure (system + user prompts)
@MainActor
final class DualPromptTest {
    
    // MARK: - Test Data
    
    static let testSystemPrompt = """
    You are an expert League of Legends coach specializing in ranked performance improvement.
    
    **YOUR ROLE:**
    - Analyze game performance data and provide actionable coaching advice
    - Help players identify their biggest improvement opportunities
    - Maintain a supportive but direct coaching style
    
    **OUTPUT REQUIREMENTS:**
    - Format: ONLY valid JSON (no markdown, no extra text)
    - Length: Maximum 110 words total
    - Structure: Must include keyTakeaways (3), championSpecificAdvice (2 sentences), nextGameFocus (2)
    
    **METRIC INTERPRETATION:**
    - "Good" = above average → acknowledge briefly
    - "Needs Improvement" = below average → suggest specific practice focus
    
    **FOCUS PRIORITY:**
    1. Metrics marked "Needs Improvement" - highest priority
    2. NEVER suggest improving metrics marked "Good"
    """
    
    static let testUserPrompt = """
    **GAME CONTEXT:**
    Player: TestPlayer | Champion: Aatrox | Role: TOP
    Result: Victory | KDA: 10/3/5 | Duration: 25min
    
    **PERFORMANCE METRICS:**
    - CS: 6.5/min (Good)
    - Deaths: 3 (Needs Improvement)
    
    **OUTPUT (JSON):**
    {
      "keyTakeaways": ["insight1", "insight2", "insight3"],
      "championSpecificAdvice": "advice here",
      "nextGameFocus": ["goal", "target"]
    }
    """
    
    // MARK: - Main Test Runner
    
    /// Runs all dual prompt tests and returns results
    static func runDualPromptTests() async -> [String] {
        var results: [String] = []
        
        results.append("\n🧪 Testing Dual Prompt Structure")
        results.append("================================\n")
        
        // Test 1: Single Prompt (Baseline)
        results.append(contentsOf: await testSinglePromptBaseline())
        results.append("")
        
        // Test 2: Dual Prompt (New Behavior)
        results.append(contentsOf: await testDualPromptWithSystemInstructions())
        results.append("")
        
        // Test 3: Comparison
        results.append(contentsOf: await testCompareSingleVsDualPrompt())
        
        return results
    }
    
    // MARK: - Test 1: Single Prompt (Baseline)
    
    private static func testSinglePromptBaseline() async -> [String] {
        var results: [String] = []
        results.append("🧪 Test 1: Single Prompt (Current Behavior)")
        results.append("-----------------------------------------")
        
        let combinedPrompt = "\(testSystemPrompt)\n\n\(testUserPrompt)"
        let proxyService = ProxyService()
        
        do {
            let response = try await proxyService.aiCoach(
                prompt: combinedPrompt,
                model: "gpt-5-mini",
                maxOutputTokens: 800,
                reasoningEffort: "low",
                textFormat: "json"
            )
            
            results.append("✅ Single Prompt Response received")
            results.append("Response: \(response)")
            
            // Verify JSON format
            if let jsonData = response.data(using: .utf8) {
                do {
                    let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                    
                    if parsed?["keyTakeaways"] != nil &&
                       parsed?["championSpecificAdvice"] != nil &&
                       parsed?["nextGameFocus"] != nil {
                        results.append("✅ JSON format valid - all required fields present")
                    } else {
                        results.append("⚠️  JSON missing some required fields")
                    }
                } catch {
                    results.append("❌ Invalid JSON: \(error.localizedDescription)")
                }
            }
            
        } catch {
            results.append("❌ Single prompt test failed: \(error.localizedDescription)")
        }
        
        return results
    }
    
    // MARK: - Test 2: Dual Prompt (New Behavior)
    
    private static func testDualPromptWithSystemInstructions() async -> [String] {
        var results: [String] = []
        results.append("🧪 Test 2: Dual Prompt (System + User)")
        results.append("--------------------------------------")
        
        do {
            // Use custom request with system parameter
            var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("ai/coach"))
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            AppConfig.addAuthHeaders(&req)
            
            let requestBody: [String: Any] = [
                "system": testSystemPrompt,      // System instructions
                "prompt": testUserPrompt,         // User data
                "model": "gpt-5-mini",
                "max_output_tokens": 800,
                "reasoning_effort": "low",
                "text_format": "json"
            ]
            
            req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            results.append("📤 Sending dual prompt request...")
            results.append("   System prompt length: \(testSystemPrompt.count) chars")
            results.append("   User prompt length: \(testUserPrompt.count) chars")
            
            // Make request with single retry
            let (data, response) = try await URLSession.shared.data(for: req)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                results.append("❌ Invalid response type")
                return results
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                results.append("❌ HTTP error \(httpResponse.statusCode): \(errorBody)")
                return results
            }
            
            // Parse response
            let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let text = responseDict?["text"] as? String else {
                results.append("❌ No text in response")
                return results
            }
            
            results.append("✅ Dual Prompt Response received")
            results.append("Response: \(text)")
            
            // Verify JSON format
            if let jsonData = text.data(using: .utf8) {
                do {
                    let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                    
                    if parsed?["keyTakeaways"] != nil &&
                       parsed?["championSpecificAdvice"] != nil &&
                       parsed?["nextGameFocus"] != nil {
                        results.append("✅ JSON format valid - all required fields present")
                    } else {
                        results.append("⚠️  JSON missing some required fields")
                    }
                } catch {
                    results.append("❌ Invalid JSON: \(error.localizedDescription)")
                }
            }
            
            // Check if response addresses "Needs Improvement" metric (Deaths)
            let lowercaseResponse = text.lowercased()
            let addressesDeaths = lowercaseResponse.contains("death") ||
                                 lowercaseResponse.contains("die") ||
                                 lowercaseResponse.contains("survival")
            
            if addressesDeaths {
                results.append("✅ Response addresses 'Needs Improvement' metric (Deaths)")
            } else {
                results.append("⚠️  Response may not clearly address 'Needs Improvement' metric")
            }
            
        } catch {
            results.append("❌ Dual prompt test failed: \(error.localizedDescription)")
        }
        
        return results
    }
    
    // MARK: - Test 3: Compare Both Approaches
    
    private static func testCompareSingleVsDualPrompt() async -> [String] {
        var results: [String] = []
        results.append("🧪 Test 3: Comparison Test")
        results.append("==========================")
        
        let proxyService = ProxyService()
        
        do {
            // Single prompt
            let combinedPrompt = "\(testSystemPrompt)\n\n\(testUserPrompt)"
            results.append("📤 Testing single prompt...")
            let singleResponse = try await proxyService.aiCoach(
                prompt: combinedPrompt,
                model: "gpt-5-mini",
                maxOutputTokens: 800,
                reasoningEffort: "low",
                textFormat: "json"
            )
            
            // Dual prompt
            results.append("📤 Testing dual prompt...")
            var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("ai/coach"))
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            AppConfig.addAuthHeaders(&req)
            
            let requestBody: [String: Any] = [
                "system": testSystemPrompt,
                "prompt": testUserPrompt,
                "model": "gpt-5-mini",
                "max_output_tokens": 800,
                "reasoning_effort": "low",
                "text_format": "json"
            ]
            
            req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: req)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                results.append("❌ Dual prompt request failed")
                return results
            }
            
            let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dualResponse = responseDict?["text"] as? String else {
                results.append("❌ No text in dual response")
                return results
            }
            
            // Compare
            results.append("")
            results.append("📊 Comparison Results:")
            results.append("---------------------")
            results.append("Single Prompt Length: \(singleResponse.count) chars")
            results.append("Dual Prompt Length: \(dualResponse.count) chars")
            results.append("")
            results.append("📝 Single Prompt Response:")
            results.append(singleResponse)
            results.append("")
            results.append("📝 Dual Prompt Response:")
            results.append(dualResponse)
            results.append("")
            results.append("✅ Comparison complete - review responses above")
            results.append("   Look for: clarity, focus on 'Needs Improvement', tone consistency")
            
        } catch {
            results.append("❌ Comparison test failed: \(error.localizedDescription)")
        }
        
        return results
    }
}

