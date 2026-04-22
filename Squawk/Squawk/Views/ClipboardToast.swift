import AppKit
import SwiftUI

/// Transient pill that briefly says "Copied to clipboard" when auto-paste was skipped
/// (e.g. Accessibility trust isn't actually granted to the running binary).
@MainActor
enum ClipboardToast {
    private static var panel: NSPanel?
    private static var dismissTask: Task<Void, Never>?

    static func show(_ message: String, duration: TimeInterval = 2.0) {
        let view = ClipboardToastView(message: message)
        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        let size = hostingView.fittingSize

        let panel = self.panel ?? makePanel(size: size)
        self.panel = panel
        panel.contentView = hostingView
        panel.setContentSize(size)
        positionAtBottomCenter(panel)
        panel.orderFrontRegardless()

        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    private static func makePanel(size: CGSize) -> NSPanel {
        let panel = NonActivatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        return panel
    }

    private static func positionAtBottomCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - panel.frame.width / 2
        // Sit a bit above where the recording pill defaults to so they don't overlap if both fire.
        let y = frame.minY + 140
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct ClipboardToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
        }
        .fixedSize()
    }
}
