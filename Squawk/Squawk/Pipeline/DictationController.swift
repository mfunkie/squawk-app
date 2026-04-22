import Cocoa
import Observation
import os

enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case refining
}

@Observable
final class DictationController {
    // MARK: - Public state
    var state: DictationState = .idle
    var ollamaAvailable = false
    var lastLatencyMs: Int?
    var lastError: String?

    // MARK: - Owned components
    let audioCaptureManager = AudioCaptureManager()
    let modelManager = ModelManager()
    private(set) var transcriptionEngine: TranscriptionEngine!
    private let transcriptRefiner = TranscriptRefiner()
    private let textInjector = TextInjector()
    let history = TranscriptHistory()
    var hotkeyManager: HotkeyManager?

    // MARK: - Settings (backed by UserDefaults to stay in sync with @AppStorage in views)
    var ollamaEnabled: Bool {
        UserDefaults.standard.object(forKey: "ollama.enabled") as? Bool ?? true
    }
    var ollamaModel: String {
        let model = UserDefaults.standard.string(forKey: "ollama.model") ?? ""
        if model.isEmpty {
            Log.pipeline.info("No Ollama model configured in settings")
            return ""
        }
        return model
    }
    var autoPasteEnabled: Bool {
        UserDefaults.standard.object(forKey: "output.autoPaste") as? Bool ?? false
    }
    var restoreClipboardEnabled: Bool {
        UserDefaults.standard.object(forKey: "output.restoreClipboard") as? Bool ?? true
    }
    var maxRecordingDuration: TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: "recording.maxDuration")
        return stored > 0 ? TimeInterval(stored) : 300
    }

    // MARK: - Private
    private var recordingTimeoutTask: Task<Void, Never>?
    private var ollamaPollingTask: Task<Void, Never>?
    private var consecutiveErrors = 0

    // MARK: - Menu Bar Icon

    var menuBarIcon: String {
        switch state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "ellipsis.circle"
        case .refining: return "sparkles"
        }
    }

    init() {
        transcriptionEngine = TranscriptionEngine(modelManager: modelManager)
    }

    // MARK: - State Transitions

    /// Toggle recording on/off. Called by HotkeyManager.
    func toggle() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            recordingTimeoutTask?.cancel()
            Task { await stopAndTranscribe() }
        case .transcribing, .refining:
            Log.pipeline.debug("Toggle ignored in state: \(String(describing: self.state))")
        }
    }

    /// Transition from transcribing to refining (when Ollama polish is enabled).
    func transitionToRefining() {
        guard state == .transcribing else { return }
        state = .refining
        Log.pipeline.info("State: transcribing → refining")
    }

    /// Mark processing complete, return to idle. Only valid from transcribing or refining.
    func finish() {
        guard state == .transcribing || state == .refining else { return }
        state = .idle
        Log.pipeline.info("State: \(String(describing: self.state)) → idle")
    }

    // MARK: - Recording

    private func startRecording() {
        guard transcriptionEngine.isReady else {
            lastError = "Speech model not loaded yet"
            return
        }

        do {
            try audioCaptureManager.startCapture()
            state = .recording
            lastError = nil
            consecutiveErrors = 0
            startRecordingTimeout()
            playCue(.start)
            Log.pipeline.info("State: idle → recording")
        } catch {
            lastError = error.localizedDescription
            Log.pipeline.error("Failed to start recording: \(error)")
        }
    }

    private func startRecordingTimeout() {
        recordingTimeoutTask?.cancel()
        let duration = maxRecordingDuration
        recordingTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            guard let self, self.state == .recording else { return }
            Log.pipeline.warning("Recording timeout reached (\(duration)s)")
            self.toggle() // recording → stopAndTranscribe
        }
    }

    // MARK: - Full Pipeline

    @MainActor
    private func stopAndTranscribe() async {
        recordingTimeoutTask?.cancel()

        // 1. Stop audio capture
        let samples = audioCaptureManager.stopCapture()
        playCue(.stop)
        guard samples.count > 8000 else { // <0.5 seconds = discard
            Log.pipeline.info("Audio too short (\(samples.count) samples) — discarding")
            state = .idle
            return
        }

        let pipelineStart = ContinuousClock.now
        let audioDuration = Double(samples.count) / 16000.0

        // 2. Transcribe
        state = .transcribing
        Log.pipeline.info("State: recording → transcribing")
        let rawTranscript: String
        do {
            rawTranscript = try await transcriptionEngine.transcribe(audioSamples: samples)
        } catch {
            handlePipelineError("Transcription failed: \(error.localizedDescription)")
            return
        }

        guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Log.pipeline.info("Empty transcription — discarding")
            state = .idle
            return
        }

        // 3. Add to history immediately with raw text
        let entry = TranscriptEntry(
            id: UUID(),
            rawText: rawTranscript,
            polishedText: nil,
            timestamp: Date(),
            audioDuration: audioDuration,
            latencyMs: nil
        )
        history.add(entry)

        // 4. Copy raw text to clipboard immediately
        textInjector.copyToClipboard(rawTranscript)

        // 5. Optionally refine with Ollama
        var finalText = rawTranscript
        let currentModel = ollamaModel
        if ollamaEnabled && ollamaAvailable && !currentModel.isEmpty {
            state = .refining
            Log.pipeline.info("State: transcribing → refining")
            do {
                let refinedTask = Task {
                    try await transcriptRefiner.refine(
                        rawTranscript: rawTranscript,
                        model: currentModel
                    )
                }

                // Timeout: if refinement takes >5 seconds, keep raw
                let result = try await withThrowingTaskGroup(of: String?.self) { group in
                    group.addTask { try await refinedTask.value }
                    group.addTask {
                        try await Task.sleep(for: .seconds(5))
                        return nil // timeout sentinel
                    }

                    // First to complete wins
                    if let first = try await group.next() {
                        group.cancelAll()
                        return first
                    }
                    return nil
                }

                if let refined = result {
                    finalText = refined
                    history.updateLatest(polishedText: refined)
                    textInjector.copyToClipboard(refined) // Update clipboard with polished version
                }
            } catch {
                Log.ollama.warning("Refinement failed, using raw: \(error)")
                // Silently fall back to raw text
            }
        }

        // 6. Auto-paste if enabled
        if autoPasteEnabled {
            let result = await textInjector.pasteIntoActiveApp(finalText)
            if result == .skippedNoAccessibility {
                ClipboardToast.show("Copied to clipboard")
            }
        }

        // 7. Record latency
        let elapsed = ContinuousClock.now - pipelineStart
        let components = elapsed.components
        let totalMs = Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000)
        lastLatencyMs = totalMs
        history.updateLatestLatency(totalMs)

        Log.pipeline.info("Pipeline complete: \(String(format: "%.1f", audioDuration))s audio → \(totalMs)ms total")

        // 8. Done
        state = .idle
    }

    // MARK: - Sound Cues

    private enum SoundCue {
        case start, stop

        var systemSoundName: String {
            switch self {
            case .start: return "Tink"
            case .stop: return "Pop"
            }
        }
    }

    private func playCue(_ cue: SoundCue) {
        NSSound(named: cue.systemSoundName)?.play()
    }

    // MARK: - Error Handling

    @MainActor
    private func handlePipelineError(_ message: String) {
        consecutiveErrors += 1
        lastError = message
        state = .idle
        Log.pipeline.error("\(message)")

        if consecutiveErrors >= 3 {
            lastError = "Multiple failures. Check Console.app for details."
        }
    }

    // MARK: - Ollama Polling

    func startOllamaPolling() {
        let client = OllamaClient()
        ollamaPollingTask = Task {
            while !Task.isCancelled {
                let available = await client.isAvailable()
                await MainActor.run {
                    self.ollamaAvailable = available
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stopOllamaPolling() {
        ollamaPollingTask?.cancel()
    }

    // MARK: - Sleep/Wake

    func observeSystemEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.state == .recording else { return }
            Log.pipeline.warning("System sleeping during recording — stopping")
            self.toggle() // recording → stopAndTranscribe
        }
    }
}
