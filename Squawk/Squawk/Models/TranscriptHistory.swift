import Foundation
import SwiftUI
import os

@Observable
final class TranscriptHistory {
    private(set) var entries: [TranscriptEntry] = []
    private let maxEntries = 200
    private let fileURL: URL

    /// Default initializer using Application Support directory.
    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let squawkDir = appSupport.appendingPathComponent("Squawk", isDirectory: true)
        try? FileManager.default.createDirectory(at: squawkDir, withIntermediateDirectories: true)
        self.init(directory: squawkDir)
    }

    /// Testable initializer with custom directory.
    init(directory: URL) {
        fileURL = directory.appendingPathComponent("history.json")
        loadFromDisk()
    }

    func add(_ entry: TranscriptEntry) {
        entries.insert(entry, at: 0) // newest first
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        saveToDisk()
    }

    func updateLatest(polishedText: String) {
        guard !entries.isEmpty else { return }
        entries[0].polishedText = polishedText
        saveToDisk()
    }

    func updateLatestLatency(_ ms: Int) {
        guard !entries.isEmpty else { return }
        entries[0].latencyMs = ms
        saveToDisk()
    }

    func remove(at indexSet: IndexSet) {
        entries.remove(atOffsets: indexSet)
        saveToDisk()
    }

    func clearAll() {
        entries.removeAll()
        saveToDisk()
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([TranscriptEntry].self, from: data)
            Log.pipeline.info("Loaded \(self.entries.count) transcript entries from disk")
        } catch {
            Log.pipeline.error("Failed to load history: \(error)")
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.pipeline.error("Failed to save history: \(error)")
        }
    }
}
