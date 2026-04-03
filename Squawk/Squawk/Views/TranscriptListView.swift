import SwiftUI

struct TranscriptListView: View {
    @Environment(DictationController.self) private var controller
    @State private var copiedEntryId: UUID?
    @State private var showClearConfirmation = false

    var body: some View {
        if controller.history.entries.isEmpty {
            TranscriptEmptyState()
        } else {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Clear All", action: presentClearConfirmation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .confirmationDialog(
                            "Clear all transcripts?",
                            isPresented: $showClearConfirmation
                        ) {
                            Button("Clear All", role: .destructive, action: clearAll)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(controller.history.entries) { entry in
                            TranscriptRow(
                                entry: entry,
                                isCopied: copiedEntryId == entry.id
                            )
                            .onTapGesture {
                                copyEntry(entry)
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Double-tap to copy")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func presentClearConfirmation() {
        showClearConfirmation = true
    }

    private func clearAll() {
        controller.history.clearAll()
    }

    private func copyEntry(_ entry: TranscriptEntry) {
        let text = entry.polishedText ?? entry.rawText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copiedEntryId = entry.id
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedEntryId == entry.id {
                copiedEntryId = nil
            }
        }
    }
}
