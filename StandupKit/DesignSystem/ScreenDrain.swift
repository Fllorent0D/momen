import SwiftUI

/// Pulse — « Le Signal » — the full-screen **drain**.
///
/// Where the ``SignalRing`` (#46) makes a single element *feel* the time, the
/// drain makes the **whole screen** feel it: a colour fills the canvas and
/// *empties* as the current speaker's slice runs out, exactly like the Mac
/// ribbon's "bandeau qui se vide" but blown up to a phone-on-the-table focus
/// screen (#13). The fill rides the same signal spectrum — calm green while
/// comfortable, amber in the last seconds (``SignalRing/SignalState/warn``),
/// and a solid breathing **red** the moment the speaker is over.
///
/// So a turn never feels the same twice, the drain *empties in several
/// different ways*: ``Style`` enumerates seven distinct, well-animated emptying
/// effects, and ``Style/forSpeaker(_:)`` deterministically rotates through them
/// per speaker index — varied across the standup, stable within one turn.
///
///     ScreenDrain(fraction: 0.62,                    // 62 % of the slice left
///                 state: .normal,
///                 style: .forSpeaker(manager.currentSpeakerIndex))
///
/// It is platform-neutral (SwiftUI only — Canvas / Path / TimelineView, no
/// AppKit or UIKit) so it lives beside the other Pulse primitives, though only
/// the iOS focus screen uses it today. It reads `fraction`/`state` and owns no
/// timer logic; the caller maps the manager's remaining-time onto it.
///
/// Reduce-motion: every animated effect collapses to one calm, motion-free
/// rectangular fill — the screen still empties, nothing waves or pulses.
public struct ScreenDrain: View {

    /// The seven emptying effects. Backed by `Int` and `CaseIterable` so a
    /// speaker index can pick one deterministically via ``forSpeaker(_:)``.
    public enum Style: Int, CaseIterable, Sendable {
        /// The fill recedes from the top downward — the screen empties top→bottom,
        /// the colour draining to a flat, glowing surface at the bottom.
        case verticalFall
        /// A full-screen colour disc that shrinks toward the centre as time runs out.
        case radialCollapse
        /// A transparent hole opens at the centre and grows outward, revealing the
        /// dark canvas underneath.
        case radialReveal
        /// The fill recedes right→left, leaving a bright vertical receding edge.
        case horizontalWipe
        /// A draining tank: the fill sits at the bottom and lowers, its surface a
        /// gentle animated sine with a few rising bubbles.
        case bottomTide
        /// A vivid sloshing liquid — a tall, fast wave with a glossy crest and
        /// bubbles — that drops as the slice empties.
        case liquidWave
        /// The fill dissolves as a grid of cells fading out pseudo-randomly.
        case dissolve

        /// Deterministically maps a speaker index onto a style, wrapping with
        /// `allCases`, so each turn gets a different — but, within the turn,
        /// stable — drain. Negative indices are handled.
        public static func forSpeaker(_ index: Int) -> Style {
            let all = Style.allCases
            let n = all.count
            return all[((index % n) + n) % n]
        }
    }

