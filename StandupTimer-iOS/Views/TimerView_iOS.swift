import SwiftUI
import UIKit
import StandupKit

/// Issue #13 — the full-screen "table mode" iOS timer (Pulse redesign).
///
/// The phone or iPad is laid flat on the table during the standup; this screen
/// has to be read at 1–2 m by everyone around it. So the time is told by the
/// *whole screen*: a Pulse ``ScreenDrain`` fills the canvas and **empties** as
/// the current speaker's slice runs out — the full-screen sibling of the Mac
/// ribbon's "bandeau qui se vide". It rides the signal spectrum (calm green →
/// amber in the last seconds → solid breathing red in overtime) and drains in a
/// *different style per speaker* (``ScreenDrain/Style/forSpeaker(_:)``) so no
/// two turns feel the same. The drain replaces the old ``SignalRing`` centre.
///
/// Over the drain rides the composed centre — the current speaker's accent chip
/// + name ABOVE a giant monospaced chrono, with a "RESTANT" / "DÉPASSEMENT"
/// label BELOW — kept legible on both the colour and the drained-dark canvas by
/// a `legibilityScrim`. A meta row sits up top (left: "DAILY · N PERS.", right:
/// a status pill that flips green→red in overtime), a "SUIVANTS" avatar strip
/// shows who's up, and the transport controls — an outlined pause/play circle,
/// a wide green "Suivant" pill and a small defer chip — sit underneath.
///
/// All timer state is **read** from an injected ``MeetingManager`` — this view
/// owns no timer logic. It only derives presentation values (the drain fraction,
/// the chrono text, the signal state) and forwards button taps to the manager.
/// Haptic feedback (#14, via ``Haptics``) fires on speaker transitions and on
/// entering overtime; keep-awake (#17) is driven off this screen's lifecycle.
///
/// The layout adapts to orientation off the live geometry: portrait stacks the
/// ring above the controls, landscape places the speaker/queue column beside the
/// ring. The ring stays the dominant element in both.
struct TimerView_iOS: View {
    @Bindable var manager: MeetingManager
    @Environment(\.colorScheme) private var colorScheme

    /// Issue #42 — the badges to celebrate over the finished screen. Captured once
    /// when the standup finishes (from `manager.newlyUnlockedBadges`) and cleared
    /// when the reveal is dismissed, so the celebration shows exactly once per
    /// finish and we then fall through to the normal finished screen.
    @State private var revealBadges: [Badge] = []

    /// Drives the finished-screen checkmark's spring-in (set `true` `onAppear`).
    @State private var finishedPop = false

    /// Speaker hand-off intro (this file): each new speaker's avatar + name grow
    /// in BIG and centred, hold a beat, then cross-dissolve out as the chip above
    /// the chrono and the chrono itself fade in. `speakerIntro` is the "showing the
    /// big name" phase; `introToken` lets a fresh hand-off (rapid "Suivant" taps)
    /// cancel a pending dismiss instead of fighting it.
    @State private var speakerIntro = false
    @State private var introToken = 0

    /// The iOS sound cue for a freshly-unlocked badge — fired by the reveal's
    /// per-badge callback (the shared reveal view stays media-free).
    private let sound = iOSSoundPlayer()

