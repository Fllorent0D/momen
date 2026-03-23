import SwiftUI

struct RibbonView: View {
    @Environment(MeetingManager.self) private var manager

    private let baseThickness: CGFloat = 14
    private let cornerRadius: CGFloat = 20

    private var tintColor: Color {
        manager.isOvertime ? manager.meeting.colorTheme.overtimeColor : manager.meeting.colorTheme.inTimeColor
    }

    private var currentThickness: CGFloat {
        guard manager.meeting.ribbonThicken else { return baseThickness }
        if manager.isOvertime { return baseThickness * 1.8 }
        let t = manager.remainingTime
        if t > 10 { return baseThickness }
        let progress = 1.0 - (t / 10.0)
        return baseThickness + progress * baseThickness * 0.8
    }

    private var shouldBlink: Bool {
        !manager.isOvertime && manager.remainingTime <= 10 && manager.remainingTime > 0
    }

    private var needsAnimation: Bool {
        shouldBlink || manager.meeting.ribbonGlow
    }

    var body: some View {
        if needsAnimation {
            animatedRibbon
        } else {
            staticRibbon
        }
    }

    // No animation needed — simple static render
    private var staticRibbon: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(tintColor, lineWidth: currentThickness)
            .ignoresSafeArea()
    }

    // Animated: blink and/or glow
    private var animatedRibbon: some View {
        TimelineView(.animation) { timeline in
            let blinkVal = shouldBlink ? blinkOpacity(at: timeline.date) : 1.0
            let glowVal = manager.meeting.ribbonGlow ? glowPulse(at: timeline.date) : 0.0

            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(tintColor, lineWidth: currentThickness)
                .shadow(
                    color: glowVal > 0 ? tintColor.opacity(0.5 * glowVal) : .clear,
                    radius: glowVal > 0 ? 20 * glowVal : 0
                )
                .opacity(blinkVal)
                .ignoresSafeArea()
        }
    }

    private func blinkOpacity(at date: Date) -> Double {
        let elapsed = 10.0 - manager.remainingTime
        let a = 3.0 * .pi / 10.0
        let phase = a * elapsed * elapsed
        return 0.2 + (sin(phase) + 1.0) / 2.0 * 0.8
    }

    private func glowPulse(at date: Date) -> CGFloat {
        let speed: Double = manager.isOvertime ? 2.0 : 0.8
        let sine = sin(date.timeIntervalSinceReferenceDate * speed * 2.0 * .pi)
        return 0.5 + CGFloat(sine + 1.0) / 2.0 * 0.5
    }
}
