import FluidAudio
import Foundation
import Observation
import os

@Observable
final class TranscriptionEngine {
    // MARK: - Public state
    var isReady = false
    var isTranscribing = false

    // MARK: - Private
    private var asrManager: AsrManager?
    private let modelManager: ModelManager

    init(modelManager: ModelManager) {
        self.modelManager = modelManager
    }

    func initialize() async throws {
        guard asrManager == nil else { return }

        if modelManager.models == nil {
            await modelManager.loadModels()
        }

        guard let models = modelManager.models else {
            throw TranscriptionError.modelsNotLoaded
        }

        let manager = AsrManager()
        try await manager.loadModels(models)
        asrManager = manager
        isReady = true
        Log.asr.info("TranscriptionEngine initialized")
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard !audioSamples.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        guard let asrManager else {
            throw TranscriptionError.notInitialized
        }

        isTranscribing = true
        defer { isTranscribing = false }

        let startTime = ContinuousClock.now

        let result = try await asrManager.transcribe(audioSamples)

        let elapsed = ContinuousClock.now - startTime
        let audioDuration = Double(audioSamples.count) / 16000.0

        Log.asr.info("""
            Transcription complete: \
            audio=\(String(format: "%.1f", audioDuration))s, \
            inference=\(elapsed), \
            RTFx=\(String(format: "%.1f", result.rtfx))x
            """)

        return result.text
    }

    func warmUp() async {
        guard isReady else { return }
        Log.asr.info("Warming up ASR model (first run may take 30-60s)...")

        let silentSamples = [Float](repeating: 0.0, count: 16000)
        _ = try? await transcribe(audioSamples: silentSamples)

        Log.asr.info("ASR model warm-up complete")
    }

    enum TranscriptionError: LocalizedError, Equatable {
        case modelsNotLoaded
        case notInitialized
        case emptyAudio

        var errorDescription: String? {
            switch self {
            case .modelsNotLoaded: return "ASR models are not loaded"
            case .notInitialized: return "Transcription engine not initialized"
            case .emptyAudio: return "No audio to transcribe"
            }
        }
    }
}
