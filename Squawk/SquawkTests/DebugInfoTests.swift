import XCTest
@testable import Squawk

final class DebugInfoTests: XCTestCase {

    func testDebugInfoContainsAppName() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "1.0.0",
            buildNumber: "42"
        )
        XCTAssertTrue(info.contains("Squawk"), "Debug info should contain app name")
    }

    func testDebugInfoContainsVersion() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "1.0.0",
            buildNumber: "42"
        )
        XCTAssertTrue(info.contains("1.0.0"), "Debug info should contain version")
        XCTAssertTrue(info.contains("42"), "Debug info should contain build number")
    }

    func testDebugInfoContainsMacOSVersion() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "1.0.0",
            buildNumber: "1"
        )
        XCTAssertTrue(info.contains("macOS"), "Debug info should contain macOS label")
    }

    func testDebugInfoContainsChipInfo() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "0.1.0",
            buildNumber: "1"
        )
        XCTAssertTrue(info.contains("Chip:"), "Debug info should contain chip info")
    }

    func testMachineModelReturnsNonEmptyString() {
        let model = DebugInfoBuilder.machineModel
        XCTAssertFalse(model.isEmpty, "Machine model should not be empty")
    }
}
