import AppKit
import ApplicationServices
import os

struct TextInjector {

    enum PasteResult: Equatable {
        case pasted
        case skippedNoAccessibility
    }

    /// Live Accessibility-trust check. Overridable in tests.
    var isAccessibilityTrusted: () -> Bool = { AXIsProcessTrusted() }

    /// Copy text to clipboard only.
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Log.pipeline.info("Text copied to clipboard (\(text.count) chars)")
    }

    /// Copy text and simulate Cmd+V paste into the active app, then restore original clipboard.
    /// Returns `.skippedNoAccessibility` (with the text left on the clipboard for manual ⌘V) when
    /// the OS doesn't trust this process — TCC's per-binary trust can lapse silently after an
    /// app upgrade even while the System Settings toggle still appears ON.
    func pasteIntoActiveApp(_ text: String) async -> PasteResult {
        let pasteboard = NSPasteboard.general

        guard isAccessibilityTrusted() else {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            Log.pipeline.warning("Auto-paste skipped: AXIsProcessTrusted() returned false. Text left on clipboard for manual ⌘V — toggle Squawk OFF then ON in System Settings → Privacy & Security → Accessibility.")
            return .skippedNoAccessibility
        }

        let savedContents = saveClipboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        try? await Task.sleep(for: .milliseconds(50))

        simulatePaste()

        try? await Task.sleep(for: .milliseconds(200))
        restoreClipboard(pasteboard, from: savedContents)

        Log.pipeline.info("Text pasted into active app and clipboard restored")
        return .pasted
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
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            Log.pipeline.error("simulatePaste: failed to create keyDown CGEvent")
            return
        }
        keyDown.flags = .maskCommand

        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            Log.pipeline.error("simulatePaste: failed to create keyUp CGEvent")
            return
        }
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