    var body: some View {
        ZStack {
            PulseColor.canvas.color(for: colorScheme)
                .ignoresSafeArea()

            if manager.timerState == .finished {
                finishedScreen
            } else if manager.isCountingDown {
                // Counting in gets its own SHARP screen — a solid signal disc with
                // the popping digit, the full-screen sibling of the Mac overlay's
                // crisp countdown circle. No drain, no soft scrim: clean hard edges
                // until "GO" hands off to the drain below.
                countdownScreen
            } else {
                // The drain (#13 redesign) is now the primary time visual: a
                // full-screen colour that empties as the speaker's slice runs
                // out, in a different style per speaker. It sits over the dark
                // canvas; the content (name / chrono / queue / controls) rides
                // on top, kept legible by `legibilityScrim`.
                ScreenDrain(fraction: drainFraction, state: drainState, style: drainStyle)
                legibilityScrim
                GeometryReader { geo in
                    let landscape = geo.size.width > geo.size.height
                    if landscape {
                        landscapeLayout(in: geo.size)
                    } else {
                        portraitLayout(in: geo.size)
                    }
                }

                // The hand-off takeover: the new speaker fills the centre big, then
                // flies up to dock as the chip (see `speakerIntroView`). Non-
                // interactive so the controls underneath stay tappable to skip.
                if speakerIntro, let participant = manager.currentParticipant {
                    speakerIntroView(participant)
                }
            }
        }
        // A way out (#14): a top-corner close that aborts the running standup and
        // returns home. The finished screen has its own dedicated dismiss button.
        .overlay(alignment: .topTrailing) {
            if manager.timerState != .finished {
                closeButton
            }
        }
        // Achievement reveal (#42): when there are badges to celebrate, lay the
        // shared `BadgeRevealView` full-screen ON TOP of the finished screen. It
        // chains through the badges and, once dismissed, clears `revealBadges` so
        // the user lands back on the normal finished screen (and the existing 8s
        // auto-return / "Terminé" flow takes them home).
        .overlay {
            if !revealBadges.isEmpty {
                BadgeRevealView(badges: revealBadges) {
                    revealBadges = []
                } onBadgeShown: { _ in
                    // Tasteful, once per badge: a success buzz + the completion chime.
                    Haptics.finished()
                    sound.playFinished()
                }
                .transition(.opacity)
            }
        }
        // Keep-awake (#17): the phone lies flat on the table for the whole standup,
        // so the display must never dim. We disable the idle timer while this
        // screen is on and re-enable it the moment it goes away — whether the
        // standup was cancelled, finished (auto-return) or manually dismissed —
        // so we never leave the device permanently awake.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        // Haptics (#14): a medium tap whenever the speaker actually changes. We key
        // off the current participant's identity so this also covers automatic
        // transitions (overtime-disabled auto-advance) and "report to end", not
        // just button presses. The `old != nil` guard skips the initial nil→first
        // assignment at start; the `isActive` guard skips the finish, which has its
        // own success buzz below.
        .onChange(of: manager.currentParticipant?.id) { old, new in
            guard let new, old != nil, old != new, manager.isActive else { return }
            Haptics.speakerTransition()
            // Don't intro while still counting in — the first speaker's reveal
            // fires off the countdown ending below, so the GO hands straight over.
            if !manager.isCountingDown { presentSpeakerIntro() }
        }
        // First speaker: when the count-in finishes into a running standup, give
        // the opening speaker the same big reveal the rest get on hand-off.
        .onChange(of: manager.isCountingDown) { _, counting in
            if !counting, manager.isActive, manager.currentParticipant != nil {
                presentSpeakerIntro()
            }
        }
        // …and a distinct, stronger buzz the instant a speaker tips into overtime.
        .onChange(of: manager.isOvertime) { _, isOver in
            if isOver { Haptics.overtime() }
        }
        // Countdown rhythm (#14): a dry metronome tick on each digit (3·2·1) and a
        // heavy launch buzz on "GO", so the start *winds up* and then snaps open —
        // felt without looking at the screen lying flat on the table.
        .onChange(of: manager.countdownValue) { _, value in
            guard manager.isCountingDown else { return }
            value > 0 ? Haptics.countdownTick() : Haptics.go()
        }
        // A success buzz when the standup wraps up.
        .onChange(of: manager.timerState == .finished) { _, finished in
            if finished {
                Haptics.finished()
                // Issue #42: if this finish unlocked any badges, kick off the
                // celebration over the finished screen. The reveal fires its own
                // per-badge sound/haptic; here we only capture what to show.
                if !manager.newlyUnlockedBadges.isEmpty {
                    revealBadges = manager.newlyUnlockedBadges
                }
            }
        }
    }

