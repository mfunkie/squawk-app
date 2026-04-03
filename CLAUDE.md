# Squawk — Native macOS Speech-to-Text Menu Bar App

## What is this project?

Squawk is a native macOS menu bar app for hotkey-activated speech-to-text transcription. Built entirely in Swift/SwiftUI, it runs 100% locally on Apple Silicon using the Apple Neural Engine for ASR inference. Optional local LLM polish via Ollama.

## Architecture

See `docs/ARCHITECTURE.md` for the full system diagram, data flow, and threading model.

**Core pipeline:** Hotkey → AVAudioEngine capture → FluidAudio Parakeet CoreML (ANE) → optional Ollama polish → NSPasteboard + CGEvent paste

**Key decisions** are documented in `docs/DECISIONS.md` (13 ADRs).

## Build Progress

Track what's done and what's next in `docs/PROGRESS.md`. Use `/do-phase` to implement the next uncompleted phase.

## Build Commands

```bash
# ALWAYS use xcodebuild — NOT swift build
# swift build compiles but crashes at runtime (Metal shader compilation)
# The Xcode project lives in the Squawk/ subdirectory
xcodebuild -project Squawk/Squawk.xcodeproj -scheme Squawk -destination 'platform=macOS' build

# Run tests
xcodebuild -project Squawk/Squawk.xcodeproj -scheme Squawk -destination 'platform=macOS' test
```

## Testing

- **Write tests often** — every phase should include unit tests for new logic
- **Red/green TDD for application logic** — write a failing test first, then write the minimum code to make it pass
- Tests live in `Squawk/SquawkTests/`
- Use `XCTest` framework (built-in, no third-party test deps)
- Test business logic, state machines, data transforms — not SwiftUI views directly
- Run tests via `xcodebuild test` (see Build Commands above)

## Key Constraints

- **macOS 14.0+ (Sonoma), Apple Silicon only**
- **100% local** — no network calls except localhost Ollama
- **Zero third-party deps beyond FluidAudio** — everything else uses Apple frameworks
- **Non-sandboxed** with Hardened Runtime (for CGEvent + Accessibility API)
- **`@Observable` (not `ObservableObject`)** — macOS 14+ modern Swift patterns
- **`function` statements** — never use `const f = () => {}` at module scope

## Phase Docs

Implementation is broken into 8 phases, each self-contained in `docs/phases/PHASE-XX.md`:

| Phase | Description |
|-------|-------------|
| 00 | Xcode Project Scaffolding |
| 01 | Audio Capture & Permissions |
| 02 | FluidAudio ASR Integration |
| 03 | Ollama Integration |
| 04 | Global Hotkey & State Machine |
| 05 | Core Pipeline Integration |
| 06 | SwiftUI Interface & Settings |
| 07 | Packaging & Distribution |

## SwiftUI

When writing or reviewing SwiftUI code, use the `/swiftui-pro` skill for best practices on macOS 14+ APIs, `@Observable` usage, and performance.

## Model Downloads

FluidAudio downloads Parakeet CoreML models from **FluidInference's public HuggingFace org** (https://huggingface.co/FluidInference) — NOT from NVIDIA's gated repos. No authentication required. Custom registry URL supported via `REGISTRY_URL` env var.

## Ollama Models

The Ollama model dropdown in settings is dynamically populated from installed models via `GET /api/tags`. Any model the user has pulled (mistral, gemma, phi3, llama3.2, etc.) is selectable — not hardcoded to a specific model.
