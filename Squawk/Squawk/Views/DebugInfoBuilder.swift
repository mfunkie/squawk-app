import Foundation

enum DebugInfoBuilder {
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

    static var machineModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}
