# PHASE-02: FluidAudio ASR Integration

## Goal

Wire FluidAudio's Parakeet CoreML model into the app, transcribe captured audio buffers, handle model download on first run, and verify transcription quality on Apple Silicon.

## Prerequisites

- PHASE-00 complete: FluidAudio SPM dependency linked and compiling
- PHASE-01 complete: `AudioCaptureManager` returns `[Float]` samples at 16kHz mono
- Internet access for first-run model download

## Directory & File Structure

Files to implement (replacing stubs from PHASE-00):

```
Squawk/
├── ASR/
│   ├── TranscriptionEngine.swift    # Full implementation
│   └── ModelManager.swift           # Full implementation
└── Views/
    └── MenuBarView.swift            # Add transcription output display
```

## Detailed Steps

### Step 1: Implement ModelManager

`ASR/ModelManager.swift` — wraps FluidAudio's model download and loading:

```swift
import FluidAudio
import Observation
import os

@Observable
final class ModelManager {
    // MARK: - Public state
    var isDownloaded = false
    var isLoading = false
    var downloadProgress: Double = 0.0
    var errorMessage: String?

    // MARK: - Internal
    private(set) var models: AsrModels?
}
```

**Model download and loading:**

FluidAudio's `AsrModels.downloadAndLoad()` handles everything — download from the hosting server, local caching, and CoreML model loading. Models are cached at `~/Library/Application Support/FluidAudio/Models/`.

```swift
func loadModels(version: AsrModelVersion = .v2) async {
    guard models == nil else { return }
    isLoading = true
    errorMessage = nil

    do {
        let loadedModels = try await AsrModels.downloadAndLoad(version: version)
        models = loadedModels
        isDownloaded = true
        Log.asr.info("ASR models loaded successfully (version: \(String(describing: version)))")
    } catch {
        errorMessage = "Model download failed: \(error.localizedDescription)"
        Log.asr.error("Failed to load ASR models: \(error)")
    }

    isLoading = false
}
```

**Model versions:**
- `.v2` — English-only, tighter vocabulary, better for English-only users
- `.v3` — 25 European languages, slightly lower English accuracy on rare words
- Default recommendation: `.v2` for English-only, `.v3` for multilingual

**Model sizes:** ~200-400MB for CoreML bundles.

**Model hosting — IMPORTANT:**

FluidAudio downloads models from **FluidInference's public HuggingFace organization** (`https://huggingface.co/FluidInference`), NOT from NVIDIA's gated repos. No authentication token is required. Available models:

