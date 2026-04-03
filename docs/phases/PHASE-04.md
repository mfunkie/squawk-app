# PHASE-04: Global Hotkey & Recording State Machine

## Goal

Implement a system-wide global hotkey that toggles recording, manage recording state transitions with a clean state machine, and provide visual feedback via the menu bar icon.

## Prerequisites

- PHASE-01 complete: `AudioCaptureManager` starts/stops capture
- PHASE-02 complete: `TranscriptionEngine` transcribes audio
- `HotkeyManager.swift` stub exists from PHASE-00
- `DictationController.swift` stub with `DictationState` enum exists

## Directory & File Structure

Files to implement:

```
Squawk/
├── Utilities/
│   └── HotkeyManager.swift          # Full implementation
├── Pipeline/
│   └── DictationController.swift     # State machine (partial — full pipeline in PHASE-05)
├── Views/
│   └── StatusIndicator.swift         # Menu bar icon state binding
└── SquawkApp.swift                   # Wire hotkey + icon state
```

## Detailed Steps

### Step 1: Define the DictationState Machine

`Pipeline/DictationController.swift` — the state machine that drives the entire app:

```swift
enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case refining
}
```

**State transitions:**

```
                    hotkey press
        idle ────────────────────► recording
         ▲                              │
         │                         hotkey press / timeout
         │                              │
         │                              ▼
         │                        transcribing
         │                              │
         │              ┌───────────────┼───────────────┐
         │              │ Ollama OFF    │ Ollama ON     │
         │              ▼               ▼               │
         └──────── (done)          refining             │
                                       │                │
                                       ▼                │
                                   (done) ──────────────┘
```

**Invalid transitions to guard against:**
- `recording → recording` (double press — debounce)
- `transcribing → recording` (must finish first)
- `refining → recording` (must finish first)
- Only `idle` can transition to `recording`

### Step 2: Implement HotkeyManager — Toggle Mode

`Utilities/HotkeyManager.swift`:

```swift
import Cocoa
import Carbon.HIToolbox
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
}
```

**Toggle mode uses `NSEvent.addGlobalMonitorForEvents`:**

This approach:
- Does NOT require Accessibility permission
- Works for modifier+key combinations (Cmd+Shift+Space)
- Fires on keyDown only (no keyUp, so no push-to-talk)
- Does NOT fire when the app's own popover is focused

```swift
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
}
```

**Key event handler with debounce:**

```swift
private func handleKeyEvent(_ event: NSEvent) {
    // Check key code matches
    guard event.keyCode == keyCode else { return }

    // Check modifiers — use intersection to ignore irrelevant flags
    let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
    guard event.modifierFlags.intersection(relevantModifiers) == modifierFlags else { return }

    // Debounce: ignore if triggered within the last 300ms
    let now = Date()
    guard now.timeIntervalSince(lastTriggerTime) > debounceInterval else {
        Log.pipeline.debug("Hotkey debounced")
        return
    }
    lastTriggerTime = now

    Log.pipeline.info("Hotkey triggered")
    onToggle?()
}
```

**Human-readable hotkey description (for UI display):**

```swift
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
    default:
        // Convert key code to character
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        // Simplified — for full implementation, use UCKeyTranslate
        keyName = "Key(\(keyCode))"
    }

    parts.append(keyName)
    return parts.joined()
}
```

### Step 3: Push-to-Talk Mode (Enhancement)

Push-to-talk requires detecting both keyDown AND keyUp, which needs `CGEvent.tapCreate()` and **Accessibility permission**.

```swift
import ApplicationServices

extension HotkeyManager {
    /// Check if Accessibility access is granted (required for push-to-talk)
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission (shows system prompt)
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings → Privacy → Accessibility
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

**CGEvent tap for push-to-talk:**

```swift
// Push-to-talk implementation (requires Accessibility permission)
// Records while key is held, stops on release
private var eventTap: CFMachPort?

func startPushToTalk() {
    guard Self.hasAccessibilityPermission else {
        Log.pipeline.warning("Push-to-talk requires Accessibility permission")
        return
    }

    let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

    guard let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,  // observe only, don't consume events
        eventsOfInterest: CGEventMask(mask),
        callback: { _, type, event, userInfo in
            // Forward to HotkeyManager instance
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
}
```

**Implementation priority:** Start with toggle mode (Step 2). Push-to-talk is an enhancement gated behind Accessibility permission. Both modes should be selectable in settings (PHASE-06).

### Step 4: Wire Menu Bar Icon to State

The `MenuBarExtra` image should change based on `DictationState`. In `SquawkApp.swift`:

```swift
@main
struct SquawkApp: App {
    @State private var dictationController = DictationController()

    private var menuBarIcon: String {
        switch dictationController.state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "ellipsis.circle"
        case .refining: return "sparkles"
        }
    }

    var body: some Scene {
        MenuBarExtra("Squawk", systemImage: menuBarIcon) {
            MenuBarView()
                .environment(dictationController)
        }
        .menuBarExtraStyle(.window)
    }
}
```

> **Note:** SwiftUI's `MenuBarExtra` reactively updates the icon when the computed property changes. No manual refresh needed.

### Step 5: Recording Timeout

Auto-stop recording after a configurable maximum duration (default 5 minutes):

```swift
// In DictationController
private var recordingTimeoutTask: Task<Void, Never>?

