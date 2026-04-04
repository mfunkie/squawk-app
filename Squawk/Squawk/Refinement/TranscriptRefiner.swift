import Foundation
import os

struct TranscriptRefiner {
    private let client: OllamaClient
    private let defaultModel = ""

    private static let defaultSystemPrompt = """
        You are a transcript cleaner. Your ONLY job is to clean up speech-to-text output.

        Rules:
        - Fix obvious mistranscriptions and misspellings
        - Add proper punctuation and capitalization
        - Remove filler words (um, uh, like, you know, so, basically)
        - Remove false starts and repeated words
        - Preserve the speaker's original meaning exactly
        - Do NOT add any information not in the original
        - Do NOT add commentary, explanations, or markdown formatting
        - Return ONLY the cleaned text, nothing else
        """

    init(client: OllamaClient = OllamaClient()) {
        self.client = client
    }

    func refine(
        rawTranscript: String,
        model: String? = nil,
        systemPrompt: String? = nil
    ) async throws -> String {
        let modelName = model ?? defaultModel
        let prompt = systemPrompt ?? Self.defaultSystemPrompt

        let response = try await client.generate(
            model: modelName,
            prompt: rawTranscript,
            system: prompt,
            temperature: 0.3,
            maxTokens: rawTranscript.count * 2
        )

        let cleaned = response.response.trimmingCharacters(in: .whitespacesAndNewlines)

        let duration = response.total_duration.map { Double($0) / 1_000_000_000 } ?? 0
        Log.ollama.info("Refinement complete: \(String(format: "%.1f", duration))s, \(response.eval_count ?? 0) tokens")

        return validated(cleaned: cleaned, original: rawTranscript)
    }

    func validated(cleaned: String, original: String) -> String {
        // Empty response → keep original
        if cleaned.isEmpty {
            Log.ollama.warning("Refinement returned empty — keeping original")
            return original
        }

        // Response much longer than original → likely hallucination
        if cleaned.count > original.count * 3 / 2 {
            Log.ollama.warning("Refinement too long (\(cleaned.count) vs \(original.count)) — keeping original")
            return original
        }

        // Response much shorter → likely truncation
        if cleaned.count < original.count * 3 / 10 {
            Log.ollama.warning("Refinement too short (\(cleaned.count) vs \(original.count)) — keeping original")
            return original
        }

        // Contains markdown formatting → LLM added commentary
        let markdownPatterns = ["```", "**", "##", "- ", "* "]
        for pattern in markdownPatterns {
            if cleaned.contains(pattern) {
                Log.ollama.warning("Refinement contains markdown — keeping original")
                return original
            }
        }

        // Contains common LLM preamble phrases
        let preamblePatterns = ["here is", "here's the", "i've cleaned", "corrected version", "cleaned up"]
        let lowered = cleaned.lowercased()
        for pattern in preamblePatterns {
            if lowered.hasPrefix(pattern) {
                Log.ollama.warning("Refinement contains LLM preamble — keeping original")
                return original
            }
        }

        return cleaned
    }
}
