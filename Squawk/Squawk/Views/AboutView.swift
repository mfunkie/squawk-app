import SwiftUI

struct AboutView: View {
    @Environment(DictationController.self) private var controller
    @AppStorage("recording.mode") private var recordingMode: String = "toggle"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Squawk")
                .font(.title2.bold())

            Text("v\(appVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Local speech-to-text for macOS")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 4) {
                AboutCreditRow(label: "ASR Engine", value: "FluidAudio + NVIDIA Parakeet")
                AboutCreditRow(label: "AI Polish", value: "Ollama (optional)")
                AboutCreditRow(label: "Runtime", value: "Apple Neural Engine")
            }
            .font(.caption)

            Button("Copy Debug Info", action: copyDebugInfo)
                .buttonStyle(.borderless)
                .font(.caption)

            Spacer()
        }
    }

    private func copyDebugInfo() {
        let info = DebugInfoBuilder.buildDebugInfo(
            appVersion: appVersion,
            buildNumber: buildNumber,
            asrModelLoaded: controller.modelManager.isDownloaded,
            ollamaAvailable: controller.ollamaAvailable,
            ollamaModel: controller.ollamaModel,
            recordingMode: recordingMode,
            autoPasteEnabled: controller.autoPasteEnabled,
            historyCount: controller.history.entries.count,
            lastError: controller.lastError
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }
}
