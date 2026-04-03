import AppKit
import os

struct TextInjector {

    /// Copy text to clipboard only.
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Log.pipeline.info("Text copied to clipboard (\(text.count) chars)")
    }

    /// Copy text and simulate Cmd+V paste into the active app, then restore original clipboard.
    func pasteIntoActiveApp(_ text: String) async {
        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard contents
        let savedContents = saveClipboard(pasteboard)

        // 2. Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Small delay to ensure clipboard is updated
        try? await Task.sleep(for: .milliseconds(50))

        // 4. Simulate Cmd+V
        simulatePaste()

        // 5. Restore original clipboard after paste completes
        try? await Task.sleep(for: .milliseconds(200))
        restoreClipboard(pasteboard, from: savedContents)

        Log.pipeline.info("Text pasted into active app and clipboard restored")
    }

    // MARK: - Clipboard Save/Restore

    private struct ClipboardContents {
        let data: [[(NSPasteboard.PasteboardType, Data)]]
    }

    private func saveClipboard(_ pasteboard: NSPasteboard) -> ClipboardContents? {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }

        var allData: [[(NSPasteboard.PasteboardType, Data)]] = []
        for item in items {
            var itemData: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData.append((type, data))
                }
            }
            allData.append(itemData)
        }

        return ClipboardContents(data: allData)
    }

    private func restoreClipboard(_ pasteboard: NSPasteboard, from saved: ClipboardContents?) {
        guard let saved else { return }
        pasteboard.clearContents()

        for itemData in saved.data {
            let newItem = NSPasteboardItem()
            for (type, data) in itemData {
                newItem.setData(data, forType: type)
            }
            pasteboard.writeObjects([newItem])
        }
    }

    // MARK: - Simulate Paste

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: V (keyCode 9) with Cmd modifier
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else { return }
        keyDown.flags = .maskCommand

        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else { return }
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
