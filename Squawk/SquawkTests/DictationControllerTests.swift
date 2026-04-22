import XCTest
@testable import Squawk

final class DictationControllerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // DictationController reads these settings from UserDefaults.standard. Without
        // clearing them, tests inherit whatever the developer toggled on their machine.
        let keys = [
            "ollama.enabled",
            "ollama.model",
            "output.autoPaste",
            "output.restoreClipboard",
            "recording.maxDuration",
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - State Machine Transitions

    func testInitialStateIsIdle() {
        let controller = DictationController()
        XCTAssertEqual(controller.state, .idle)
    }

    func testToggleFromIdleWhenModelNotReadyShowsError() {
        let controller = DictationController()
        // transcriptionEngine.isReady is false by default
        controller.toggle()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(controller.lastError, "Speech model not loaded yet")
    }

    func testToggleFromRecordingStopsRecording() {
        let controller = DictationController()
        // Manually set recording state to test the transition
        controller.state = .recording
        controller.toggle()
        // toggle from recording kicks off async stopAndTranscribe,
        // but state moves out of recording
        // Since stopAndTranscribe is async, we check it left recording
        let expectation = XCTestExpectation(description: "state transitions")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Should be idle (audio was empty so it discards)
            XCTAssertEqual(controller.state, .idle)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testToggleDuringTranscribingIsIgnored() {
        let controller = DictationController()
        controller.state = .transcribing
        controller.toggle()
        XCTAssertEqual(controller.state, .transcribing)
    }

    func testToggleDuringRefiningIsIgnored() {
        let controller = DictationController()
        controller.state = .refining
        controller.toggle()
        XCTAssertEqual(controller.state, .refining)
    }

    func testTransitionToRefining() {
        let controller = DictationController()
        controller.state = .transcribing
        controller.transitionToRefining()
        XCTAssertEqual(controller.state, .refining)
    }

    func testTransitionToRefiningIgnoredIfNotTranscribing() {
        let controller = DictationController()
        controller.state = .idle
        controller.transitionToRefining()
        XCTAssertEqual(controller.state, .idle)
    }

    func testFinishReturnsToIdle() {
        let controller = DictationController()
        controller.state = .transcribing
        controller.finish()
        XCTAssertEqual(controller.state, .idle)

        controller.state = .refining
        controller.finish()
        XCTAssertEqual(controller.state, .idle)
    }

    func testFinishFromIdleStaysIdle() {
        let controller = DictationController()
        controller.finish()
        XCTAssertEqual(controller.state, .idle)
    }

    func testFinishFromRecordingStaysRecording() {
        let controller = DictationController()
        controller.state = .recording
        controller.finish()
        // finish should not affect recording — use toggle to stop
        XCTAssertEqual(controller.state, .recording)
    }

    // MARK: - Menu Bar Icon

    func testMenuBarIconForEachState() {
        let controller = DictationController()

        controller.state = .idle
        XCTAssertEqual(controller.menuBarIcon, "mic")

        controller.state = .recording
        XCTAssertEqual(controller.menuBarIcon, "mic.fill")

        controller.state = .transcribing
        XCTAssertEqual(controller.menuBarIcon, "ellipsis.circle")

        controller.state = .refining
        XCTAssertEqual(controller.menuBarIcon, "sparkles")
    }

    // MARK: - Pipeline Properties

    func testInitialOllamaSettings() {
        let controller = DictationController()
        XCTAssertTrue(controller.ollamaEnabled)
        // ollamaModel reads from UserDefaults; empty when no setting saved
        XCTAssertNotNil(controller.ollamaModel)
        XCTAssertFalse(controller.autoPasteEnabled)
        XCTAssertTrue(controller.restoreClipboardEnabled)
    }

    func testInitialPipelineState() {
        let controller = DictationController()
        XCTAssertFalse(controller.ollamaAvailable)
        XCTAssertNil(controller.lastLatencyMs)
        XCTAssertNil(controller.lastError)
    }

    func testHistoryIsAccessible() {
        let controller = DictationController()
        XCTAssertNotNil(controller.history.entries)
    }

    func testModelNotReadyDoesNotTransitionFromIdle() {
        let controller = DictationController()
        controller.toggle()
        // Should stay idle and set error
        XCTAssertEqual(controller.state, .idle)
        XCTAssertNotNil(controller.lastError)
    }
}
