//
//  SquawkUITests.swift
//  SquawkUITests
//
//  Created by Mark Funk on 4/3/26.
//

import XCTest

final class SquawkUITests: XCTestCase {

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
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        // XCTApplicationLaunchMetric needs to relaunch the app each iteration, but
        // SingleInstanceGuard.terminateIfDuplicate() kills any second copy before it
        // connects to the test runner — every iteration after the first reports zero metrics.
        throw XCTSkip("Incompatible with single-instance enforcement (SquawkApp.init).")
    }
}
