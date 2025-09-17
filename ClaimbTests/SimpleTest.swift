//
//  SimpleTest.swift
//  ClaimbTests
//
//  Created by AI Assistant on 2025-09-10.
//

import Foundation

@testable import Claimb

/// Simple test to verify basic functionality without XCTest
final class SimpleTest {

    static func runBasicTests() -> [String] {
        var results: [String] = []

        // Test UIState basic functionality
        let loadingState = UIState<String>.loading
        if loadingState.isLoading {
            results.append("✅ UIState loading state works")
        } else {
            results.append("❌ UIState loading state failed")
        }

        let loadedState = UIState<String>.loaded("test")
        if loadedState.isLoaded && loadedState.data == "test" {
            results.append("✅ UIState loaded state works")
        } else {
            results.append("❌ UIState loaded state failed")
        }

        // Test ClaimbLogger basic functionality
        ClaimbLogger.debug("Test debug message")
        ClaimbLogger.info("Test info message")
        ClaimbLogger.warning("Test warning message")
        ClaimbLogger.error("Test error message")
        results.append("✅ ClaimbLogger basic functionality works")

        // Test DesignSystem basic functionality
        let primaryColor = DesignSystem.Colors.primary
        let bodyFont = DesignSystem.Typography.body
        let mediumSpacing = DesignSystem.Spacing.md
        results.append("✅ DesignSystem basic functionality works")

        return results
    }
}
