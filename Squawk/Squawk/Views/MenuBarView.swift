import SwiftUI
import os

struct MenuBarView: View {
    @Environment(ModelManager.self) private var modelManager
    @Environment(TranscriptionEngine.self) private var transcriptionEngine
    @Environment(AppState.self) private var appState
    @State private var audioCaptureManager = AudioCaptureManager()
    @State private var permissionStatus: MicrophonePermission = AudioPermissions.currentStatus
    @State private var lastSampleCount = 0
    @State private var lastTranscript = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Squawk")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.ollamaAvailable ? .green : .gray)
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
            if audioCaptureManager.isCapturing {
                ProgressView(value: Double(audioCaptureManager.audioLevel), total: 0.5)
                    .progressViewStyle(.linear)
                Text("Recording...")
                    .foregroundStyle(.red)
            }

            // Transcription in progress
            if transcriptionEngine.isTranscribing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Test buttons
            if permissionStatus == .authorized {
                Button(audioCaptureManager.isCapturing ? "Stop & Transcribe" : "Record") {
                    toggleRecording()
                }
                .disabled(!transcriptionEngine.isReady || transcriptionEngine.isTranscribing)
            }

            if lastSampleCount > 0 {
                Text("\(lastSampleCount) samples (\(String(format: "%.1f", Double(lastSampleCount) / 16000.0))s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Transcript display
            if !lastTranscript.isEmpty {
                Text(lastTranscript)
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

    private func toggleRecording() {
        if audioCaptureManager.isCapturing {
            stopAndTranscribe()
        } else {
            do {
                try audioCaptureManager.startCapture()
            } catch {
                Log.audio.error("Failed to start capture: \(error)")
            }
        }
    }

    private func stopAndTranscribe() {
        let samples = audioCaptureManager.stopCapture()
        lastSampleCount = samples.count
        guard !samples.isEmpty else { return }

        Task {
            do {
                let text = try await transcriptionEngine.transcribe(audioSamples: samples)
                lastTranscript = text
            } catch {
                Log.asr.error("Transcription failed: \(error)")
                lastTranscript = "Error: \(error.localizedDescription)"
            }
        }
    }
}
