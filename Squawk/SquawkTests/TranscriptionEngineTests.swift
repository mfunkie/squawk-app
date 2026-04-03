import Foundation
import Testing
@testable import Squawk

struct TranscriptionErrorTests {

    @Test func modelsNotLoadedDescription() {
        let error = TranscriptionEngine.TranscriptionError.modelsNotLoaded
        #expect(error.errorDescription == "ASR models are not loaded")
    }

    @Test func notInitializedDescription() {
        let error = TranscriptionEngine.TranscriptionError.notInitialized
        #expect(error.errorDescription == "Transcription engine not initialized")
    }

    @Test func emptyAudioDescription() {
        let error = TranscriptionEngine.TranscriptionError.emptyAudio
        #expect(error.errorDescription == "No audio to transcribe")
    }
}

struct ModelManagerTests {

    @MainActor
    @Test func initialState() {
        let manager = ModelManager()
        #expect(manager.isDownloaded == false)
        #expect(manager.isLoading == false)
        #expect(manager.downloadProgress == 0.0)
        #expect(manager.errorMessage == nil)
        #expect(manager.models == nil)
    }
}

struct TranscriptionEngineStateTests {

    @MainActor
    @Test func initialState() {
        let modelManager = ModelManager()
        let engine = TranscriptionEngine(modelManager: modelManager)
        #expect(engine.isReady == false)
        #expect(engine.isTranscribing == false)
    }

    @MainActor
    @Test func transcribeThrowsWhenNotInitialized() async {
        let modelManager = ModelManager()
        let engine = TranscriptionEngine(modelManager: modelManager)
        do {
            _ = try await engine.transcribe(audioSamples: [0.0, 0.1, 0.2])
            Issue.record("Expected TranscriptionError.notInitialized")
        } catch let error as TranscriptionEngine.TranscriptionError {
            #expect(error == .notInitialized)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @MainActor
    @Test func transcribeThrowsOnEmptyAudio() async throws {
        // Can't fully initialize without real models, but test empty audio guard
        // by verifying it throws notInitialized (since engine isn't set up)
        let modelManager = ModelManager()
        let engine = TranscriptionEngine(modelManager: modelManager)
        do {
            _ = try await engine.transcribe(audioSamples: [])
            Issue.record("Expected error")
        } catch let error as TranscriptionEngine.TranscriptionError {
            // Empty audio check happens before notInitialized check,
            // so we should get emptyAudio
            #expect(error == .emptyAudio)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
