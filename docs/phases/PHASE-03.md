# PHASE-03: Ollama Integration for Transcript Polishing

## Goal

Send raw transcriptions to a local Ollama instance for cleanup (punctuation, filler word removal, grammar fixes) and handle unavailability gracefully so the app always works even without Ollama.

## Prerequisites

- PHASE-02 complete: `TranscriptionEngine` returns raw transcript strings
- Ollama installed locally (`brew install ollama` or from ollama.com)
- A model pulled: `ollama pull mistral` (or phi3, llama3.2)

## Directory & File Structure

Files to implement (replacing stubs from PHASE-00):

```
Squawk/
├── Refinement/
│   ├── OllamaClient.swift           # Full implementation
│   └── TranscriptRefiner.swift      # Full implementation
└── Models/
    └── AppState.swift               # Add ollamaAvailable tracking
```

## Detailed Steps

### Step 1: Implement OllamaClient

`Refinement/OllamaClient.swift` — low-level HTTP client for the Ollama REST API:

```swift
import Foundation
import os

struct OllamaClient {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
}
```

**Health check — verify Ollama is running:**

```swift
func isAvailable() async -> Bool {
    let url = baseURL.appendingPathComponent("api/tags")
    var request = URLRequest(url: url)
    request.timeoutInterval = 3 // Fast timeout for health checks

    do {
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    } catch {
        return false
    }
}
```

**List available models:**

```swift
struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
        let size: Int64
    }
    let models: [Model]
}

func listModels() async throws -> [String] {
    let url = baseURL.appendingPathComponent("api/tags")
    let (data, _) = try await session.data(from: url)
    let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
    return response.models.map(\.name)
}
```

**Generate (non-streaming) — the core API call:**

```swift
struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let system: String?
    let stream: Bool = false

    struct Options: Encodable {
        let temperature: Double
        let num_predict: Int
    }
    let options: Options?
}

struct OllamaGenerateResponse: Decodable {
    let response: String
    let done: Bool
    let total_duration: Int64?     // nanoseconds
    let eval_count: Int?           // tokens generated
}

func generate(
    model: String,
    prompt: String,
    system: String?,
    temperature: Double = 0.3,
    maxTokens: Int = 2048
) async throws -> OllamaGenerateResponse {
    let url = baseURL.appendingPathComponent("api/generate")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 10

    let body = OllamaGenerateRequest(
        model: model,
        prompt: prompt,
        system: system,
        options: .init(temperature: temperature, num_predict: maxTokens)
    )
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await session.data(for: request)

    guard let http = response as? HTTPURLResponse else {
        throw OllamaError.invalidResponse
    }

    if http.statusCode == 404 {
        throw OllamaError.modelNotFound(model)
    }

    guard http.statusCode == 200 else {
        throw OllamaError.httpError(http.statusCode)
    }

    return try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
}

enum OllamaError: LocalizedError {
    case invalidResponse
    case modelNotFound(String)
    case httpError(Int)
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Ollama"
        case .modelNotFound(let model):
            return "Model '\(model)' not found. Run: ollama pull \(model)"
        case .httpError(let code):
            return "Ollama returned HTTP \(code)"
        case .connectionFailed:
            return "Cannot connect to Ollama at localhost:11434"
        }
    }
}
```

### Step 2: Implement TranscriptRefiner

`Refinement/TranscriptRefiner.swift` — orchestrates the cleanup prompt and validates the response:

```swift
import Foundation
import os

struct TranscriptRefiner {
    private let client: OllamaClient
    private let defaultModel = "mistral"

    init(client: OllamaClient = OllamaClient()) {
        self.client = client
    }
}
```

**Default system prompt:**

```swift
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
```

**Core refine method:**

```swift
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
        maxTokens: rawTranscript.count * 2 // generous but bounded
    )

    let cleaned = response.response.trimmingCharacters(in: .whitespacesAndNewlines)

    let duration = response.total_duration.map { Double($0) / 1_000_000_000 } ?? 0
    Log.ollama.info("Refinement complete: \(String(format: "%.1f", duration))s, \(response.eval_count ?? 0) tokens")

    return validated(cleaned: cleaned, original: rawTranscript)
}
```

**Hallucination guard — the `validated()` function:**

LLMs sometimes hallucinate, add commentary, or produce markdown when asked not to. This function catches common failure modes:

```swift
private func validated(cleaned: String, original: String) -> String {
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
```

### Step 3: Graceful Degradation & Background Polling

In `AppState` or `DictationController`, manage Ollama availability:

```swift
// In DictationController or AppState
var ollamaAvailable = false
private var pollingTask: Task<Void, Never>?

func startOllamaPolling() {
    let client = OllamaClient()
    pollingTask = Task {
        while !Task.isCancelled {
            let available = await client.isAvailable()
            await MainActor.run {
                ollamaAvailable = available
            }
            try? await Task.sleep(for: .seconds(30))
        }
    }
}

func stopOllamaPolling() {
    pollingTask?.cancel()
}
```

