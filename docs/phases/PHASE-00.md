# PHASE-00: Xcode Project Scaffolding

## Goal

Create the Xcode project, add FluidAudio as an SPM dependency, configure the app as menu-bar-only with no dock icon, and verify that a bare `MenuBarExtra` renders in the system tray.

## Prerequisites

- macOS 14.0+ (Sonoma) on Apple Silicon
- Xcode 15+ installed with command-line tools
- Internet access for FluidAudio SPM resolution

## Directory & File Structure

```
Squawk/
├── Squawk.xcodeproj/
├── Squawk/
│   ├── SquawkApp.swift              # @main entry point with MenuBarExtra
│   ├── Info.plist                   # LSUIElement = YES
│   ├── Squawk.entitlements          # Audio input entitlement
│   ├── Assets.xcassets/             # App icon, menu bar template images
│   │   ├── AppIcon.appiconset/
│   │   └── Contents.json
│   ├── Audio/
│   │   ├── AudioCaptureManager.swift
│   │   └── AudioPermissions.swift
│   ├── ASR/
│   │   ├── TranscriptionEngine.swift
│   │   └── ModelManager.swift
│   ├── Refinement/
│   │   ├── OllamaClient.swift
│   │   └── TranscriptRefiner.swift
│   ├── Pipeline/
│   │   ├── DictationController.swift
│   │   └── TextInjector.swift
│   ├── Views/
│   │   ├── MenuBarView.swift
│   │   ├── TranscriptListView.swift
│   │   ├── SettingsView.swift
│   │   └── StatusIndicator.swift
│   ├── Models/
│   │   ├── AppState.swift
│   │   ├── TranscriptEntry.swift
│   │   └── AppSettings.swift
│   └── Utilities/
│       ├── HotkeyManager.swift
│       └── Logging.swift
└── Package.resolved
```

## Detailed Steps

### Step 1: Create Xcode Project

> **🧑‍💻 USER ACTION REQUIRED — Xcode GUI:**
> 1. Open Xcode → File → New → Project
> 2. Select **macOS → App**
> 3. Configure:
>    - Product Name: `Squawk`
>    - Team: your dev team (or Personal Team)
>    - Organization Identifier: `com.squawk`
>    - Bundle Identifier: `com.squawk.app`
>    - Interface: **SwiftUI**
>    - Language: **Swift**
> 4. **Save into the `squawk-app` working directory** (this repo root)
> 5. Set Deployment Target to **macOS 14.0** in the target's General tab
> 6. Tell Claude Code when done so it can continue with file creation.

After the user creates the project, delete the auto-generated `ContentView.swift` — we won't use it.

### Step 2: Configure Menu-Bar-Only App

1. **Info.plist** — add `LSUIElement` key:
   ```xml
   <key>LSUIElement</key>
   <true/>
   ```
   This hides the app from the Dock and the Cmd+Tab app switcher. The app lives entirely in the menu bar.

2. **SquawkApp.swift** — replace the default `WindowGroup` with a `MenuBarExtra`:
   ```swift
   import SwiftUI

   @main
   struct SquawkApp: App {
       var body: some Scene {
           MenuBarExtra("Squawk", systemImage: "mic") {
               MenuBarView()
           }
           .menuBarExtraStyle(.window)
       }
   }
   ```

   **Critical:** Use `.menuBarExtraStyle(.window)`, NOT `.menu`. The `.window` style renders a rich SwiftUI popover that supports arbitrary views, scroll views, tab pickers, etc. The `.menu` style is limited to basic `Button`, `Toggle`, `Divider`, and `Picker` items — no custom layouts.

3. **MenuBarView.swift** — minimal placeholder:
   ```swift
   import SwiftUI

   struct MenuBarView: View {
       var body: some View {
           VStack(spacing: 12) {
               Text("Squawk is running")
                   .font(.headline)
               Divider()
               Button("Quit") {
                   NSApplication.shared.terminate(nil)
               }
               .keyboardShortcut("q")
           }
           .padding()
           .frame(width: 300)
       }
   }
   ```

### Step 3: Add FluidAudio SPM Dependency

