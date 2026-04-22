import SwiftUI

struct OutputSettingsSection: View {
    @AppStorage("output.autoPaste") private var autoPaste: Bool = false
    @AppStorage("output.restoreClipboard") private var restoreClipboard: Bool = true
    @AppStorage("output.completionSound") private var completionSound: Bool = true

    @State private var hasAccessibility = HotkeyManager.hasAccessibilityPermission
    @State private var showFixDetails = false

    var body: some View {
        Section("Output") {
            Toggle("Auto-paste into active app", isOn: $autoPaste)
            if autoPaste {
                Text("Simulates ⌘V after transcription. Requires Accessibility permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                accessibilityStatusRow

                Toggle("Restore clipboard after paste", isOn: $restoreClipboard)
            }

            Toggle("Play sound on completion", isOn: $completionSound)
        }
        .task(id: autoPaste) {
            // Poll TCC trust while this section is on screen — the System Settings toggle
            // can change out-of-process, and the toggle visually showing ON does not
            // guarantee AXIsProcessTrusted() returns true.
            while !Task.isCancelled {
                hasAccessibility = HotkeyManager.hasAccessibilityPermission
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @ViewBuilder
    private var accessibilityStatusRow: some View {
        if hasAccessibility {
            Label("Accessibility granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Accessibility not granted — auto-paste will silently fail", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)

                HStack(spacing: 8) {
                    Button("Open System Settings") {
                        HotkeyManager.openAccessibilitySettings()
                    }
                    Button(showFixDetails ? "Hide fix" : "Toggle ON but still failing?") {
                        showFixDetails.toggle()
                    }
                }
                .controlSize(.small)

                if showFixDetails {
                    Text("If Squawk already appears with the toggle ON, switch it OFF and back ON. macOS sometimes shows the toggle as enabled but doesn't actually trust the current build after an app update.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
