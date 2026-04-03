import XCTest
@testable import Squawk

final class AudioLevelBarsTests: XCTestCase {

    // MARK: - Bar Height

    func testBarHeightIsMinimumWhenLevelBelowThreshold() {
        // All bars should be at minimum height (4) when level is 0
        let calc = AudioLevelCalculator(barCount: 5)
        for index in 0..<5 {
            XCTAssertEqual(calc.barHeight(for: index, level: 0), 4, "Bar \(index) should be 4pt at level 0")
        }
    }

    func testBarHeightIncreasesWithIndex() {
        // When level is high enough to activate all bars, heights should increase
        let calc = AudioLevelCalculator(barCount: 5)
        let heights = (0..<5).map { calc.barHeight(for: $0, level: 0.6) }
        // Active bars: 8, 10, 12, 14, 16
        for i in 1..<heights.count {
            XCTAssertGreaterThan(heights[i], heights[i - 1], "Bar \(i) should be taller than bar \(i-1)")
        }
    }

    func testOnlyFirstBarsActiveAtLowLevel() {
        // At a low level, only the first bar(s) should be active
        let calc = AudioLevelCalculator(barCount: 5)
        let level: Float = 0.05
        // Threshold for bar 0 = 1/5 * 0.5 = 0.1, so even bar 0 is inactive at 0.05
        XCTAssertEqual(calc.barHeight(for: 0, level: level), 4)

        // At level 0.15, bar 0 (threshold 0.1) should be active, bar 1 (threshold 0.2) not
        XCTAssertGreaterThan(calc.barHeight(for: 0, level: 0.15), 4)
        XCTAssertEqual(calc.barHeight(for: 1, level: 0.15), 4)
    }

    // MARK: - Bar Active State

    func testBarIsActiveWhenLevelExceedsThreshold() {
        let calc = AudioLevelCalculator(barCount: 5)
        // Bar 0 threshold = 0.1
        XCTAssertTrue(calc.isBarActive(index: 0, level: 0.15))
        XCTAssertFalse(calc.isBarActive(index: 0, level: 0.05))
    }

    func testAllBarsActiveAtMaxLevel() {
        let calc = AudioLevelCalculator(barCount: 5)
        // Level above 0.5 should activate all bars
        for index in 0..<5 {
            XCTAssertTrue(calc.isBarActive(index: index, level: 0.6), "Bar \(index) should be active at level 0.6")
        }
    }

    func testNoBarsActiveAtZeroLevel() {
        let calc = AudioLevelCalculator(barCount: 5)
        for index in 0..<5 {
            XCTAssertFalse(calc.isBarActive(index: index, level: 0), "Bar \(index) should be inactive at level 0")
        }
    }
}
