# PHASE-06: SwiftUI Interface & Settings

## Goal

Build the complete SwiftUI interface: transcript history view, full settings panel, recording indicator with audio level visualization, and about view. All SwiftUI code in this phase should be reviewed with the `/swiftui-pro` skill for best practices.

## Prerequisites

- PHASE-05 complete: Full pipeline working end-to-end
- `DictationController` is `@Observable` and injected via `.environment()`
- `TranscriptHistory` populated with entries
- All pipeline state transitions reflected in `DictationState`

## Directory & File Structure

```
Squawk/
├── Views/
│   ├── MenuBarView.swift            # Root view — rewrite from test UI
│   ├── StatusBar.swift              # NEW — state indicator + audio level
│   ├── TranscriptListView.swift     # Full implementation
│   ├── TranscriptRow.swift          # NEW — individual transcript row
│   ├── SettingsView.swift           # Full implementation
│   ├── HotkeyCapture.swift         # NEW — hotkey recording overlay
│   ├── AboutView.swift             # NEW
│   └── StatusIndicator.swift       # Full implementation
└── SquawkApp.swift                  # Final MenuBarExtra configuration
```

> **Important:** Use the `/swiftui-pro` skill when writing and reviewing all SwiftUI views in this phase. It will catch common issues with `@Observable` usage, view performance, accessibility, and modern API usage for macOS 14+.

## Detailed Steps

### Step 1: MenuBarView — Root View

`Views/MenuBarView.swift` — the root content of the `MenuBarExtra(.window)` popover:

```swift
import SwiftUI

struct MenuBarView: View {
    @Environment(DictationController.self) private var controller
    @State private var selectedTab: Tab = .transcripts

    enum Tab: String, CaseIterable {
        case transcripts = "Transcripts"
        case settings = "Settings"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar at top — always visible
            StatusBar()

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .transcripts:
                    TranscriptListView()
                case .settings:
                    SettingsView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Bottom bar: tab picker + quit
            HStack {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 340, height: 450)
    }
}
```

### Step 2: StatusBar — State Indicator + Audio Level

`Views/StatusBar.swift`:

```swift
import SwiftUI

struct StatusBar: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            statusText
            Spacer()

            if controller.state == .recording {
                AudioLevelBars(level: controller.audioCaptureManager.audioLevel)
            }

            if let latency = controller.lastLatencyMs, controller.state == .idle {
                Text("\(latency)ms")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.2), value: controller.state)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch controller.state {
        case .idle:
            Image(systemName: "mic")
                .foregroundStyle(.secondary)
        case .recording:
            // Pulsing red dot
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .modifier(PulsingModifier())
        case .transcribing:
            ProgressView()
                .controlSize(.small)
        case .refining:
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .symbolEffect(.pulse)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch controller.state {
        case .idle:
            if let error = controller.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                Text("Ready — ⌘⇧Space to record")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .recording:
            Text("Recording...")
                .font(.caption)
                .foregroundStyle(.red)
        case .transcribing:
            Text("Transcribing...")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .refining:
            Text("Polishing with AI...")
                .font(.caption)
                .foregroundStyle(.purple)
        }
    }
}

// Pulsing animation for the recording dot
struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
```

**Audio level bars visualization:**

```swift
struct AudioLevelBars: View {
    let level: Float
    private let barCount = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.1), value: level)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index + 1) / Float(barCount) * 0.5
        let active = level > threshold
        return active ? CGFloat(8 + index * 2) : 4
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index + 1) / Float(barCount) * 0.5
        return level > threshold ? .red : .red.opacity(0.2)
    }
}
```

### Step 3: TranscriptListView

`Views/TranscriptListView.swift`:

```swift
import SwiftUI

struct TranscriptListView: View {
    @Environment(DictationController.self) private var controller
    @State private var copiedEntryId: UUID?

    var body: some View {
        if controller.history.entries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                // Clear all button
                HStack {
                    Spacer()
                    Button("Clear All") {
                        // Confirmation handled via alert
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .confirmationDialog("Clear all transcripts?", isPresented: .constant(false)) {
                        Button("Clear All", role: .destructive) {
                            controller.history.clearAll()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(controller.history.entries) { entry in
                            TranscriptRow(
                                entry: entry,
                                isCopied: copiedEntryId == entry.id
                            )
                            .onTapGesture {
                                copyEntry(entry)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Press ⌘⇧Space to start transcribing")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func copyEntry(_ entry: TranscriptEntry) {
        let text = entry.polishedText ?? entry.rawText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copiedEntryId = entry.id
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedEntryId == entry.id {
                copiedEntryId = nil
            }
        }
    }
}
```