> **🧑‍💻 USER ACTION REQUIRED — Xcode GUI:**
> 1. In Xcode: **File → Add Package Dependencies**
> 2. Enter URL: `https://github.com/FluidInference/FluidAudio.git`
> 3. Dependency rule: **Up to Next Major Version**, starting from `0.12.0`
> 4. **IMPORTANT:** On the "Choose Package Products" screen, add **only the `FluidAudio` library** product to the `Squawk` app target. Do NOT add any executable targets — FluidAudio ships CLI tools that should not be embedded in the app.
> 5. Wait for SPM resolution to complete (may take 1-2 minutes on first fetch).
> 6. Tell Claude Code when done so it can verify the import compiles.

After the user adds the dependency, verify by adding `import FluidAudio` at the top of `SquawkApp.swift` and building.

### Step 4: Configure Entitlements & Signing

> **🧑‍💻 USER ACTION REQUIRED — Xcode GUI (Signing & Capabilities tab):**
> 1. Select the **Squawk** target → **Signing & Capabilities** tab
> 2. Ensure **Hardened Runtime** is ON (add it via "+ Capability" if not present)
> 3. Ensure **App Sandbox** is **OFF** (remove it if present) — we need CGEvent posting and Accessibility API access, both blocked by sandbox
> 4. Under Hardened Runtime, check **Audio Input** if available as a runtime exception
> 5. Verify signing identity is set (your dev team or Personal Team)
> 6. Tell Claude Code when done.

After the user configures signing, create/update `Squawk.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

**Sandboxing decision:**
- App Sandbox: **OFF** — the app needs `CGEvent` posting for auto-paste and Accessibility API access for push-to-talk. Both are blocked by the sandbox. This is standard for menu bar utilities (see: Rectangle, Raycast, Alfred).
- Hardened Runtime: **ON** — required for notarization.
- See `docs/DECISIONS.md` ADR #6 for full rationale.

### Step 5: Create Skeleton Source Files

Create all subdirectories and stub files. Each stub should contain a minimal type definition so the project compiles:

```swift
// Audio/AudioCaptureManager.swift
import AVFoundation
import Observation

@Observable
final class AudioCaptureManager {
    var isCapturing = false
    var audioLevel: Float = 0.0
}
```

```swift
// Audio/AudioPermissions.swift
import AVFoundation

enum AudioPermissions {
    static func checkAndRequest() async -> Bool {
        return false // stub
    }
}
```

```swift
// ASR/TranscriptionEngine.swift
import Observation

@Observable
final class TranscriptionEngine {
    var isReady = false
}
```

```swift
// ASR/ModelManager.swift
import Observation

@Observable
final class ModelManager {
    var isDownloaded = false
    var downloadProgress: Double = 0.0
}
```

```swift
// Refinement/OllamaClient.swift
import Foundation

struct OllamaClient {
    let baseURL = URL(string: "http://localhost:11434")!
}
```

```swift
// Refinement/TranscriptRefiner.swift
import Foundation

struct TranscriptRefiner {
    func refine(rawTranscript: String) async throws -> String {
        return rawTranscript // stub
    }
}
```

```swift
// Pipeline/DictationController.swift
import Observation

@Observable
final class DictationController {
    var state: DictationState = .idle
}

enum DictationState {
    case idle, recording, transcribing, refining
}
```

```swift
// Pipeline/TextInjector.swift
import AppKit

struct TextInjector {
    func inject(text: String) {
        // stub
    }
}
```

```swift
// Models/AppState.swift
import Observation

@Observable
final class AppState {
    var ollamaAvailable = false
}
```

```swift
// Models/TranscriptEntry.swift
import Foundation

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    var rawText: String
    var polishedText: String?
    let timestamp: Date
    var audioDuration: TimeInterval
    var latencyMs: Int?
}
```

```swift
// Models/AppSettings.swift
import Foundation

enum AppSettings {
    static let defaultHotkeyKeyCode: UInt16 = 49 // Space
}
```

```swift
// Utilities/HotkeyManager.swift
import Cocoa

final class HotkeyManager {
    // stub
}
```

```swift
// Utilities/Logging.swift
import os

