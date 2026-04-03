# Architecture Decision Records

## ADR-01: Native Swift/SwiftUI over Tauri/Electron

**Status:** Accepted

**Context:** Squawk requires deep integration with macOS APIs: AVAudioEngine for audio capture, CoreML for ANE inference, CGEvent for synthetic keyboard input, and Accessibility APIs for push-to-talk. These are all native C/Objective-C/Swift APIs.

**Decision:** Build entirely in Swift with SwiftUI. No web runtime, no bridging layer.

**Rationale:**
- Zero IPC overhead between audio capture, ML inference, and text injection
- Direct access to AVAudioEngine tap callbacks on the real-time audio thread
- CoreML inference dispatches to ANE transparently — no FFI boundary
- CGEvent posting requires running in the same process space as the window server
- FluidAudio is a Swift Package — drops in with one SPM line
- Binary size <20MB, memory <50MB idle — an order of magnitude smaller than Electron/Tauri
- First-class macOS citizen: native dark mode, system font, accessibility support

**Tradeoffs:**
- No cross-platform potential (macOS only — acceptable for an ANE-dependent app)
- SwiftUI still has rough edges for complex macOS UIs
- Smaller ecosystem of third-party UI libraries compared to web

---

## ADR-02: FluidAudio over Raw CoreML / whisper.cpp / ONNX Runtime

**Status:** Accepted

**Context:** Multiple options exist for running speech recognition on macOS: raw CoreML APIs, whisper.cpp (C++), ONNX Runtime, or the FluidAudio SDK.

**Decision:** Use FluidAudio SDK for ASR.

**Rationale:**
- Production-ready Swift SDK — no C++ bridging, no manual CoreML pipeline setup
- Handles model download, caching, preprocessing, and postprocessing
- Includes Silero VAD via CoreML (built-in voice activity detection)
- Runs on Apple Neural Engine (ANE), not GPU — leaves GPU free for user workloads
- Apache 2.0 license, 1.4k+ stars, 44+ releases, actively maintained
- Used by shipping apps (FluidVoice, speak2)
- Supports both batch and streaming (Parakeet EOU) modes

**Tradeoffs:**
- Third-party dependency — if abandoned, we'd need to replace (mitigated by Apache 2.0 license)
- API surface may change between versions (mitigated by version pinning)
- Must use `xcodebuild` not `swift build` due to Metal shader compilation in dependency tree

---

## ADR-03: CoreML + ANE over MLX/GPU

**Status:** Accepted

