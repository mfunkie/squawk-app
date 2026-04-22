import SwiftUI

/// Pure, testable bar-height logic for the center-outward audio meter.
/// The middle bar reaches max height at low input levels; outer bars
/// only start growing past the minimum once the level crosses their
/// activation threshold. Each bar grows vertically from the centerline.
struct CenterOutwardMeterCalculator {
    let barCount: Int
    var minHeight: CGFloat = 3
    var maxHeight: CGFloat = 22
    /// Fraction of the level range (0...1) dedicated to "fanning out"
    /// from the center. At level >= (1 - fanRange), every bar has
    /// started growing. Lower values = snappier outward travel.
    var fanRange: Double = 0.6

    /// Peak heights per bar, shaping a waveform-like silhouette
    /// (tallest in the middle, shorter on the edges) even at max level.
    /// Count must equal `barCount`.
    var peakHeights: [CGFloat] = [12, 18, 22, 18, 12]

    /// Level (0...1) below which this bar stays at minimum height.
    /// Center bar = 0 (always growing); edges = fanRange.
    func activationThreshold(for index: Int) -> Double {
        let maxDistance = Double(barCount - 1) / 2
        guard maxDistance > 0 else { return 0 }
        let distanceFromCenter = abs(Double(index) - maxDistance)
        return (distanceFromCenter / maxDistance) * fanRange
    }

    func barHeight(for index: Int, level: Double) -> CGFloat {
        let peak = index < peakHeights.count ? peakHeights[index] : maxHeight
        let threshold = activationThreshold(for: index)
        let remaining = max(0.0001, 1.0 - threshold)
        let fillT = max(0, min(1, (level - threshold) / remaining))
        return minHeight + CGFloat(fillT) * (peak - minHeight)
    }
}

/// Center-outward audio level meter: 5 thin capsule bars that grow
/// vertically from a shared centerline. The middle bar responds first;
/// outer bars light up only as the level climbs. Drop in for situations
/// where SF Symbol `waveform`'s left-to-right fill isn't the right shape.
struct AudioWaveMeter: View {
    /// Normalized 0...1 audio level.
    let level: Double

    private static let calculator = CenterOutwardMeterCalculator(barCount: 5)
    private static let barWidth: CGFloat = 3
    private static let spacing: CGFloat = 3

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(0..<Self.calculator.barCount, id: \.self) { index in
                Capsule()
                    .fill(.primary)
                    .frame(
                        width: Self.barWidth,
                        height: Self.calculator.barHeight(for: index, level: level)
                    )
            }
        }
        .frame(height: Self.calculator.maxHeight)
        .animation(.easeOut(duration: 0.05), value: level)
    }
}
