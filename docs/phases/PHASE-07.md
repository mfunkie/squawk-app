# PHASE-07: Packaging, First-Run, & Distribution

## Goal

Handle the first-run experience (model download, permissions), package the app as a `.dmg`, handle edge cases (sleep/wake, device changes, rapid input), and prepare for distribution.

## Prerequisites

- All previous phases (00-06) complete and working
- Full pipeline: hotkey → record → transcribe → (optional polish) → clipboard/paste
- Settings persist, UI is complete
- App builds successfully with `xcodebuild`

## Directory & File Structure

New/modified files:

```
Squawk/
├── Views/
│   └── FirstRunView.swift            # NEW — setup wizard
├── Pipeline/
│   └── DictationController.swift     # Add edge case handling
├── SquawkApp.swift                   # First-run flow gate
├── Info.plist                        # Final metadata
├── Assets.xcassets/
│   ├── AppIcon.appiconset/           # All icon sizes
│   └── MenuBarIcon.imageset/         # Custom template images (optional)
├── Squawk.entitlements               # Final entitlements
└── README.md                         # User-facing documentation
```

Build/distribution files (not in Xcode target):
```
scripts/
├── build.sh                          # xcodebuild archive + export
├── notarize.sh                       # notarytool submit + staple
└── create-dmg.sh                     # DMG with drag-to-Applications
```

## Detailed Steps

### Step 1: First-Run Setup Wizard

`Views/FirstRunView.swift` — shown in the `MenuBarExtra` popover on first launch:

> **Note:** Use the `/swiftui-pro` skill when implementing this view.

```swift
import SwiftUI

struct FirstRunView: View {
    @Environment(DictationController.self) private var controller
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var currentStep: SetupStep = .welcome

    enum SetupStep: Int, CaseIterable {
        case welcome
        case modelDownload
        case microphonePermission
        case accessibilityPermission
        case ready
    }

    var body: some View {
        VStack(spacing: 20) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(SetupStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Step content
            stepContent

            Spacer()

            // Navigation
            stepNavigation
        }
        .padding(20)
        .frame(width: 340, height: 450)
    }
}
```

**Step content for each setup step:**

```swift
@ViewBuilder
private var stepContent: some View {
    switch currentStep {
    case .welcome:
        VStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Welcome to Squawk")
                .font(.title2.bold())
            Text("Local voice-to-text for your Mac.\nFast, private, powered by Apple Neural Engine.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }

    case .modelDownload:
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 36))
            Text("Speech Model")
                .font(.title3.bold())

            if controller.modelManager.isDownloaded {
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if controller.modelManager.isLoading {
                VStack {
                    ProgressView(value: controller.modelManager.downloadProgress)
                    Text("Downloading... (~300MB)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("This only happens once.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else if let error = controller.modelManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("Retry") {
                    Task { await controller.modelManager.loadModels() }
                }
            } else {
                Button("Download Model") {
                    Task { await controller.modelManager.loadModels() }
                }
            }
        }

    case .microphonePermission:
        VStack(spacing: 12) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 36))
            Text("Microphone Access")
                .font(.title3.bold())
            Text("Squawk needs your microphone to transcribe speech. Audio never leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            let status = AudioPermissions.currentStatus
            switch status {
            case .authorized:
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                VStack {
                    Label("Permission denied", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                    Button("Open System Settings") {
                        AudioPermissions.openSystemSettings()
                    }
                }
            default:
                Button("Grant Access") {
                    Task { _ = await AudioPermissions.requestAccess() }
                }
            }
        }

    case .accessibilityPermission:
        VStack(spacing: 12) {
            Image(systemName: "hand.raised")
                .font(.system(size: 36))
            Text("Accessibility (Optional)")
                .font(.title3.bold())
            Text("Required for push-to-talk and auto-paste. You can skip this and enable later in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if HotkeyManager.hasAccessibilityPermission {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant Access") {
                    HotkeyManager.requestAccessibilityPermission()
                }
                Button("Skip for now") {
                    currentStep = .ready
                }
                .foregroundStyle(.secondary)
            }
        }

    case .ready:
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("All Set!")
                .font(.title2.bold())
            Text("Press ⌘⇧Space anywhere to start dictating.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}
```

