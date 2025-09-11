//
//  ClaimbUITests.swift
//  ClaimbUITests
//
//  Created by Niklas Johansson on 2025-09-07.
//

import XCTest

final class ClaimbUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func testRoleSelectorDisplay() throws {
        // Test that role selector is displayed when user is logged in
        let app = XCUIApplication()
        app.launch()
        
        // Wait for the app to load and check if role selector is visible
        let roleSelector = app.staticTexts["Primary Role"]
        XCTAssertTrue(roleSelector.waitForExistence(timeout: 10), "Role selector should be visible")
        
        // Check that role buttons are present
        let topButton = app.buttons["Top"]
        let jungleButton = app.buttons["Jungle"]
        let midButton = app.buttons["Mid"]
        let bottomButton = app.buttons["Bottom"]
        let supportButton = app.buttons["Support"]
        
        XCTAssertTrue(topButton.exists, "Top role button should exist")
        XCTAssertTrue(jungleButton.exists, "Jungle role button should exist")
        XCTAssertTrue(midButton.exists, "Mid role button should exist")
        XCTAssertTrue(bottomButton.exists, "Bottom role button should exist")
        XCTAssertTrue(supportButton.exists, "Support role button should exist")
    }
    
    @MainActor
    func testRoleSelectorInteraction() throws {
        // Test role selector button interactions
        let app = XCUIApplication()
        app.launch()
        
        // Wait for role selector to load
        let roleSelector = app.staticTexts["Primary Role"]
        XCTAssertTrue(roleSelector.waitForExistence(timeout: 10), "Role selector should be visible")
        
        // Test clicking different role buttons
        let topButton = app.buttons["Top"]
        let midButton = app.buttons["Mid"]
        
        if topButton.exists {
            topButton.tap()
            // Verify the button appears selected (this would need to be customized based on your UI)
        }
        
        if midButton.exists {
            midButton.tap()
            // Verify the button appears selected
        }
    }
    
    @MainActor
    func testWinRateDisplay() throws {
        // Test that win rates are displayed for each role
        let app = XCUIApplication()
        app.launch()
        
        // Wait for role selector to load
        let roleSelector = app.staticTexts["Primary Role"]
        XCTAssertTrue(roleSelector.waitForExistence(timeout: 10), "Role selector should be visible")
        
        // Check for win rate percentages (they should be displayed as text)
        // This is a basic check - you might need to adjust based on your actual UI structure
        let winRateElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%'"))
        XCTAssertTrue(winRateElements.count > 0, "Win rate percentages should be displayed")
    }
}
