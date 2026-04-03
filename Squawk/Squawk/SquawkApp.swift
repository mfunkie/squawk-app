import SwiftUI
import FluidAudio

@main
struct SquawkApp: App {
    @State private var modelManager = ModelManager()
    @State private var transcriptionEngine: TranscriptionEngine

    init() {
        let mm = ModelManager()
        _modelManager = State(initialValue: mm)
        _transcriptionEngine = State(initialValue: TranscriptionEngine(modelManager: mm))
    }

    var body: some Scene {
        MenuBarExtra("Squawk", systemImage: "mic") {
            MenuBarView()
                .environment(modelManager)
                .environment(transcriptionEngine)
                .task {
                    await modelManager.loadModels()
                    if modelManager.isDownloaded {
                        try? await transcriptionEngine.initialize()
                        await transcriptionEngine.warmUp()
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}