**Behavior when Ollama is unavailable:**
- Pipeline silently skips refinement — raw transcript becomes final output
- No error toast, no alert — just a gray status indicator in the menu
- When Ollama comes online, next transcription will use it automatically
- Status indicator in tray menu: green dot = connected, gray dot = unavailable

**Behavior when model is not pulled:**
- Ollama returns HTTP 404 with `OllamaError.modelNotFound`
- Show in settings: "Model 'mistral' not found. Run `ollama pull mistral` in Terminal"
- Do NOT auto-pull models — that's a user decision

### Step 4: Model Recommendations

Document in settings UI or first-run tips:

| Model | Speed | Quality | Best For |
|-------|-------|---------|----------|
| `phi3:mini` | ~200ms | Basic cleanup | Fast, minimal corrections |
| `mistral` | ~500ms | Solid | Default recommendation |
| `llama3.2:3b` | ~800ms | Best | Complex sentences, technical jargon |

Speed estimates are for ~50 word transcripts on M1+. User can change the model in settings (PHASE-06).

### Step 5: Testing the Refiner in Isolation

Add a temporary test in MenuBarView or use Console.app:

```swift
// Test cases to verify:
let testCases = [
    "um so like i went to the uh store and bought some some milk",
    "the the meeting is at at three PM tomorrow",
    "i think we should basically just you know refactor the the database layer",
]

for raw in testCases {
    let refined = try await refiner.refine(rawTranscript: raw)
    print("IN:  \(raw)")
    print("OUT: \(refined)")
    print("---")
}
```

Expected outputs:
- "I went to the store and bought some milk."
- "The meeting is at three PM tomorrow."
- "I think we should refactor the database layer."

## Key Dependencies

| Dependency | Import | Usage |
|-----------|--------|-------|
| Foundation | `import Foundation` | `URLSession`, `JSONEncoder/Decoder`, `URL` |
| os | `import os` | `Logger` |

**Zero third-party dependencies.** All HTTP communication uses `URLSession`.

**External dependency:** Ollama must be installed and running at `localhost:11434` for refinement to work. The app must function without it.

## Gotchas & Edge Cases

1. **Ollama not installed** — The app must not crash or error. `isAvailable()` returns `false`, refinement is skipped silently. The user may never install Ollama, and that's fine.

2. **Ollama model not pulled** — Even if Ollama is running, the specified model might not be downloaded. Detect the 404 error and show a helpful message with the `ollama pull` command.

3. **Slow Ollama responses** — A 10-second timeout prevents the pipeline from hanging. If refinement times out, use the raw transcript.

4. **Hallucination** — The `validated()` function catches common failure modes, but it's not perfect. Over time, the system prompt can be tuned. Log all discarded refinements at warning level so they can be reviewed.

5. **Markdown in response** — Despite instructions, some models (especially larger ones) add markdown. The validator catches `**`, ` ``` `, etc.

6. **Context window overflow** — For very long transcripts (>5 minutes of speech), the prompt + response may exceed the model's context window. Consider truncating the prompt or chunking for very long inputs.

7. **Ollama version differences** — The `/api/generate` endpoint is stable across Ollama versions, but response field names may vary. Test with the user's installed version.

8. **localhost vs 127.0.0.1** — Some network configurations resolve `localhost` to IPv6 `::1`. If connection fails, try `127.0.0.1` as a fallback.

## Acceptance Criteria

- [ ] Ollama running + mistral pulled: raw transcript is cleaned (filler words removed, punctuation added)
- [ ] Ollama stopped: raw text passes through silently with no errors
- [ ] Starting Ollama mid-session: detected within 30 seconds, next transcription uses refinement
- [ ] Model not pulled: helpful error message with `ollama pull` command
- [ ] Hallucinated response (too long): discarded, raw text kept, warning logged
- [ ] Hallucinated response (markdown): discarded, raw text kept, warning logged
- [ ] Refinement timeout (>10s): raw text used, no hang
- [ ] Console.app shows refinement timing and token counts
- [ ] Ollama status indicator (green/gray) visible in menu bar popover

## Estimated Complexity

**M** — The HTTP client is straightforward. The hallucination guard needs careful tuning. Graceful degradation is the most important requirement — the app must never break because of Ollama.

## References

- **speak2** → `OllamaRefiner.swift`: Nearly identical feature. Study its system prompt, timeout handling, and how it validates LLM output. Also has an `MLXRefiner` for on-device refinement without Ollama.
- **Ollama API docs** → `github.com/ollama/ollama/blob/main/docs/api.md`: Official REST API reference for `/api/generate`, `/api/tags`, etc.
- **FluidVoice**: Check if it has any LLM integration for comparison.
