import XCTest
@testable import Squawk

final class TranscriptHistoryTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeHistory() -> TranscriptHistory {
        TranscriptHistory(directory: tempDir)
    }

    private func makeEntry(rawText: String = "hello world") -> TranscriptEntry {
        TranscriptEntry(
            id: UUID(),
            rawText: rawText,
            polishedText: nil,
            timestamp: Date(),
            audioDuration: 2.0,
            latencyMs: nil
        )
    }

    // MARK: - Add

    func testAddInsertsAtFront() {
        let history = makeHistory()
        let entry1 = makeEntry(rawText: "first")
        let entry2 = makeEntry(rawText: "second")

        history.add(entry1)
        history.add(entry2)

        XCTAssertEqual(history.entries.count, 2)
        XCTAssertEqual(history.entries[0].rawText, "second")
        XCTAssertEqual(history.entries[1].rawText, "first")
    }

    // MARK: - Update Latest

    func testUpdateLatestSetsPolishedText() {
        let history = makeHistory()
        history.add(makeEntry(rawText: "raw"))

        history.updateLatest(polishedText: "polished")

        XCTAssertEqual(history.entries[0].polishedText, "polished")
    }

    func testUpdateLatestOnEmptyHistoryDoesNothing() {
        let history = makeHistory()
        // Should not crash
        history.updateLatest(polishedText: "polished")
        XCTAssertTrue(history.entries.isEmpty)
    }

    // MARK: - Remove

    func testRemoveAtIndexSet() {
        let history = makeHistory()
        history.add(makeEntry(rawText: "a"))
        history.add(makeEntry(rawText: "b"))
        history.add(makeEntry(rawText: "c"))

        // entries are [c, b, a] — remove index 1 (b)
        history.remove(at: IndexSet(integer: 1))

        XCTAssertEqual(history.entries.count, 2)
        XCTAssertEqual(history.entries[0].rawText, "c")
        XCTAssertEqual(history.entries[1].rawText, "a")
    }

    // MARK: - Clear All

    func testClearAllRemovesEverything() {
        let history = makeHistory()
        history.add(makeEntry())
        history.add(makeEntry())

        history.clearAll()

        XCTAssertTrue(history.entries.isEmpty)
    }

    // MARK: - Max Entries Cap

    func testMaxEntriesCapsAt200() {
        let history = makeHistory()

        for i in 0..<210 {
            history.add(makeEntry(rawText: "entry \(i)"))
        }

        XCTAssertEqual(history.entries.count, 200)
        // Most recent should be first
        XCTAssertEqual(history.entries[0].rawText, "entry 209")
    }

    // MARK: - Persistence

    func testPersistsToDiskAndLoadsBack() {
        let history = makeHistory()
        history.add(makeEntry(rawText: "persisted"))
        history.updateLatest(polishedText: "polished persisted")

        // Create a new instance pointing at the same directory
        let history2 = makeHistory()

        XCTAssertEqual(history2.entries.count, 1)
        XCTAssertEqual(history2.entries[0].rawText, "persisted")
        XCTAssertEqual(history2.entries[0].polishedText, "polished persisted")
    }

    func testClearAllPersistsEmptyState() {
        let history = makeHistory()
        history.add(makeEntry())
        history.clearAll()

        let history2 = makeHistory()
        XCTAssertTrue(history2.entries.isEmpty)
    }
}
