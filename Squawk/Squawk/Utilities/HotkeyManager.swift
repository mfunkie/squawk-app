import Cocoa
import Carbon.HIToolbox
import ApplicationServices
import os

final class HotkeyManager {
    // MARK: - Configuration
    var keyCode: UInt16 = UInt16(kVK_Space) // 49
    var modifierFlags: NSEvent.ModifierFlags = [.command, .shift]
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
