import AVFoundation
import Observation

@Observable
final class AudioCaptureManager {
    var isCapturing = false
    var audioLevel: Float = 0.0
}
