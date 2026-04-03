import SwiftUI

struct TranscriptEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("Press ⌘⇧Space to start transcribing")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