**Gate in SquawkApp:**

```swift
@main
struct SquawkApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false

    var body: some Scene {
        MenuBarExtra("Squawk", systemImage: menuBarIcon) {
            if hasCompletedSetup {
                MenuBarView()
                    .environment(dictationController)
            } else {
                FirstRunView()
                    .environment(dictationController)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
```

### Step 2: Edge Case Handling

**Sleep during recording:**

```swift
// In DictationController init:
NotificationCenter.default.addObserver(
    forName: NSWorkspace.willSleepNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    guard let self, self.state == .recording else { return }
    Log.pipeline.warning("System sleeping during recording — stopping and transcribing")
    Task { await self.stopAndTranscribe() }
}
```

**Audio device changes during recording:**

Already handled in PHASE-01 via `AVAudioEngineConfigurationChange`. Additionally:

```swift
// In DictationController:
NotificationCenter.default.addObserver(
    forName: AVAudioSession.routeChangeNotification,
    object: nil,
    queue: .main
) { [weak self] notification in
    guard let self, self.state == .recording else { return }
    Log.audio.warning("Audio route changed during recording")
    // Continue recording — AVAudioEngine handles the switch
}
```

**Empty utterance detection:**

Already handled in PHASE-05 — discard if <0.5 seconds of audio.

**Long utterance:**

Already handled in PHASE-04 — auto-stop at configurable max duration.

**Rapid hotkey presses:**

Already handled in PHASE-04 — 300ms debounce.

**Ollama model not pulled:**

```swift
// When refinement fails with modelNotFound:
if case .modelNotFound(let model) = error as? OllamaError {
    lastError = "Run: ollama pull \(model)"
}
```

**Low disk space before model download:**

```swift
func checkDiskSpace() -> Bool {
    let fileManager = FileManager.default
    let homeURL = fileManager.homeDirectoryForCurrentUser
    do {
        let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        let requiredBytes: Int64 = 1_000_000_000 // 1GB
        return available > requiredBytes
    } catch {
        return true // Don't block on error
    }
}
```

**App already running — single instance:**

```swift
// In SquawkApp.init():
let runningApps = NSWorkspace.shared.runningApplications.filter {
    $0.bundleIdentifier == Bundle.main.bundleIdentifier
}
if runningApps.count > 1 {
    // Another instance is running — activate it and quit self
    runningApps.first?.activate()
    NSApplication.shared.terminate(nil)
}
```

### Step 3: App Icon

> **🧑‍💻 USER ACTION REQUIRED — Xcode GUI (Asset Catalog):**
> After Claude Code generates the icon PNGs (or you provide a source image), you need to:
> 1. Open `Assets.xcassets` in Xcode
> 2. Select `AppIcon`
> 3. Drag each sized PNG into the corresponding slot
> 4. Optionally: add a `MenuBarIcon` image set, mark it as **Template Image** for automatic light/dark adaptation
> 5. Tell Claude Code when done.

Create all required icon sizes in `Assets.xcassets/AppIcon.appiconset/`:

| Size | Scale | Filename |
|------|-------|----------|
| 16x16 | 1x | icon_16x16.png |
| 16x16 | 2x | icon_16x16@2x.png |
| 32x32 | 1x | icon_32x32.png |
| 32x32 | 2x | icon_32x32@2x.png |
| 128x128 | 1x | icon_128x128.png |
| 128x128 | 2x | icon_128x128@2x.png |
| 256x256 | 1x | icon_256x256.png |
| 256x256 | 2x | icon_256x256@2x.png |
| 512x512 | 1x | icon_512x512.png |
| 512x512 | 2x | icon_512x512@2x.png |

Design: a stylized microphone or speech bubble. Start with a simple SF Symbol-based design and iterate.

