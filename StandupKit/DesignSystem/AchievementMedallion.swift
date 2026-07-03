import SwiftUI

/// Pulse — the **achievement medallion**.
///
/// A faithful SwiftUI port of `Standup timer multiplateforme/Medallion.dc.html`:
/// a single, tier-aware view that renders one badge as a circular medallion drawn
/// **100 % procedurally** — no per-badge PNG artwork. It is the shared visual atom
/// for every badge surface: the end-of-standup reveal (#42, large ~200pt), the
/// Stats grid (#43, small ~64pt) and any future inline chip. SwiftUI only — no
/// `AppKit`/`UIKit` — so the Mac panel and the iOS full-screen reveal draw from one
/// source of truth.
///
/// **Anatomy** (mirrors the design):
/// - **ring** — a conic "brushed metal" gradient whose colour *encodes the tier*;
/// - **rim / inner hair** — lit-bezel highlights;
/// - **disc** — a hollowed night well so the glyph reads as engraved;
/// - **glyph** — the badge's SF Symbol, engraved into the disc and tinted by the metal;
/// - **halo + shimmer** — radial glow and a rotating sweep, shown at *reveal* only.
///
/// **States.** `.unlocked` shows full tier metal. `.locked` swaps in a graphite
/// palette (built-in desaturation) and draws a green **progress arc** (X/N).
/// `.secret` shows a dead iridescent ring and a "?" in place of the glyph.
///
///     AchievementMedallion(badge: badge, unlocked: true)                   // 96pt grid
///     AchievementMedallion(badge: badge, unlocked: true, size: 200, reveal: true) // reveal
///     AchievementMedallion(glyph: .trophy, tier: .legendary, state: .unlocked, size: 150)
///
/// Everything is drawn in a 200×200 base space and scaled to `size`, matching the
/// design's `scale(size/200)`. No raw hex escapes the metal palette.
public struct AchievementMedallion: View {

    /// The three medallion states from the design (`unlocked` / `locked` / `secret`).
    public enum MedallionState: Sendable { case unlocked, locked, secret }

    private let symbol: String
    private let tier: BadgeTier
    private let state: MedallionState
    private let progress: Double
    private let size: CGFloat
    private let showHalo: Bool
    private let showShimmer: Bool
    private let a11yLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the rotating shimmer sweep (reveal only).
    @State private var sweep = false
    /// Drives the halo's breathing glow (reveal only).
    @State private var glowing = false

    private static let base: CGFloat = 200        // design coordinate space

    /// Designer-facing initializer — full control over the SF Symbol, tier, state
    /// and flourishes.
    public init(
        systemName: String,
        tier: BadgeTier,
        state: MedallionState,
        progress: Double = 0,
        size: CGFloat = 150,
        halo: Bool = false,
        shimmer: Bool = false
    ) {
        self.symbol = systemName
        self.tier = tier
        self.state = state
        self.progress = max(0, min(1, progress))
        self.size = size
        self.showHalo = halo
        self.showShimmer = shimmer
        self.a11yLabel = "\(tier.label)"
    }

    /// Badge convenience — the API every existing call site uses. Maps `unlocked`
    /// plus the badge's secrecy into a ``MedallionState`` and pulls the glyph/tier
    /// from the badge. Pass `reveal: true` to light up the halo + shimmer.
    /// - Parameters:
    ///   - badge: The achievement to render.
    ///   - unlocked: `true` shows full tier metal; `false` → graphite (or "?" if secret).
    ///   - size: Diameter in points (default `96`). Everything scales from this.
    ///   - progress: 0…1 toward unlock — draws the green arc when locked.
    ///   - reveal: Enables the halo + shimmer flourish (end-of-standup reveal).
    public init(badge: Badge, unlocked: Bool, size: CGFloat = 96, progress: Double = 0, reveal: Bool = false) {
        self.symbol = badge.systemImage
        self.tier = badge.tier
        self.state = (badge.isSecret && !unlocked) ? .secret : (unlocked ? .unlocked : .locked)
        self.progress = max(0, min(1, progress))
        self.size = size
        self.showHalo = reveal
        self.showShimmer = reveal
        let stateLabel = unlocked
            ? String(localized: "débloqué", bundle: .standupKit)
            : String(localized: "verrouillé", bundle: .standupKit)
        self.a11yLabel = (badge.isSecret && !unlocked)
            ? String(localized: "Badge secret verrouillé", bundle: .standupKit)
            : "\(badge.title), \(badge.tier.label), \(stateLabel)"
    }

