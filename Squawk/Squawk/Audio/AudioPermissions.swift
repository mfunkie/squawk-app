import AVFoundation
import AppKit

enum MicrophonePermission {
    case authorized
    case notDetermined
    case denied
    case restricted
}

enum AudioPermissions {
    /// Check current authorization status without prompting.
    static var currentStatus: MicrophonePermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    /// Request microphone access. Returns true if authorized.
    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    /// Open System Settings to the Microphone privacy pane.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