    /// Top-corner abort (#14): cancel the standup and return home. `manager.cancel()`
    /// clears the overlay (`overlay.isPresented = false`), which swaps the root view
    /// back to home and triggers this screen's `onDisappear` (re-enabling sleep).
    private var closeButton: some View {
        Button {
            manager.cancel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                .frame(width: 44, height: 44)
                .background(Circle().fill(PulseColor.surface2.color(for: colorScheme)))
        }
        .buttonStyle(.plain)
        .padding(PulseSpacing.lg)
        .accessibilityLabel("Annuler le standup")
    }

    // MARK: - Orientation layouts

    private func portraitLayout(in size: CGSize) -> some View {
        VStack(spacing: PulseSpacing.lg) {
            metaRow
            Spacer(minLength: 0)
            centerBlock(maxWidth: size.width * 0.86)
            Spacer(minLength: 0)
            queueStrip
            controls
        }
        .padding(.horizontal, PulseSpacing.xl)
        .padding(.vertical, PulseSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func landscapeLayout(in size: CGSize) -> some View {
        HStack(spacing: PulseSpacing.xxl) {
            centerBlock(maxWidth: size.width * 0.42)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                metaRow
                Spacer(minLength: 0)
                queueStrip
                controls
            }
            .frame(maxWidth: .infinity)
        }
        .padding(PulseSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Legibility scrim

    /// Keeps the speaker / chrono / meta / controls readable over BOTH the
    /// colour fill and the drained-dark canvas: a soft top + bottom darkening
    /// (under the meta row and the controls) and a central radial pool behind
    /// the giant chrono. Non-interactive so taps fall through to the controls.
    private var legibilityScrim: some View {
        let c = PulseColor.canvas.color(for: colorScheme)
        return ZStack {
            LinearGradient(
                stops: [
                    .init(color: c.opacity(0.55), location: 0),
                    .init(color: .clear, location: 0.22),
                    .init(color: .clear, location: 0.74),
                    .init(color: c.opacity(0.65), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(gradient: Gradient(colors: [c.opacity(0.5), .clear]),
                           center: .center, startRadius: 0, endRadius: 280)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Meta row

    private var metaRow: some View {
        HStack {
            Text("DAILY · \(manager.totalParticipants) PERS.")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            Spacer()
            // Reserve room for the close button in the trailing corner.
            statusPill
                .padding(.trailing, 48)
        }
    }

    private var statusPill: some View {
        Group {
            if manager.isOvertime {
                PulseStatusPill("DÉPASSEMENT", systemImage: "circle.fill", tone: .over)
            } else if manager.isPaused {
                PulseStatusPill("EN PAUSE", systemImage: "pause.fill", tone: .neutral)
            } else {
                PulseStatusPill("EN COURS", systemImage: "circle.fill", tone: .signal)
            }
        }
    }

    // MARK: - Countdown (sharp, like the Mac circle)

    /// The "3 · 2 · 1 · GO" count-in: a single solid signal disc on the bare
    /// canvas, the digit popping in with each tick. Deliberately hard-edged — the
    /// full-screen twin of the Mac overlay's countdown circle — so the start reads
    /// crisp before the soft drain takes over.
    private var countdownScreen: some View {
        Text(centerText)
            .pulseText(.chrono)
            .minimumScaleFactor(0.4)
            .foregroundStyle(PulseColor.canvas.color(for: colorScheme))
            .frame(width: 240, height: 240)
            .background(PulseColor.signal.color(for: colorScheme), in: Circle())
            // A fresh identity per tick drives the scale pop; the bouncy spring
            // gives it the same playful landing as the Mac countdown.
            .id(centerText)
            .transition(.scale(scale: 0.3).combined(with: .opacity))
            .animation(.bouncy(duration: 0.4), value: centerText)
    }

    // MARK: - Speaker hand-off intro

    /// Kick off the big-name reveal for the current speaker, then auto-dock it into
    /// the chip after a short hold. `introToken` guards the dock: a newer hand-off
    /// bumps the token, so a stale timer won't yank a still-fresh reveal away.
    private func presentSpeakerIntro() {
        introToken += 1
        let token = introToken
        // One smooth spring in, one smooth spring out — high damping so it settles
        // cleanly with no overshoot wobble (the "flaky" feel came from competing,
        // bouncier animations, now removed).
        withAnimation(.smooth(duration: 0.45)) {
            speakerIntro = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard token == introToken else { return }
            withAnimation(.smooth(duration: 0.45)) {
                speakerIntro = false
            }
        }
    }

    /// The big centred reveal: the speaker's avatar over their name, filling the
    /// screen. Grows in and dissolves out around the centre (no sliding), so the
    /// hand-off reads as a clean, predictable "big name → timer". Non-interactive.
    private func speakerIntroView(_ participant: Participant) -> some View {
        VStack(spacing: PulseSpacing.lg) {
            AvatarDisc(participant: participant, size: 132, fontSize: 50)
            Text(participant.name)
                .pulseText(.display)
                .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .shadow(color: PulseColor.canvas.color(for: colorScheme).opacity(0.7), radius: 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PulseSpacing.xxl)
        // Centred scale + fade both ways — never slides in from an edge.
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    // MARK: - Composed centre (over the drain)

    /// The composed centre that rides on top of the drain: the current speaker's
    /// accent chip + name ABOVE a giant monospaced chrono, with a RESTANT /
    /// DÉPASSEMENT label BELOW. The chrono stays high-contrast ink — it reads on
    /// both the colour fill and the drained-dark canvas thanks to the scrim and
    /// a soft drop shadow — while the colour cue is carried by the whole screen.
    private func centerBlock(maxWidth: CGFloat) -> some View {
        VStack(spacing: PulseSpacing.sm) {
            // The docked chip: hidden while the big reveal is on screen, it fades
            // in above the chrono as the reveal dissolves out.
            if let participant = manager.currentParticipant, !manager.isCountingDown, !speakerIntro {
                HStack(spacing: PulseSpacing.xs) {
                    AvatarDisc(participant: participant, size: 34, fontSize: 15)
                    Text(participant.name)
                        .pulseText(.heading)
                        .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: maxWidth)
                .transition(.opacity)
            }

            // The hero read-out: the running chrono, its digits rolling over with
            // `.numericText`. (The count-in has its own sharp `countdownScreen`.)
            // It fades + lifts in behind the speaker as the big reveal docks, so
            // the timer "arrives" the moment the name lands.
            Text(centerText)
                .pulseText(.chrono)
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .frame(maxWidth: maxWidth)
                .shadow(color: PulseColor.canvas.color(for: colorScheme).opacity(0.7), radius: 14)
                // Hidden under the big reveal; fades in (via the hand-off spring)
                // the moment the name docks. Digit roll-over is its own quick snap.
                .opacity(speakerIntro ? 0 : 1)
                .animation(.snappy(duration: 0.28), value: centerText)

            if !manager.isCountingDown && !speakerIntro {
                Text(manager.isOvertime ? "DÉPASSEMENT" : "RESTANT")
                    .pulseText(.label)
                    .foregroundStyle(stateColor)
                    .contentTransition(.opacity)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Drain wiring

    /// Raw fraction of the speaker's slice still remaining, `1 → 0`. Drives the
    /// signal-state thresholds (warn in the last 8 %).
    private var remainingFraction: Double {
        guard manager.timePerPerson > 0 else { return 1 }
        return min(max(manager.remainingTime / manager.timePerPerson, 0), 1)
    }

    /// The fraction handed to the ``ScreenDrain``. Full (`1`) while counting in
    /// (the screen sits brimming green) and full again in overtime (so it
    /// refills solid breathing red); otherwise it tracks the remaining slice.
    private var drainFraction: Double {
        if manager.isCountingDown || manager.isOvertime { return 1 }
        return remainingFraction
    }

    /// The signal state shared by the drain, the chrono label and the controls:
    /// over-red in overtime, else derived from the remaining fraction.
    private var drainState: SignalRing.SignalState {
        manager.isOvertime ? .over : .forFraction(remainingFraction)
    }

    /// One consistent drain style for every speaker — a calm, predictable
    /// top-to-bottom fall, the same each turn.
    private var drainStyle: ScreenDrain.Style { .verticalFall }

    /// The centre read-out: the countdown digit while counting in, the `+m:ss`
    /// overtime once over, otherwise the remaining `m:ss`.
    private var centerText: String {
        if manager.isCountingDown {
            return manager.countdownValue > 0 ? "\(manager.countdownValue)" : "GO"
        }
        if manager.isOvertime {
            return TimeFormatter.formatOvertime(manager.elapsedOvertime)
        }
        return TimeFormatter.format(manager.remainingTime)
    }

    /// The dominant accent for the current state: signal green normally, over-red
    /// in overtime — drives the RESTANT label, the queue label and the controls.
    private var stateColor: Color {
        accent.color(for: colorScheme)
    }

    private var accent: PulseColor {
        manager.isOvertime ? .over : .signal
    }

    // MARK: - Queue strip

    /// "SUIVANTS" label + a horizontal row of upcoming accent avatar discs.
    private var queueStrip: some View {
        let upcoming = upcomingParticipants
        return VStack(spacing: PulseSpacing.sm) {
            Text("SUIVANTS")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            HStack(spacing: PulseSpacing.sm) {
                ForEach(upcoming) { participant in
                    AvatarDisc(participant: participant, size: 40, fontSize: 13)
                        // As a speaker finishes, the head of the queue pops away
                        // and the rest slide forward to fill the gap.
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.2).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: manager.currentSpeakerIndex)
        }
        .frame(height: upcoming.isEmpty ? 0 : nil)
        .opacity(upcoming.isEmpty ? 0 : 1)
    }

    private var upcomingParticipants: [Participant] {
        let start = manager.currentSpeakerIndex + 1
        guard start < manager.activeParticipants.count else { return [] }
        return Array(manager.activeParticipants[start...].prefix(8))
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: PulseSpacing.lg) {
            // Outlined pause/play circle.
            Button {
                Haptics.light()
                manager.togglePause()
            } label: {
                Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 22, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(stateColor)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(PulseColor.surface2.color(for: colorScheme)))
                    .overlay(
                        Circle().strokeBorder(stateColor.opacity(0.5), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(manager.isPaused ? "Reprendre" : "Pause")

            // Wide primary "Suivant" pill — flips green→red in overtime.
            Button {
                manager.nextSpeaker()
            } label: {
                HStack(spacing: PulseSpacing.xs) {
                    Text("Suivant")
                    Image(systemName: "play.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pulse(.primary, accent: accent, size: .large))

            // Defer the current speaker to the end of the queue.
            Button {
                manager.moveCurrentToEnd()
            } label: {
                Image(systemName: "arrow.uturn.down")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.pulse(.icon))
            .disabled(upcomingParticipants.isEmpty)
            .accessibilityLabel("Reporter à la fin")
        }
    }

    // MARK: - Finished

    private var finishedScreen: some View {
        VStack(spacing: PulseSpacing.xl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(PulseColor.signal.color(for: colorScheme))
                // A spring-loaded landing: the mark overshoots in, then a symbol
                // bounce gives the "done!" a little flourish.
                .scaleEffect(finishedPop ? 1 : 0.4)
                .opacity(finishedPop ? 1 : 0)
                .symbolEffect(.bounce, value: finishedPop)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                        finishedPop = true
                    }
                }
            Text("Standup terminé")
                .pulseText(.display)
                .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                .multilineTextAlignment(.center)
            if let record = manager.lastMeetingRecord {
                Text("\(record.speakers.count) orateurs · \(TimeFormatter.format(record.totalDuration))")
                    .pulseText(.bodyLarge)
                    .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            }

            // Manual dismiss (#14): return home now instead of waiting out the 8s
            // auto-return. `cancel()` from the finished state clears the overlay
            // (`overlay.isPresented = false`) and resets to idle — the record is
            // already saved by `finishMeeting()`, so nothing is lost.
            Button {
                manager.cancel()
            } label: {
                Text("Terminé")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pulse(.primary, accent: .signal, size: .large))
            .padding(.top, PulseSpacing.lg)
            .padding(.horizontal, PulseSpacing.xxl)
        }
        .padding(PulseSpacing.xxl)
    }
}