**Context:** Apple Silicon Macs have three compute targets: CPU, GPU, and ANE. MLX (Apple's ML framework) targets GPU. CoreML can target ANE, GPU, or CPU.

**Decision:** Use CoreML with ANE targeting via FluidAudio.

**Rationale:**
- FluidInference (the FluidAudio team) explicitly archived their MLX Swift port because CoreML/ANE achieves better performance with less power
- ANE inference leaves both CPU and GPU completely free for the user's other work
- Battery impact is minimal — ANE is designed for sustained ML workloads
- ~120× real-time factor on M4 Pro, ~80-100× on M1

**Tradeoffs:**
- First CoreML compilation takes 30-60 seconds (cached afterward)
- ANE is a black box — no profiling tools, limited debugging
- CoreML model conversion from ONNX can lose precision (handled by FluidAudio's pre-converted models)

---

## ADR-04: Parakeet TDT v3 over Whisper

**Status:** Accepted

**Context:** OpenAI Whisper and NVIDIA Parakeet are the leading open-source ASR models.

**Decision:** Use NVIDIA Parakeet TDT via FluidAudio's CoreML conversion.

**Rationale:**
- #1 on the Open ASR Leaderboard (2.1% WER as of 2024)
- ~120× RTF on CoreML — significantly faster than Whisper on ANE
- 25 European language support (v3 model)
- CC-BY-4.0 license (Whisper is MIT — both permissive)
- FluidAudio provides pre-converted, optimized CoreML bundles

**Tradeoffs:**
- Model download (~300MB) required on first run
- English-only v2 model is better for English; v3 trades some English accuracy for multilingual support
- Smaller community than Whisper (but growing)

---

## ADR-05: AVAudioEngine over CoreAudio/AudioUnit

**Status:** Accepted

**Context:** macOS offers multiple audio capture APIs: CoreAudio (C), AudioUnit (C), and AVAudioEngine (Swift/ObjC).

**Decision:** Use AVAudioEngine.

**Rationale:**
- High-level Swift API with automatic format conversion (resampling from 48kHz → 16kHz)
- Tap-based capture is simple: `installTap(onBus:bufferSize:format:)`
- Handles device enumeration and routing changes
- Sufficient for microphone capture (we don't need AudioUnit's routing flexibility)
- No manual ring buffers or callback management

**Tradeoffs:**
- Less control over buffer sizes (tap `bufferSize` is a hint, not guaranteed)
- `AVAudioEngine` can crash if `inputNode` is accessed with no audio device
- Configuration change notifications require tap reinstallation

---

## ADR-06: Non-Sandboxed App

**Status:** Accepted

**Context:** macOS apps can run sandboxed (App Sandbox) or non-sandboxed with Hardened Runtime.

**Decision:** Non-sandboxed with Hardened Runtime enabled.

**Rationale:**
- `CGEvent.post(tap: .cghidEventTap)` — required for auto-paste (simulating Cmd+V) — is blocked by App Sandbox
- Accessibility API (`AXIsProcessTrusted`, `CGEvent.tapCreate` for push-to-talk) requires non-sandboxed execution
- Menu bar utilities commonly ship non-sandboxed (Rectangle, Raycast, Alfred, Bartender)
- Hardened Runtime is still enabled — required for notarization

**Tradeoffs:**
- Cannot distribute via Mac App Store (MAS requires sandbox)
- Must distribute via DMG + notarization (Developer ID)
- User must explicitly trust the app on first launch (Gatekeeper)

---

## ADR-07: NSEvent Global Monitor for Toggle Mode

**Status:** Accepted

**Context:** Two approaches for global hotkeys: `NSEvent.addGlobalMonitorForEvents` (observe-only) and `CGEvent.tapCreate` (intercept/modify).

**Decision:** Use `NSEvent.addGlobalMonitorForEvents` for toggle mode (default). Reserve `CGEvent.tapCreate` for push-to-talk mode.

**Rationale:**
- Global monitor does NOT require Accessibility permission — lower barrier to entry
- Sufficient for modifier+key combinations (Cmd+Shift+Space)
- Push-to-talk needs keyDown AND keyUp detection, which requires `CGEvent.tapCreate`
- Users who don't need push-to-talk never see an Accessibility permission prompt

**Tradeoffs:**
- Global monitor doesn't fire when the app's own window is focused (mitigated by also installing a local monitor)
- Cannot consume/block the key event (observe-only) — the shortcut also reaches the focused app
- Push-to-talk requires separate implementation path with Accessibility permission

---

## ADR-08: @AppStorage over Custom Config File

**Status:** Accepted

**Context:** Settings can be stored in UserDefaults (@AppStorage), a custom JSON/TOML file, or a database.

**Decision:** Use `@AppStorage` backed by UserDefaults.

**Rationale:**
- Built-in persistence with zero code — just declare `@AppStorage("key")`
- Automatic SwiftUI binding — settings views update reactively
- No serialization, migration, or file management code
- Standard macOS pattern — settings visible in `defaults read com.squawk.app`

**Tradeoffs:**
- Only supports basic types (String, Int, Bool, Double, Data, URL)
- Enums must be stored as strings
- No versioning or migration system (acceptable for simple settings)

---

## ADR-09: JSON File for History over SQLite/SwiftData

**Status:** Accepted

**Context:** Transcript history needs persistence across app launches. Options: JSON file, SQLite, SwiftData, Core Data.

**Decision:** JSON file in Application Support.

**Rationale:**
- <200 entries — no indexing, querying, or complex relations needed
- JSON is human-readable and debuggable
- No migration complexity — the schema is a flat array of structs
- Single-file persistence with atomic writes
- Zero dependencies beyond Foundation's JSONEncoder

**Tradeoffs:**
- Entire file read/written on each change (negligible for <200 entries)
- No concurrent access safety (single-process app, so not an issue)
- No full-text search (not needed — entries are short)

---

## ADR-10: URLSession over Alamofire/Third-Party HTTP

**Status:** Accepted

**Context:** The app makes HTTP calls to exactly one endpoint: Ollama at localhost:11434.

**Decision:** Use Foundation's URLSession directly.

**Rationale:**
- One endpoint, two API calls (health check + generate) — no complexity justifying a library
- URLSession is built-in, zero additional dependencies
- Codable request/response types are trivial
- Maintains the "zero third-party deps beyond FluidAudio" constraint

**Tradeoffs:**
- Slightly more boilerplate than Alamofire for request building
- No automatic retry/backoff (not needed for localhost)

---

## ADR-11: SMAppService over LaunchAgent Plist

**Status:** Accepted

**Context:** "Launch at login" can be implemented via `SMAppService` (macOS 13+) or by writing a LaunchAgent plist to `~/Library/LaunchAgents/`.

**Decision:** Use `SMAppService.mainApp.register()`.

**Rationale:**
- Modern Apple API, replaces deprecated approaches
- Single method call to register/unregister
- No plist file management
- Works with macOS 13+ (our target is 14+)

**Tradeoffs:**
- Requires proper code signing (won't work with ad-hoc/unsigned builds)
- Less visibility than a plist file (can't easily inspect registration state)

---

## ADR-12: os.Logger over Print/Third-Party Logging

**Status:** Accepted

**Context:** Logging options include `print()`, `NSLog`, `os.Logger`, or third-party frameworks (CocoaLumberjack, SwiftyBeaver).

**Decision:** Use `os.Logger` (Unified Logging System).

**Rationale:**
- Native macOS integration — logs visible in Console.app with filtering
- Category-based: `audio`, `asr`, `ollama`, `pipeline`
- Performance-optimized: string interpolation is lazy, disabled logs have near-zero cost
- Privacy annotations for sensitive data
- Zero dependencies

**Tradeoffs:**
- Logs not easily accessible to users (must use Console.app)
- No built-in log file export (mitigated by "Copy Debug Info" feature)

---

## ADR-13: Batch ASR First, Streaming as Enhancement

**Status:** Accepted

**Context:** FluidAudio supports both batch transcription (Parakeet TDT) and streaming (Parakeet EOU 120M with end-of-utterance detection).

**Decision:** Implement batch ASR first. Streaming is an optional enhancement.

**Rationale:**
- Batch is simpler: record → stop → transcribe → done
- FluidAudio's batch API is more mature and better documented
- Streaming adds significant UI complexity (floating overlay panel, partial result display)
- Batch latency is already excellent (~100ms for 5s audio) — streaming's main benefit is UX, not speed
- Can be added as a separate mode without changing the core pipeline

**Tradeoffs:**
- No live preview of transcription while speaking
- User must wait until recording stops to see any text
- Streaming would feel more "magical" — plan to add in a future phase
