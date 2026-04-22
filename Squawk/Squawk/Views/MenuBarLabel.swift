import SwiftUI

struct MenuBarLabel: View {
    let state: DictationState

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch state {
        case .idle: return "bird"
        case .recording: return "bird.fill"
        case .transcribing: return "ellipsis.circle"
        case .refining: return "sparkles"
        }
    }

    private var iconColor: Color {
        switch state {
        case .idle: return .primary
        case .recording: return .red
        case .transcribing: return .orange
        case .refining: return .purple
        }
    }
}
