import SwiftUI

struct TranscriptEmptyState: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("Press \(controller.hotkeyManager?.hotkeyDescription ?? "\u{2318}\u{21E7}Space") to start transcribing")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
