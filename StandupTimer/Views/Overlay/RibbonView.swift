import SwiftUI

struct RibbonView: View {
    @Environment(MeetingManager.self) private var manager

    private let thickness: CGFloat = 14
    private let cornerRadius: CGFloat = 20

    private var tintColor: Color {
        manager.isOvertime ? .red : .green
    }

    var body: some View {
        TimelineView(.animation(paused: !shouldBlink)) { timeline in
            let opacity = blinkOpacity(at: timeline.date)

            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(tintColor, lineWidth: thickness)
                .shadow(color: tintColor.opacity(0.4), radius: 8)
                .opacity(opacity)
                .ignoresSafeArea()
        }
    }

    // MARK: - Blink Logic

    private var shouldBlink: Bool {
        !manager.isOvertime && manager.remainingTime <= 10 && manager.remainingTime > 0
    }

    private func blinkOpacity(at date: Date) -> Double {
        guard shouldBlink else { return 1.0 }

        let elapsed = 10.0 - manager.remainingTime
        let a = 3.0 * .pi / 10.0
        let phase = a * elapsed * elapsed
        let sine = sin(phase)
        return 0.2 + (sine + 1.0) / 2.0 * 0.8
    }
}
