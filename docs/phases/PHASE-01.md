# PHASE-01: Audio Capture & Permissions

## Goal

Implement microphone audio capture using `AVAudioEngine`, handle macOS microphone permissions gracefully, and output raw PCM buffers in the format FluidAudio expects (16kHz, mono, Float32).

## Prerequisites

- PHASE-00 complete: Xcode project builds, `MenuBarExtra` renders, FluidAudio imported
- `AudioCaptureManager.swift` and `AudioPermissions.swift` stubs exist
- `Squawk.entitlements` has `com.apple.security.device.audio-input`

## Directory & File Structure

Files to implement (replacing stubs from PHASE-00):

```
Squawk/
├── Audio/
│   ├── AudioCaptureManager.swift    # Full implementation
│   └── AudioPermissions.swift       # Full implementation
├── Views/
│   └── MenuBarView.swift            # Add test record button + level meter
├── Utilities/
│   └── Logging.swift                # Already done in PHASE-00
└── Models/
    └── AppState.swift               # Add audioPermission status
```

## Detailed Steps

### Step 1: Implement AudioPermissions

`Audio/AudioPermissions.swift` — encapsulates all microphone permission logic:

```swift
import AVFoundation
import AppKit

enum MicrophonePermission {
    case authorized
    case notDetermined
    case denied
    case restricted
}

enum AudioPermissions {
    /// Check current authorization status without prompting.
    static var currentStatus: MicrophonePermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Request microphone access. Returns true if authorized.
    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    /// Open System Settings to the Microphone privacy pane.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

**Key behaviors:**
- Call `currentStatus` on app launch and before every recording attempt
- If `.notDetermined`, call `requestAccess()` — this triggers the system permission dialog
- If `.denied`, show an alert in the popover with a button that calls `openSystemSettings()`
- If `.restricted` (managed device), show an explanation that the admin has blocked mic access
- Never silently fail — always surface permission issues in the UI

### Step 2: Implement AudioCaptureManager

`Audio/AudioCaptureManager.swift` — the core audio capture engine:

```swift
import AVFoundation
import Accelerate
import Observation
import os

@Observable
final class AudioCaptureManager {
    // MARK: - Public state
    var isCapturing = false
    var audioLevel: Float = 0.0

    // MARK: - Private
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private var bufferLock = os_unfair_lock()
    private var levelUpdateCounter = 0
}
```

**Audio format requirements — FluidAudio expects:**
- Sample rate: **16,000 Hz**
- Channels: **1 (mono)**
- Format: **Float32 PCM**
- Sample range: **[-1.0, 1.0]**

**Tap installation:**

```swift
func startCapture() throws {
    guard !isCapturing else { return }

    let inputNode = audioEngine.inputNode
    let desiredFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    // AVAudioEngine automatically resamples from hardware rate (48kHz)
    // to our desired 16kHz format
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: desiredFormat) {
        [weak self] buffer, _ in
        self?.processTapBuffer(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()
    isCapturing = true
    Log.audio.info("Audio capture started")
}
```

**Tap buffer processing (runs on real-time audio thread):**

```swift
private func processTapBuffer(_ buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData else { return }
    let frameCount = Int(buffer.frameLength)
    let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

    // Thread-safe buffer append
    os_unfair_lock_lock(&bufferLock)
    audioBuffer.append(contentsOf: samples)
    os_unfair_lock_unlock(&bufferLock)

    // Compute RMS for audio level meter (throttled to ~15fps)
    levelUpdateCounter += 1
    if levelUpdateCounter % 3 == 0 {
        let rms = computeRMS(samples)
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = rms
        }
    }
}
```

**RMS computation using Accelerate (efficient, vectorized):**

```swift
private func computeRMS(_ samples: [Float]) -> Float {
    var rms: Float = 0
    vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
    return rms
}
```

**Stop capture and return accumulated samples:**

```swift
func stopCapture() -> [Float] {
    guard isCapturing else { return [] }

    audioEngine.inputNode.removeTap(onBus: 0)
    audioEngine.stop()
    isCapturing = false

    os_unfair_lock_lock(&bufferLock)
    let samples = audioBuffer
    audioBuffer.removeAll(keepingCapacity: true)
    os_unfair_lock_unlock(&bufferLock)

    audioLevel = 0.0
    Log.audio.info("Audio capture stopped. Collected \(samples.count) samples (\(Double(samples.count) / 16000.0, format: .fixed(precision: 1))s)")
    return samples
}
```

### Step 3: Handle Audio Engine Configuration Changes

Bluetooth headphones, external mics, and sleep/wake can cause `AVAudioEngine` configuration changes. Handle the notification:

```swift
private func observeConfigurationChanges() {
    NotificationCenter.default.addObserver(
        forName: .AVAudioEngineConfigurationChange,
        object: audioEngine,
        queue: nil
    ) { [weak self] _ in
        guard let self, self.isCapturing else { return }
        Log.audio.warning("Audio engine configuration changed, restarting")
        // Re-install tap and restart
        do {
            self.audioEngine.inputNode.removeTap(onBus: 0)
            try self.startCapture()
        } catch {
            Log.audio.error("Failed to restart after config change: \(error)")
            self.isCapturing = false
        }
    }
}
```

Call `observeConfigurationChanges()` from the initializer.

### Step 4: Guard Against Missing Input Devices

```swift
func startCapture() throws {
    guard !isCapturing else { return }

    // Guard: check that an input device exists before accessing inputNode
    // On some macOS versions, accessing inputNode with no device crashes
    guard !audioEngine.inputNode.inputFormat(forBus: 0).channelCount == 0 else {
        throw AudioCaptureError.noInputDevice
    }

    // ... rest of startCapture
}

