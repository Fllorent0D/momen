import SwiftUI

/// Pulse — the **end-of-standup achievement reveal** (#42).
///
/// When a standup wraps up and one or more badges have just been unlocked, this
/// view celebrates them: each badge enters BIG (an ``AchievementMedallion`` at
/// ~200pt, unlocked) on a spring, a tier-coloured halo bursts out behind it, and
/// a cross-platform confetti shower rains down. If several badges were earned at
/// once they are CHAINED — one is shown, then the next advances on a tap or after
/// a short auto-delay — and once the last is dismissed `onFinished` fires.
///
/// **SwiftUI only.** Everything here is pure SwiftUI — the confetti is a
/// `TimelineView(.animation)` + `Canvas` particle system, NOT the macOS-app
/// `ConfettiView` (which lives in the app target and may use AppKit). So the same
/// reveal compiles for the iOS full-screen cover and the future Mac panel from one
/// source of truth, with no `AppKit`/`UIKit`/`AVFoundation` dependency.
///
/// **Presentation only.** Sound and haptics are the platform caller's job — the
/// view stays free of `AVFoundation`/`UIKit`. As each badge appears it calls the
/// optional ``onBadgeShown`` so the caller can fire a buzz + chime in step.
///
/// **Accessibility.** When *Reduce Motion* is on, the spring, halo burst and
/// confetti are all dropped in favour of a calm cross-fade — the badge and its
/// text still read exactly the same.
///
///     BadgeRevealView(badges: manager.newlyUnlockedBadges) {
///         // all badges revealed → return to the finished screen
///     } onBadgeShown: { badge in
///         Haptics.success(); sound.playFinished()
///     }
public struct BadgeRevealView: View {

