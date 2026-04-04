import SwiftUI
import Carbon.HIToolbox

struct HotkeyCaptureOverlay: View {
    @Binding var isActive: Bool
    var onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    @State private var monitor: Any?

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Press a new shortcut")
                    .font(.headline)
                Text("Use a modifier key (\u{2318}, \u{2325}, \u{2303}, \u{21E7}) + a letter or key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Cancel") {
                    stopMonitoring()
                    isActive = false
                }
                Button("Reset to Default") {
                    stopMonitoring()
                    onCapture(UInt16(kVK_Space), [.command, .shift])
                    isActive = false
                }
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 12))
        }
        .onAppear { startMonitoring() }
        .onDisappear { stopMonitoring() }
    }

    private func startMonitoring() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressed = event.modifierFlags.intersection(relevantModifiers)
            guard !pressed.isEmpty else { return event }

            stopMonitoring()
            onCapture(event.keyCode, pressed)
            isActive = false
            return nil // consume the event
        }
    }

    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
