import SwiftUI
import ServiceManagement
import os

struct GeneralSettingsSection: View {
    @AppStorage("general.launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        Section("General") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    updateLaunchAtLogin(launchAtLogin)
                }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.pipeline.error("Launch at login toggle failed: \(error)")
            launchAtLogin = !enabled
        }
    }
}
