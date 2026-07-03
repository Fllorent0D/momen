import SwiftUI

/// Pulse — « Le Signal » — the conic timer ring.
///
/// The founding rule of the system: *one does not read the time, one feels it
/// through colour.* `SignalRing` renders that rule as a single reusable view —
/// a green→lime→amber→red conic arc whose sweep tracks the time remaining, a
/// soft breathing halo behind it, and a monospaced chrono read-out at its
/// centre. It is platform-neutral (SwiftUI only) so the Mac overlay (#51) and
/// the iOS focus timer (#13) share one source of truth, sized to taste.
///
///     SignalRing(fraction: 0.62, timeText: "2:14")          // derives state
///     SignalRing(fraction: -0.1, timeText: "+0:23", state: .over)
///
/// Every colour, duration and proportion comes from a Pulse token — there is no
/// raw hex, point size or magic number in this file.
public struct SignalRing: View {

    /// The signal state, mapped to the spec's four-band legend
    /// (En cours / Bientôt → ``normal``, Limite → ``warn``, Dépassement → ``over``).
    public enum SignalState: Sendable {
        /// Comfortably within budget — calm green arc, slow ambient halo.
        case normal
        /// Last seconds before the limit — amber arc, slow halo.
        case warn
        /// Over the limit — full red ring that breathes, the chrono counts up.
        case over

        /// Derives the state from the remaining-time fraction using the spec
        /// thresholds: `≤ 0` → ``over``, `≤ 0.08` (the "Limite" band) → ``warn``,
        /// otherwise ``normal``.
        public static func forFraction(_ fraction: Double) -> SignalState {
            if fraction <= 0 { return .over }
            if fraction <= 0.08 { return .warn }
            return .normal
        }
    }

    /// Fraction of time remaining, `1` (full) → `0` (limit). Values below `0`
    /// read as overtime; the value is clamped to `0...1` for the arc sweep.
    private let fraction: Double
    /// The text shown at the centre (e.g. `"2:14"` or `"+0:23"`).
    private let timeText: String
    /// The resolved signal state.
    private let state: SignalState

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the halo's breathing opacity and (in ``SignalState/over``) the
    /// chrono's pulse scale. Toggled once on appear into a repeating animation.
    @State private var animating = false

    /// - Parameters:
    ///   - fraction: Time remaining as `1 → 0` (negative = overtime).
    ///   - timeText: The chrono read-out for the centre.
    ///   - state: Override the signal state; when `nil` it is derived from
    ///     `fraction` via ``SignalState/forFraction(_:)``.
    public init(fraction: Double, timeText: String, state: SignalState? = nil) {
        self.fraction = fraction
        self.timeText = timeText
        self.state = state ?? SignalState.forFraction(fraction)
    }

    public var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            // Ring thickness = 8.5% of the canvas (Pulse app-icon spec).
            let thickness = diameter * 0.085
            // Inner disc the chrono lives on, inset by the stroke on both sides.
            let inner = diameter - thickness * 2

            ZStack {
                halo(diameter: diameter)
                track(diameter: diameter, thickness: thickness)
                arc(diameter: diameter, thickness: thickness)
                chrono(inner: inner)
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { if !reduceMotion { animating = true } }
    }

    // MARK: - Layers

