# Squawk

Local speech-to-text for macOS. Fast, private, powered by Apple Neural Engine.

Squawk is a native menu bar app that transcribes your speech to text using on-device AI. No data leaves your Mac — ever.

## Features

- **Hotkey-activated** — Press `⌘⇧Space` anywhere to start/stop recording
- **100% local** — Runs entirely on your Mac using Apple Neural Engine
- **Fast** — Under 1.5 seconds from speech to text for a 5-second clip
- **Optional AI polish** — Clean up transcripts with a local Ollama LLM
- **Auto-paste** — Optionally paste transcribed text directly into the active app
- **Transcript history** — Browse and copy previous transcriptions

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon** (M1, M2, M3, M4)
- ~300MB disk space for the speech model (downloaded on first run)

### Optional

- [Ollama](https://ollama.ai) — for AI-powered transcript cleanup. Install Ollama and pull a model:
  ```bash
  ollama pull mistral
  ```

## Installation

1. Download `Squawk.dmg` from the Releases page
2. Open the DMG and drag Squawk to your Applications folder
3. Launch Squawk — it appears as a microphone icon in the menu bar
4. Complete the first-run setup (model download + microphone permission)

## Quick Start

1. Launch Squawk (it lives in your menu bar)
2. Grant microphone permission when prompted
3. Press **⌘⇧Space** anywhere to start recording
4. Press **⌘⇧Space** again to stop — your speech is transcribed and copied to the clipboard
5. Paste with **⌘V**

## Settings

Click the Squawk menu bar icon and go to the **Settings** tab:

| Setting | Description |
|---------|-------------|
| Hotkey | Change the global keyboard shortcut |
| Recording mode | Toggle (press to start/stop) or Push-to-talk (hold to record) |
| Ollama | Enable/disable AI polish, choose model, custom prompt |
| Auto-paste | Automatically paste transcribed text into the active app |
| Launch at login | Start Squawk when you log in |

## Troubleshooting

**"Speech model not loaded yet"**
Wait for the model to finish downloading on first launch. Check the menu bar popover for download progress.

**Hotkey doesn't work**
Ensure no other app is using `⌘⇧Space`. You can change the hotkey in Settings.

**Push-to-talk not working**
Push-to-talk requires Accessibility permission. Go to System Settings → Privacy & Security → Accessibility and enable Squawk.

**Ollama not detected**
Make sure Ollama is running (`ollama serve`) and you've pulled a model (`ollama pull mistral`).

**Empty transcriptions**
Check that the correct microphone is selected in System Settings → Sound → Input. Recordings shorter than 0.5 seconds are discarded.

## Building from Source

```bash
# Clone the repo
git clone https://github.com/your-username/squawk-app.git
cd squawk-app

# Build with xcodebuild (NOT swift build)
xcodebuild -project Squawk/Squawk.xcodeproj -scheme Squawk -destination 'platform=macOS' build

# Run tests
xcodebuild -project Squawk/Squawk.xcodeproj -scheme Squawk -destination 'platform=macOS' test

# Archive for distribution
./scripts/build.sh
```

> **Note:** Do not use `swift build` — it compiles but crashes at runtime due to Metal shader requirements.

## Architecture

See `docs/ARCHITECTURE.md` for the full system diagram.

**Pipeline:** Hotkey → AVAudioEngine capture → FluidAudio Parakeet CoreML (ANE) → optional Ollama polish → NSPasteboard + CGEvent paste

## Credits

- **ASR Engine:** [FluidAudio](https://github.com/FluidInference) + NVIDIA Parakeet
- **AI Polish:** [Ollama](https://ollama.ai) (optional)
- **Runtime:** Apple Neural Engine via CoreML

## License

MIT
