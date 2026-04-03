import SwiftUI

struct StatusIndicator: View {
    var state: DictationState

    private var systemImage: String {
        switch state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "ellipsis.circle"
        case .refining: return "sparkles"
        }
    }

    var body: some View {
        Image(systemName: systemImage)
    }
}
