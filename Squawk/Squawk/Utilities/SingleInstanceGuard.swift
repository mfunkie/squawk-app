import AppKit

enum SingleInstanceGuard {
    /// Returns `true` if another instance of this app is already running.
    static var isAnotherInstanceRunning: Bool {
        let bundleID = Bundle.main.bundleIdentifier
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID
        }
        return runningApps.count > 1
    }

    /// If another instance is running, activate it and terminate this one.
    static func terminateIfDuplicate() {
        guard isAnotherInstanceRunning else { return }
        let bundleID = Bundle.main.bundleIdentifier
        if let existing = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID && $0 != NSRunningApplication.current
        }) {
            existing.activate()
        }
        NSApplication.shared.terminate(nil)
    }
}
