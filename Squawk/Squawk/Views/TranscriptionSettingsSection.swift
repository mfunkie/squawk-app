import SwiftUI

struct TranscriptionSettingsSection: View {
    @Environment(DictationController.self) private var controller
    @AppStorage("asr.modelVersion") private var modelVersion: String = "v2"

    var body: some View {
        Section("Transcription") {
            modelPicker
            modelStatusRow
            downloadButton
        }
    }

    private var modelPicker: some View {
        Picker("Model", selection: $modelVersion) {
            Text("English (Parakeet v2)").tag("v2")
            Text("Multilingual — 25 languages (Parakeet v3)").tag("v3")
        }
    }

    private var modelStatusRow: some View {
        HStack {
            Text("Model status")
            Spacer()
            if controller.modelManager.isDownloaded {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else if controller.modelManager.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Downloading...")
                    .font(.caption)
            } else {
                Label("Not loaded", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        if !controller.modelManager.isDownloaded && !controller.modelManager.isLoading {
            Button("Download Model", action: downloadModel)
        }
    }

    private func downloadModel() {
        Task { await controller.modelManager.loadModels() }
    }
}
