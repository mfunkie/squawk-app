import SwiftUI
import os

struct MenuBarView: View {
    @State private var audioCaptureManager = AudioCaptureManager()
    @State private var permissionStatus: MicrophonePermission = AudioPermissions.currentStatus
    @State private var lastSampleCount = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Squawk")
                .font(.headline)

            // Permission status
            permissionView

            // Audio level meter
            if audioCaptureManager.isCapturing {
                ProgressView(value: Double(audioCaptureManager.audioLevel), total: 0.5)
                    .progressViewStyle(.linear)
                Text("Recording...")
                    .foregroundStyle(.red)
            }

            // Test buttons
            if permissionStatus == .authorized {
                Button(audioCaptureManager.isCapturing ? "Stop" : "Record") {
                    toggleRecording()
                }
            }

            if lastSampleCount > 0 {
                Text("\(lastSampleCount) samples (\(String(format: "%.1f", Double(lastSampleCount) / 16000.0))s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 300)
        .task {
            if permissionStatus == .notDetermined {
                let granted = await AudioPermissions.requestAccess()
                permissionStatus = granted ? .authorized : .denied
            }
        }
    }

    @ViewBuilder
    private var permissionView: some View {
        switch permissionStatus {
        case .authorized:
            EmptyView()
        case .notDetermined:
            Text("Microphone permission needed")
                .foregroundStyle(.orange)
        case .denied:
            VStack {
                Text("Microphone access denied")
                    .foregroundStyle(.red)
                Button("Open System Settings") {
                    AudioPermissions.openSystemSettings()
                }
            }
        case .restricted:
            Text("Microphone access restricted by admin")
                .foregroundStyle(.red)
        }
    }

    private func toggleRecording() {
        if audioCaptureManager.isCapturing {
            let samples = audioCaptureManager.stopCapture()
            lastSampleCount = samples.count
        } else {
            do {
                try audioCaptureManager.startCapture()
            } catch {
                Log.audio.error("Failed to start capture: \(error)")
            }
        }
    }
}
