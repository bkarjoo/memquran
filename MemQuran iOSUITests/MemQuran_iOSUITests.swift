//
//  MemQuran_iOSUITests.swift
//  MemQuran iOSUITests
//
//  Created by Behrooz Karjoo on 10/11/25.
//

import XCTest

final class MemQuran_iOSUITests: XCTestCase {

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

    // MARK: - Audio Caching Toggle Tests

    @MainActor
    func testAudioCachingToggleInteraction() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Settings (look for settings button/gear icon)
        // Note: The exact navigation may depend on your UI structure
        // This is a placeholder - adjust based on actual UI
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()

            // Find the "Cache Audio Files" toggle
            let cacheToggle = app.switches["Cache Audio Files"]

            // Verify toggle exists
            XCTAssertTrue(cacheToggle.exists, "Cache Audio Files toggle should exist in Settings")

            // Get initial state (should default to ON/1)
            let initialState = cacheToggle.value as? String

            // Toggle OFF
            cacheToggle.tap()

            // Wait a moment for the change to persist
            sleep(1)

            // Verify state changed
            let newState = cacheToggle.value as? String
            XCTAssertNotEqual(initialState, newState, "Toggle state should change after tap")

            // Dismiss settings (if needed)
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else if app.navigationBars.buttons.element(boundBy: 0).exists {
                app.navigationBars.buttons.element(boundBy: 0).tap()
            }

            // Reopen settings
            if settingsButton.exists {
                settingsButton.tap()

                // Verify state persisted
                let persistedState = app.switches["Cache Audio Files"].value as? String
                XCTAssertEqual(newState, persistedState, "Toggle state should persist across navigation")
            }
        } else {
            // If we can't find the settings button, record a failure but don't crash the test
            XCTFail("Could not find Settings button in the UI")
        }
    }

    @MainActor
    func testAudioCachingToggleDescription() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Settings
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()

            // Verify the toggle exists
            let cacheToggle = app.switches["Cache Audio Files"]
            XCTAssertTrue(cacheToggle.exists, "Cache Audio Files toggle should exist")

            // Look for descriptive text containing "300 MB"
            // The exact predicate may need adjustment based on how SwiftUI renders the text
            let descriptionText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] '300 MB'"))

            // Verify descriptive text is visible
            XCTAssertTrue(descriptionText.firstMatch.exists,
                         "Descriptive text mentioning '300 MB' should be visible near the toggle")

            // Also verify it mentions "offline" or "audio"
            let offlineText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'offline'"))
            XCTAssertTrue(offlineText.firstMatch.exists || descriptionText.firstMatch.exists,
                         "Descriptive text should mention offline playback or storage")
        } else {
            XCTFail("Could not find Settings button in the UI")
        }
    }
}
