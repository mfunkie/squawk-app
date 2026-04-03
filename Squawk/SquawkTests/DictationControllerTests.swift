import XCTest
@testable import Squawk

final class DictationControllerTests: XCTestCase {

    // MARK: - State Machine Transitions

    func testInitialStateIsIdle() {
        let controller = DictationController()
        XCTAssertEqual(controller.state, .idle)
    }

    func testToggleFromIdleTransitionsToRecording() {
        let controller = DictationController()
        controller.toggle()
        XCTAssertEqual(controller.state, .recording)
    }

    func testToggleFromRecordingTransitionsToTranscribing() {
        let controller = DictationController()
        controller.toggle()
        XCTAssertEqual(controller.state, .recording)
        controller.toggle()
        XCTAssertEqual(controller.state, .transcribing)
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
}
