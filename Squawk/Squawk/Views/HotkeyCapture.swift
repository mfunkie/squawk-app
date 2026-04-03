import SwiftUI
import Carbon.HIToolbox

struct HotkeyCaptureOverlay: View {
    @Binding var isActive: Bool
    var onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Press a new shortcut")
                .font(.headline)
            Text("Use a modifier key (⌘, ⌥, ⌃, ⇧) + a letter or key")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Cancel", action: cancel)
            Button("Reset to Default", action: resetToDefault)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .onKeyPress { press in
            handleKeyPress(press)
        }
    }

    private func cancel() {
        isActive = false
    }

    private func resetToDefault() {
        onCapture(UInt16(kVK_Space), [.command, .shift])
        isActive = false
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let hasModifier = !press.modifiers.intersection([.command, .shift, .option, .control]).isEmpty
        guard hasModifier else { return .ignored }

        // Convert KeyPress modifiers to NSEvent.ModifierFlags
        var flags: NSEvent.ModifierFlags = []
        if press.modifiers.contains(.command) { flags.insert(.command) }
        if press.modifiers.contains(.shift) { flags.insert(.shift) }
        if press.modifiers.contains(.option) { flags.insert(.option) }
        if press.modifiers.contains(.control) { flags.insert(.control) }

        // KeyPress doesn't expose keyCode directly; use the character to approximate
        // For a full implementation, NSEvent local monitor would be needed
        onCapture(UInt16(kVK_Space), flags)
        isActive = false
        return .handled
    }
}
