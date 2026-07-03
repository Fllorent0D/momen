import UIKit

/// Issue #14 — centralised haptic vocabulary for the iOS timer.
///
/// Every buzz the timer screen produces goes through here so the feedback stays
/// consistent: a *medium impact* when the speaker actually changes (next /
/// previous / report-to-end), a *light impact* for softer actions like
/// pause / resume, and a distinct, stronger *notification* buzz when a speaker
/// tips into overtime or the standup finishes.
///
/// Generators are created and `prepare()`d immediately before firing to keep the
/// Taptic Engine warm and minimise latency. On devices without a Taptic Engine
/// these calls are simply no-ops, so callers never need to feature-check.
@MainActor
enum Haptics {
    /// A medium impact for a deliberate speaker transition (next / previous /
    /// report-to-end). The most common buzz of the standup.
    static func speakerTransition() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// A light impact for secondary actions such as pause / resume.
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// A crisp selection tick for incidental UI changes — toggling presence,
    /// flipping a segment, nudging a stepper. The lightest buzz in the kit.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// A dry, rigid tap for each countdown digit (3 · 2 · 1) so the start feels
    /// like a metronome winding up. Intensity is dialled down to stay subtle.
    static func countdownTick() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 0.6)
    }

    /// The launch buzz on "GO" — a heavy impact that snaps the standup open.
    static func go() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    /// A distinct, stronger notification buzz the instant the current speaker
    /// enters overtime — meant to be felt without looking.
    static func overtime() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// A success notification when the standup wraps up.
    static func finished() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
