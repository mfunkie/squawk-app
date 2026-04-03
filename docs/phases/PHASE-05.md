# PHASE-05: Core Pipeline Integration

## Goal

Connect all components into a single working dictation pipeline orchestrated by `DictationController`, including clipboard copy, auto-paste with clipboard restoration, and transcript history.

## Prerequisites

- PHASE-01 complete: `AudioCaptureManager` captures PCM audio
- PHASE-02 complete: `TranscriptionEngine` transcribes audio to text
- PHASE-03 complete: `TranscriptRefiner` polishes transcripts (with graceful degradation)
- PHASE-04 complete: `HotkeyManager` triggers recording, `DictationState` machine defined
- All components tested individually

## Directory & File Structure

Files to implement or complete:

```
Squawk/
├── Pipeline/
│   ├── DictationController.swift     # Full orchestrator implementation
│   └── TextInjector.swift            # Full implementation
├── Models/
│   ├── TranscriptEntry.swift         # Already defined in PHASE-00
│   └── TranscriptHistory.swift       # NEW — persistence layer
├── Views/
│   └── MenuBarView.swift             # Wire to DictationController
└── SquawkApp.swift                   # Final wiring
```

## Detailed Steps

### Step 1: Implement TextInjector

`Pipeline/TextInjector.swift` — handles clipboard and auto-paste:

```swift
import AppKit
import os

struct TextInjector {
    /// Copy text to clipboard only.
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Log.pipeline.info("Text copied to clipboard (\(text.count) chars)")
    }

    /// Copy text and simulate Cmd+V paste into the active app, then restore original clipboard.
    func pasteIntoActiveApp(_ text: String) async {
        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard contents
        let savedContents = saveClipboard(pasteboard)

        // 2. Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Small delay to ensure clipboard is updated
        try? await Task.sleep(for: .milliseconds(50))

        // 4. Simulate Cmd+V
        simulatePaste()

        // 5. Restore original clipboard after paste completes
        try? await Task.sleep(for: .milliseconds(200))
        restoreClipboard(pasteboard, from: savedContents)

        Log.pipeline.info("Text pasted into active app and clipboard restored")
    }
}
```

