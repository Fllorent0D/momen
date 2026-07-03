import SwiftUI

/// Pulse motion durations, in seconds. Drawn from the spec's keyframes
/// (glow 2.8 · breathe 1.6/1.2/0.8 · overtime pulse 1.0 · spinner 1.1). The
/// governing rule: *movement accelerates with tension* — calm and slow while
/// green, short and nervous while red. Nothing moves without a reason.
public enum PulseDuration {
    /// 0.18 — standard control transition (hover, selection). Chosen value,
    /// not from the spec, kept short so chrome feels responsive.
    public static let micro: Double = 0.18
    /// 0.8 — tense breathe, approaching/over the limit.
    public static let quick: Double = 0.8
    /// 1.0 — overtime pulse.
    public static let base: Double = 1.0
    /// 1.6 — calm breathe, comfortably within budget.
    public static let calm: Double = 1.6
    /// 1.1 — indeterminate spinner revolution.
    public static let spin: Double = 1.1
    /// 2.8 — ambient ring glow.
    public static let glow: Double = 2.8
}

/// Ready-made Pulse animations.
public enum PulseMotion {

    /// Standard ease for control state changes.
    public static let standard = Animation.easeInOut(duration: PulseDuration.micro)

    /// Calm breathing loop (green / within budget).
    public static let calmBreathe = Animation
        .easeInOut(duration: PulseDuration.calm)
        .repeatForever(autoreverses: true)

    /// Tense breathing loop (approaching the limit).
    public static let tenseBreathe = Animation
        .easeInOut(duration: PulseDuration.quick)
        .repeatForever(autoreverses: true)

    /// Overtime pulse (red / over budget).
    public static let overtimePulse = Animation
        .easeInOut(duration: PulseDuration.base)
        .repeatForever(autoreverses: true)

    /// Ambient ring glow.
    public static let ambientGlow = Animation
        .easeInOut(duration: PulseDuration.glow)
        .repeatForever(autoreverses: true)

    /// Indeterminate spinner.
    public static let spinner = Animation
        .linear(duration: PulseDuration.spin)
        .repeatForever(autoreverses: false)

    /// A breathing loop whose tempo tightens with `tension` (0 = calm/slow,
    /// 1 = nervous/fast), interpolating between ``PulseDuration/calm`` and
    /// ``PulseDuration/quick``. Encodes the spec's core motion rule directly.
    public static func breathe(tension: Double) -> Animation {
        let t = min(max(tension, 0), 1)
        let duration = PulseDuration.calm + (PulseDuration.quick - PulseDuration.calm) * t
        return .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
}