enum AudioCaptureError: LocalizedError {
    case noInputDevice
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "No microphone found. Connect an audio input device."
        case .permissionDenied:
            return "Microphone access denied. Open System Settings to grant permission."
        }
    }
}
```

### Step 5: Input Device Enumeration (for Settings)

Provide a list of available input devices for the settings UI (PHASE-06):

```swift
import AVFoundation

extension AudioCaptureManager {
    struct InputDevice: Identifiable, Hashable {
        let id: String        // uniqueID
        let name: String      // localizedName
    }

    var availableInputDevices: [InputDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        return discoverySession.devices.map {
            InputDevice(id: $0.uniqueID, name: $0.localizedName)
        }
    }

    var defaultInputDevice: InputDevice? {
        guard let device = AVCaptureDevice.default(for: .audio) else { return nil }
        return InputDevice(id: device.uniqueID, name: device.localizedName)
    }
}
```

### Step 6: Update MenuBarView with Test Controls

Add temporary recording controls to `MenuBarView` for testing:

```swift
import SwiftUI

struct MenuBarView: View {
    @State private var audioCaptureManager = AudioCaptureManager()
    @State private var permissionStatus: MicrophonePermission = AudioPermissions.currentStatus
    @State private var lastSampleCount = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Squawk")
                .font(.headline)

            // Permission status
            permissionView

            // Audio level meter
            if audioCaptureManager.isCapturing {
                ProgressView(value: Double(audioCaptureManager.audioLevel), total: 0.5)
                    .progressViewStyle(.linear)
                Text("Recording...")
                    .foregroundStyle(.red)
            }

            // Test buttons
            if permissionStatus == .authorized {
                Button(audioCaptureManager.isCapturing ? "Stop" : "Record") {
                    toggleRecording()
                }
            }

