import Foundation

/// Pure logic for audio level bar calculations, extracted for testability.
struct AudioLevelCalculator {
    let barCount: Int

    func threshold(for index: Int) -> Float {
        Float(index + 1) / Float(barCount) * 0.5
    }

    func isBarActive(index: Int, level: Float) -> Bool {
        level > threshold(for: index)
    }

    func barHeight(for index: Int, level: Float) -> CGFloat {
        isBarActive(index: index, level: level) ? CGFloat(8 + index * 2) : 4
    }

    /// Maps raw RMS to a perceptually-linear 0...1 value suitable for an
    /// SF Symbol `variableValue`. Uses a dBFS curve because speech RMS on a
    /// built-in mic typically sits around 0.01-0.03 (≈ -40 to -30 dBFS) — a
    /// linear map would peg the visual near zero. -60 dBFS maps to 0 (silence
    /// floor), -20 dBFS maps to 1 (shouting).
    func normalizedLevel(for level: Float) -> Double {
        guard level > 0.001 else { return 0 }
        let db = 20 * log10(Double(level))
        let normalized = (db + 60) / 40
        return min(1.0, max(0.0, normalized))
    }
}
