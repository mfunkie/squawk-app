import SwiftUI

struct StatusBar: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        HStack(spacing: 8) {
            StatusBarIcon(state: controller.state)
            StatusBarText(
                state: controller.state,
                lastError: controller.lastError
            )
            Spacer()

            if controller.state == .recording {
                AudioLevelBars(level: controller.audioCaptureManager.audioLevel)
            }

            if let latency = controller.lastLatencyMs, controller.state == .idle {
                Text("\(latency)ms")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.2), value: controller.state)
    }
}
