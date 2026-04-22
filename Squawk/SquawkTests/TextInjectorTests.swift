import XCTest
@testable import Squawk

final class TextInjectorTests: XCTestCase {

    // MARK: - Copy to Clipboard

    func testCopyToClipboardSetsString() {
        let injector = TextInjector()
        injector.copyToClipboard("hello clipboard")

        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "hello clipboard")
    }

    func testCopyToClipboardOverwritesPrevious() {
        let injector = TextInjector()
        injector.copyToClipboard("first")
        injector.copyToClipboard("second")

        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "second")
    }

    func testCopyToClipboardHandlesEmptyString() {
        let injector = TextInjector()
        injector.copyToClipboard("")

        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "")
    }

    func testCopyToClipboardHandlesUnicode() {
        let injector = TextInjector()
        injector.copyToClipboard("Hello 世界 🌍")

        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "Hello 世界 🌍")
    }

    // MARK: - Accessibility Trust Gate

    func testPasteSkipsSimulationWhenAccessibilityNotTrusted() async {
        var injector = TextInjector()
        injector.isAccessibilityTrusted = { false }

        let result = await injector.pasteIntoActiveApp("manual paste fallback")

        XCTAssertEqual(result, .skippedNoAccessibility)
        // Text must remain on the clipboard so the user can ⌘V manually.
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "manual paste fallback")
    }

    func testPasteReportsPastedWhenAccessibilityTrusted() async {
        var injector = TextInjector()
        injector.isAccessibilityTrusted = { true }

        let result = await injector.pasteIntoActiveApp("trusted path")

        XCTAssertEqual(result, .pasted)
    }
}
