import SwiftUI

struct RecordingSettingsSection: View {
    @Environment(DictationController.self) private var controller
    @Binding var isCapturingHotkey: Bool

    @AppStorage("recording.maxDuration") private var maxDuration: Int = 300

    var body: some View {
        Section("Recording") {
            hotkeyRow
            maxDurationStepper
        }
    }

    private var hotkeyRow: some View {
        HStack {
            Text("Hotkey")
            Spacer()
            Text(controller.hotkeyManager?.hotkeyDescription ?? "\u{2318}\u{21E7}Space")
                .foregroundStyle(.secondary)
            Button("Change", action: startCapture)
                .buttonStyle(.borderless)
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
}
