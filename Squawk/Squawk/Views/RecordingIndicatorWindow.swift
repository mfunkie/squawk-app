import AppKit
import Observation
import SwiftUI

/// A borderless, non-activating panel that never steals focus from the frontmost app.
final class RecordingIndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Manages the floating pill-shaped recording indicator window.
///
/// Observes `DictationController.state` via `withObservationTracking` so the panel
/// shows/hides without relying on any particular SwiftUI view being mounted (the
/// MenuBarExtra content is lazy and may be torn down between popover opens).
@Observable
@MainActor
final class RecordingIndicatorController {
    private var panel: RecordingIndicatorPanel?
    private weak var observedController: DictationController?

    private enum Keys {
        static let x = "recordingIndicator.x"
        static let y = "recordingIndicator.y"
        static let hasPosition = "recordingIndicator.hasPosition"
    }

    func start(observing controller: DictationController) {
        observedController = controller
        observeState()
        handle(state: controller.state)
    }

    // MARK: - Observation

    private func observeState() {
        guard let controller = observedController else { return }
        withObservationTracking {
            _ = controller.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let c = self.observedController else { return }
                self.handle(state: c.state)
                self.observeState()
            }
        }
    }

    private func handle(state: DictationState) {
        switch state {
        case .recording:
            show()
        case .idle, .transcribing, .refining:
            hide()
        }
    }

    // MARK: - Show / Hide

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        positionIfNeeded(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Panel construction

    private func makePanel() -> RecordingIndicatorPanel {
        let hostingView = NSHostingView(rootView: RecordingIndicatorView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let size = hostingView.fittingSize
        let panel = RecordingIndicatorPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView

        // Let the hosting view drive the panel size.
        panel.setContentSize(size)
        return panel
    }

    // MARK: - Positioning

    private func positionIfNeeded(_ panel: NSPanel) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Keys.hasPosition) {
            let x = defaults.double(forKey: Keys.x)
            let y = defaults.double(forKey: Keys.y)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            observeFrameChanges(panel)
            return
        }

        // Default: bottom-center of the main screen, 80pt from the bottom edge.
        guard let screen = NSScreen.main else {
            observeFrameChanges(panel)
            return
        }
        let frame = screen.visibleFrame
        let x = frame.midX - panel.frame.width / 2
        let y = frame.minY + 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        observeFrameChanges(panel)
    }

    private var frameObserver: NSObjectProtocol?

    private func observeFrameChanges(_ panel: NSPanel) {
        guard frameObserver == nil else { return }
        // Controller lives for the app lifetime, so no explicit teardown is needed;
        // the weak panel capture prevents a retain cycle.
        frameObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak panel] _ in
            guard let panel else { return }
            let origin = panel.frame.origin
            let defaults = UserDefaults.standard
            defaults.set(origin.x, forKey: Keys.x)
            defaults.set(origin.y, forKey: Keys.y)
            defaults.set(true, forKey: Keys.hasPosition)
        }
    }
}
