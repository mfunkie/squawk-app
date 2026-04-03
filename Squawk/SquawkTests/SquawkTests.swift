import Foundation
import Testing
@testable import Squawk

struct AudioCaptureErrorTests {

    @Test func noInputDeviceErrorDescription() {
        let error = AudioCaptureError.noInputDevice
        #expect(error.errorDescription == "No microphone found. Connect an audio input device.")
    }

    @Test func permissionDeniedErrorDescription() {
        let error = AudioCaptureError.permissionDenied
        #expect(error.errorDescription == "Microphone access denied. Open System Settings to grant permission.")
    }
}

struct AudioCaptureManagerRMSTests {

    @Test func rmsOfEmptySamplesReturnsZero() {
        let rms = AudioCaptureManager.computeRMS([])
        #expect(rms == 0)
    }

    @Test func rmsOfSilenceReturnsZero() {
        let silence = [Float](repeating: 0, count: 1000)
        let rms = AudioCaptureManager.computeRMS(silence)
        #expect(rms == 0)
    }

    @Test func rmsOfConstantSignalReturnsAbsValue() {
        let constant = [Float](repeating: 0.5, count: 1000)
        let rms = AudioCaptureManager.computeRMS(constant)
        #expect(abs(rms - 0.5) < 0.001)
    }

    @Test func rmsOfSineWaveIsExpectedValue() {
        // RMS of a sine wave is amplitude / sqrt(2)
        let amplitude: Float = 1.0
        let sampleCount = 16000
        let frequency: Float = 440
        let sampleRate: Float = 16000
        let samples = (0..<sampleCount).map { i in
            amplitude * sin(2 * .pi * frequency * Float(i) / sampleRate)
        }
        let rms = AudioCaptureManager.computeRMS(samples)
        let expectedRMS = amplitude / sqrt(2.0)
        #expect(abs(rms - expectedRMS) < 0.01)
    }
}

struct MicrophonePermissionTests {

    @Test func allCasesExist() {
        // Verify the enum has all expected cases
        let cases: [MicrophonePermission] = [.authorized, .notDetermined, .denied, .restricted]
        #expect(cases.count == 4)
    }
}

struct AudioCaptureManagerStateTests {

    @MainActor
    @Test func initialStateIsNotCapturing() {
        let manager = AudioCaptureManager()
        #expect(manager.isCapturing == false)
        #expect(manager.audioLevel == 0.0)
    }

    @MainActor
    @Test func stopCaptureWhenNotCapturingReturnsEmpty() {
        let manager = AudioCaptureManager()
        let samples = manager.stopCapture()
        #expect(samples.isEmpty)
    }
}