- [`FluidInference/parakeet-tdt-0.6b-v2-coreml`](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml) — English-only
- [`FluidInference/parakeet-tdt-0.6b-v3-coreml`](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) — 25 languages
- [`FluidInference/parakeet-realtime-eou-120m-coreml`](https://huggingface.co/FluidInference/parakeet-realtime-eou-120m-coreml) — Streaming
- [`FluidInference/parakeet-ctc-110m-coreml`](https://huggingface.co/FluidInference/parakeet-ctc-110m-coreml) — Lightweight

**Custom registry support:** For air-gapped or corporate environments, FluidAudio supports:
- `REGISTRY_URL` environment variable — point to a custom mirror
- `https_proxy` — route through corporate proxy

If FluidAudio's hosting is unreachable, the download will fail — surface this to the user with a retry button.

### Step 2: Implement TranscriptionEngine

`ASR/TranscriptionEngine.swift` — wraps the FluidAudio batch transcription API:

```swift
import FluidAudio
import Observation
import os

@Observable
final class TranscriptionEngine {
    // MARK: - Public state
    var isReady = false
    var isTranscribing = false

    // MARK: - Private
    private var asrManager: AsrManager?
    private let modelManager: ModelManager

    init(modelManager: ModelManager) {
        self.modelManager = modelManager
    }
}
```

**Initialization — create AsrManager after models load:**

```swift
func initialize() async throws {
    guard asrManager == nil else { return }

    if modelManager.models == nil {
        await modelManager.loadModels()
    }

    guard let models = modelManager.models else {
        throw TranscriptionError.modelsNotLoaded
    }

    asrManager = AsrManager(config: .init(), models: models)
    isReady = true
    Log.asr.info("TranscriptionEngine initialized")
}
```

**Core transcription method:**

```swift
func transcribe(audioSamples: [Float]) async throws -> String {
    guard let asrManager else {
        throw TranscriptionError.notInitialized
    }

    isTranscribing = true
    defer { isTranscribing = false }

    let startTime = ContinuousClock.now

    // FluidAudio's AsrManager accepts raw Float32 samples at 16kHz
    // Check the actual API — it may require:
    //   asrManager.transcribe(samples:) or
    //   asrManager.transcribe(audioFile:) with a temp WAV file
    let result = try await asrManager.transcribe(samples: audioSamples)

    let elapsed = ContinuousClock.now - startTime
    let audioDuration = Double(audioSamples.count) / 16000.0
    let rtf = elapsed.components.seconds > 0
        ? audioDuration / Double(elapsed.components.seconds)
        : 0

    Log.asr.info("""
        Transcription complete: \
        audio=\(String(format: "%.1f", audioDuration))s, \
        inference=\(elapsed), \
        RTF=\(String(format: "%.0f", rtf))x
        """)

    return result
}

enum TranscriptionError: LocalizedError {
    case modelsNotLoaded
    case notInitialized
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .modelsNotLoaded: return "ASR models are not loaded"
        case .notInitialized: return "Transcription engine not initialized"
        case .emptyAudio: return "No audio to transcribe"
        }
    }
}
```

**FluidAudio API notes:**

The exact `AsrManager` API surface should be verified against FluidAudio's documentation and source. Key types to look for:
- `AsrModels` — model container, created via `downloadAndLoad(version:)`
- `AsrManager` — inference engine, initialized with config + models
- `AsrConfig` — configuration (default `.init()` is fine)
- `AsrModelVersion` — `.v2` (English) or `.v3` (multilingual)
- The transcription method likely accepts `[Float]` samples directly or via an `AVAudioPCMBuffer`

If `AsrManager` requires a file path instead of raw samples, write a temporary WAV file:

```swift
private func writeTempWAV(samples: [Float]) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let wavURL = tempDir.appendingPathComponent("squawk_temp.wav")

    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { ptr in
        buffer.floatChannelData![0].update(from: ptr.baseAddress!, count: samples.count)
    }

    let audioFile = try AVAudioFile(forWriting: wavURL, settings: format.settings)
    try audioFile.write(from: buffer)
    return wavURL
}
```

### Step 3: Model Warm-Up

First CoreML inference triggers model compilation, which takes 30-60 seconds. This is cached by the system afterward. Warm up on launch:

```swift
func warmUp() async {
    guard isReady else { return }
    Log.asr.info("Warming up ASR model (first run may take 30-60s)...")

    // Transcribe 1 second of silence to trigger CoreML compilation
    let silentSamples = [Float](repeating: 0.0, count: 16000)
    _ = try? await transcribe(audioSamples: silentSamples)

    Log.asr.info("ASR model warm-up complete")
}
```

**On very first launch ever:**
- CoreML compilation runs (~30-60 seconds)
- Show status in the popover: "Optimizing model for your Mac... (this only happens once)"
- Subsequent launches use the cached compilation — warm-up takes <1 second

### Step 4: First-Run Download UX

Update `MenuBarView` to show download progress when models are not yet cached:

```swift
@ViewBuilder
private var modelStatusView: some View {
    if modelManager.isLoading {
        VStack(spacing: 8) {
            ProgressView(value: modelManager.downloadProgress)
            Text("Downloading speech model...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("~300MB — this only happens once")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    } else if let error = modelManager.errorMessage {
        VStack(spacing: 8) {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            Button("Retry Download") {
                Task { await modelManager.loadModels() }
            }
        }
    }
}
```

Block recording until models are ready — the "Record" button should be disabled when `!transcriptionEngine.isReady`.

### Step 5: Wire Into MenuBarView for Testing

Update the test UI from PHASE-01 to include transcription:

```swift
@State private var transcriptionEngine: TranscriptionEngine
@State private var lastTranscript = ""

// After stopping recording:
private func stopAndTranscribe() {
    let samples = audioCaptureManager.stopCapture()
    guard !samples.isEmpty else { return }

    Task {
        do {
            let text = try await transcriptionEngine.transcribe(audioSamples: samples)
            lastTranscript = text
        } catch {
            Log.asr.error("Transcription failed: \(error)")
            lastTranscript = "Error: \(error.localizedDescription)"
        }
    }
}
```

Display the transcript in the popover:
```swift
if !lastTranscript.isEmpty {
    Text(lastTranscript)
        .font(.body)
        .textSelection(.enabled)
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

### Step 6: Launch-Time Initialization

In `SquawkApp.swift`, trigger model loading on launch:

```swift
@main
struct SquawkApp: App {
    @State private var modelManager = ModelManager()
    @State private var transcriptionEngine: TranscriptionEngine

    init() {
        let mm = ModelManager()
        _modelManager = State(initialValue: mm)
        _transcriptionEngine = State(initialValue: TranscriptionEngine(modelManager: mm))
    }

    var body: some Scene {
        MenuBarExtra("Squawk", systemImage: "mic") {
            MenuBarView()
                .environment(modelManager)
                .environment(transcriptionEngine)
        }
        .menuBarExtraStyle(.window)
    }
}
```

Trigger model load + warm-up in a background task:
```swift
.task {
    await modelManager.loadModels()
    if modelManager.isDownloaded {
        try? await transcriptionEngine.initialize()
        await transcriptionEngine.warmUp()
    }
}
```

## Key Dependencies

| Dependency | Import | Usage |
|-----------|--------|-------|
| FluidAudio | `import FluidAudio` | `AsrModels`, `AsrManager`, `AsrModelVersion`, `AsrConfig` |
| AVFoundation | `import AVFoundation` | `AVAudioFile`, `AVAudioPCMBuffer` (for temp WAV if needed) |
| Observation | `import Observation` | `@Observable` macro |
| os | `import os` | `Logger` |

## Gotchas & Edge Cases

1. **`xcodebuild` only** — FluidAudio depends on Metal shaders that are compiled by Xcode's build system. `swift build` will produce a binary that compiles but crashes at runtime when ASR is invoked. Always build with `xcodebuild`.

2. **First CoreML compilation is slow** — On the very first launch after install (or after macOS update clears the cache), CoreML compiles the model for the specific hardware. This takes 30-60 seconds and cannot be skipped. Subsequent launches are fast because the compiled model is cached at `~/Library/Caches/`.

3. **Model download may fail** — Network issues, FluidAudio hosting downtime, or corporate firewalls can block the download. Always surface failures to the user with a retry option.

4. **Model hosting** — FluidAudio downloads from FluidInference's public HuggingFace org (not NVIDIA's gated repos). No authentication tokens needed. Custom registry URL supported via `REGISTRY_URL` env var for corporate/air-gapped environments.

5. **Memory usage** — A loaded Parakeet model consumes ~200-400MB of RAM. This is expected and unavoidable for on-device ASR. The model remains loaded for the app's lifetime to avoid repeated load times.

6. **Very long audio** — FluidAudio's `AsrManager` likely handles chunking internally for long recordings. If you encounter issues with >5 minute recordings, manually chunk into 30-second segments with 1-second overlap.

7. **Empty audio** — Transcribing silence or very short audio (<0.5 seconds) may produce empty strings or garbage. Guard against this at the `DictationController` level (PHASE-05).

8. **`AsrManager` thread safety** — Check whether `AsrManager.transcribe()` is safe to call from multiple concurrent tasks. If not, serialize access with an actor or async queue.

## Acceptance Criteria

- [ ] On first launch, model downloads successfully (visible progress or completion)
- [ ] Recording 5 seconds of clear English speech produces an accurate transcription
- [ ] Transcription text appears in the popover UI
- [ ] Transcription completes in <500ms for a 5-second clip on Apple Silicon
- [ ] Warm-up runs on startup without user-visible delay (after first-ever CoreML compilation)
- [ ] Model download failure is surfaced in the UI with a retry button
- [ ] `xcodebuild` build succeeds
- [ ] Console.app shows transcription timing (audio duration, inference time, RTF)
- [ ] Recording button is disabled while models are loading

## Estimated Complexity

**L** — FluidAudio integration is the critical path. The API surface must be verified against actual documentation, model download involves network and caching, and CoreML warm-up adds first-run complexity. The transcription itself should be straightforward once the API is understood.

## References

- **FluidAudio** (`github.com/FluidInference/FluidAudio`): Primary reference for `AsrModels`, `AsrManager`, and the download/load API. Study the CLI examples and any sample code.
- **speak2** → `ParakeetTranscriber.swift`: Shows how to initialize and call FluidAudio's transcription API in a real app.
- **FluidVoice**: Another app using the same SDK — study its model initialization and error handling.
- **swift-scribe** → `Transcription/` directory: Official FluidAudio example architecture.
