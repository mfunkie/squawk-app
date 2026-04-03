import SwiftUI

struct RecordingSettingsSection: View {
    @Environment(DictationController.self) private var controller
    @Binding var isCapturingHotkey: Bool

    @AppStorage("recording.mode") private var recordingMode: String = "toggle"
    @AppStorage("recording.maxDuration") private var maxDuration: Int = 300

    var body: some View {
        Section("Recording") {
            hotkeyRow
            modePicker
            accessibilityWarning
            maxDurationStepper
        }
    }

    private var hotkeyRow: some View {
        HStack {
            Text("Hotkey")
            Spacer()
            Text("⌘⇧Space")
                .foregroundStyle(.secondary)
            Button("Change", action: startCapture)
                .buttonStyle(.borderless)
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $recordingMode) {
            Text("Toggle (press to start/stop)").tag("toggle")
            Text("Push-to-talk (hold to record)").tag("pushToTalk")
        }
    }

    @ViewBuilder
    private var accessibilityWarning: some View {
        if recordingMode == "pushToTalk" && !HotkeyManager.hasAccessibilityPermission {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Push-to-talk requires Accessibility permission")
                    .font(.caption)
                Button("Grant", action: grantAccessibility)
                    .buttonStyle(.borderless)
            }
        }
    }

    private var maxDurationStepper: some View {
        Stepper(
            "Max duration: \(maxDuration / 60) min",
            value: $maxDuration,
            in: 60...600,
            step: 60
        )
    }

    private func startCapture() {
        isCapturingHotkey = true
    }

    private func grantAccessibility() {
        HotkeyManager.openAccessibilitySettings()
    }
}
