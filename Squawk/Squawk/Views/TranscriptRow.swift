import SwiftUI

struct TranscriptRow: View {
    let entry: TranscriptEntry
    let isCopied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if entry.polishedText != nil {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                        .accessibilityLabel("AI polished")
                }

                Spacer()

                if isCopied {
                    Text("Copied!")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                if let latency = entry.latencyMs {
                    Text("\(latency)ms")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .monospacedDigit()
                }
            }

            Text(entry.polishedText ?? entry.rawText)
                .font(.callout)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(8)
        .background(isCopied ? Color.green.opacity(0.1) : Color.clear)
        .clipShape(.rect(cornerRadius: 6))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: isCopied)
    }
}
