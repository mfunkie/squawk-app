import SwiftUI

@main
struct SquawkApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var dictationController: DictationController
    private let hotkeyManager: HotkeyManager

    init() {
        // Single-instance enforcement
        SingleInstanceGuard.terminateIfDuplicate()

        let controller = DictationController()
        let hotkey = HotkeyManager()
        hotkey.onToggle = { [weak controller] in
            Task { @MainActor in
                controller?.toggle()
            }
        }
        _dictationController = State(initialValue: controller)
        hotkeyManager = hotkey

        // Start services
        hotkey.start()
        controller.startOllamaPolling()

        // Load models in background
        Task {
            await controller.modelManager.loadModels()
            if controller.modelManager.isDownloaded {
                try? await controller.transcriptionEngine.initialize()
                await controller.transcriptionEngine.warmUp()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra("Squawk", systemImage: dictationController.menuBarIcon) {
            if hasCompletedSetup {
                MenuBarView()
                    .environment(dictationController)
                    .onAppear {
                        dictationController.observeSystemEvents()
                    }
            } else {
                FirstRunView()
                    .environment(dictationController)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
