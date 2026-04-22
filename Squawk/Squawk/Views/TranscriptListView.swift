import SwiftUI

struct TranscriptListView: View {
    @Environment(DictationController.self) private var controller
    @State private var copiedEntryId: UUID?
    @State private var showClearConfirmation = false

    var body: some View {
        if controller.history.entries.isEmpty {
            TranscriptEmptyState()
        } else {
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Clear All", action: presentClearConfirmation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

                if showClearConfirmation {
                    ClearAllConfirmation(
                        onCancel: dismissClearConfirmation,
                        onConfirm: confirmClearAll
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: showClearConfirmation)
        }
    }

    private func presentClearConfirmation() {
        showClearConfirmation = true
    }

    private func dismissClearConfirmation() {
        showClearConfirmation = false
    }

    private func confirmClearAll() {
        controller.history.clearAll()
        showClearConfirmation = false
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

private struct ClearAllConfirmation: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 16) {
                Text("Clear all transcripts?")
                    .font(.headline)

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)

                    Button(role: .destructive, action: onConfirm) {
                        Text("Clear All")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            }
            .padding(20)
            .frame(maxWidth: 260)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(radius: 18, y: 6)
            .padding(24)
        }
    }
}
