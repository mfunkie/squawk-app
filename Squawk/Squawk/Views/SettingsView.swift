import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case recording = "Recording"
    case transcription = "Transcription"
    case refinement = "Refinement"
    case output = "Output"
    case general = "General"
    case about = "About"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .recording: "mic"
        case .transcription: "waveform"
        case .refinement: "sparkles"
        case .output: "square.and.arrow.up"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

struct SettingsWindowView: View {
    @Environment(DictationController.self) private var controller
    @State private var selection: SettingsSection = .recording
    @State private var isCapturingHotkey = false

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .navigationTitle("Settings")
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(selection.rawValue)
        }
        .frame(minWidth: 680, minHeight: 460)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .recording:
            Form { RecordingSettingsSection(isCapturingHotkey: $isCapturingHotkey) }
                .formStyle(.grouped)
                .overlay {
                    if isCapturingHotkey {
                        HotkeyCaptureOverlay(isActive: $isCapturingHotkey, onCapture: captureHotkey)
                    }
                }
        case .transcription:
            Form { TranscriptionSettingsSection() }.formStyle(.grouped)
        case .refinement:
            Form { RefinementSettingsSection() }.formStyle(.grouped)
        case .output:
            Form { OutputSettingsSection() }.formStyle(.grouped)
        case .general:
            Form { GeneralSettingsSection() }.formStyle(.grouped)
        case .about:
            AboutView()
        }
    }

    private func captureHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        guard let hotkey = controller.hotkeyManager else { return }
        hotkey.stop()
        hotkey.keyCode = keyCode
        hotkey.modifierFlags = modifiers
        hotkey.start()
    }
}
