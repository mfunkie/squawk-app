import SwiftUI
import FluidAudio

@main
struct SquawkApp: App {
    @State private var modelManager = ModelManager()
    @State private var transcriptionEngine: TranscriptionEngine
    @State private var appState = AppState()
    @State private var dictationController = DictationController()
    private let hotkeyManager = HotkeyManager()

    init() {
        let mm = ModelManager()
        _modelManager = State(initialValue: mm)
        _transcriptionEngine = State(initialValue: TranscriptionEngine(modelManager: mm))
    }

    var body: some Scene {
        MenuBarExtra("Squawk", systemImage: dictationController.menuBarIcon) {
            MenuBarView()
                .environment(modelManager)
                .environment(transcriptionEngine)
                .environment(appState)
                .environment(dictationController)
                .task {
                    await modelManager.loadModels()
                    if modelManager.isDownloaded {
                        try? await transcriptionEngine.initialize()
                        await transcriptionEngine.warmUp()
                    }
                }
                .task {
                    appState.startOllamaPolling()
                }
                .onAppear {
                    hotkeyManager.onToggle = { [dictationController] in
                        dictationController.toggle()
                    }
                    hotkeyManager.start()
                    dictationController.observeSystemEvents()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
