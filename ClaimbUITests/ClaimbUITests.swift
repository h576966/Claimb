import XCTest

final class ClaimbUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITestMode"]
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 1), "App failed to launch in UI tests.")
    }
}

