import SwiftUI

struct SettingsView: View {
    @Environment(DictationController.self) private var controller
    @State private var isCapturingHotkey = false

    var body: some View {
        ScrollView {
            Form {
                RecordingSettingsSection(isCapturingHotkey: $isCapturingHotkey)
                TranscriptionSettingsSection()
                RefinementSettingsSection()
                OutputSettingsSection()
                GeneralSettingsSection()
            }
            .formStyle(.grouped)
            .padding(.horizontal, 4)
        }
        .overlay {
            if isCapturingHotkey {
                HotkeyCaptureOverlay(isActive: $isCapturingHotkey) { _, _ in
                    // Hotkey change will be implemented when HotkeyManager supports dynamic updates
                }
            }
        }
    }
}
