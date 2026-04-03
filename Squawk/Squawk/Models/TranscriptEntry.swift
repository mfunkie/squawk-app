import Foundation

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    var rawText: String
    var polishedText: String?
    let timestamp: Date
    var audioDuration: TimeInterval
    var latencyMs: Int?
}
