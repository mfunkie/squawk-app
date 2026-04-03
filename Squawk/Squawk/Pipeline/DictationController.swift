import Observation

@Observable
final class DictationController {
    var state: DictationState = .idle
}

enum DictationState {
    case idle, recording, transcribing, refining
}
