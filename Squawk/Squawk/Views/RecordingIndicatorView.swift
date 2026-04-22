import SwiftUI

struct RecordingIndicatorView: View {
    let hotkeyDescription: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .modifier(PulsingModifier())

            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .symbolEffect(.variableColor.iterative.reversing)

            VStack(alignment: .leading, spacing: 1) {
                Text("Listening")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                Text("\(hotkeyDescription) to send")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
        }
        .fixedSize()
    }
}
