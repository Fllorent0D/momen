import SwiftUI

struct OverlayTimerBar: View {
    let progress: Double
    let isOvertime: Bool

    private var barColor: Color {
        isOvertime ? .red : .green
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.white.opacity(0.2))

                // Progress fill
                Capsule()
                    .fill(barColor.opacity(0.8))
                    .frame(width: geometry.size.width * (isOvertime ? 1.0 : (1.0 - progress)))
            }
        }
        .frame(height: 6)
        .animation(.linear(duration: 0.1), value: progress)
    }
}