    public var body: some View {
        let metal = Metal.resolve(tier: tier, state: state)

        ZStack {
            if showHalo && state != .secret { haloLayer(metal) }
            ringLayer(metal)
            rimLayer
            innerHairLayer(metal)
            discLayer
            if showShimmer && state != .secret { shimmerLayer }
            if state == .locked { progressLayer }

            if state == .secret {
                secretMark
            } else {
                glyphLayer(metal)
            }
        }
        .frame(width: Self.base, height: Self.base)
        .scaleEffect(size / Self.base)
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            if showShimmer {
                withAnimation(.linear(duration: PulseDuration.glow).repeatForever(autoreverses: false)) { sweep = true }
            }
            if showHalo {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { glowing = true }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(a11yLabel)
    }

    // MARK: - Layers (drawn in the 200×200 base space)

    /// Soft tier-coloured glow bleeding out behind the disc; breathes at reveal.
    private func haloLayer(_ m: Metal) -> some View {
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(colors: [m.halo.opacity(0.4), .clear]),
                center: .center, startRadius: 0, endRadius: Self.base * 0.6
            ))
            .padding(-22)
            .blur(radius: 5)
            .opacity(glowing ? 1 : 0.45)
            .allowsHitTesting(false)
    }

    /// The metal bezel — a conic gradient whose hue encodes the tier.
    private func ringLayer(_ m: Metal) -> some View {
        Circle()
            .fill(m.ring)
            .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.22), lineWidth: 1))
    }

    /// A top-left → bottom-right sheen so the ring reads as a lit bezel.
    private var rimLayer: some View {
        Circle()
            .fill(LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white.opacity(0.5), location: 0),
                    .init(color: .clear, location: 0.34),
                    .init(color: .clear, location: 0.64),
                    .init(color: .black.opacity(0.3), location: 1),
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .allowsHitTesting(false)
    }

    /// The faint inner hairline between bezel and disc.
    private func innerHairLayer(_ m: Metal) -> some View {
        Circle()
            .strokeBorder(m.rimMid.opacity(0.33), lineWidth: 2)
            .padding(27)
            .allowsHitTesting(false)
    }

    /// The hollowed night well the glyph sits in.
    private var discLayer: some View {
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(colors: [Color(pulseHex: 0x15181D), Color(pulseHex: 0x0A0B0D)]),
                center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: Self.base * 0.45
            ))
            .padding(30)
            .overlay(
                Circle().stroke(Color.black.opacity(0.5), lineWidth: 2).padding(30)
            )
            .shadow(color: .black.opacity(0.6), radius: 0)
    }

    /// Green progress arc riding the outer edge (locked state only).
    private var progressLayer: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(Color(pulseHex: 0x00E08A), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(3)
            .shadow(color: Color(pulseHex: 0x00E08A, opacity: 0.6), radius: 5)
            .allowsHitTesting(false)
    }

    /// Rotating highlight that sweeps the disc during a reveal.
    private var shimmerLayer: some View {
        Circle()
            .fill(AngularGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.18),
                    .init(color: .white.opacity(0.9), location: 0.25),
                    .init(color: .clear, location: 0.32),
                    .init(color: .clear, location: 1),
                ]),
                center: .center
            ))
            .rotationEffect(.degrees(sweep ? 360 : 0))
            .padding(30)
            .mask(Circle().padding(30))
            .allowsHitTesting(false)
    }

    /// The badge's SF Symbol, engraved into the disc and tinted with the metal so it
    /// reads as struck from the same material as the ring.
    private func glyphLayer(_ m: Metal) -> some View {
        Image(systemName: symbol)
            .font(.system(size: Self.base * 0.3, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(LinearGradient(
                colors: [m.gHi, m.gLo],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .shadow(color: .black.opacity(0.55), radius: 2, y: 2)
            .frame(width: 96, height: 96)
            .position(x: 100, y: 100)
    }

    /// The "?" shown for an as-yet-unearned secret badge.
    private var secretMark: some View {
        Text(verbatim: "?")
            .font(.custom(PulseFontFamily.mono, size: 58).weight(.heavy))
            .foregroundStyle(Color(pulseHex: 0x5F6B78))
            .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
            .position(x: 100, y: 100)
    }
}

// MARK: - Metal palette

/// The resolved "metal" for a medallion: its conic ring gradient plus the four inks
/// the bezel, hairline and glyph draw from. Ported verbatim from the tier tables in
/// `Medallion.dc.html` (`T`, plus the locked/secret overrides).
private struct Metal {
    let ring: AngularGradient
    let rimMid: Color
    let halo: Color
    let gHi: Color
    let gLo: Color
    let gMid: Color

    /// Builds a conic `AngularGradient` from `(hex, degree)` stops and a CSS
    /// `from` angle. CSS conic 0° sits at the top; SwiftUI's at 3 o'clock — hence −90.
    static func conic(_ stops: [(UInt32, Double)], from: Double) -> AngularGradient {
        let gradient = Gradient(stops: stops.map {
            Gradient.Stop(color: Color(pulseHex: $0.0), location: $0.1 / 360)
        })
        return AngularGradient(
            gradient: gradient, center: .center,
            startAngle: .degrees(from - 90), endAngle: .degrees(from - 90 + 360)
        )
    }

    static func resolve(tier: BadgeTier, state: AchievementMedallion.MedallionState) -> Metal {
        switch state {
        case .locked:
            return Metal(
                ring: conic([(0x3A3F46, 0), (0x23262B, 60), (0x15181C, 120), (0x33383F, 185),
                             (0x1C2024, 250), (0x2E333A, 312), (0x3A3F46, 360)], from: 218),
                rimMid: Color(pulseHex: 0x3C424A), halo: .black,
                gHi: Color(pulseHex: 0x555D66), gLo: Color(pulseHex: 0x2D333A), gMid: Color(pulseHex: 0x474E57))

        case .secret:
            return Metal(
                ring: conic([(0x123A2E, 0), (0x143A52, 72), (0x2A2148, 144),
                             (0x3A1E2E, 216), (0x3A3020, 288), (0x123A2E, 360)], from: 0),
                rimMid: Color(pulseHex: 0x39414B), halo: Color(pulseHex: 0x2A3550),
                gHi: Color(pulseHex: 0x525A63), gLo: Color(pulseHex: 0x2D333A), gMid: Color(pulseHex: 0x444B54))

        case .unlocked:
            return unlockedMetal(for: tier)
        }
    }

    private static func unlockedMetal(for tier: BadgeTier) -> Metal {
        switch tier {
        case .common: // bronze
            return metal([(0xF7D3A9, 0), (0xDD9D63, 38), (0x7C4621, 92), (0xF1BD8D, 150), (0xB06C30, 205),
                          (0xF7D3A9, 250), (0x86501F, 305), (0xE3A877, 345), (0xF7D3A9, 360)], from: 218,
                         hi: 0xF3C79B, lo: 0xB9763C, mid: 0xEAB488, halo: 0xE0904C)
        case .uncommon: // silver
            return metal([(0xFFFFFF, 0), (0xC6D0D8, 38), (0x6F7A83, 95), (0xEEF3F6, 150), (0x98A4AD, 205),
                          (0xFFFFFF, 250), (0x7B8690, 305), (0xDDE5EB, 345), (0xFFFFFF, 360)], from: 218,
                         hi: 0xF6FAFC, lo: 0xAAB6BF, mid: 0xE2E9EE, halo: 0xCDD6DD)
        case .rare: // gold
            return metal([(0xFFF4CF, 0), (0xE9C168, 38), (0x9A6F1C, 95), (0xFFE7A0, 150), (0xC8922C, 205),
                          (0xFFF4CF, 250), (0xA87A20, 305), (0xF3CD5E, 345), (0xFFF4CF, 360)], from: 218,
                         hi: 0xFFE9A8, lo: 0xCAA033, mid: 0xF7D774, halo: 0xF0C24B)
        case .legendary: // diamond
            return metal([(0xF4E9FF, 0), (0xCBA6FF, 38), (0x6A3FB0, 95), (0xE7D6FF, 150), (0x9A6AE0, 205),
                          (0xF4E9FF, 250), (0x7D4FD4, 305), (0xD9BFFF, 345), (0xF4E9FF, 360)], from: 218,
                         hi: 0xEDDFFF, lo: 0xA273EC, mid: 0xDCC6FF, halo: 0xB07CFF)
        case .secret: // iridescent
            return metal([(0x00E08A, 0), (0x36C2FF, 72), (0xB07CFF, 144), (0xFF5B8A, 216), (0xFFC53D, 288), (0x00E08A, 360)],
                         from: 0, hi: 0xFFFFFF, lo: 0xC8D0D6, mid: 0xEEF2F4, halo: 0xB07CFF)
        }
    }

    private static func metal(_ stops: [(UInt32, Double)], from: Double,
                              hi: UInt32, lo: UInt32, mid: UInt32, halo: UInt32) -> Metal {
        Metal(ring: conic(stops, from: from),
              rimMid: Color(pulseHex: mid), halo: Color(pulseHex: halo),
              gHi: Color(pulseHex: hi), gLo: Color(pulseHex: lo), gMid: Color(pulseHex: mid))
    }
}

// MARK: - Tier → medallion accent (reveal chrome)

public extension BadgeTier {
    /// A representative scheme-aware colour for a tier's medallion, used by the reveal
    /// (#42) for its title accent and burst tint. Built from existing Pulse tokens and
    /// the identity palette's jewels — no bespoke hex lives here twice.
    var medallionColor: PulseColor {
        switch self {
        case .common:    return .inkMuted                  // bronze reads discreet
        case .uncommon:  return .signal                    // Pulse green
        case .rare:      return .warn                      // gold
        case .legendary: return PulseAccent.medallionRare  // diamond violet
        case .secret:    return PulseAccent.medallionSecret
        }
    }
}

private extension PulseAccent {
    /// Violet from the identity palette for the legendary/diamond track.
    static var medallionRare: PulseColor {
        let violet = PulseAccent.color(for: 8)
        return PulseColor(dark: violet, light: violet)
    }

    /// Cool cyan from the identity palette for the secret track.
    static var medallionSecret: PulseColor {
        let cyan = PulseAccent.color(for: 1)
        return PulseColor(dark: cyan, light: cyan)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Achievement Medallion") {
    let samples: [Badge] = [
        BadgeCatalog.badge(id: "premier_standup"),   // common
        BadgeCatalog.badge(id: "dix_standups"),      // uncommon
        BadgeCatalog.badge(id: "serie_10j"),         // rare
        BadgeCatalog.badge(id: "cent_standups"),     // legendary
        BadgeCatalog.badge(id: "leve_tot"),          // secret
    ].compactMap { $0 }

    return ScrollView {
        VStack(spacing: PulseSpacing.xl) {
            VStack(spacing: PulseSpacing.sm) {
                Text("Débloqués").pulseText(.label).foregroundStyle(PulseColor.inkMuted)
                HStack(spacing: PulseSpacing.lg) {
                    ForEach(samples) { AchievementMedallion(badge: $0, unlocked: true, size: 88) }
                }
            }
            VStack(spacing: PulseSpacing.sm) {
                Text("Verrouillés").pulseText(.label).foregroundStyle(PulseColor.inkMuted)
                HStack(spacing: PulseSpacing.lg) {
                    ForEach(samples) { AchievementMedallion(badge: $0, unlocked: false, size: 88, progress: 0.35) }
                }
            }
            // Large reveal size with halo + shimmer.
            AchievementMedallion(badge: samples[3], unlocked: true, size: 200, reveal: true)
        }
        .padding(PulseSpacing.xxl)
    }
    .background(PulseColor.canvas)
    .preferredColorScheme(.dark)
}
#endif