    /// Soft radial halo behind the ring. Breathes slowly while green/amber,
    /// faster and redder once over the limit (spec: glow 2.8s → 1.1s).
    private func halo(diameter: CGFloat) -> some View {
        let tint = signalColor
        return Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [tint.opacity(0.45), .clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.62
                )
            )
            .frame(width: diameter * 1.16, height: diameter * 1.16)
            .blur(radius: diameter * 0.04)
            .opacity(animating ? 0.95 : 0.4)
            .animation(haloAnimation, value: animating)
    }

    /// The unfilled remainder of the circle — the spec's `#1b1f24` track.
    private func track(diameter: CGFloat, thickness: CGFloat) -> some View {
        Circle()
            .stroke(PulseColor.surface2.color(for: colorScheme), lineWidth: thickness)
            .frame(width: diameter, height: diameter)
    }

    /// The coloured sweep. Its arc length is the remaining `fraction`, and the
    /// angular gradient is anchored to that same span so the colour rides the
    /// signal spectrum — green→lime within budget, amber→ember at the limit,
    /// a solid breathing red once over.
    private func arc(diameter: CGFloat, thickness: CGFloat) -> some View {
        let sweep = state == .over ? 1 : max(0, min(fraction, 1))
        return Circle()
            .trim(from: 0, to: sweep)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: arcColors),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360 * sweep)
                ),
                style: StrokeStyle(lineWidth: thickness, lineCap: .round)
            )
            // Rotate so the sweep starts at 12 o'clock (spec conic `from -90deg`).
            .rotationEffect(.degrees(-90))
            .frame(width: diameter, height: diameter)
            .scaleEffect(overPulseScale)
            .animation(overPulseAnimation, value: animating)
    }

    /// Centred monospaced chrono read-out. Uses the Pulse `chrono` role and
    /// shrinks to fit whatever ring size it is given.
    private func chrono(inner: CGFloat) -> some View {
        Text(timeText)
            .pulseText(.chrono)
            .foregroundStyle(chronoColor)
            .lineLimit(1)
            .minimumScaleFactor(0.1)
            .frame(width: inner * 0.86)
            .scaleEffect(overPulseScale)
            .animation(overPulseAnimation, value: animating)
    }

    // MARK: - Tokens per state

    /// The dominant signal token for the current state.
    private var signalColor: Color {
        switch state {
        case .normal: return PulseColor.signal.color(for: colorScheme)
        case .warn:   return PulseColor.warn.color(for: colorScheme)
        case .over:   return PulseColor.over.color(for: colorScheme)
        }
    }

    /// The two-stop spectrum slice the arc gradient interpolates across.
    /// Lime and ember emerge as the blends between the canonical tokens, exactly
    /// as in the Directions signal bar (signal → lime → warn → ember → over).
    private var arcColors: [Color] {
        let signal = PulseColor.signal.color(for: colorScheme)
        let warn = PulseColor.warn.color(for: colorScheme)
        let over = PulseColor.over.color(for: colorScheme)
        switch state {
        // Predominantly the state colour, tinting toward the next spectrum
        // token only near the leading edge: green stays full with a lime tip,
        // amber with an ember tip, red solid.
        case .normal: return [signal, signal, warn]   // vert plein → lime
        case .warn:   return [warn, warn, over]        // ambre → ember
        case .over:   return [over, over]              // rouge plein
        }
    }

    /// Centre text colour: neutral ink while green, the signal token once the
    /// timer is tense or over (spec: amber `0:18`, red `+0:23`).
    private var chronoColor: Color {
        switch state {
        case .normal: return PulseColor.ink.color(for: colorScheme)
        case .warn:   return PulseColor.warn.color(for: colorScheme)
        case .over:   return PulseColor.over.color(for: colorScheme)
        }
    }

    // MARK: - Motion

    private var haloAnimation: Animation? {
        guard !reduceMotion else { return nil }
        // Calm ambient breath while green/amber; tense overtime pulse when over.
        return state == .over ? PulseMotion.overtimePulse : PulseMotion.ambientGlow
    }

    /// The over-limit chrono/ring pulse (spec `overPulse`, ~1.04 scale).
    private var overPulseScale: CGFloat {
        guard state == .over, animating, !reduceMotion else { return 1 }
        return 1.04
    }

    private var overPulseAnimation: Animation? {
        guard state == .over, !reduceMotion else { return nil }
        return PulseMotion.overtimePulse
    }
}

#if DEBUG
#Preview("Signal Ring") {
    HStack(spacing: PulseSpacing.xl) {
        SignalRing(fraction: 0.62, timeText: "2:14")
        SignalRing(fraction: 0.05, timeText: "0:18")
        SignalRing(fraction: -0.2, timeText: "+0:23")
    }
    .padding(PulseSpacing.xxl)
    .frame(height: 180)
    .background(PulseColor.canvas)
    .preferredColorScheme(.dark)
}
#endif
