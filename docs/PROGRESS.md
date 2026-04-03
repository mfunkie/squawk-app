# Squawk — Build Progress

> Track completion of each phase. Mark items `[x]` as they are completed.

## Phase Status

| Phase | Description | Status |
|-------|-------------|--------|
| PHASE-00 | Xcode Project Scaffolding | Done |
| PHASE-01 | Audio Capture & Permissions | Done |
| PHASE-02 | FluidAudio ASR Integration | Done |
| PHASE-03 | Ollama Integration | Done |
| PHASE-04 | Global Hotkey & State Machine | Not Started |
| PHASE-05 | Core Pipeline Integration | Not Started |
| PHASE-06 | SwiftUI Interface & Settings | Not Started |
| PHASE-07 | Packaging & Distribution | Not Started |

---

## PHASE-00: Xcode Project Scaffolding

- [x] Xcode project created with correct bundle ID and deployment target
- [x] `LSUIElement = YES` in Info.plist (no dock icon)
- [x] `MenuBarExtra` with `.window` style renders in system tray
- [x] FluidAudio SPM dependency added and compiling
- [x] All skeleton source files created and compiling
- [x] Entitlements configured (audio input, hardened runtime, no sandbox)
- [x] `xcodebuild` build succeeds

## PHASE-01: Audio Capture & Permissions

- [x] `AudioCaptureManager` captures 16kHz mono Float32 PCM
- [x] Audio level (RMS) updates during recording
- [x] `AudioPermissions` checks and requests microphone access
- [x] Permission denied state shows System Settings link
- [x] No crash with no input device
- [x] Audio engine handles configuration changes (BT headphones)
- [x] Test record/stop button works in popover

## PHASE-02: FluidAudio ASR Integration

- [x] `ModelManager` downloads and loads Parakeet CoreML model
- [x] Download progress shown in UI on first run
- [x] Download failure surfaced with retry button
- [x] `TranscriptionEngine` transcribes audio samples to text
- [x] Transcription <500ms for 5-second clip on Apple Silicon
- [x] Model warm-up runs on launch
- [x] First-ever CoreML compilation communicated to user

## PHASE-03: Ollama Integration

- [x] `OllamaClient` health check, model listing, and generate work
- [x] `TranscriptRefiner` cleans up raw transcripts
- [x] Hallucination guard rejects bad responses (too long, markdown, preamble)
- [x] Graceful degradation: skip refinement silently when Ollama unavailable
- [x] Background polling detects Ollama availability changes
- [x] Ollama model dropdown populated from installed models
- [x] Model-not-found error shows `ollama pull` instructions

## PHASE-04: Global Hotkey & State Machine

- [ ] Cmd+Shift+Space toggles recording from any app
- [ ] Both global and local event monitors installed
- [ ] 300ms debounce prevents double-trigger
- [ ] Menu bar icon changes per state (idle/recording/transcribing/refining)
- [ ] Recording timeout at configurable max duration
- [ ] Sleep/wake re-registers hotkey
- [ ] Push-to-talk mode (optional, Accessibility-gated)

## PHASE-05: Core Pipeline Integration

- [ ] Full pipeline: hotkey → record → ASR → (optional Ollama) → clipboard
- [ ] `TextInjector` copies text to clipboard
- [ ] Auto-paste simulates Cmd+V into active app
- [ ] Clipboard contents saved and restored after paste
- [ ] Transcript history persists to JSON
- [ ] Empty/short recordings discarded
- [ ] Ollama refinement timeout (5s) falls back to raw text
- [ ] Error recovery returns to idle state
- [ ] End-to-end latency <1.5s (no Ollama) for 5s audio

## PHASE-06: SwiftUI Interface & Settings

- [ ] MenuBarView with tabs (Transcripts / Settings / About)
- [ ] StatusBar shows state with audio level bars during recording
- [ ] TranscriptListView with click-to-copy and "Copied!" feedback
- [ ] Empty state with instructions
- [ ] Settings: hotkey change with capture UI
- [ ] Settings: recording mode (toggle / push-to-talk)
- [ ] Settings: ASR model version picker
- [ ] Settings: Ollama enable/disable, dynamic model dropdown, custom prompt
- [ ] Settings: auto-paste toggle, clipboard restore toggle
- [ ] Settings: launch at login via SMAppService
- [ ] About view with version, credits, "Copy Debug Info"
- [ ] Dark mode renders correctly

## PHASE-07: Packaging & Distribution

- [ ] First-run wizard: welcome → model download → mic permission → ready
- [ ] `hasCompletedSetup` prevents re-showing wizard
- [ ] Edge cases: sleep/wake, device changes, rapid input, empty utterance
- [ ] Single-instance enforcement
- [ ] Low disk space warning before model download
- [ ] App icon in all required sizes
- [ ] `xcodebuild archive` succeeds
- [ ] Exported .app runs on clean Mac
- [ ] Notarization passes
- [ ] DMG with drag-to-Applications
- [ ] .app bundle <20MB
- [ ] Idle memory <50MB
- [ ] README.md complete
- [ ] Launch at login works after reboot
