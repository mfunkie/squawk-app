import SwiftUI

struct AudioLevelBars: View {
    let level: Float
    private let calculator = AudioLevelCalculator(barCount: 5)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(calculator.isBarActive(index: index, level: level) ? .red : .red.opacity(0.2))
                    .frame(width: 3, height: calculator.barHeight(for: index, level: level))
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.1), value: level)
    }
}
