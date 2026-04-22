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

    // MARK: - Enhanced Debug Info (Phase 07)

    func testEnhancedDebugInfoContainsASRModelStatus() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "1.0.0",
            buildNumber: "1",
            asrModelLoaded: true,
            ollamaAvailable: false,
            ollamaModel: "mistral",
            autoPasteEnabled: false,
            historyCount: 5,
            lastError: nil
        )
        XCTAssertTrue(info.contains("ASR Model: loaded"))
    }

    func testEnhancedDebugInfoContainsOllamaStatus() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "1.0.0",
            buildNumber: "1",
            asrModelLoaded: false,
            ollamaAvailable: true,
            ollamaModel: "gemma",
            autoPasteEnabled: true,
            historyCount: 0,
            lastError: nil
        )
        XCTAssertTrue(info.contains("Ollama: connected (gemma)"))
        XCTAssertTrue(info.contains("ASR Model: not loaded"))
        XCTAssertTrue(info.contains("Auto-paste: true"))
    }

    func testEnhancedDebugInfoContainsLastError() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "1.0.0",
            buildNumber: "1",
            asrModelLoaded: false,
            ollamaAvailable: false,
            ollamaModel: "mistral",
            autoPasteEnabled: false,
            historyCount: 0,
            lastError: "Something broke"
        )
        XCTAssertTrue(info.contains("Last error: Something broke"))
    }

    func testEnhancedDebugInfoShowsNoneWhenNoError() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "1.0.0",
            buildNumber: "1",
            asrModelLoaded: true,
            ollamaAvailable: false,
            ollamaModel: "mistral",
            autoPasteEnabled: false,
            historyCount: 3,
            lastError: nil
        )
        XCTAssertTrue(info.contains("Last error: none"))
    }

    // Verify the legacy 3-arg overload still works
    func testLegacyBuildDebugInfoStillWorks() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: "1.0.0",
            buildNumber: "42"
        )
        XCTAssertTrue(info.contains("Squawk"))
        XCTAssertTrue(info.contains("1.0.0"))
    }
}