            if lastSampleCount > 0 {
                Text("\(lastSampleCount) samples (\(String(format: "%.1f", Double(lastSampleCount) / 16000.0))s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 300)
        .task {
            if permissionStatus == .notDetermined {
                let granted = await AudioPermissions.requestAccess()
                permissionStatus = granted ? .authorized : .denied
            }
        }
    }

    @ViewBuilder
    private var permissionView: some View {
        switch permissionStatus {
        case .authorized:
            EmptyView()
        case .notDetermined:
            Text("Microphone permission needed")
                .foregroundStyle(.orange)
        case .denied:
            VStack {
                Text("Microphone access denied")
                    .foregroundStyle(.red)
                Button("Open System Settings") {
                    AudioPermissions.openSystemSettings()
                }
            }
        case .restricted:
            Text("Microphone access restricted by admin")
                .foregroundStyle(.red)
        }
    }

    private func toggleRecording() {
        if audioCaptureManager.isCapturing {
            let samples = audioCaptureManager.stopCapture()
            lastSampleCount = samples.count
        } else {
            do {
                try audioCaptureManager.startCapture()
            } catch {
                Log.audio.error("Failed to start capture: \(error)")
            }
        }
    }
}
```

### Step 7: Add Microphone Usage Description

In `Info.plist`, add the microphone usage description (required by macOS):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Squawk needs microphone access to transcribe your speech.</string>
```

## Key Dependencies

| Framework | Import | Usage |
|-----------|--------|-------|
| AVFoundation | `import AVFoundation` | `AVAudioEngine`, `AVCaptureDevice`, audio permissions |
| Accelerate | `import Accelerate` | `vDSP_rmsqv` for efficient RMS computation |
| Observation | `import Observation` | `@Observable` macro |
| os | `import os` | `os_unfair_lock`, `Logger` |
| AppKit | `import AppKit` | `NSWorkspace` for opening System Settings |

## Gotchas & Edge Cases

1. **`audioEngine.inputNode` crash** — On some macOS versions, accessing `audioEngine.inputNode` when no input device exists can crash. Always guard by checking `inputFormat.channelCount > 0` or wrapping in a do/catch.

2. **Tap buffer size is a suggestion** — When you request `bufferSize: 4096`, the system may deliver buffers of different sizes (commonly 512, 1024, or 4096). Always use `buffer.frameLength` for the actual count.

3. **Resampling** — `AVAudioEngine` handles resampling from the hardware sample rate (usually 48kHz) to our requested 16kHz automatically when you specify the desired format in `installTap`. You do NOT need to resample manually.

4. **Audio thread constraints** — The tap closure runs on a real-time audio thread. Do not:
   - Allocate memory (the `append(contentsOf:)` may allocate — acceptable for our use case but not ideal for pro audio)
   - Block on locks for long periods
   - Call any Objective-C runtime methods that might lock
   - Update `@Observable` properties directly (use `DispatchQueue.main.async`)

5. **`os_unfair_lock` must not be moved in memory** — In Swift, value types can be moved. Wrap the lock in a class or use `withUnsafeMutablePointer` if you encounter issues. Alternatively, use `NSLock` which is safer in Swift but slightly slower.

6. **Bluetooth headphones** — Connecting/disconnecting BT headphones triggers `AVAudioEngineConfigurationChange`. The engine's format changes and the tap becomes invalid. You must remove the old tap and reinstall it.

7. **Privacy prompt timing** — `AVCaptureDevice.requestAccess(for: .audio)` shows a system dialog. If the user ignores it (doesn't click Allow or Deny), the `await` hangs indefinitely. There is no timeout — the UI should indicate that permission is pending.

8. **macOS 14 Sonoma** — Apple added stricter audio permission prompts. The app MUST have `NSMicrophoneUsageDescription` in Info.plist or the permission dialog won't show and the request will silently fail.

## Acceptance Criteria

- [ ] Clicking "Record" in the popover starts microphone capture
- [ ] Audio level meter updates visibly while recording
- [ ] Clicking "Stop" stops capture and displays sample count
- [ ] Sample count matches expected duration (e.g., ~80,000 samples for 5 seconds at 16kHz)
- [ ] macOS microphone permission dialog appears on first recording attempt
- [ ] Denying permission shows an error with a "Open System Settings" button
- [ ] No crash when no input device is available
- [ ] Console.app shows log messages for start/stop with sample counts
- [ ] Connecting/disconnecting headphones during recording doesn't crash the app
- [ ] `xcodebuild` build succeeds with the new code

## Estimated Complexity

**M** — AVAudioEngine is well-documented but has edge cases around device changes and threading. Permission handling is straightforward but needs all four states covered.

## References

- **speak2** → `DictationController.swift`: Study how it manages audio capture lifecycle and integrates with the hotkey press/release cycle.
- **FluidVoice** → Check its audio capture implementation for any FluidAudio-specific format requirements.
- **Apple documentation** → [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine), [Requesting Microphone Access](https://developer.apple.com/documentation/avfoundation/capture_setup/requesting_authorization_to_capture_and_save_media).
