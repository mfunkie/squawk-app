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
    var state: DictationState = .idle
    private var recordingTimeoutTask: Task<Void, Never>?

    /// Maximum recording duration in seconds (default 5 minutes)
    var maxRecordingDuration: TimeInterval = 300

    // MARK: - Menu Bar Icon

    var menuBarIcon: String {
        switch state {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "ellipsis.circle"
        case .refining: return "sparkles"
        }
    }

    // MARK: - State Transitions

    /// Toggle recording on/off. Only transitions from idle→recording or recording→transcribing.
    func toggle() {
        switch state {
        case .idle:
            state = .recording
            startRecordingTimeout()
            Log.pipeline.info("State: idle → recording")
        case .recording:
            recordingTimeoutTask?.cancel()
            state = .transcribing
            Log.pipeline.info("State: recording → transcribing")
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

    // MARK: - Recording Timeout

    private func startRecordingTimeout() {
        recordingTimeoutTask?.cancel()
        let duration = maxRecordingDuration
        recordingTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            guard let self, self.state == .recording else { return }
            Log.pipeline.warning("Recording timeout reached (\(duration)s)")
            self.toggle() // transitions recording → transcribing
        }
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
            self.toggle() // recording → transcribing
        }
    }
}
