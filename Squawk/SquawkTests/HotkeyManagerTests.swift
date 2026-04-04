import XCTest
@testable import Squawk

final class HotkeyManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear persisted hotkey settings so tests use defaults
        UserDefaults.standard.removeObject(forKey: "hotkey.keyCode")
        UserDefaults.standard.removeObject(forKey: "hotkey.modifierFlags")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "hotkey.keyCode")
        UserDefaults.standard.removeObject(forKey: "hotkey.modifierFlags")
        super.tearDown()
    }

    // MARK: - Default Configuration

    func testDefaultKeyCodeIsSpace() {
        let manager = HotkeyManager()
        XCTAssertEqual(manager.keyCode, 49) // kVK_Space
    }

    func testDefaultModifiersAreCmdShift() {
        let manager = HotkeyManager()
        XCTAssertTrue(manager.modifierFlags.contains(.command))
        XCTAssertTrue(manager.modifierFlags.contains(.shift))
        XCTAssertFalse(manager.modifierFlags.contains(.option))
        XCTAssertFalse(manager.modifierFlags.contains(.control))
    }

    // MARK: - Hotkey Description

    func testHotkeyDescriptionDefaultCmdShiftSpace() {
        let manager = HotkeyManager()
        let desc = manager.hotkeyDescription
        XCTAssertTrue(desc.contains("⇧"), "Should contain shift symbol")
        XCTAssertTrue(desc.contains("⌘"), "Should contain command symbol")
        XCTAssertTrue(desc.contains("Space"), "Should contain Space")
    }

    func testHotkeyDescriptionWithControlOption() {
        let manager = HotkeyManager()
        manager.modifierFlags = [.control, .option]
        manager.keyCode = 36 // kVK_Return
        let desc = manager.hotkeyDescription
        XCTAssertTrue(desc.contains("⌃"), "Should contain control symbol")
        XCTAssertTrue(desc.contains("⌥"), "Should contain option symbol")
        XCTAssertTrue(desc.contains("Return"), "Should contain Return")
    }

    // MARK: - Persistence

    func testHotkeySettingsPersistToUserDefaults() {
        let manager = HotkeyManager()
        manager.keyCode = 36 // Return
        manager.modifierFlags = [.control, .option]

        // Read from a new instance
        let manager2 = HotkeyManager()
        XCTAssertEqual(manager2.keyCode, 36)
        XCTAssertEqual(manager2.modifierFlags, [.control, .option])
    }

    // MARK: - Debounce

    func testDebounceRejectsTriggerWithinInterval() {
        let manager = HotkeyManager()
        var triggerCount = 0
        manager.onToggle = { triggerCount += 1 }

        manager.simulateTrigger()
        manager.simulateTrigger() // should be debounced
        XCTAssertEqual(triggerCount, 1)
    }

    func testDebounceAllowsTriggerAfterInterval() {
        let manager = HotkeyManager()
        var triggerCount = 0
        manager.onToggle = { triggerCount += 1 }

        manager.simulateTrigger()
        manager.resetDebounceForTesting()
        manager.simulateTrigger()
        XCTAssertEqual(triggerCount, 2)
    }
}