**Clipboard save/restore (pattern from speak2's TextInjector):**

```swift
private struct ClipboardContents {
    let items: [NSPasteboardItem]
    let types: [NSPasteboard.PasteboardType]
    // Store raw data per type for each item
    let data: [[(NSPasteboard.PasteboardType, Data)]]
}

private func saveClipboard(_ pasteboard: NSPasteboard) -> ClipboardContents? {
    guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }

    var allData: [[(NSPasteboard.PasteboardType, Data)]] = []
    for item in items {
        var itemData: [(NSPasteboard.PasteboardType, Data)] = []
        for type in item.types {
            if let data = item.data(forType: type) {
                itemData.append((type, data))
            }
        }
        allData.append(itemData)
    }

    return ClipboardContents(items: items, types: pasteboard.types ?? [], data: allData)
}

private func restoreClipboard(_ pasteboard: NSPasteboard, from saved: ClipboardContents?) {
    guard let saved else { return }
    pasteboard.clearContents()

    for itemData in saved.data {
        let newItem = NSPasteboardItem()
        for (type, data) in itemData {
            newItem.setData(data, forType: type)
        }
        pasteboard.writeObjects([newItem])
    }
}
```

**Simulate Cmd+V via CGEvent:**

```swift
private func simulatePaste() {
    let source = CGEventSource(stateID: .hidSystemState)

    // Key down: V (keyCode 9) with Cmd modifier
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else { return }
    keyDown.flags = .maskCommand

    // Key up
    guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else { return }
    keyUp.flags = .maskCommand

    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
}
```

> **Note:** `CGEvent.post(tap: .cghidEventTap)` requires either Accessibility permission or a non-sandboxed app. Since we're non-sandboxed (see DECISIONS.md #6), this works without additional permission in most cases. However, some apps with custom input handling may require Accessibility permission for reliable paste.

### Step 2: Implement TranscriptHistory

`Models/TranscriptHistory.swift` — persists transcript entries to JSON:

```swift
import Foundation
import os

@Observable
final class TranscriptHistory {
    private(set) var entries: [TranscriptEntry] = []
    private let maxEntries = 200
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let squawkDir = appSupport.appendingPathComponent("Squawk", isDirectory: true)
        try? FileManager.default.createDirectory(at: squawkDir, withIntermediateDirectories: true)
        fileURL = squawkDir.appendingPathComponent("history.json")

        loadFromDisk()
    }

    func add(_ entry: TranscriptEntry) {
        entries.insert(entry, at: 0) // newest first
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        saveToDisk()
    }

    func updateLatest(polishedText: String) {
        guard !entries.isEmpty else { return }
        entries[0].polishedText = polishedText
        saveToDisk()
    }

    func remove(at indexSet: IndexSet) {
        entries.remove(atOffsets: indexSet)
        saveToDisk()
    }

    func clearAll() {
        entries.removeAll()
        saveToDisk()
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([TranscriptEntry].self, from: data)
            Log.pipeline.info("Loaded \(self.entries.count) transcript entries from disk")
        } catch {
            Log.pipeline.error("Failed to load history: \(error)")
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.pipeline.error("Failed to save history: \(error)")
        }
    }
}
```

### Step 3: Complete DictationController — The Orchestrator

`Pipeline/DictationController.swift` — the central coordinator that owns all pipeline components:

```swift
import Observation
import os

@Observable
final class DictationController {
    // MARK: - Public state
    var state: DictationState = .idle
    var ollamaAvailable = false
    var lastLatencyMs: Int?
    var lastError: String?

    // MARK: - Owned components
    let audioCaptureManager = AudioCaptureManager()
    let modelManager = ModelManager()
    private(set) var transcriptionEngine: TranscriptionEngine!
    private let transcriptRefiner = TranscriptRefiner()
    private let textInjector = TextInjector()
    let history = TranscriptHistory()

    // MARK: - Settings (bound to @AppStorage in views)
    var ollamaEnabled = true
    var ollamaModel = "mistral"
    var autoPasteEnabled = false
    var restoreClipboardEnabled = true

    // MARK: - Private
    private var recordingTimeoutTask: Task<Void, Never>?
    private var ollamaPollingTask: Task<Void, Never>?
    private var consecutiveErrors = 0

    init() {
        transcriptionEngine = TranscriptionEngine(modelManager: modelManager)
    }
}
```

**The toggle method — called by HotkeyManager:**

```swift
@MainActor
func toggle() {
    switch state {
    case .idle:
        startRecording()
    case .recording:
        Task { await stopAndTranscribe() }
    case .transcribing, .refining:
        // Ignore — still processing previous recording
        Log.pipeline.debug("Toggle ignored — currently \(String(describing: self.state))")
    }
}
```

**Start recording:**

```swift
@MainActor
private func startRecording() {
    guard transcriptionEngine.isReady else {
        lastError = "Speech model not loaded yet"
        return
    }

    do {
        try audioCaptureManager.startCapture()
        state = .recording
        lastError = nil
        consecutiveErrors = 0

        // Start recording timeout
        let maxSeconds = 300 // 5 minutes, configurable
        recordingTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(maxSeconds))
            guard !Task.isCancelled else { return }
            Log.pipeline.warning("Recording timeout (\(maxSeconds)s)")
            await stopAndTranscribe()
        }
    } catch {
        lastError = error.localizedDescription
        Log.pipeline.error("Failed to start recording: \(error)")
    }
}
```

**Stop and run the full pipeline:**

```swift
@MainActor
private func stopAndTranscribe() async {
    recordingTimeoutTask?.cancel()

    // 1. Stop audio capture
    let samples = audioCaptureManager.stopCapture()
    guard samples.count > 8000 else { // <0.5 seconds = discard
        Log.pipeline.info("Audio too short (\(samples.count) samples) — discarding")
        state = .idle
        return
    }

    let pipelineStart = ContinuousClock.now
    let audioDuration = Double(samples.count) / 16000.0

    // 2. Transcribe
    state = .transcribing
    let rawTranscript: String
    do {
        rawTranscript = try await transcriptionEngine.transcribe(audioSamples: samples)
    } catch {
        handlePipelineError("Transcription failed: \(error.localizedDescription)")
        return
    }

    guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        Log.pipeline.info("Empty transcription — discarding")
        state = .idle
        return
    }

    // 3. Add to history immediately with raw text
    let entry = TranscriptEntry(
        id: UUID(),
        rawText: rawTranscript,
        polishedText: nil,
        timestamp: Date(),
        audioDuration: audioDuration,
        latencyMs: nil
    )
    history.add(entry)

    // 4. Copy raw text to clipboard immediately
    textInjector.copyToClipboard(rawTranscript)

    // 5. Optionally refine with Ollama
    var finalText = rawTranscript
    if ollamaEnabled && ollamaAvailable {
        state = .refining
        do {
            let refinedTask = Task {
                try await transcriptRefiner.refine(
                    rawTranscript: rawTranscript,
                    model: ollamaModel
                )
            }

            // Timeout: if refinement takes >5 seconds, keep raw
            let result = try await withThrowingTaskGroup(of: String?.self) { group in
                group.addTask { try await refinedTask.value }
                group.addTask {
                    try await Task.sleep(for: .seconds(5))
                    return nil // timeout sentinel
                }

                // First to complete wins
                if let first = try await group.next() {
                    group.cancelAll()
                    return first
                }
                return nil
            }

            if let refined = result {
                finalText = refined
                history.updateLatest(polishedText: refined)
                textInjector.copyToClipboard(refined) // Update clipboard with polished version
            }
        } catch {
            Log.ollama.warning("Refinement failed, using raw: \(error)")
            // Silently fall back to raw text
        }
    }

    // 6. Auto-paste if enabled
    if autoPasteEnabled {
        await textInjector.pasteIntoActiveApp(finalText)
    }

    // 7. Record latency
    let totalMs = Int((ContinuousClock.now - pipelineStart).components.seconds * 1000)
    lastLatencyMs = totalMs
    history.entries[0].latencyMs = totalMs

    Log.pipeline.info("Pipeline complete: \(String(format: "%.1f", audioDuration))s audio → \(totalMs)ms total")

    // 8. Done
    state = .idle
}
```

**Error handling:**

```swift
@MainActor
private func handlePipelineError(_ message: String) {
    consecutiveErrors += 1
    lastError = message
    state = .idle
    Log.pipeline.error("\(message)")

    // Don't spam errors — if 3+ consecutive failures, show persistent indicator
    if consecutiveErrors >= 3 {
        lastError = "Multiple failures. Check Console.app for details."
    }
}
```

### Step 4: Wire Everything Together in SquawkApp

```swift
import SwiftUI

@main
struct SquawkApp: App {
    @State private var dictationController = DictationController()
    @State private var hotkeyManager = HotkeyManager()

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

    init() {
        // Wire hotkey to dictation controller toggle
        let controller = DictationController()
        let hotkey = HotkeyManager()
        hotkey.onToggle = { [weak controller] in
            Task { @MainActor in
                controller?.toggle()
            }
        }
        _dictationController = State(initialValue: controller)
        _hotkeyManager = State(initialValue: hotkey)

        // Start services
        hotkey.start()
        controller.startOllamaPolling()

        // Load models in background
        Task {
            await controller.modelManager.loadModels()
            if controller.modelManager.isDownloaded {
                try? await controller.transcriptionEngine.initialize()
                await controller.transcriptionEngine.warmUp()
            }
        }
    }
}
```

### Step 5: Streaming Transcription (Enhancement — Optional for v1)

FluidAudio's Parakeet EOU 120M supports streaming with end-of-utterance detection:

- 160ms or 320ms chunk sizes
- Partial results emitted in real-time
- Requires a `LiveTranscriptionPanel` — floating `NSPanel` with `.nonactivatingPanel` style mask
- Shows partial transcript near the cursor as the user speaks

**This is a significant enhancement.** Implement as a separate mode toggled in settings. The batch pipeline (Steps 1-4) should be fully working first.

For the streaming panel:
```swift
// A floating, non-activating panel that shows live transcription
// Does not steal focus from the active app
class LiveTranscriptionPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
    }
}
```

### Step 6: Performance Monitoring

Log end-to-end performance for every transcription:

```swift
// In DictationController, after pipeline completes:
Log.pipeline.info("""
    Pipeline metrics:
      Audio: \(String(format: "%.1f", audioDuration))s
      ASR: \(asrTimeMs)ms
      Ollama: \(ollamaTimeMs)ms
      Total: \(totalMs)ms
    """)
```

Surface in the popover:
```swift
if let latency = dictationController.lastLatencyMs {
    Text("Last: \(latency)ms")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

## Key Dependencies

| Framework | Import | Usage |
|-----------|--------|-------|
| AppKit | `import AppKit` | `NSPasteboard`, `CGEvent`, `NSPanel` |
| Foundation | `import Foundation` | `FileManager`, `JSONEncoder/Decoder`, `URL` |
| Observation | `import Observation` | `@Observable` |
| os | `import os` | `Logger` |

## Gotchas & Edge Cases

1. **Clipboard restoration timing** — The 200ms delay before restoring the clipboard is a heuristic. Some apps (Electron-based editors, remote desktop) may need longer. Consider making this configurable (50ms-500ms range).

2. **CGEvent paste in sandboxed target apps** — Some apps (banking, password managers) may block synthetic paste events. There's no workaround — clipboard-only mode is the fallback.

3. **Empty utterance** — If the user toggles quickly (<0.5s recording), discard the audio. The 8000-sample threshold (0.5s at 16kHz) prevents transcribing silence/noise.

4. **Concurrent pipeline runs** — The state machine prevents this: only `idle` can transition to `recording`. If the user presses the hotkey while transcribing, it's ignored.

5. **File path for history** — `~/Library/Application Support/Squawk/history.json`. Create the directory on first write. Use `.atomic` write option to prevent corruption.

6. **Memory pressure** — 200 transcript entries in memory is negligible. The JSON file won't exceed a few hundred KB.

7. **Auto-paste steals keyboard focus momentarily** — The `CGEvent` paste happens in ~10ms but some apps may show a brief focus flash. This is unavoidable with the CGEvent approach.

8. **Refinement timeout race** — The `withThrowingTaskGroup` approach ensures we never wait more than 5 seconds for Ollama. If it completes in time, we use the refined text; otherwise, raw text is already in the clipboard.

## Acceptance Criteria

- [ ] Full flow: Cmd+Shift+Space → speak 3s → Cmd+Shift+Space → text appears in clipboard within 1s
- [ ] Paste into TextEdit confirms correct text
- [ ] Paste into VS Code confirms correct text
- [ ] Paste into a web browser text field confirms correct text
- [ ] Auto-paste: text appears at cursor position in active app
- [ ] Auto-paste: original clipboard contents restored after paste
- [ ] Multiple sequential dictations work without issues
- [ ] Transcript history accumulates in the popover (newest first)
- [ ] History persists across app restart
- [ ] Total latency <1.5s for a 5-second utterance (without Ollama)
- [ ] Total latency <3s for a 5-second utterance (with Ollama refinement)
- [ ] Empty/very short recordings are discarded silently
- [ ] Ollama timeout (>5s): raw text used, no hang
- [ ] Error recovery: ASR failure → error shown briefly → return to idle
- [ ] Console.app shows pipeline timing breakdown

## Estimated Complexity

**L** — This is the integration phase where all components come together. The `DictationController` orchestrator is the most complex piece, managing async operations, timeouts, error recovery, and state transitions. Clipboard save/restore has edge cases. Auto-paste requires careful timing.

## References

- **speak2** → `DictationController.swift`: The closest reference. Study its pipeline orchestration, especially how it coordinates audio capture → ASR → refinement → text injection.
- **speak2** → `TextInjector.swift`: Clipboard save/restore pattern and CGEvent paste simulation. Key detail: it saves ALL pasteboard item types (not just string) to properly restore rich content like images.
- **speak2** → `OllamaRefiner.swift`: Timeout handling and fallback behavior.