enum Log {
    static let audio = Logger(subsystem: "com.squawk.app", category: "audio")
    static let asr = Logger(subsystem: "com.squawk.app", category: "asr")
    static let ollama = Logger(subsystem: "com.squawk.app", category: "ollama")
    static let pipeline = Logger(subsystem: "com.squawk.app", category: "pipeline")
}
```

### Step 6: Menu Bar Icon Assets

For development, use SF Symbols — no custom assets needed yet:
- Idle: `"mic"` — standard microphone outline
- Recording: `"mic.fill"` — filled microphone
- Processing: `"ellipsis.circle"` — indicates work in progress
- Refining: `"sparkles"` — AI polish

These are passed directly as the `systemImage` parameter in `MenuBarExtra`. Custom 18×18pt template images can replace them in PHASE-07.

### Step 7: Build Verification

**CRITICAL:** Build with `xcodebuild`, NOT `swift build`.

FluidAudio depends on libraries that include Metal shader compilation steps. These require Xcode's full build system. `swift build` will compile the Swift source but the resulting binary will crash at runtime when ASR is invoked because Metal shaders won't be compiled.

```bash
xcodebuild -project Squawk.xcodeproj -scheme Squawk \
  -destination 'platform=macOS' \
  build
```

Verify:
1. Build succeeds with no errors
2. Run the app — no window appears, no dock icon
3. Menu bar shows a microphone icon (SF Symbol)
4. Click icon → SwiftUI popover appears with "Squawk is running"
5. Click "Quit" → app terminates cleanly
6. Check Console.app for any warnings/crashes

## Key Dependencies

| Dependency | Version | Source |
|-----------|---------|--------|
| FluidAudio | ≥0.12.0 | SPM: `https://github.com/FluidInference/FluidAudio.git` |
| SwiftUI | macOS 14+ | Apple (built-in) |
| AppKit | macOS 14+ | Apple (built-in) |

## Gotchas & Edge Cases

1. **`MenuBarExtra` requires macOS 13+** — we target 14, so this is fine. But be aware that `.menuBarExtraStyle(.window)` specifically requires macOS 13+.

2. **FluidAudio SPM resolution** may take 1-2 minutes on first fetch. It pulls several CoreML-related dependencies.

3. **No `ContentView`** — Xcode's template creates one. Delete it immediately to avoid confusion. All UI lives in `MenuBarView`.

4. **`LSUIElement` and the menu bar** — with `LSUIElement = YES`, the app has no main menu bar (File, Edit, etc.) and no dock icon. This is the correct behavior for a pure menu bar utility.

5. **Hardened Runtime + non-sandboxed** — this combination is valid and common for developer tools and menu bar apps. Notarization still works.

6. **`@Observable` macro** — requires macOS 14.0+ and Swift 5.9+. Since our deployment target is macOS 14.0, this is available. Do NOT use the older `ObservableObject` / `@Published` pattern.

7. **FluidAudio executable target** — the package includes a CLI tool. If accidentally linked to the app target, it will cause build errors or bloat the binary. Only link the `FluidAudio` library product.

## Acceptance Criteria

- [ ] Xcode project builds with `xcodebuild` without errors
- [ ] App launches with no window and no Dock icon
- [ ] Menu bar shows a microphone SF Symbol icon
- [ ] Clicking the icon shows a SwiftUI popover (`.window` style, not a basic menu)
- [ ] Popover contains "Squawk is running" text and a "Quit" button
- [ ] "Quit" terminates the app cleanly with no crash
- [ ] `import FluidAudio` compiles without error
- [ ] All skeleton source files compile (no red errors)
- [ ] Project targets macOS 14.0 deployment
- [ ] Hardened Runtime is ON, App Sandbox is OFF
- [ ] Audio input entitlement is present in `.entitlements` file

## Estimated Complexity

**S** — Straightforward project setup and configuration. Main risk is FluidAudio SPM resolution and ensuring the correct library target is linked.

## References

- **speak2** (`github.com/zachswift615/speak2`): Study its Xcode project structure and `SquawkApp.swift` equivalent for `MenuBarExtra` configuration.
- **FluidVoice** (`github.com/altic-dev/FluidVoice`): Another menu bar app using FluidAudio — check how it configures the SPM dependency.
- **swift-scribe** (`github.com/FluidInference/swift-scribe`): Official FluidAudio example showing recommended directory layout.