**Custom menu bar icons** (optional, replacing SF Symbols):
- 18x18 pt @1x and 36x36 pt @2x PNG
- Mark as "Template Image" in the asset catalog for automatic light/dark mode adaptation

### Step 4: Build & Archive

> **🧑‍💻 USER ACTION REQUIRED — Xcode GUI (optional, for manual archive):**
> If you prefer to archive via Xcode GUI instead of the script below:
> 1. In Xcode: **Product → Archive**
> 2. Wait for archive to complete
> 3. In the Organizer window, select the archive → **Distribute App**
> 4. Choose **Developer ID** distribution method
> 5. Follow the signing prompts
> 6. The script below automates this same process via CLI.

`scripts/build.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCHEME="Squawk"
PROJECT="Squawk.xcodeproj"
ARCHIVE_PATH="build/Squawk.xcarchive"
EXPORT_PATH="build/export"

echo "Building archive..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO

echo "Exporting app..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist ExportOptions.plist

echo "Build complete: $EXPORT_PATH/Squawk.app"
```

`ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signing</key>
    <dict>
        <key>style</key>
        <string>automatic</string>
    </dict>
</dict>
</plist>
```

### Step 5: Notarization

> **🧑‍💻 USER ACTION REQUIRED — Terminal (one-time setup):**
> Before the notarize script can run, you must store your Apple ID credentials in the keychain:
> ```bash
> xcrun notarytool store-credentials squawk-notarize \
>   --apple-id YOUR_APPLE_ID \
>   --team-id YOUR_TEAM_ID \
>   --password YOUR_APP_SPECIFIC_PASSWORD
> ```
> Generate an app-specific password at https://appleid.apple.com/account/manage
> Tell Claude Code when this is configured.

`scripts/notarize.sh`:

```bash
#!/bin/bash
set -euo pipefail

APP_PATH="build/export/Squawk.app"
BUNDLE_ID="com.squawk.app"
TEAM_ID="${TEAM_ID:?Set TEAM_ID environment variable}"
APPLE_ID="${APPLE_ID:?Set APPLE_ID environment variable}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-squawk-notarize}"

echo "Creating zip for notarization..."
ditto -c -k --keepParent "$APP_PATH" "build/Squawk.zip"

echo "Submitting for notarization..."
xcrun notarytool submit "build/Squawk.zip" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "Stapling ticket..."
xcrun stapler staple "$APP_PATH"

echo "Notarization complete!"
```

### Step 6: DMG Creation

`scripts/create-dmg.sh`:

```bash
#!/bin/bash
set -euo pipefail

APP_PATH="build/export/Squawk.app"
DMG_PATH="build/Squawk.dmg"
VOLUME_NAME="Squawk"

# Using create-dmg (install: brew install create-dmg)
create-dmg \
    --volname "$VOLUME_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "Squawk.app" 175 190 \
    --hide-extension "Squawk.app" \
    --app-drop-link 425 190 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"

echo "DMG created: $DMG_PATH"
```

### Step 7: Logging & Debug Info

Ensure all logging uses `os.Logger` with the `com.squawk.app` subsystem:

```swift
// Already defined in Utilities/Logging.swift:
enum Log {
    static let audio = Logger(subsystem: "com.squawk.app", category: "audio")
    static let asr = Logger(subsystem: "com.squawk.app", category: "asr")
    static let ollama = Logger(subsystem: "com.squawk.app", category: "ollama")
    static let pipeline = Logger(subsystem: "com.squawk.app", category: "pipeline")
}
```

View logs in Console.app: filter by `com.squawk.app`.

**"Copy Debug Info" content:**

```swift
func debugInfo() -> String {
    """
    Squawk \(appVersion) (\(buildNumber))
    macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
    Chip: \(machineModel)
    ASR Model: \(modelManager.isDownloaded ? "loaded" : "not loaded")
    Ollama: \(ollamaAvailable ? "connected (\(ollamaModel))" : "unavailable")
    Recording mode: \(recordingMode)
    Auto-paste: \(autoPasteEnabled)
    History entries: \(history.entries.count)
    Last error: \(lastError ?? "none")
    """
}
```

