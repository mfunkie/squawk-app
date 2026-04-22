import SwiftUI

struct RecordingIndicatorView: View {
    let audioManager: AudioCaptureManager
    let hotkeyDescription: String

    private static let calculator = AudioLevelCalculator(barCount: 5)

    var body: some View {
        let level = Self.calculator.normalizedLevel(for: audioManager.audioLevel)

        HStack(spacing: 10) {
            AudioWaveMeter(level: level)

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
