import SwiftUI
import StandupKit

/// Pulse — the Mac ambient overlay (#51).
///
/// Two reads of the same signal, picked by a minimal local toggle:
///
/// - **Banner** (default, *« le bandeau qui se vide »*): a full-width night bar
///   that *is* the chrono — a colour fill drains left→right as the speaker's
///   time elapses, riding the Pulse spectrum (signal → warn → over). A bright
///   leading edge marks the drain boundary, and a tinted veil washes the whole
///   bar in the final moments / overtime so the speaker + chrono stay legible at
///   three metres. This is the spec's recommended Mac ambient mode.
/// - **Ring** (*« le Signal »*): the shared `SignalRing` for a compact focus
///   read — the same arc + breathing halo + centre chrono.
///
/// Placement on screen is owned by `OverlayPanel` (it honours
/// `meeting.bannerPosition`); this view only renders content. Every colour,
/// radius, gap and type role comes from a Pulse token — no raw hex here.
struct OverlayView: View {
    @Environment(MeetingManager.self) private var manager

    enum OverlayMode { case banner, ring }
    @State private var mode: OverlayMode = .banner

    /// Fills the bar to full once overtime begins (the "bandeau plein" state).
    @State private var overtimeFill: Double = 0
    /// Drives the overtime veil's breathing opacity.
    @State private var breathe = false

    @State private var productivityQuote: String = ProductivityQuotes.random()

    /// Issue #42 — the badges to celebrate over the finished screen. Captured once
    /// when the standup transitions to `.finished` (from `manager.newlyUnlockedBadges`)
    /// and cleared when the reveal is dismissed, so the celebration shows exactly
    /// once per finish and we then fall back to the normal finished screen.
    @State private var revealBadges: [Badge] = []

    /// The macOS cue for a freshly-unlocked badge — fired by the reveal's per-badge
    /// callback (the shared reveal view stays media-free). No haptics on Mac.
    private let badgeSound = MacSoundPlayer()

    private let bannerWidth: CGFloat = 780
    private let ringWidth: CGFloat = 300

    // MARK: - Derived signal

    /// Time remaining as `1 → 0`, clamped (the bar's drain fraction).
    private var remainingFraction: Double {
        max(0, min(1, 1 - manager.progress))
    }

    /// The four-band signal state, shared with `SignalRing`.
    private var signalState: SignalRing.SignalState {
        manager.isOvertime ? .over : SignalRing.SignalState.forFraction(remainingFraction)
    }

    private var chronoText: String {
        manager.isOvertime
            ? TimeFormatter.formatOvertime(manager.elapsedOvertime)
            : TimeFormatter.format(manager.remainingTime)
    }

    private var nextSpeakerName: String? {
        let next = manager.currentSpeakerIndex + 1
        guard next < manager.activeParticipants.count else { return nil }
        return manager.activeParticipants[next].name
    }

    private var canMoveToEnd: Bool {
        manager.activeParticipants.count - manager.currentSpeakerIndex > 1
    }

    // MARK: - Body

