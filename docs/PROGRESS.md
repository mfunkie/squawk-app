# Squawk — Build Progress

> Track completion of each phase. Mark items `[x]` as they are completed.

## Phase Status

| Phase | Description | Status |
|-------|-------------|--------|
| PHASE-00 | Xcode Project Scaffolding | Done |
| PHASE-01 | Audio Capture & Permissions | Done |
| PHASE-02 | FluidAudio ASR Integration | Done |
| PHASE-03 | Ollama Integration | Done |
| PHASE-04 | Global Hotkey & State Machine | Done |
| PHASE-05 | Core Pipeline Integration | Done |
| PHASE-06 | SwiftUI Interface & Settings | Done |
| PHASE-07 | Packaging & Distribution | Done |

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

- [x] Cmd+Shift+Space toggles recording from any app
- [x] Both global and local event monitors installed
- [x] 300ms debounce prevents double-trigger
- [x] Menu bar icon changes per state (idle/recording/transcribing/refining)
- [x] Recording timeout at configurable max duration
- [x] Sleep/wake re-registers hotkey
- [x] Push-to-talk mode (optional, Accessibility-gated)

## PHASE-05: Core Pipeline Integration

- [x] Full pipeline: hotkey → record → ASR → (optional Ollama) → clipboard
- [x] `TextInjector` copies text to clipboard
- [x] Auto-paste simulates Cmd+V into active app
- [x] Clipboard contents saved and restored after paste
- [x] Transcript history persists to JSON
- [x] Empty/short recordings discarded
- [x] Ollama refinement timeout (5s) falls back to raw text
- [x] Error recovery returns to idle state
- [x] End-to-end latency <1.5s (no Ollama) for 5s audio

## PHASE-06: SwiftUI Interface & Settings

- [x] MenuBarView with tabs (Transcripts / Settings / About)
- [x] StatusBar shows state with audio level bars during recording
- [x] TranscriptListView with click-to-copy and "Copied!" feedback
- [x] Empty state with instructions
- [x] Settings: hotkey change with capture UI
- [x] Settings: recording mode (toggle / push-to-talk)
- [x] Settings: ASR model version picker
- [x] Settings: Ollama enable/disable, dynamic model dropdown, custom prompt
- [x] Settings: auto-paste toggle, clipboard restore toggle
- [x] Settings: launch at login via SMAppService
- [x] About view with version, credits, "Copy Debug Info"
- [x] Dark mode renders correctly

## PHASE-07: Packaging & Distribution

- [x] First-run wizard: welcome → model download → mic permission → ready
- [x] `hasCompletedSetup` prevents re-showing wizard
- [x] Edge cases: sleep/wake, device changes, rapid input, empty utterance
- [x] Single-instance enforcement
- [x] Low disk space warning before model download
- [ ] App icon in all required sizes
- [ ] `xcodebuild archive` succeeds
- [ ] Exported .app runs on clean Mac
- [ ] Notarization passes
- [x] DMG with drag-to-Applications
- [ ] .app bundle <20MB
- [ ] Idle memory <50MB
- [x] README.md complete
- [ ] Launch at login works after reboot