### Step 8: Performance Budgets

Verify these targets before release:

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Idle memory | <50MB | Activity Monitor |
| Active memory (model loaded) | <500MB | Activity Monitor |
| Idle CPU | ~0% | Activity Monitor |
| Recording CPU | <5% | Activity Monitor |
| Binary size | <20MB | `du -sh Squawk.app` (excluding models) |
| First CoreML compile | 30-60s | Measured on first launch |
| Subsequent launch to ready | <2s | Measured from open to green status |
| 5s speech → transcript | <1.5s (no Ollama) | Pipeline latency log |
| 5s speech → polished | <3s (with Ollama) | Pipeline latency log |

### Step 9: README.md

Generate a user-facing README with:

- App description and screenshots/GIF
- Installation: download DMG, drag to Applications
- Prerequisites: macOS 14+, Apple Silicon (M1/M2/M3/M4)
- Optional: Ollama for AI polish
- Quick start: launch → grant mic permission → ⌘⇧Space
- Hotkey reference
- Troubleshooting (common issues)
- Building from source
- License: MIT

## Key Dependencies

| Framework | Import | Usage |
|-----------|--------|-------|
| ServiceManagement | `import ServiceManagement` | `SMAppService` |
| SwiftUI | `import SwiftUI` | First-run wizard |
| AppKit | `import AppKit` | Single-instance check, `NSWorkspace` |

Build tools:
- `xcodebuild` (Xcode CLI tools)
- `xcrun notarytool` (Xcode CLI tools)
- `xcrun stapler` (Xcode CLI tools)
- `create-dmg` (Homebrew: `brew install create-dmg`)

## Gotchas & Edge Cases

1. **Notarization requires Apple Developer account** — Free accounts can't notarize. Developer Program membership ($99/year) is required for Developer ID signing and notarization.

2. **Hardened Runtime + non-sandboxed** — This combo works for notarization. But you may need runtime exceptions if FluidAudio loads dynamic libraries.

3. **First-run CoreML compilation** — This 30-60 second wait is unavoidable on the very first launch. Communicate it clearly to the user.

4. **`SMAppService` requires proper signing** — Launch-at-login won't work with ad-hoc signing. Needs a proper Developer ID.

5. **arm64 only** — No Intel support. The app requires Apple Silicon for ANE inference. Document this clearly.

6. **Model download on metered connections** — ~300MB download. Consider warning users on cellular hotspots (though macOS doesn't expose metered connection status easily).

7. **Gatekeeper on first launch** — Even notarized apps may show "downloaded from the internet" warning on first launch. This is normal macOS behavior.

8. **Duplicate instances** — The single-instance check in Step 2 prevents confusion. Without it, two instances would fight over the global hotkey.

## Acceptance Criteria

- [ ] First-run wizard completes: model downloads, mic permission granted
- [ ] First-run wizard skippable for Accessibility permission
- [ ] `hasCompletedSetup` flag prevents re-showing wizard
- [ ] `xcodebuild archive` produces valid .xcarchive
- [ ] Exported .app runs on a clean Mac (no Xcode installed)
- [ ] App survives sleep/wake cycles
- [ ] Launch at login works after reboot
- [ ] DMG opens with drag-to-Applications layout
- [ ] Notarized app runs without Gatekeeper warning
- [ ] .app bundle size <20MB (excluding downloaded models)
- [ ] Idle memory <50MB
- [ ] "Copy Debug Info" produces useful diagnostic information
- [ ] Single-instance enforcement: launching again activates existing
- [ ] Low disk space: warning shown before model download if <1GB free
- [ ] README.md is complete and accurate

## Estimated Complexity

**XL** — This phase touches many concerns: first-run UX, edge case hardening, build pipeline, notarization, DMG packaging, and final polish. Each piece is individually small, but the aggregate is significant.

## References

- **speak2**: Study its build configuration and distribution approach.
- **Apple docs** → [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- **Apple docs** → [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- **create-dmg** → `github.com/create-dmg/create-dmg`