`Views/TranscriptRow.swift`:

```swift
import SwiftUI

struct TranscriptRow: View {
    let entry: TranscriptEntry
    let isCopied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if entry.polishedText != nil {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }

                Spacer()

                if isCopied {
                    Text("Copied!")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                if let latency = entry.latencyMs {
                    Text("\(latency)ms")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .monospacedDigit()
                }
            }

            Text(entry.polishedText ?? entry.rawText)
                .font(.callout)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(8)
        .background(isCopied ? Color.green.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle()) // Make entire row tappable
        .animation(.easeInOut(duration: 0.2), value: isCopied)
    }
}
```

### Step 4: SettingsView

`Views/SettingsView.swift` — uses `Form` with `Section` groups:

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(DictationController.self) private var controller

    // Settings backed by @AppStorage
    @AppStorage("hotkey.keyCode") private var hotkeyKeyCode: Int = 49
    @AppStorage("hotkey.modifiers") private var hotkeyModifiers: Int = 0
    @AppStorage("recording.mode") private var recordingMode: String = "toggle"
    @AppStorage("recording.maxDuration") private var maxDuration: Int = 300
    @AppStorage("asr.modelVersion") private var modelVersion: String = "v2"
    @AppStorage("ollama.enabled") private var ollamaEnabled: Bool = true
    @AppStorage("ollama.model") private var ollamaModel: String = "mistral"
    @AppStorage("ollama.customPrompt") private var customPrompt: String = ""
    @AppStorage("ollama.temperature") private var temperature: Double = 0.3
    @AppStorage("output.autoPaste") private var autoPaste: Bool = false
    @AppStorage("output.restoreClipboard") private var restoreClipboard: Bool = true
    @AppStorage("output.completionSound") private var completionSound: Bool = true
    @AppStorage("general.launchAtLogin") private var launchAtLogin: Bool = false

    @State private var isCapturingHotkey = false
    @State private var availableOllamaModels: [String] = []

    var body: some View {
        ScrollView {
            Form {
                recordingSection
                transcriptionSection
                refinementSection
                outputSection
                generalSection
            }
            .formStyle(.grouped)
            .padding(.horizontal, 4)
        }
    }
}
```

**Recording section:**

```swift
private var recordingSection: some View {
    Section("Recording") {
        // Hotkey display + change
        HStack {
            Text("Hotkey")
            Spacer()
            if isCapturingHotkey {
                Text("Press new shortcut...")
                    .foregroundStyle(.orange)
            } else {
                Text("⌘⇧Space") // Dynamic based on stored values
                    .foregroundStyle(.secondary)
                Button("Change") {
                    isCapturingHotkey = true
                }
                .buttonStyle(.borderless)
            }
        }

        // Mode picker
        Picker("Mode", selection: $recordingMode) {
            Text("Toggle (press to start/stop)").tag("toggle")
            Text("Push-to-talk (hold to record)").tag("pushToTalk")
        }

        if recordingMode == "pushToTalk" && !HotkeyManager.hasAccessibilityPermission {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Push-to-talk requires Accessibility permission")
                    .font(.caption)
                Button("Grant") {
                    HotkeyManager.openAccessibilitySettings()
                }
                .buttonStyle(.borderless)
            }
        }

        // Input device picker
        Picker("Microphone", selection: .constant("default")) {
            Text("System Default").tag("default")
            ForEach(controller.audioCaptureManager.availableInputDevices) { device in
                Text(device.name).tag(device.id)
            }
        }

        // Max duration stepper
        Stepper("Max duration: \(maxDuration / 60) min", value: $maxDuration, in: 60...600, step: 60)
    }
}
```

**Transcription section:**

```swift
private var transcriptionSection: some View {
    Section("Transcription") {
        Picker("Model", selection: $modelVersion) {
            Text("English (Parakeet v2)").tag("v2")
            Text("Multilingual — 25 languages (Parakeet v3)").tag("v3")
        }

        HStack {
            Text("Model status")
            Spacer()
            if controller.modelManager.isDownloaded {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else if controller.modelManager.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Downloading...")
                    .font(.caption)
            } else {
                Label("Not loaded", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }

        if !controller.modelManager.isDownloaded && !controller.modelManager.isLoading {
            Button("Download Model") {
                Task { await controller.modelManager.loadModels() }
            }
        }
    }
}
```

**AI Refinement section — with dynamic model dropdown from Ollama:**

```swift
private var refinementSection: some View {
    Section("AI Refinement") {
        Toggle("Enable AI polish", isOn: $ollamaEnabled)

        if ollamaEnabled {
            // Ollama connection status
            HStack {
                Text("Ollama")
                Spacer()
                if controller.ollamaAvailable {
                    Label("Connected", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label("Not running", systemImage: "circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            // Dynamic model picker — populated from Ollama's installed models
            Picker("Model", selection: $ollamaModel) {
                if availableOllamaModels.isEmpty {
                    Text(ollamaModel).tag(ollamaModel)
                } else {
                    ForEach(availableOllamaModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
            .task {
                await refreshOllamaModels()
            }

            Button("Refresh Models") {
                Task { await refreshOllamaModels() }
            }
            .buttonStyle(.borderless)
            .font(.caption)

            if !controller.ollamaAvailable {
                Text("Install Ollama from ollama.com and run: ollama pull \(ollamaModel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Advanced settings
            DisclosureGroup("Advanced") {
                // Custom system prompt
                VStack(alignment: .leading) {
                    Text("System Prompt")
                        .font(.caption)
                    TextEditor(text: $customPrompt)
                        .font(.caption)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    if customPrompt.isEmpty {
                        Text("Using default prompt")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Temperature slider
                HStack {
                    Text("Temperature")
                    Slider(value: $temperature, in: 0...1, step: 0.1)
                    Text(String(format: "%.1f", temperature))
                        .monospacedDigit()
                        .font(.caption)
                }
            }
        }
    }
}

private func refreshOllamaModels() async {
    let client = OllamaClient()
    do {
        availableOllamaModels = try await client.listModels()
    } catch {
        availableOllamaModels = []
    }
}
```

**Output section:**

```swift
private var outputSection: some View {
    Section("Output") {
        Toggle("Auto-paste into active app", isOn: $autoPaste)
        if autoPaste {
            Text("Simulates ⌘V after transcription. Some apps may require Accessibility permission.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if autoPaste {
            Toggle("Restore clipboard after paste", isOn: $restoreClipboard)
        }

        Toggle("Play sound on completion", isOn: $completionSound)
    }
}
```

**General section:**

```swift
private var generalSection: some View {
    Section("General") {
        Toggle("Launch at login", isOn: Binding(
            get: { launchAtLogin },
            set: { newValue in
                launchAtLogin = newValue
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    Log.pipeline.error("Launch at login toggle failed: \(error)")
                    launchAtLogin = !newValue // revert
                }
            }
        ))
    }
}
```

### Step 5: Hotkey Capture UI

`Views/HotkeyCapture.swift` — overlay that captures a new hotkey combination:

```swift
import SwiftUI
import Carbon.HIToolbox

struct HotkeyCaptureOverlay: View {
    @Binding var isActive: Bool
    var onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    var body: some View {
        if isActive {
            VStack(spacing: 12) {
                Text("Press a new shortcut")
                    .font(.headline)
                Text("Use a modifier key (⌘, ⌥, ⌃, ⇧) + a letter or key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Cancel") { isActive = false }
                Button("Reset to Default") {
                    onCapture(UInt16(kVK_Space), [.command, .shift])
                    isActive = false
                }
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onLocalKeyEvent { event in
                // Validate: must have at least one modifier
                let mods: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
                guard !event.modifierFlags.intersection(mods).isEmpty else { return }

                onCapture(event.keyCode, event.modifierFlags.intersection(mods))
                isActive = false
            }
        }
    }
}
```

> The `onLocalKeyEvent` is a custom modifier using `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`. Implement as a ViewModifier or use the `onKeyPress` modifier available in macOS 14+.

### Step 6: AboutView

`Views/AboutView.swift`:

```swift
import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Squawk")
                .font(.title2.bold())

            Text("v\(appVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Local speech-to-text for macOS")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 4) {
                creditRow("ASR Engine", "FluidAudio + NVIDIA Parakeet")
                creditRow("AI Polish", "Ollama (optional)")
                creditRow("Runtime", "Apple Neural Engine")
            }
            .font(.caption)

            Button("Copy Debug Info") {
                copyDebugInfo()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            Spacer()
        }
    }

    private func creditRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .padding(.horizontal, 20)
    }

    private func copyDebugInfo() {
        let info = """
            Squawk v\(appVersion) (\(buildNumber))
            macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
            Chip: \(ProcessInfo.processInfo.machineModel)
            """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }
}

private extension ProcessInfo {
    var machineModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}
```

### Step 7: Dark Mode

All colors use semantic SwiftUI values (`.primary`, `.secondary`, `.tertiary`, `.quaternary`), which automatically adapt to light and dark mode. No explicit color overrides needed.

For custom backgrounds, use `.regularMaterial`, `.thinMaterial`, etc. — these adapt to the system appearance.

## Key Dependencies

| Framework | Import | Usage |
|-----------|--------|-------|
| SwiftUI | `import SwiftUI` | All views |
| ServiceManagement | `import ServiceManagement` | `SMAppService` for launch at login |
| AppKit | `import AppKit` | `NSPasteboard`, `NSWorkspace` |
| Carbon.HIToolbox | `import Carbon.HIToolbox` | Key code constants for hotkey capture |

## Gotchas & Edge Cases

1. **`MenuBarExtra(.window)` frame size** — The popover doesn't auto-size to content. Set an explicit `.frame(width: 340, height: 450)` on the root view.

2. **`@AppStorage` and enums** — `@AppStorage` only supports basic types (String, Int, Bool, Double, Data, URL). For enums, store as String and convert.

3. **`SMAppService` errors** — `register()` can fail silently if the app isn't properly signed. Test with a signed build.

> **🧑‍💻 USER ACTION — if launch-at-login doesn't work:** Verify in Xcode that the target is signed with a valid Developer ID or Personal Team (not ad-hoc). SMAppService requires proper signing.

4. **`Form` in menu bar popover** — `Form` with `.grouped` style works well in the `.window` style popover. Test that scrolling works for long settings lists.

5. **Dynamic Ollama model list** — The model dropdown is populated by querying `GET /api/tags` from Ollama. If Ollama isn't running, fall back to showing just the currently configured model name as a text field. Refresh on view appear and via a manual "Refresh" button.

6. **Hotkey capture conflicts** — When capturing a new hotkey, validate that it doesn't conflict with system shortcuts (Cmd+C, Cmd+V, Cmd+Q, etc.). Show a warning for known conflicts.

7. **Animation performance** — The pulsing recording dot and audio level bars should use lightweight animations. Avoid redrawing the entire view hierarchy on each audio level update.

8. **`TextEditor` in Form** — On macOS, `TextEditor` in a `Form` can have sizing issues. Set an explicit `.frame(height:)`.

## Acceptance Criteria

- [ ] Menu bar popover opens with correct ~340x450 frame
- [ ] Three tabs work: Transcripts, Settings, About
- [ ] Status bar shows correct state for idle/recording/transcribing/refining
- [ ] Audio level bars animate during recording
- [ ] Transcript list shows entries newest-first
- [ ] Click-to-copy works with "Copied!" feedback animation
- [ ] Empty state shows helpful message
- [ ] Settings: all toggles persist across app restart
- [ ] Settings: hotkey change takes effect immediately
- [ ] Settings: Ollama model dropdown populated from installed models
- [ ] Settings: launch at login works with `SMAppService`
- [ ] About: version and credits display correctly
- [ ] About: "Copy Debug Info" copies system info to clipboard
- [ ] Light mode and dark mode both render correctly
- [ ] Quit button terminates the app cleanly

## Estimated Complexity

**L** — Many views to implement with careful layout. Settings view has the most complexity with dynamic Ollama model list, hotkey capture, and Accessibility permission prompting. The transcript list needs good performance with LazyVStack.

## References

- **speak2**: Study its `LiveTranscriptionPanel` and menu bar view hierarchy.
- **FluidVoice**: Check its settings UI patterns for FluidAudio model selection.
- Use the `/swiftui-pro` skill to review all views for macOS 14+ best practices, proper `@Observable` usage, and accessibility.