    var body: some View {
        content
            // The overlay lives on the Pulse night surface regardless of system
            // appearance, so every token resolves to its dark variant.
            .environment(\.colorScheme, .dark)
            .animation(.easeInOut(duration: 0.5), value: manager.isOvertime)
            .onAppear { if manager.isOvertime { startOvertime() } }
            .onChange(of: manager.isOvertime) { _, isOvertime in
                if isOvertime { startOvertime() } else { overtimeFill = 0; breathe = false }
            }
            .onChange(of: manager.timerState) { _, newState in
                if newState == .finished {
                    productivityQuote = ProductivityQuotes.random()
                    // Issue #42: if this finish unlocked any badges, kick off the
                    // celebration over the finished screen. Captured once here; the
                    // empty case leaves `revealBadges` empty, so the reveal never shows.
                    if !manager.newlyUnlockedBadges.isEmpty {
                        revealBadges = manager.newlyUnlockedBadges
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if manager.isCountingDown {
            countdownContent
        } else if manager.timerState == .finished {
            finishedView
        } else if manager.isActive {
            activeContent
        }
    }

    @ViewBuilder
    private var activeContent: some View {
        switch mode {
        case .banner:
            bannerContent
                .frame(width: bannerWidth)
        case .ring:
            ringContent
        }
    }

    private func startOvertime() {
        overtimeFill = 0
        withAnimation(.easeOut(duration: 0.5)) { overtimeFill = 1.0 }
        breathe = false
        withAnimation(PulseMotion.overtimePulse) { breathe = true }
    }

    // MARK: - Banner « qui se vide »

    private var bannerContent: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let fillFraction = manager.isOvertime ? overtimeFill : remainingFraction
                let barWidth = geo.size.width * fillFraction

                ZStack(alignment: .leading) {
                    // Night surface revealed as the colour drains away.
                    RoundedRectangle(cornerRadius: PulseRadius.panel)
                        .fill(PulseColor.surface)

                    // Draining colour fill — a clean solid green ("vert plein"),
                    // turning solid red in overtime. A soft top sheen keeps it
                    // glossy rather than flat. The amber/red warning comes from
                    // the veil (below), so the bar stays one pretty hue instead
                    // of a muddy green→amber gradient. No per-fill clip: the
                    // drain (right) edge stays straight; the container's outer
                    // clipShape rounds the corners uniformly.
                    Rectangle()
                        .fill(fillColor)
                        .overlay(
                            LinearGradient(colors: [.white.opacity(0.10), .clear],
                                           startPoint: .top, endPoint: .center)
                        )
                        .frame(width: barWidth)

                    // Bright leading edge at the drain boundary.
                    if !manager.isOvertime, fillFraction > 0.01, fillFraction < 0.99 {
                        Rectangle()
                            .fill(PulseColor.ink)
                            .frame(width: 2)
                            .offset(x: barWidth - 1)
                            .shadow(color: fillColor, radius: 7)
                    }

                    // Tinted veil over the whole bar in the final moments /
                    // overtime — keeps the speaker + chrono readable.
                    if let veil = veilColor {
                        RoundedRectangle(cornerRadius: PulseRadius.panel)
                            .fill(veil)
                            .opacity(veilOpacity)
                            .animation(manager.isOvertime ? PulseMotion.overtimePulse : .easeInOut,
                                       value: breathe)
                    }

                    // Content ink flips at the drain boundary: DARK over the
                    // green fill, LIGHT over the drained night surface. In
                    // overtime the red fills the whole bar, so the dark region
                    // collapses to zero and everything reads light.
                    let darkWidth = manager.isOvertime ? 0 : barWidth

                    // 1 — BASE: the real, visible, INTERACTIVE row in light ink.
                    // This is what carries every button tap (no opacity/hit-test
                    // tricks). It reads correctly over the drained dark surface
                    // and over the red overtime fill.
                    bannerRow(tint: lightInk, onTint: darkInk)

                    // 2 — OVERLAY: a dark-ink copy masked to the green region,
                    // non-interactive (taps fall through to the base below). It
                    // visually replaces the light text with dark text wherever the
                    // green fill is present, flipping at the drain boundary. In
                    // overtime darkWidth = 0, so this layer disappears entirely.
                    bannerRow(tint: darkInk, onTint: lightInk)
                        .mask(alignment: .leading) {
                            HStack(spacing: 0) {
                                Color.black.frame(width: darkWidth)
                                Color.clear
                            }
                        }
                        .allowsHitTesting(false)
                }
                .animation(.linear(duration: 0.1), value: manager.progress)
                .animation(.easeOut(duration: 0.5), value: overtimeFill)
            }
            .frame(height: 72)
        }
        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.panel))
        // Crisp hairline for a premium, defined edge — reads as polished rather
        // than a flat coloured block (corporate-friendly).
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadius.panel)
                .strokeBorder(PulseColor.ink.color(for: .dark).opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }

    /// The bar fill — one clean hue: the signal green while running, solid red
    /// in overtime. The amber "approaching limit" warning is carried by the veil
    /// (not the fill), so the ribbon never muddies into a green→amber gradient.
    private var fillColor: Color {
        manager.isOvertime
            ? PulseColor.over.color(for: .dark)
            : PulseColor.signal.color(for: .dark)
    }

    /// The veil tint — amber as the bar nears empty, red in overtime; `nil`
    /// while there is still comfortable colour to read.
    private var veilColor: Color? {
        if manager.isOvertime { return PulseColor.over.color(for: .dark) }
        return remainingFraction <= 0.2 ? PulseColor.warn.color(for: .dark) : nil
    }

    private var veilOpacity: Double {
        if manager.isOvertime { return breathe ? 0.30 : 0.14 }
        guard remainingFraction <= 0.2 else { return 0 }
        // Fades in from 0 (at 20% left) to its strongest as the bar empties.
        return (1 - remainingFraction / 0.2) * 0.30
    }

    // MARK: - Banner content row (ink flips with the drain boundary)

    /// Near-black ink for text/icons sitting ON the green fill.
    private var darkInk: Color { PulseColor.ink.color(for: .light) }
    /// Near-white ink for text/icons on the drained night surface (and red overtime).
    private var lightInk: Color { PulseColor.ink.color(for: .dark) }

    /// The banner's content, tinted by `tint` so it can be drawn twice — once
    /// dark (masked to the green fill) and once light (masked to the drained
    /// area). `onTint` is the contrasting ink used for text sitting on a
    /// `tint`-filled pill (the "Suivant" CTA).
    private func bannerRow(tint: Color, onTint: Color) -> some View {
        HStack(spacing: PulseSpacing.md) {
            circleButton("chevron.left", tint: tint, enabled: manager.currentSpeakerIndex > 0) {
                manager.previousSpeaker()
            }

            if let participant = manager.currentParticipant {
                AvatarView(participant: participant, size: 40)
                    .id(participant.name)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.snappy(duration: 0.35), value: manager.currentSpeakerIndex)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let participant = manager.currentParticipant {
                    Text(participant.name)
                        .pulseText(.heading)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .id(participant.name)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                Text(nextSpeakerName.map { "SUIVANT  \($0)" } ?? "DERNIER INTERVENANT")
                    .pulseText(.label)
                    .foregroundStyle(tint.opacity(0.7))
                    .lineLimit(1)
            }
            .animation(.snappy(duration: 0.35), value: manager.currentSpeakerIndex)

            Spacer(minLength: PulseSpacing.sm)

            VStack(spacing: 1) {
                Text("TOTAL").pulseText(.label).foregroundStyle(tint.opacity(0.7))
                Text(TimeFormatter.format(manager.totalElapsed))
                    .pulseText(.mono).foregroundStyle(tint.opacity(0.7))
            }

            Text(chronoText)
                .pulseText(.chronoCompact)
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText(countsDown: !manager.isOvertime))
                .animation(.snappy(duration: 0.3),
                           value: manager.isOvertime ? Int(manager.elapsedOvertime) : Int(manager.remainingTime))

            circleButton(manager.isPaused ? "play.fill" : "pause.fill", tint: tint, filled: true) {
                manager.togglePause()
            }

            if canMoveToEnd {
                circleButton("arrow.uturn.down", tint: tint, filled: true) { manager.moveCurrentToEnd() }
                    .help("Reporter à la fin")
            }

            Button { manager.nextSpeaker() } label: {
                HStack(spacing: PulseSpacing.xxs) {
                    Text("Suivant").pulseText(.callout)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(onTint)
                .padding(.horizontal, PulseSpacing.md).padding(.vertical, PulseSpacing.sm)
                .background(tint, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PulseSpacing.lg)
    }

    /// A round icon control, tinted to flip with the drain boundary.
    private func circleButton(_ symbol: String, tint: Color = PulseColor.ink.color(for: .dark),
                              enabled: Bool = true,
                              filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? tint : tint.opacity(0.25))
                .frame(width: 38, height: 38)
                .background(tint.opacity(filled ? 0.16 : (enabled ? 0.12 : 0.05)), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Ring « le Signal »

    private var ringContent: some View {
        VStack(spacing: PulseSpacing.md) {
            SignalRing(fraction: manager.isOvertime ? -0.1 : remainingFraction,
                       timeText: chronoText,
                       state: signalState)
                .frame(width: 150, height: 150)

            if let participant = manager.currentParticipant {
                Text(participant.name)
                    .pulseText(.heading)
                    .foregroundStyle(PulseColor.ink)
                    .lineLimit(1)
                    .id(participant.name)
                    .transition(.opacity)
                    .animation(.snappy(duration: 0.35), value: manager.currentSpeakerIndex)
            }

            Text(nextSpeakerName.map { "SUIVANT  \($0)" } ?? "DERNIER INTERVENANT")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted)
                .lineLimit(1)

            HStack(spacing: PulseSpacing.sm) {
                circleButton("chevron.left", enabled: manager.currentSpeakerIndex > 0) {
                    manager.previousSpeaker()
                }
                circleButton(manager.isPaused ? "play.fill" : "pause.fill", filled: true) {
                    manager.togglePause()
                }
                if canMoveToEnd {
                    circleButton("arrow.uturn.down", filled: true) { manager.moveCurrentToEnd() }
                        .help("Reporter à la fin")
                }
                circleButton("chevron.right", filled: true) { manager.nextSpeaker() }
            }
        }
        .padding(PulseSpacing.xl)
        .frame(width: ringWidth)
        .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: PulseRadius.panel))
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
    }

    // MARK: - Countdown 3-2-1

    private var countdownContent: some View {
        Text("\(manager.countdownValue)")
            .pulseText(.chrono)
            .minimumScaleFactor(0.4)
            .foregroundStyle(PulseColor.canvas)
            .frame(width: 120, height: 120)
            .background(PulseColor.signal, in: Circle())
            .shadow(color: PulseColor.signal.color(for: .dark).opacity(0.5), radius: 20)
            .contentTransition(.numericText())
            .animation(.bouncy(duration: 0.4), value: manager.countdownValue)
    }

    // MARK: - Finished with summary

    /// The finished screen, with the achievement reveal (#42) layered ON TOP as a
    /// centered, enlarged panel when this finish unlocked badges. The reveal is a
    /// ZStack sibling (not an `.overlay`) so the floating panel grows to its larger
    /// frame — *« panneau centré agrandi »* — and shrinks back once dismissed. The
    /// normal finished content (icon + quote + summary + copy + confetti) stays
    /// intact underneath and is what remains after the reveal clears itself.
    private var finishedView: some View {
        // Pin to the top: the panel measures its live content and re-anchors to
        // the screen corner, so a default (centered) ZStack would shove the
        // finished content downward the moment the taller reveal appears — the
        // "finished page moves when I earn a badge" bug. Top alignment keeps the
        // finished content at the same anchored spot; the reveal grows downward.
        ZStack(alignment: .top) {
            finishedContent.frame(width: bannerWidth)

            if !revealBadges.isEmpty {
                BadgeRevealView(badges: revealBadges) {
                    // All badges revealed → drop back to the normal finished screen
                    // (the existing auto-return / summary flow continues underneath).
                    revealBadges = []
                } onBadgeShown: { _ in
                    // Tasteful, once per badge: the completion chime (no haptics on Mac).
                    badgeSound.playFinished()
                }
                .frame(width: 700, height: 620)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.panel))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseRadius.panel)
                        .strokeBorder(PulseColor.ink.color(for: .dark).opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 20, y: 8)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: revealBadges.isEmpty)
    }

    private var finishedContent: some View {
        VStack(spacing: PulseSpacing.sm) {
            ZStack {
                HStack(spacing: PulseSpacing.md) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(PulseColor.signal)
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                        Text("Réunion terminée")
                            .pulseText(.heading)
                            .foregroundStyle(PulseColor.ink)
                        Text(productivityQuote)
                            .pulseText(.body)
                            .foregroundStyle(PulseColor.inkMuted)
                            .italic()
                            .lineLimit(2)
                    }

                    Spacer(minLength: PulseSpacing.sm)

                    VStack(spacing: PulseSpacing.xs) {
                        Text(TimeFormatter.format(manager.totalElapsed))
                            .pulseText(.chronoCompact)
                            .monospacedDigit()
                            .foregroundStyle(PulseColor.inkMuted)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Button { manager.copySummaryToClipboard() } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundStyle(PulseColor.ink)
                                .padding(PulseSpacing.sm)
                                .background(PulseColor.surface2, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Copier le résumé")
                    }
                }
                .padding(.horizontal, PulseSpacing.lg).padding(.vertical, PulseSpacing.md)
                .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: PulseRadius.panel))

                if manager.meeting.confetti {
                    ConfettiView().allowsHitTesting(false)
                }
            }

            if let record = manager.lastMeetingRecord {
                HStack(spacing: PulseSpacing.xs) {
                    ForEach(record.speakers) { s in
                        VStack(spacing: 2) {
                            Text(String(s.participantName.prefix(6)))
                                .pulseText(.callout)
                            Text(TimeFormatter.format(s.actualTime))
                                .pulseText(.mono)
                        }
                        .foregroundStyle(s.wasOvertime ? PulseColor.over.color(for: .dark)
                                                       : PulseColor.ink.color(for: .dark))
                        .padding(.horizontal, PulseSpacing.xs).padding(.vertical, PulseSpacing.xxs)
                        .background(PulseColor.surface2, in: RoundedRectangle(cornerRadius: PulseRadius.chip))
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isActive = true

    var body: some View {
        if isActive {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    var alive = 0
                    for p in particles {
                        let age = now - p.startTime
                        guard age > 0, age < p.lifetime else {
                            if age <= 0 { alive += 1 }; continue
                        }
                        alive += 1
                        let x = p.startX + p.velocityX * age
                        let y = p.startY + p.velocityY * age + 300 * age * age
                        context.opacity = 1.0 - (age / p.lifetime)
                        context.translateBy(x: x, y: y)
                        context.rotate(by: .degrees(p.rotation * age))
                        context.fill(
                            Rectangle().path(in: CGRect(x: -p.size/2, y: -p.size/2, width: p.size, height: p.size * 0.6)),
                            with: .color(p.color))
                        context.rotate(by: .degrees(-p.rotation * age))
                        context.translateBy(x: -x, y: -y)
                        context.opacity = 1
                    }
                    if alive == 0 && !particles.isEmpty {
                        DispatchQueue.main.async { isActive = false }
                    }
                }
            }
            .onAppear { spawnParticles() }
        }
    }

    private func spawnParticles() {
        let colors: [Color] = [.red, .green, .blue, .yellow, .orange, .purple, .pink, .mint]
        let now = Date.now.timeIntervalSinceReferenceDate
        particles = (0..<40).map { _ in
            ConfettiParticle(
                startX: .random(in: 100...650), startY: .random(in: -20...0),
                velocityX: .random(in: -80...80), velocityY: .random(in: -200 ... -50),
                size: .random(in: 6...12), color: colors.randomElement()!,
                rotation: .random(in: -400...400), lifetime: .random(in: 1.5...2.5),
                startTime: now + .random(in: 0...0.3))
        }
    }
}

struct ConfettiParticle {
    let startX, startY, velocityX, velocityY, size: CGFloat
    let color: Color
    let rotation, lifetime, startTime: Double
}