    private let badges: [Badge]
    private let onFinished: () -> Void
    private let onBadgeShown: ((Badge) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Which badge in the chain is currently on screen.
    @State private var index = 0
    /// Drives the medallion + text entrance (0 → 1) for the current badge.
    @State private var entered = false
    /// One-shot halo burst progress (0 → 1) for the current badge.
    @State private var haloProgress: Double = 0

    /// Seconds each badge stays up before auto-advancing.
    private let autoAdvanceDelay: Duration = .seconds(3)

    /// - Parameters:
    ///   - badges: The newly-unlocked badges to celebrate, in reveal order.
    ///   - onFinished: Called once the last badge has been dismissed.
    ///   - onBadgeShown: Called as each badge appears, so the platform caller can
    ///     fire sound + haptics in step (the view itself stays media-free).
    public init(
        badges: [Badge],
        onFinished: @escaping () -> Void = {},
        onBadgeShown: ((Badge) -> Void)? = nil
    ) {
        self.badges = badges
        self.onFinished = onFinished
        self.onBadgeShown = onBadgeShown
    }

    public var body: some View {
        ZStack {
            // A near-opaque canvas scrim so the reveal fully covers whatever sits
            // beneath it (the iOS finished screen / the Mac overlay later).
            PulseColor.canvas.color(for: colorScheme)
                .opacity(0.97)
                .ignoresSafeArea()

            if let badge = currentBadge {
                // Confetti rains behind the medallion (skipped under Reduce Motion).
                if !reduceMotion {
                    ConfettiBurst(colors: confettiPalette(for: badge), seed: index)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .id(index) // fresh burst per badge in the chain
                }

                content(for: badge)
                    .padding(PulseSpacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A tap anywhere advances to the next badge / dismisses the reveal.
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        // Present the current badge: reset its entrance, notify the caller (for
        // sound + haptics), animate it in, then auto-advance after a beat. Keyed on
        // `index` so it re-runs — fresh entrance + burst — for each chained badge,
        // and is cancelled automatically if the user taps to advance early.
        .task(id: index) {
            guard let badge = currentBadge else { return }
            entered = false
            haloProgress = 0
            onBadgeShown?(badge)
            // Let the reset frame render before animating, so the entrance always
            // plays from scratch for every badge in the chain.
            await Task.yield()
            if reduceMotion {
                withAnimation(.easeOut(duration: PulseDuration.quick)) { entered = true }
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.56)) { entered = true }
                withAnimation(.easeOut(duration: PulseDuration.quick)) { haloProgress = 1 }
            }
            try? await Task.sleep(for: autoAdvanceDelay)
            if !Task.isCancelled { advance() }
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Chain

    private var currentBadge: Badge? {
        badges.indices.contains(index) ? badges[index] : nil
    }

    /// Move to the next badge, or finish once the last one is dismissed. Mutating
    /// `index` restarts the `.task(id:)` above, which re-plays the entrance.
    private func advance() {
        if index + 1 < badges.count {
            index += 1
        } else {
            onFinished()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for badge: Badge) -> some View {
        let tint = badge.tier.medallionColor.color(for: colorScheme)

        VStack(spacing: PulseSpacing.xl) {
            Text("Badge débloqué !", bundle: .standupKit)
                .pulseText(.label)
                .foregroundStyle(tint)
                .opacity(entered ? 1 : 0)

            ZStack {
                haloBurst(tint: tint)
                AchievementMedallion(badge: badge, unlocked: true, size: 200, reveal: true)
                    .scaleEffect(reduceMotion ? 1 : (entered ? 1 : 0.4))
                    .opacity(entered ? 1 : 0)
            }
            .frame(width: 240, height: 240)

            VStack(spacing: PulseSpacing.sm) {
                Text(badge.title)
                    .pulseText(.title)
                    .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                    .multilineTextAlignment(.center)

                Text(badge.subtitle)
                    .pulseText(.bodyLarge)
                    .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                    .multilineTextAlignment(.center)

                tierLabel(badge, tint: tint)
                    .padding(.top, PulseSpacing.xxs)
            }
            .opacity(entered ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (entered ? 0 : 12))

            if badges.count > 1 {
                pageDots(tint: tint)
                    .padding(.top, PulseSpacing.xs)
            }

            Text(index + 1 < badges.count
                 ? LocalizedStringKey("Touchez pour le suivant")
                 : LocalizedStringKey("Touchez pour continuer"),
                 bundle: .standupKit)
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                .opacity(entered ? 0.7 : 0)
                .padding(.top, PulseSpacing.sm)
        }
    }

    /// The tier pill under the title ("Rare", "Légendaire", …).
    private func tierLabel(_ badge: Badge, tint: Color) -> some View {
        Text(badge.tier.label.uppercased())
            .pulseText(.label)
            .foregroundStyle(tint)
            .padding(.horizontal, PulseSpacing.md)
            .padding(.vertical, PulseSpacing.xs)
            .background(
                Capsule().fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1)
            )
    }

    /// One dot per badge in the chain, the current one lit in the tier colour.
    private func pageDots(tint: Color) -> some View {
        HStack(spacing: PulseSpacing.xs) {
            ForEach(badges.indices, id: \.self) { i in
                Circle()
                    .fill(i == index ? tint : PulseColor.inkMuted.color(for: colorScheme).opacity(0.35))
                    .frame(width: 7, height: 7)
            }
        }
    }

    /// The expanding tier-coloured glow that bursts out behind the medallion as it
    /// lands. A one-shot: scales up while fading away. Suppressed under Reduce
    /// Motion (where `haloProgress` never animates, leaving it invisible anyway).
    private func haloBurst(tint: Color) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [tint.opacity(0.55), .clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                )
            )
            .scaleEffect(0.3 + haloProgress * 1.5)
            .opacity((1 - haloProgress) * 0.9)
            .blur(radius: 6)
            .allowsHitTesting(false)
    }

    /// Confetti tints: the badge's tier colour plus the Pulse accents, so the
    /// shower reads as "this tier" without a wall of one flat hue.
    private func confettiPalette(for badge: Badge) -> [Color] {
        [
            badge.tier.medallionColor.color(for: colorScheme),
            PulseColor.signal.color(for: colorScheme),
            PulseColor.warn.color(for: colorScheme),
            PulseColor.ink.color(for: colorScheme),
        ]
    }
}

// MARK: - Cross-platform confetti (pure SwiftUI)

/// A self-contained confetti shower drawn with `TimelineView(.animation)` driving
/// a `Canvas` particle system — no `AppKit`/`UIKit`, no external dependency, so it
/// runs identically on macOS and iOS. Each piece is launched upward from the
/// centre with a random spread, then arcs down under gravity while spinning and
/// fading. Particles are generated from a deterministic seed so every frame
/// recomputes the *same* shower from the elapsed time — the Canvas stays stateless.
private struct ConfettiBurst: View {

    let colors: [Color]
    let seed: Int

    /// Anchors elapsed time; set once when the burst is created (`.id` gives a
    /// fresh instance — and a fresh start — per badge in the chain).
    @State private var start = Date()

    /// How long the shower lasts before the Canvas goes empty.
    private let lifetime: Double = 2.6
    private let particleCount = 110

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed < lifetime else { return }

                var rng = SplitMix64(seed: UInt64(bitPattern: Int64(seed)) &+ 0x9E37)
                // Launch from a band across the upper-middle of the canvas.
                let originY = size.height * 0.42
                let gravity = 1500.0 // points / s²

                for _ in 0..<particleCount {
                    let originX = size.width * Double.random(in: 0.3...0.7, using: &rng)
                    let angle = Double.random(in: (-Double.pi * 0.85)...(-Double.pi * 0.15), using: &rng)
                    let speed = Double.random(in: 320...780, using: &rng)
                    let vx = cos(angle) * speed
                    let vy = sin(angle) * speed // negative = upward
                    let spin = Double.random(in: -6...6, using: &rng)
                    let phase = Double.random(in: 0...(2 * Double.pi), using: &rng)
                    let w = Double.random(in: 5...11, using: &rng)
                    let h = Double.random(in: 8...16, using: &rng)
                    let color = colors[Int.random(in: 0..<colors.count, using: &rng)]

                    let x = originX + vx * elapsed
                    let y = originY + vy * elapsed + 0.5 * gravity * elapsed * elapsed

                    // Fade out over the last third of the lifetime.
                    let fade = max(0, min(1, (lifetime - elapsed) / (lifetime * 0.4)))
                    guard fade > 0 else { continue }

                    var piece = context
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(phase + spin * elapsed))
                    let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                    piece.fill(
                        Path(roundedRect: rect, cornerRadius: 1.5),
                        with: .color(color.opacity(fade))
                    )
                }
            }
        }
    }
}

// MARK: - Deterministic RNG

/// A tiny SplitMix64 generator — pure integer arithmetic, no Foundation/AppKit —
/// so the confetti shower is reproducible frame-to-frame from a single seed.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Badge Reveal — chain") {
    let badges = [
        BadgeCatalog.badge(id: "cent_standups"),   // legendary
        BadgeCatalog.badge(id: "serie_10j"),       // rare
        BadgeCatalog.badge(id: "premier_standup"), // common
    ].compactMap { $0 }

    return BadgeRevealView(badges: badges)
        .preferredColorScheme(.dark)
}
#endif
