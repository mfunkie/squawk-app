import Foundation

enum DebugInfoBuilder {
    /// Basic debug info (version + system)
    static func buildDebugInfo(
        appVersion: String,
        buildNumber: String
    ) -> String {
        """
        Squawk v\(appVersion) (\(buildNumber))
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        Chip: \(machineModel)
        """
    }

    /// Enhanced debug info with full app state
    static func buildDebugInfo(
        appVersion: String,
        buildNumber: String,
        asrModelLoaded: Bool,
        ollamaAvailable: Bool,
        ollamaModel: String,
        recordingMode: String,
        autoPasteEnabled: Bool,
        historyCount: Int,
        lastError: String?
    ) -> String {
        let ollamaStatus = ollamaAvailable ? "connected (\(ollamaModel))" : "unavailable"
        return """
        Squawk v\(appVersion) (\(buildNumber))
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        Chip: \(machineModel)
        ASR Model: \(asrModelLoaded ? "loaded" : "not loaded")
        Ollama: \(ollamaStatus)
        Recording mode: \(recordingMode)
        Auto-paste: \(autoPasteEnabled)
        History entries: \(historyCount)
        Last error: \(lastError ?? "none")
        """
    }

    static var machineModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}
