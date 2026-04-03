import SwiftUI

struct StatusBarText: View {
    let state: DictationState
    let lastError: String?

    var body: some View {
        switch state {
        case .idle:
            if let error = lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                Text("Ready — ⌘⇧Space to record")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .recording:
            Text("Recording...")
                .font(.caption)
                .foregroundStyle(.red)
        case .transcribing:
            Text("Transcribing...")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .refining:
            Text("Polishing with AI...")
                .font(.caption)
                .foregroundStyle(.purple)
        }
    }
}