    /// Fraction of the speaker's slice still remaining, `1` (full) → `0` (empty).
    /// Clamped on init. The caller passes `1` while counting in and `1` in
    /// overtime (paired with ``SignalRing/SignalState/over``) so the screen
    /// refills solid red.
    private let fraction: Double
    /// The signal state — drives the colour (green / amber / red) and, when
    /// ``SignalRing/SignalState/over``, the whole-screen breathing pulse.
    private let state: SignalRing.SignalState
    /// Which emptying effect to render.
    private let style: Style

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(fraction: Double, state: SignalRing.SignalState, style: Style) {
        self.fraction = min(max(fraction, 0), 1)
        self.state = state
        self.style = style
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if reduceMotion {
                // Reduce-motion: one calm fill, no wave / particle / pulse.
                reducedDrain(size)
            } else {
                // Everything else is driven off a display-linked clock so the
                // wavy surfaces and the overtime breath are frame-smooth.
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    effect(in: size, t: t)
                        .opacity(overBreath(t))
                        // Smooth the 0.1 s timer steps into a continuous slide for
                        // the shape-based effects (Canvas effects read `fraction`
                        // live, so this is a no-op for them).
                        .animation(.linear(duration: 0.18), value: fraction)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Effects

    @ViewBuilder
    private func effect(in size: CGSize, t: Double) -> some View {
        switch style {
        case .verticalFall:   verticalFall(size)
        case .radialCollapse: radialCollapse(size)
        case .radialReveal:   radialReveal(size)
        case .horizontalWipe: horizontalWipe(size)
        case .bottomTide:     bottomTide(size, t: t)
        case .liquidWave:     liquidWave(size, t: t)
        case .dissolve:       dissolve(size)
        }
    }

    /// verticalFall — a bottom-anchored block of height `fraction · H`, the
    /// emptiness falling from the top. A soft feathered top with a bright
    /// receding line reads the surface at a glance.
    private func verticalFall(_ size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            Color.clear
            Rectangle()
                .fill(fillGradient)
                .overlay(alignment: .top) {
                    // Feathered fade + crisp highlight at the receding edge.
                    ZStack(alignment: .top) {
                        LinearGradient(colors: [tint.opacity(0), tint.opacity(0.85)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 30)
                        Rectangle().fill(highlight).frame(height: 2)
                    }
                }
                .frame(height: size.height * fraction)
        }
        .frame(width: size.width, height: size.height, alignment: .bottom)
    }

    /// radialCollapse — a centred colour disc, radius `fraction · maxR` (with
    /// `maxR` reaching the corners at full), shrinking toward the centre.
    private func radialCollapse(_ size: CGSize) -> some View {
        let maxR = hypot(size.width, size.height) / 2
        let r = max(maxR * fraction, 0.5)
        return Circle()
            .fill(RadialGradient(gradient: Gradient(colors: [tintBright, tintDeep]),
                                 center: .center, startRadius: 0, endRadius: r))
            .overlay(
                Circle().stroke(highlight, lineWidth: 2).blur(radius: 3).opacity(0.6)
            )
            .frame(width: r * 2, height: r * 2)
            .frame(width: size.width, height: size.height)
    }

    /// radialReveal — full-screen fill with a centred transparent hole of radius
    /// `(1 − fraction) · maxR` that grows outward, opening onto the dark canvas.
    private func radialReveal(_ size: CGSize) -> some View {
        let maxR = hypot(size.width, size.height) / 2
        let holeR = max(maxR * (1 - fraction), 0.5)
        return Rectangle()
            .fill(fillGradient)
            .frame(width: size.width, height: size.height)
            .mask {
                ZStack {
                    Rectangle().fill(.white)
                    // Punch a soft-edged hole that grows as time empties.
                    Circle()
                        .frame(width: holeR * 2, height: holeR * 2)
                        .blur(radius: 8)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
    }

    /// horizontalWipe — a trailing-anchored block of width `fraction · W`; the
    /// emptiness grows from the left, a bright vertical line at the receding edge.
    private func horizontalWipe(_ size: CGSize) -> some View {
        ZStack(alignment: .trailing) {
            Color.clear
            Rectangle()
                .fill(LinearGradient(colors: [tintDeep, tintBright],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(alignment: .leading) {
                    ZStack(alignment: .leading) {
                        LinearGradient(colors: [tint.opacity(0), tint.opacity(0.85)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 30)
                        Rectangle().fill(highlight).frame(width: 2)
                    }
                }
                .frame(width: size.width * fraction)
        }
        .frame(width: size.width, height: size.height, alignment: .trailing)
    }

    /// bottomTide — a calm draining tank: a low-amplitude animated sine surface
    /// at `(1 − fraction) · H`, with a few slowly rising bubble highlights.
    private func bottomTide(_ size: CGSize, t: Double) -> some View {
        Canvas { ctx, sz in
            let baseY = sz.height * (1 - fraction)
            let shapes = waveShapes(in: sz, baseY: baseY, t: t,
                                    amp: 7, wavelength: sz.width * 0.85,
                                    speed: 1.4, secondary: true)
            ctx.fill(shapes.fill,
                     with: .linearGradient(Gradient(colors: [tintBright, tintDeep]),
                                           startPoint: CGPoint(x: 0, y: baseY - 12),
                                           endPoint: CGPoint(x: 0, y: sz.height)))
            drawBubbles(in: &ctx, sz: sz, baseY: baseY, t: t, count: 3, rise: 24)
        }
    }

    /// liquidWave — a vivid slosh: a tall, fast two-harmonic wave with a glossy
    /// white crest stroke and lively bubbles, dropping as the slice empties.
    private func liquidWave(_ size: CGSize, t: Double) -> some View {
        Canvas { ctx, sz in
            let baseY = sz.height * (1 - fraction)
            let shapes = waveShapes(in: sz, baseY: baseY, t: t,
                                    amp: 18, wavelength: sz.width * 0.6,
                                    speed: 2.4, secondary: true)
            ctx.fill(shapes.fill,
                     with: .linearGradient(Gradient(colors: [tintBright, tintDeep]),
                                           startPoint: CGPoint(x: 0, y: baseY - 20),
                                           endPoint: CGPoint(x: 0, y: sz.height)))
            ctx.stroke(shapes.surface, with: .color(.white.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            drawBubbles(in: &ctx, sz: sz, baseY: baseY, t: t, count: 5, rise: 40)
        }
    }

    /// dissolve — a grid of cells, each with a fixed pseudo-random threshold;
    /// a cell fades out once `fraction` drops below its threshold, so the screen
    /// dissolves away in a stable, scattered pattern as time empties.
    private func dissolve(_ size: CGSize) -> some View {
        Canvas { ctx, sz in
            let cols = 11
            let cell = sz.width / CGFloat(cols)
            let rows = max(1, Int((sz.height / cell).rounded(.up)))
            let rowH = sz.height / CGFloat(rows)
            for r in 0..<rows {
                for c in 0..<cols {
                    let threshold = cellThreshold(c, r)
                    // Present (a→1) while there's more time left than the cell's
                    // threshold; fades over a soft band as `fraction` crosses it.
                    let a = smoothstep(threshold, threshold + 0.10, fraction)
                    if a <= 0.01 { continue }
                    let rect = CGRect(x: CGFloat(c) * cell + 1.5,
                                      y: CGFloat(r) * rowH + 1.5,
                                      width: cell - 3, height: rowH - 3)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 4),
                             with: .color(tint.opacity(0.92 * a)))
                }
            }
        }
    }

    /// Reduce-motion fallback shared by every style: one calm bottom-anchored
    /// fill, eased on `fraction`, with no continuous animation.
    private func reducedDrain(_ size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            Color.clear
            Rectangle()
                .fill(fillGradient)
                .frame(height: size.height * fraction)
        }
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .animation(.easeInOut(duration: 0.3), value: fraction)
    }

    // MARK: - Wave + bubble helpers

    /// Builds both the closed fill polygon and the bare top polyline for a
    /// sine surface, so an effect can fill the body and stroke a glossy crest
    /// from the *same* curve. `secondary` adds a faster, smaller harmonic.
    private func waveShapes(in sz: CGSize, baseY: CGFloat, t: Double,
                            amp: CGFloat, wavelength: CGFloat,
                            speed: Double, secondary: Bool) -> (fill: Path, surface: Path) {
        func y(at x: CGFloat) -> CGFloat {
            let phase = Double(x) / Double(max(wavelength, 1)) * 2 * .pi
            var d = sin(phase + t * speed) * Double(amp)
            if secondary { d += sin(phase * 1.7 - t * speed * 0.6) * Double(amp) * 0.4 }
            return baseY + CGFloat(d)
        }
        var surface = Path()
        surface.move(to: CGPoint(x: 0, y: y(at: 0)))
        var x: CGFloat = 0
        let step: CGFloat = 5
        while x <= sz.width {
            surface.addLine(to: CGPoint(x: x, y: y(at: x)))
            x += step
        }
        surface.addLine(to: CGPoint(x: sz.width, y: y(at: sz.width)))

        var fill = surface
        fill.addLine(to: CGPoint(x: sz.width, y: sz.height))
        fill.addLine(to: CGPoint(x: 0, y: sz.height))
        fill.closeSubpath()
        return (fill, surface)
    }

    /// A handful of faint highlight bubbles drifting up through the fill. Their
    /// columns are spread evenly and their vertical drift is `t`-driven so they
    /// loop within the filled region above `baseY`.
    private func drawBubbles(in ctx: inout GraphicsContext, sz: CGSize,
                             baseY: CGFloat, t: Double, count: Int, rise: Double) {
        guard baseY < sz.height - 4 else { return }
        let span = sz.height - baseY
        for i in 0..<count {
            let fx = (Double(i) + 0.5) / Double(count)
            let x = CGFloat(fx) * sz.width + CGFloat(sin(t * 0.7 + Double(i)) * 10)
            // Loop the bubble from the floor up to just under the surface.
            let phase = (t * rise / Double(max(span, 1)) + fx * 1.7)
                .truncatingRemainder(dividingBy: 1)
            let y = sz.height - CGFloat(phase) * (span - 6) - 6
            let radius = CGFloat(3 + (i % 3))
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            let fade = 1 - phase            // dimmer as it nears the surface
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.16 * fade)))
        }
    }

    // MARK: - Overtime breath

    /// Whole-screen opacity pulse while over the limit — the drain has refilled
    /// solid red (caller passes `fraction == 1`), and this breathes it ~1 s,
    /// matching the ring's overtime pulse. Steady `1` otherwise.
    private func overBreath(_ t: Double) -> Double {
        guard state == .over else { return 1 }
        let s = 0.5 + 0.5 * sin(t * 2 * .pi / PulseDuration.base)
        return 0.74 + 0.26 * s
    }

    // MARK: - Colour tokens

    private var tint: Color {
        switch state {
        case .normal: return PulseColor.signal.color(for: colorScheme)
        case .warn:   return PulseColor.warn.color(for: colorScheme)
        case .over:   return PulseColor.over.color(for: colorScheme)
        }
    }

    private var tintBright: Color { tint.opacity(0.95) }
    private var tintDeep: Color { tint.opacity(0.74) }
    private var highlight: Color { Color.white.opacity(0.7) }

    private var fillGradient: LinearGradient {
        LinearGradient(colors: [tintBright, tintDeep], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Dissolve maths

    /// Smooth `0→1` ramp between `a` and `b` (Hermite). Used so dissolve cells
    /// fade across a soft band rather than snapping.
    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        guard b > a else { return x >= b ? 1 : 0 }
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// A fixed pseudo-random `0…1` per grid cell (classic hash-of-sine), so the
    /// dissolve pattern is scattered yet identical every frame for a given size.
    private func cellThreshold(_ c: Int, _ r: Int) -> Double {
        let n = sin(Double(c) * 127.1 + Double(r) * 311.7) * 43758.5453
        return n - floor(n)
    }
}

#if DEBUG
#Preview("Screen Drain") {
    ScreenDrain(fraction: 0.55, state: .normal, style: .liquidWave)
        .background(PulseColor.canvas)
        .preferredColorScheme(.dark)
}
#endif
