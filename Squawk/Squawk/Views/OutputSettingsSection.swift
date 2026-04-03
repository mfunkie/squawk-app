import SwiftUI

struct OutputSettingsSection: View {
    @AppStorage("output.autoPaste") private var autoPaste: Bool = false
    @AppStorage("output.restoreClipboard") private var restoreClipboard: Bool = true
    @AppStorage("output.completionSound") private var completionSound: Bool = true

    var body: some View {
        Section("Output") {
            Toggle("Auto-paste into active app", isOn: $autoPaste)
            if autoPaste {
                Text("Simulates ⌘V after transcription. Some apps may require Accessibility permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Restore clipboard after paste", isOn: $restoreClipboard)
            }

            Toggle("Play sound on completion", isOn: $completionSound)
        }
    }
}
