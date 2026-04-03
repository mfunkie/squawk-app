# Squawk Architecture

## System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  SquawkApp (@main, MenuBarExtra .window style)                  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  MenuBarView (SwiftUI)                                    │   │
│  │  ├── StatusBar (state + audio level)                      │   │
│  │  ├── TranscriptListView / SettingsView / AboutView (tabs) │   │
│  │  └── Tab picker + Quit                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                         │                                       │
│                         │ @Environment                          │
│                         ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  DictationController (@Observable)  ◄──── HotkeyManager  │   │
│  │  State: idle → recording → transcribing → refining → idle │   │
│  │                                                           │   │
│  │  ┌────────────────┐  ┌──────────────────┐                │   │
│  │  │AudioCapture    │  │TranscriptionEngine│                │   │
│  │  │Manager         │  │                  │                │   │
│  │  │ AVAudioEngine  │  │ FluidAudio SDK   │                │   │
│  │  │ 16kHz mono f32 │  │ AsrModels        │                │   │
│  │  │ os_unfair_lock │  │ AsrManager       │                │   │
│  │  └────────────────┘  │ CoreML → ANE     │                │   │
│  │                      └──────────────────┘                │   │
│  │  ┌────────────────┐  ┌──────────────────┐                │   │
│  │  │TranscriptRefiner│  │TextInjector      │                │   │
│  │  │ OllamaClient   │  │ NSPasteboard     │                │   │
│  │  │ URLSession      │  │ CGEvent (Cmd+V)  │                │   │
│  │  │ localhost:11434 │  │ Clipboard restore│                │   │
│  │  └────────────────┘  └──────────────────┘                │   │
│  │                                                           │   │
│  │  ┌────────────────┐                                       │   │
│  │  │TranscriptHistory│                                      │   │
│  │  │ [TranscriptEntry]│                                     │   │
│  │  │ JSON persistence │                                     │   │
│  │  └────────────────┘                                       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Recording Pipeline (step by step)

```
1. User presses ⌘⇧Space
   Thread: Main (NSEvent global monitor callback)

2. HotkeyManager.onToggle() → DictationController.toggle()
   Thread: Main (@MainActor)

3. State: idle → recording
   AudioCaptureManager.startCapture()
   Thread: Main (engine.start())

4. AVAudioEngine tap delivers PCM buffers
   Thread: Real-time audio thread (DO NOT block)
   Action: append samples to buffer (os_unfair_lock), compute RMS

5. User presses ⌘⇧Space again
   Thread: Main

6. State: recording → transcribing
   AudioCaptureManager.stopCapture() → returns [Float]
   Thread: Main

7. TranscriptionEngine.transcribe(audioSamples:)
   Thread: Swift concurrency (Task) → CoreML dispatches to ANE
   Duration: ~100ms for 5s audio on M-series

8. State: transcribing → refining (if Ollama enabled + available)
   TranscriptRefiner.refine(rawTranscript:)
   Thread: Swift concurrency (Task) → URLSession to localhost:11434
   Duration: ~200-800ms depending on model
   Timeout: 5s, fallback to raw text

9. TextInjector.copyToClipboard() / .pasteIntoActiveApp()
   Thread: Main (NSPasteboard, CGEvent)

10. State: refining/transcribing → idle
    TranscriptHistory.add(entry)
    Thread: Main
```

### Thread Annotations

| Thread | Components | Constraints |
|--------|-----------|-------------|
| **Main / MainActor** | SwiftUI views, DictationController state, NSPasteboard, CGEvent, HotkeyManager | All UI state mutations |
| **Real-time audio** | AVAudioEngine tap callback | No allocations, no locks >microseconds, no ObjC runtime |
| **Swift concurrency** | TranscriptionEngine, OllamaClient, TranscriptHistory I/O | async/await, structured concurrency |
| **ANE** | CoreML inference (managed by FluidAudio) | Transparent — CoreML dispatches automatically |

## State Management

### DictationController (@Observable)

The single source of truth for the entire app. Injected into the SwiftUI view hierarchy via `.environment()`.

```swift
@Observable
final class DictationController {
    var state: DictationState = .idle          // Drives menu bar icon + status bar
    var ollamaAvailable: Bool = false          // Background polling
    var lastLatencyMs: Int?                    // Performance display
    var lastError: String?                     // Error display

    let audioCaptureManager: AudioCaptureManager
    let modelManager: ModelManager
    let transcriptionEngine: TranscriptionEngine
    let history: TranscriptHistory
    // ...
}
```

### Settings (@AppStorage / UserDefaults)

All user preferences stored via `@AppStorage` — no custom persistence layer:

| Key | Type | Default |
|-----|------|---------|
| `hotkey.keyCode` | Int | 49 (Space) |
| `hotkey.modifiers` | Int | Cmd+Shift |
| `recording.mode` | String | "toggle" |
| `recording.maxDuration` | Int | 300 |
| `asr.modelVersion` | String | "v2" |
| `ollama.enabled` | Bool | true |
| `ollama.model` | String | "mistral" |
| `ollama.customPrompt` | String | "" |
| `ollama.temperature` | Double | 0.3 |
| `output.autoPaste` | Bool | false |
| `output.restoreClipboard` | Bool | true |
| `output.completionSound` | Bool | true |
| `general.launchAtLogin` | Bool | false |
| `hasCompletedSetup` | Bool | false |

### Transcript History (JSON file)

```swift
struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    var rawText: String
    var polishedText: String?
    let timestamp: Date
    var audioDuration: TimeInterval
    var latencyMs: Int?
}
```

Capped at 200 entries, persisted to JSON.

## File System Layout

```
~/Library/Application Support/
├── Squawk/
│   └── history.json                    # Transcript history (managed by Squawk)
└── FluidAudio/
    └── Models/                         # CoreML model cache (managed by FluidAudio SDK)
        ├── parakeet-tdt-v2-*.mlmodelc
        └── parakeet-tdt-v3-*.mlmodelc

~/Library/Caches/
└── com.squawk.app/                     # CoreML compilation cache (managed by macOS)
```

## Component Ownership

```
SquawkApp
├── owns → DictationController (via @State)
├── owns → HotkeyManager (via @State)
│
DictationController
├── owns → AudioCaptureManager
├── owns → ModelManager
├── owns → TranscriptionEngine (depends on ModelManager)
├── owns → TranscriptRefiner (contains OllamaClient)
├── owns → TextInjector
└── owns → TranscriptHistory
```

## Dependency Graph

```
SwiftUI views
    └── depends on → DictationController (@Environment)
        ├── AudioCaptureManager
        │   └── AVFoundation, Accelerate
        ├── TranscriptionEngine
        │   ├── ModelManager
        │   │   └── FluidAudio (AsrModels)
        │   └── FluidAudio (AsrManager)
        ├── TranscriptRefiner
        │   └── OllamaClient
        │       └── Foundation (URLSession)
        ├── TextInjector
        │   └── AppKit (NSPasteboard, CGEvent)
        └── TranscriptHistory
            └── Foundation (FileManager, JSONEncoder)

HotkeyManager
    └── Cocoa (NSEvent), Carbon.HIToolbox, ApplicationServices (CGEvent tap)
```

## Security Model

- **Non-sandboxed** — required for CGEvent posting and Accessibility API
- **Hardened Runtime** — enabled for notarization
- **No network access** except `localhost:11434` (Ollama)
- **No cloud telemetry, analytics, or crash reporting**
- **Audio data never leaves the machine** — processed entirely on-device
- **Transcript history stored locally** in Application Support, unencrypted (user's responsibility)
