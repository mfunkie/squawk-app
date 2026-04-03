import Observation
import os

@Observable
final class AppState {
    var ollamaAvailable = false
    private var pollingTask: Task<Void, Never>?

    func startOllamaPolling() {
        let client = OllamaClient()
        pollingTask = Task {
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
        pollingTask?.cancel()
    }
}
