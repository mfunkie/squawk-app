import Cocoa
import Carbon.HIToolbox
import ApplicationServices
import os

final class HotkeyManager {
    // MARK: - Configuration (persisted to UserDefaults)
    var keyCode: UInt16 {
        get {
            let stored = UserDefaults.standard.integer(forKey: "hotkey.keyCode")
            return stored > 0 ? UInt16(stored) : UInt16(kVK_Space)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkey.keyCode") }
    }
    var modifierFlags: NSEvent.ModifierFlags {
        get {
            let stored = UserDefaults.standard.integer(forKey: "hotkey.modifierFlags")
            return stored > 0 ? NSEvent.ModifierFlags(rawValue: UInt(stored)) : [.command, .shift]
        }
        set { UserDefaults.standard.set(Int(newValue.rawValue), forKey: "hotkey.modifierFlags") }
    }
    var onToggle: (() -> Void)?

    // MARK: - Private
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastTriggerTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.3

    // Push-to-talk
    private var eventTap: CFMachPort?
    var onPushStart: (() -> Void)?
    var onPushEnd: (() -> Void)?

    // MARK: - Toggle Mode (no Accessibility needed)

    func start() {
        // Global monitor: fires when OTHER apps are focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor: fires when THIS app's popover is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            self?.handleKeyEvent(event)
            return event // pass through
        }

        observeSystemEvents()
        Log.pipeline.info("Hotkey registered: \(self.hotkeyDescription)")
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        stopPushToTalk()
    }

    // MARK: - Key Event Handling

    private func handleKeyEvent(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }

        // Check modifiers — use intersection to ignore irrelevant flags
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        guard event.modifierFlags.intersection(relevantModifiers) == modifierFlags else { return }

        guard debounceCheck() else {
            Log.pipeline.debug("Hotkey debounced")
            return
        }

