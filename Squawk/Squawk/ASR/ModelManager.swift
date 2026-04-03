import FluidAudio
import Foundation
import Observation
import os

@Observable
final class ModelManager {
    // MARK: - Public state
    var isDownloaded = false
    var isLoading = false
    var downloadProgress: Double = 0.0
    var errorMessage: String?

    // MARK: - Internal
    private(set) var models: AsrModels?

    func loadModels(version: AsrModelVersion = .v2) async {
        guard models == nil else { return }
        isLoading = true
        errorMessage = nil

        do {
            let loadedModels = try await AsrModels.downloadAndLoad(
                version: version,
                progressHandler: { @Sendable [weak self] progress in
                    let fraction = progress.fractionCompleted
                    guard let manager = self else { return }
                    Task { @MainActor in
                        manager.downloadProgress = fraction
                    }
                }
            )
            models = loadedModels
            isDownloaded = true
            Log.asr.info("ASR models loaded successfully (version: \(String(describing: version)))")
        } catch {
            errorMessage = "Model download failed: \(error.localizedDescription)"
            Log.asr.error("Failed to load ASR models: \(error)")
        }

        isLoading = false
    }
}
