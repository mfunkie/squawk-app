import SwiftUI

@main
struct SquawkApp: App {
    @State private var dictationController: DictationController
    private let hotkeyManager: HotkeyManager

    init() {
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
            MenuBarView()
                .environment(dictationController)
                .onAppear {
                    dictationController.observeSystemEvents()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