        Log.pipeline.info("Hotkey triggered")
        onToggle?()
    }

    /// Returns true if enough time has elapsed since last trigger.
    private func debounceCheck() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > debounceInterval else {
            return false
        }
        lastTriggerTime = now
        return true
    }

    // MARK: - Hotkey Description

    var hotkeyDescription: String {
        var parts: [String] = []
        if modifierFlags.contains(.control) { parts.append("⌃") }
        if modifierFlags.contains(.option) { parts.append("⌥") }
        if modifierFlags.contains(.shift) { parts.append("⇧") }
        if modifierFlags.contains(.command) { parts.append("⌘") }

        let keyName: String
        switch Int(keyCode) {
        case kVK_Space: keyName = "Space"
        case kVK_Return: keyName = "Return"
        case kVK_Tab: keyName = "Tab"
        case kVK_Escape: keyName = "Esc"
        case kVK_Delete: keyName = "Delete"
        case kVK_ForwardDelete: keyName = "Fwd Delete"
        case kVK_UpArrow: keyName = "↑"
        case kVK_DownArrow: keyName = "↓"
        case kVK_LeftArrow: keyName = "←"
        case kVK_RightArrow: keyName = "→"
        case kVK_Home: keyName = "Home"
        case kVK_End: keyName = "End"
        case kVK_PageUp: keyName = "Page Up"
        case kVK_PageDown: keyName = "Page Down"
        case kVK_ANSI_A: keyName = "A"
        case kVK_ANSI_B: keyName = "B"
        case kVK_ANSI_C: keyName = "C"
        case kVK_ANSI_D: keyName = "D"
        case kVK_ANSI_E: keyName = "E"
        case kVK_ANSI_F: keyName = "F"
        case kVK_ANSI_G: keyName = "G"
        case kVK_ANSI_H: keyName = "H"
        case kVK_ANSI_I: keyName = "I"
        case kVK_ANSI_J: keyName = "J"
        case kVK_ANSI_K: keyName = "K"
        case kVK_ANSI_L: keyName = "L"
        case kVK_ANSI_M: keyName = "M"
        case kVK_ANSI_N: keyName = "N"
        case kVK_ANSI_O: keyName = "O"
        case kVK_ANSI_P: keyName = "P"
        case kVK_ANSI_Q: keyName = "Q"
        case kVK_ANSI_R: keyName = "R"
        case kVK_ANSI_S: keyName = "S"
        case kVK_ANSI_T: keyName = "T"
        case kVK_ANSI_U: keyName = "U"
        case kVK_ANSI_V: keyName = "V"
        case kVK_ANSI_W: keyName = "W"
        case kVK_ANSI_X: keyName = "X"
        case kVK_ANSI_Y: keyName = "Y"
        case kVK_ANSI_Z: keyName = "Z"
        case kVK_ANSI_0: keyName = "0"
        case kVK_ANSI_1: keyName = "1"
        case kVK_ANSI_2: keyName = "2"
        case kVK_ANSI_3: keyName = "3"
        case kVK_ANSI_4: keyName = "4"
        case kVK_ANSI_5: keyName = "5"
        case kVK_ANSI_6: keyName = "6"
        case kVK_ANSI_7: keyName = "7"
        case kVK_ANSI_8: keyName = "8"
        case kVK_ANSI_9: keyName = "9"
        case kVK_ANSI_Minus: keyName = "-"
        case kVK_ANSI_Equal: keyName = "="
        case kVK_ANSI_LeftBracket: keyName = "["
        case kVK_ANSI_RightBracket: keyName = "]"
        case kVK_ANSI_Backslash: keyName = "\\"
        case kVK_ANSI_Semicolon: keyName = ";"
        case kVK_ANSI_Quote: keyName = "'"
        case kVK_ANSI_Comma: keyName = ","
        case kVK_ANSI_Period: keyName = "."
        case kVK_ANSI_Slash: keyName = "/"
        case kVK_ANSI_Grave: keyName = "`"
        case kVK_F1: keyName = "F1"
        case kVK_F2: keyName = "F2"
        case kVK_F3: keyName = "F3"
        case kVK_F4: keyName = "F4"
        case kVK_F5: keyName = "F5"
        case kVK_F6: keyName = "F6"
        case kVK_F7: keyName = "F7"
        case kVK_F8: keyName = "F8"
        case kVK_F9: keyName = "F9"
        case kVK_F10: keyName = "F10"
        case kVK_F11: keyName = "F11"
        case kVK_F12: keyName = "F12"
        default: keyName = "Key(\(keyCode))"
        }

        parts.append(keyName)
        return parts.joined()
    }

    // MARK: - Push-to-Talk (requires Accessibility permission)

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func startPushToTalk() {
        guard Self.hasAccessibilityPermission else {
            Log.pipeline.warning("Push-to-talk requires Accessibility permission")
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo!).takeUnretainedValue()
                manager.handleCGEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.pipeline.error("Failed to create CGEvent tap")
            return
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        Log.pipeline.info("Push-to-talk CGEvent tap installed")
    }

    func stopPushToTalk() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard code == keyCode else { return }

        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        guard flags.intersection(relevantModifiers) == modifierFlags else { return }

        switch type {
        case .keyDown:
            guard debounceCheck() else { return }
            Log.pipeline.info("Push-to-talk: key down")
            onPushStart?()
        case .keyUp:
            Log.pipeline.info("Push-to-talk: key up")
            onPushEnd?()
        default:
            break
        }
    }

    // MARK: - Sleep/Wake

    private func observeSystemEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.pipeline.info("System woke — re-registering hotkey")
            self?.stop()
            self?.start()
        }
    }

    // MARK: - Testing Support

    /// Simulate a hotkey trigger for unit tests.
    func simulateTrigger() {
        guard debounceCheck() else { return }
        onToggle?()
    }

    /// Reset debounce timer for testing purposes.
    func resetDebounceForTesting() {
        lastTriggerTime = .distantPast
    }
}
