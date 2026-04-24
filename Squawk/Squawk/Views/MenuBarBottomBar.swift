import SwiftUI
import AppKit

struct MenuBarBottomBar: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {
            Button(action: openSettingsWindow) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .keyboardShortcut(",")

            Spacer()

            Button("Quit", action: quit)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func openSettingsWindow() {
        // Dismiss the MenuBarExtra popover (it is the key window when this
        // button is clicked). Ordering it out before presenting Settings
        // avoids leaving the popover floating alongside the new window.
        NSApp.keyWindow?.orderOut(nil)
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

struct SettingsMenuItem: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings\u{2026}") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
    }
}
