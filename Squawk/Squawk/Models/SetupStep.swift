import Foundation

enum SetupStep: Int, CaseIterable {
    case welcome
    case modelDownload
    case microphonePermission
    case accessibilityPermission
    case ready

    /// Whether this step can be advanced without any prerequisite check.
    var canAdvanceWithoutPrerequisite: Bool {
        switch self {
        case .welcome, .accessibilityPermission:
            return true
        case .modelDownload, .microphonePermission, .ready:
            return false
        }
    }

    /// Whether this is the last step in the wizard.
    var isLast: Bool {
        self == SetupStep.allCases.last
    }
}
