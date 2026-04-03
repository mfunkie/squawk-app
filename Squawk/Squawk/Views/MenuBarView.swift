import SwiftUI
import os

struct MenuBarView: View {
    @Environment(DictationController.self) private var controller
    @State private var permissionStatus: MicrophonePermission = AudioPermissions.currentStatus

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Squawk")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(controller.ollamaAvailable ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text("Ollama")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Model status
            modelStatusView

            // Permission status
            permissionView

            // Audio level meter
            if controller.audioCaptureManager.isCapturing {
                ProgressView(value: Double(controller.audioCaptureManager.audioLevel), total: 0.5)
                    .progressViewStyle(.linear)
                Text("Recording...")
                    .foregroundStyle(.red)
            }

            // Transcription in progress
            if controller.transcriptionEngine.isTranscribing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // State: refining
            if controller.state == .refining {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Polishing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Error display
            if let error = controller.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Latency display
            if let latency = controller.lastLatencyMs {
                Text("Last: \(latency)ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Recent transcript
            if let latest = controller.history.entries.first {
                let displayText = latest.polishedText ?? latest.rawText
                Text(displayText)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
    private var modelStatusView: some View {
        let modelManager = controller.modelManager
        let transcriptionEngine = controller.transcriptionEngine!

        if modelManager.isLoading {
            VStack(spacing: 8) {
                ProgressView(value: modelManager.downloadProgress)
                Text("Downloading speech model...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("~300MB — this only happens once")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else if let error = modelManager.errorMessage {
            VStack(spacing: 8) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("Retry Download") {
                    Task { await modelManager.loadModels() }
                }
            }
        } else if transcriptionEngine.isReady {
            EmptyView()
        } else if modelManager.isDownloaded {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Optimizing model for your Mac...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
}
