import SwiftUI

struct StatusBarIcon: View {
    let state: DictationState

    var body: some View {
        switch state {
        case .idle:
            Image(systemName: "mic")
                .foregroundStyle(.secondary)
        case .recording:
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .modifier(PulsingModifier())
        case .transcribing:
            ProgressView()
                .controlSize(.small)
        case .refining:
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .symbolEffect(.pulse)
        }
    }
}
