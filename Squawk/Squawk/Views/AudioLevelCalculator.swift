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
}
