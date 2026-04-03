import SwiftUI
import FluidAudio

@main
struct SquawkApp: App {
    var body: some Scene {
        MenuBarExtra("Squawk", systemImage: "mic") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
