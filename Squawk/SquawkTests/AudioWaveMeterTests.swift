import XCTest
@testable import Squawk

final class AudioWaveMeterTests: XCTestCase {

    // MARK: - Activation Threshold

    func testCenterBarHasZeroThreshold() {
        let calc = CenterOutwardMeterCalculator(barCount: 5)
        // Center of a 5-bar layout is index 2; it always grows.
        XCTAssertEqual(calc.activationThreshold(for: 2), 0.0, accuracy: 0.0001)
    }

    func testOuterBarsHaveFullFanThreshold() {
        let calc = CenterOutwardMeterCalculator(barCount: 5)
        // Outermost bars activate only when level is in the last `fanRange`.
        XCTAssertEqual(calc.activationThreshold(for: 0), calc.fanRange, accuracy: 0.0001)
        XCTAssertEqual(calc.activationThreshold(for: 4), calc.fanRange, accuracy: 0.0001)
    }

    func testThresholdsAreSymmetricAroundCenter() {
        let calc = CenterOutwardMeterCalculator(barCount: 5)
        XCTAssertEqual(calc.activationThreshold(for: 0),
                       calc.activationThreshold(for: 4),
                       accuracy: 0.0001)
        XCTAssertEqual(calc.activationThreshold(for: 1),
                       calc.activationThreshold(for: 3),
                       accuracy: 0.0001)
    }

    // MARK: - Bar Heights

    func testAllBarsAtMinimumAtSilence() {
        let calc = CenterOutwardMeterCalculator(barCount: 5)
        for index in 0..<5 {
            XCTAssertEqual(calc.barHeight(for: index, level: 0),
                           calc.minHeight,
                           accuracy: 0.0001)
        }
    }

    func testAllBarsAtPeakAtMaxLevel() {
        let calc = CenterOutwardMeterCalculator(barCount: 5)
        for index in 0..<5 {
            XCTAssertEqual(calc.barHeight(for: index, level: 1.0),
                           calc.peakHeights[index],
                           accuracy: 0.0001)
        }
    }

    func testCenterBarGrowsBeforeOuterBars() {
        let calc = CenterOutwardMeterCalculator(barCount: 5)
        // At a low-to-mid level, the center bar should already be partially grown
        // while the outermost bars are still at minimum (threshold not crossed).
        let midLevel = 0.3
        XCTAssertGreaterThan(calc.barHeight(for: 2, level: midLevel), calc.minHeight)
        XCTAssertEqual(calc.barHeight(for: 0, level: midLevel),
                       calc.minHeight,
                       accuracy: 0.0001)
        XCTAssertEqual(calc.barHeight(for: 4, level: midLevel),
                       calc.minHeight,
                       accuracy: 0.0001)
    }

    func testBarHeightIsMonotonicInLevel() {
        let calc = CenterOutwardMeterCalculator(barCount: 5)
        let levels: [Double] = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
        for index in 0..<5 {
            let heights = levels.map { calc.barHeight(for: index, level: $0) }
            for i in 1..<heights.count {
                XCTAssertGreaterThanOrEqual(
                    heights[i], heights[i - 1],
                    "bar \(index) at level \(levels[i]) should not be shorter than at \(levels[i-1])"
                )
            }
        }
    }
}
