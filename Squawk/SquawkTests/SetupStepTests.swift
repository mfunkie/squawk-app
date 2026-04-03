import XCTest
@testable import Squawk

final class SetupStepTests: XCTestCase {

    func testSetupStepOrder() {
        let steps = SetupStep.allCases
        XCTAssertEqual(steps.count, 5)
        XCTAssertEqual(steps[0], .welcome)
        XCTAssertEqual(steps[1], .modelDownload)
        XCTAssertEqual(steps[2], .microphonePermission)
        XCTAssertEqual(steps[3], .accessibilityPermission)
        XCTAssertEqual(steps[4], .ready)
    }

    func testSetupStepRawValues() {
        XCTAssertEqual(SetupStep.welcome.rawValue, 0)
        XCTAssertEqual(SetupStep.ready.rawValue, 4)
    }

    func testCanAdvanceFromWelcome() {
        // Welcome step can always advance (no prerequisites)
        XCTAssertTrue(SetupStep.welcome.canAdvanceWithoutPrerequisite)
    }

    func testReadyIsLastStep() {
        XCTAssertTrue(SetupStep.ready.isLast)
        XCTAssertFalse(SetupStep.welcome.isLast)
    }
}
