import SwiftUI

@main
struct SquawkApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var dictationController: DictationController
    @State private var hasStartedServices = false
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
        controller.hotkeyManager = hotkey
        _dictationController = State(initialValue: controller)
        hotkeyManager = hotkey
    }

    var body: some Scene {
        MenuBarExtra("Squawk", systemImage: dictationController.menuBarIcon) {
            Group {
                if hasCompletedSetup {
                    MenuBarView()
                        .environment(dictationController)
                } else {
                    FirstRunView()
                        .environment(dictationController)
                }
            }
            .onAppear {
                startServicesIfNeeded()
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func startServicesIfNeeded() {
        guard !hasStartedServices else { return }
        hasStartedServices = true
        hotkeyManager.start()
        dictationController.observeSystemEvents()
        dictationController.startOllamaPolling()
        Task {
            await dictationController.modelManager.loadModels()
            if dictationController.modelManager.isDownloaded {
                try? await dictationController.transcriptionEngine.initialize()
                await dictationController.transcriptionEngine.warmUp()
            }
        }
    }
}
