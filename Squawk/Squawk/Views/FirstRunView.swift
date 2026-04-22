import SwiftUI

struct FirstRunView: View {
    @Environment(DictationController.self) private var controller
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var currentStep: SetupStep = .welcome
    @State private var micStatus: MicrophonePermission = AudioPermissions.currentStatus
    @State private var hasAccessibility: Bool = HotkeyManager.hasAccessibilityPermission

    var body: some View {
        VStack(spacing: 20) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(SetupStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Step content
            stepContent

            Spacer()

            // Navigation
            stepNavigation
        }
        .padding(20)
        .frame(width: 340, height: 450)
        .onAppear {
            micStatus = AudioPermissions.currentStatus
            hasAccessibility = HotkeyManager.hasAccessibilityPermission
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            VStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Welcome to Squawk")
                    .font(.title2.bold())
                Text("Local voice-to-text for your Mac.\nFast, private, powered by Apple Neural Engine.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

        case .modelDownload:
            modelDownloadStep

        case .microphonePermission:
            microphonePermissionStep

        case .accessibilityPermission:
            accessibilityPermissionStep

        case .ready:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("All Set!")
                    .font(.title2.bold())
                Text("Press \(controller.hotkeyManager?.hotkeyDescription ?? "\u{2318}\u{21E7}Space") anywhere to start dictating.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var modelDownloadStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 36))
            Text("Speech Model")
                .font(.title3.bold())

            if controller.modelManager.isDownloaded {
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if controller.modelManager.isLoading {
                VStack {
                    ProgressView(value: controller.modelManager.downloadProgress)
                    Text("Downloading... (~300MB)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("This only happens once.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else if let error = controller.modelManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("Retry") {
                    Task { await controller.modelManager.loadModels() }
                }
            } else {
                if !DiskSpaceChecker.hasEnoughSpace() {
                    Label("Low disk space — need ~1GB free", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Button("Download Model") {
                    Task { await controller.modelManager.loadModels() }
                }
            }
        }
    }

    @ViewBuilder
    private var microphonePermissionStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 36))
            Text("Microphone Access")
                .font(.title3.bold())
            Text("Squawk needs your microphone to transcribe speech. Audio never leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            switch micStatus {
            case .authorized:
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                VStack {
                    Label("Permission denied", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                    Button("Open System Settings") {
                        AudioPermissions.openSystemSettings()
                    }
                }
            default:
                Button("Grant Access") {
                    Task {
                        _ = await AudioPermissions.requestAccess()
                        micStatus = AudioPermissions.currentStatus
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accessibilityPermissionStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised")
                .font(.system(size: 36))
            Text("Accessibility (Optional)")
                .font(.title3.bold())
            Text("Required for auto-paste. You can skip this and enable later in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if hasAccessibility {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant Access") {
                    HotkeyManager.requestAccessibilityPermission()
                    // Poll for change since accessibility prompt is out-of-process
                    Task {
                        for _ in 0..<30 {
                            try? await Task.sleep(for: .seconds(1))
                            let granted = HotkeyManager.hasAccessibilityPermission
                            if granted {
                                hasAccessibility = true
                                break
                            }
                        }
                    }
                }
                Button("Skip for now") {
                    currentStep = .ready
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private var stepNavigation: some View {
        if currentStep == .ready {
            Button("Get Started") {
                hasCompletedSetup = true
            }
            .buttonStyle(.borderedProminent)
        } else if currentStep != .welcome || true {
            HStack {
                if currentStep.rawValue > 0 {
                    Button("Back") {
                        if let prev = SetupStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = prev
                        }
                    }
                }
                Spacer()
                Button("Next") {
                    if let next = SetupStep(rawValue: currentStep.rawValue + 1) {
                        currentStep = next
                    }
                }
                .disabled(!canAdvance)
            }
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .modelDownload:
            return controller.modelManager.isDownloaded
        case .microphonePermission:
            return micStatus == .authorized
        case .accessibilityPermission:
            return true // Can always skip or proceed
        case .ready:
            return true
        }
    }
}
