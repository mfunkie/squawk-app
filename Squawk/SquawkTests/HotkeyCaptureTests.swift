import XCTest
import Carbon.HIToolbox
@testable import Squawk

final class HotkeyCaptureTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "hotkey.keyCode")
        UserDefaults.standard.removeObject(forKey: "hotkey.modifierFlags")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "hotkey.keyCode")
        UserDefaults.standard.removeObject(forKey: "hotkey.modifierFlags")
        super.tearDown()
    }

    func testHotkeyManagerUpdatesKeyCode() {
        let manager = HotkeyManager()
        XCTAssertEqual(manager.keyCode, UInt16(kVK_Space))

        manager.keyCode = UInt16(kVK_ANSI_K)
        manager.modifierFlags = [.command, .option]
        XCTAssertEqual(manager.keyCode, UInt16(kVK_ANSI_K))
        XCTAssertEqual(manager.modifierFlags, [.command, .option])
    }

    func testHotkeyDescriptionAfterChange() {
        let manager = HotkeyManager()
        manager.keyCode = UInt16(kVK_Return)
        manager.modifierFlags = [.control, .option]
        XCTAssertEqual(manager.hotkeyDescription, "⌃⌥Return")
    }
}
