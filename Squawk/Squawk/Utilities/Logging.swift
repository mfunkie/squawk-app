import os

enum Log {
    static let audio = Logger(subsystem: "com.squawk.Squawk", category: "audio")
    static let asr = Logger(subsystem: "com.squawk.Squawk", category: "asr")
    static let ollama = Logger(subsystem: "com.squawk.Squawk", category: "ollama")
    static let pipeline = Logger(subsystem: "com.squawk.Squawk", category: "pipeline")
}