func startRecording() {
    // ... start audio capture ...
    state = .recording

    // Start timeout
    let maxDuration = AppSettings.maxRecordingDuration // default 300 seconds
    recordingTimeoutTask = Task {
        try? await Task.sleep(for: .seconds(maxDuration))
        guard !Task.isCancelled else { return }
        Log.pipeline.warning("Recording timeout reached (\(maxDuration)s)")
        await stopAndTranscribe()
    }
}

func stopAndTranscribe() {
    recordingTimeoutTask?.cancel()
    // ... stop capture and transcribe ...
}
```

### Step 6: Handle Sleep/Wake

CGEvent taps can become invalid after sleep/wake. Re-register on wake:

```swift
private func observeSystemEvents() {
    NotificationCenter.default.addObserver(
        forName: NSWorkspace.didWakeNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Log.pipeline.info("System woke — re-registering hotkey")
        self?.stop()
        self?.start()
    }
}
```

Also stop any active recording on sleep:

```swift
NotificationCenter.default.addObserver(
    forName: NSWorkspace.willSleepNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    guard let self, self.dictationController.state == .recording else { return }
    Log.pipeline.warning("System sleeping during recording — stopping")
    // Stop recording and optionally transcribe partial audio
}
```

## Key Dependencies

| Framework | Import | Usage |
|-----------|--------|-------|
| Cocoa | `import Cocoa` | `NSEvent.addGlobalMonitorForEvents`, `NSEvent.ModifierFlags` |
| Carbon.HIToolbox | `import Carbon.HIToolbox` | Key code constants (`kVK_Space`, etc.) |
| ApplicationServices | `import ApplicationServices` | `AXIsProcessTrusted()`, `CGEvent.tapCreate()` |

## Gotchas & Edge Cases

1. **`addGlobalMonitorForEvents` does NOT fire for the focused app** — You MUST also install a local monitor with `addLocalMonitorForEvents` to catch hotkey presses when the popover is open.

2. **Cmd+Space is Spotlight** — Default hotkey is **Cmd+Shift+Space** to avoid conflict. Warn users if they try to bind Cmd+Space.

3. **Cmd+Shift+Space might be Input Sources** — Some users have "Select next input source" bound to Cmd+Shift+Space in System Settings → Keyboard → Shortcuts. Document this conflict.

4. **Debounce is essential** — Without debounce, holding keys with auto-repeat triggers rapid toggle events. The 300ms debounce window prevents this.

5. **CGEvent tap invalidation** — After sleep/wake or Fast User Switching, CGEvent taps may become invalid. Listen for `NSWorkspace.didWakeNotification` and re-register.

6. **Bluetooth keyboard key codes** — Generally the same as built-in keyboard, but some third-party keyboards may use non-standard key codes. The hotkey customization UI (PHASE-06) handles this by capturing actual key events.

7. **Push-to-talk race condition** — If the user releases the key very quickly (<100ms), the keyUp may arrive before audio capture fully starts. Add a minimum recording duration of 500ms.

8. **Multiple screens / full-screen apps** — Global monitors work regardless of the focused app, including full-screen apps. No special handling needed.

## Acceptance Criteria

- [ ] Cmd+Shift+Space toggles recording from any app in macOS
- [ ] Menu bar icon changes: mic (idle) → mic.fill (recording) → ellipsis.circle (transcribing)
- [ ] Rapid double-tap within 300ms is debounced (only one toggle)
- [ ] Recording auto-stops at configured maximum duration (default 5 min)
- [ ] Hotkey works when the Squawk popover is focused (local monitor)
- [ ] Hotkey works when other apps are focused (global monitor)
- [ ] Sleep during recording: recording stops gracefully
- [ ] Wake from sleep: hotkey re-registers and works
- [ ] Push-to-talk mode (if Accessibility permission granted): hold to record, release to stop
- [ ] No Accessibility permission prompt for toggle mode

## Estimated Complexity

**M** — Toggle mode is straightforward with `NSEvent`. Push-to-talk with `CGEvent` tap is more complex but well-documented. The state machine is simple with 4 states and clear transitions.

## References

- **speak2** → `DictationController.swift`: Uses fn key for push-to-talk via `CGEvent` tap. Study its state management and how it handles rapid key presses.
- **speak2** → Key handling: It specifically uses the fn key (keyCode 63), which doesn't require modifier combinations. Worth studying as an alternative default.
- **Apple docs** → [NSEvent.addGlobalMonitorForEvents](https://developer.apple.com/documentation/appkit/nsevent/1535472-addglobalmonitorforevents), [CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/1454426-tapcreate).
