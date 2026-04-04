import AVFoundation
import Accelerate
import Observation
import os

enum AudioCaptureError: LocalizedError {
    case noInputDevice
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "No microphone found. Connect an audio input device."
        case .permissionDenied:
            return "Microphone access denied. Open System Settings to grant permission."
        }
    }
}

@Observable
final class AudioCaptureManager {
    // MARK: - Public state
    var isCapturing = false
    var audioLevel: Float = 0.0

    // MARK: - Private
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private var bufferLock = os_unfair_lock()
    private var levelUpdateCounter = 0

    init() {
        observeConfigurationChanges()
    }

    // MARK: - Capture

    func startCapture() throws {
        guard !isCapturing else { return }

        // Guard: check that an input device exists
        let inputNode = audioEngine.inputNode
        let hwFormat = inputNode.inputFormat(forBus: 0)
        guard hwFormat.channelCount > 0 else {
            throw AudioCaptureError.noInputDevice
        }

        let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        // Set up converter from hardware format to 16kHz mono
        guard let converter = AVAudioConverter(from: hwFormat, to: desiredFormat) else {
            Log.audio.error("Cannot create audio converter from \(hwFormat) to \(desiredFormat)")
            throw AudioCaptureError.noInputDevice
        }

        // Tap at hardware format — resampling in the tap callback avoids format mismatch
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) {
            [weak self] buffer, _ in
            self?.convertAndProcess(buffer: buffer, converter: converter, outputFormat: desiredFormat)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isCapturing = true
        Log.audio.info("Audio capture started (hw: \(hwFormat.sampleRate)Hz → 16kHz)")
    }

    func stopCapture() -> [Float] {
        guard isCapturing else { return [] }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false

        os_unfair_lock_lock(&bufferLock)
        let samples = audioBuffer
        audioBuffer.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(&bufferLock)

        audioLevel = 0.0
        let duration = Double(samples.count) / 16000.0
        Log.audio.info("Audio capture stopped. Collected \(samples.count) samples (\(String(format: "%.1f", duration))s)")
        return samples
    }

    // MARK: - Buffer Processing

    private func convertAndProcess(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outputFormat: AVAudioFormat) {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount) else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            Log.audio.error("Audio conversion error: \(error)")
            return
        }

        processTapBuffer(outputBuffer)
    }

    private func processTapBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        // Thread-safe buffer append
        os_unfair_lock_lock(&bufferLock)
        audioBuffer.append(contentsOf: samples)
        os_unfair_lock_unlock(&bufferLock)

        // Compute RMS for audio level meter (throttled to ~15fps)
        levelUpdateCounter += 1
        if levelUpdateCounter % 3 == 0 {
            let rms = Self.computeRMS(samples)
            DispatchQueue.main.async { [weak self] in
                self?.audioLevel = rms
            }
        }
    }

    // MARK: - RMS

    static func computeRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }

    // MARK: - Configuration Changes

    private func observeConfigurationChanges() {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            guard let self, self.isCapturing else { return }
            Log.audio.warning("Audio engine configuration changed, restarting")
            do {
                self.audioEngine.inputNode.removeTap(onBus: 0)
                try self.startCapture()
            } catch {
                Log.audio.error("Failed to restart after config change: \(error)")
                self.isCapturing = false
            }
        }
    }
}

// MARK: - Input Device Enumeration

extension AudioCaptureManager {
    struct InputDevice: Identifiable, Hashable {
        let id: String
        let name: String
    }

    var availableInputDevices: [InputDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        return discoverySession.devices.map {
            InputDevice(id: $0.uniqueID, name: $0.localizedName)
        }
    }

    var defaultInputDevice: InputDevice? {
        guard let device = AVCaptureDevice.default(for: .audio) else { return nil }
        return InputDevice(id: device.uniqueID, name: device.localizedName)
    }
}
