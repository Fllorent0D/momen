import SwiftUI
import Combine
import StandupKit

/// The iOS home screen — the Pulse standup **setup** (issue #13, part C; Pulse
/// redesign).
///
/// The home screen *is* the configuration: a big "Qui parle aujourd'hui ?"
/// heading, a duration card, the present-team list with per-person presence
/// toggles, and a single prominent "Démarrer le standup" CTA — all rendered on
/// the Pulse canvas with the shared design system, matching the Pulse mockups
/// (no native `Form`). Advanced settings (presets, sounds, overtime,
/// personnalisation Pro, reminder, reorder/delete) live behind a top-bar gear
/// that opens ``IOSConfigurationView``; stats behind a chart icon.
///
/// While a meeting runs it presents ``TimerView_iOS`` full-screen, driven by the
/// injected ``iOSOverlayPresenting`` — on iOS the "overlay" is a root-view
/// takeover, so `overlay.isPresented` (set by `MeetingManager.startMeeting`,
/// cleared when it finishes/cancels) is the single signal that swaps home ⇄
/// timer.
struct ContentView: View {
    @Bindable var manager: MeetingManager
    @Bindable var proAccess: ProAccessManager
    @Bindable var overlay: iOSOverlayPresenting

    @Environment(\.colorScheme) private var colorScheme
    @State private var showConfig = false
    @State private var showStats = false

    /// Accumulated rotation for the "ROTATION" icon — bumped by a full turn on
    /// every tap so the glyph spins along with the team shuffle it performs.
    @State private var rotationSpin = 0.0

    var body: some View {
        NavigationStack {
            ZStack {
                PulseColor.canvas.color(for: colorScheme)
                    .ignoresSafeArea()
                home
            }
            .navigationTitle("Qui parle aujourd'hui ?")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    planPill
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showStats = true } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                    .tint(PulseColor.signal)
                    .accessibilityLabel("Statistiques")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showConfig = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .tint(PulseColor.signal)
                    .accessibilityLabel("Réglages")
                }
            }
        }
        // The iOS "overlay" = the timer takes over the whole screen.
        .fullScreenCover(isPresented: Binding(
            get: { overlay.isPresented },
            set: { if !$0 { manager.cancel() } }
        )) {
            TimerView_iOS(manager: manager)
        }
        .sheet(isPresented: $showConfig) {
            IOSConfigurationView(
                meeting: manager.meeting,
                presetStore: manager.presetStore,
                proAccess: proAccess,
                onPaywall: { reason in proAccess.presentPaywall(reason) }
            )
        }
        .sheet(isPresented: $showStats) {
            IOSStatsView(store: manager.statsStore, badgeStore: manager.badgeStore)
        }
        .sheet(isPresented: Binding(
            get: { proAccess.isPaywallPresented },
            set: { if !$0 { proAccess.dismissPaywall() } }
        )) {
            PaywallView_iOS(proAccess: proAccess)
        }
        .onAppear {
            manager.openPaywall = { reason in proAccess.presentPaywall(reason) }
            manager.isProUnlocked = { proAccess.isProUnlocked }
            manager.enforceFreePlanIfNeeded(isProUnlocked: proAccess.isProUnlocked)
            // Synchro iCloud = feature Pro (D9).
            CloudSyncStore.shared.setEnabled(proAccess.isPurchased)
            #if DEBUG
            // fastlane snapshot : ouvre l'écran voulu pour la capture.
            let launchArgs = ProcessInfo.processInfo.arguments
            if launchArgs.contains("UITEST_START") { manager.startMeeting() }
            if launchArgs.contains("UITEST_STATS") { showStats = true }
            #endif
        }
        .onChange(of: proAccess.isProUnlocked) { _, isUnlocked in
            manager.enforceFreePlanIfNeeded(isProUnlocked: isUnlocked)
        }
        .onChange(of: proAccess.isPurchased) { _, isPurchased in
            CloudSyncStore.shared.setEnabled(isPurchased)
        }
        // Live Activity (#52): mirror the running standup into the Lock Screen /
        // Dynamic Island. We only OBSERVE `MeetingManager` here — start/update/end
        // the activity from its public state without touching the manager itself.
        // `timerState` covers the whole lifecycle (running/paused/overtime →
        // start-or-update, finished/idle → end); `currentSpeakerIndex` pushes the
        // speaker change immediately; the 1 Hz tick advances the chrono (the
        // controller skips redundant updates so a pause costs nothing).
        .onChange(of: manager.timerState) { _, state in
            switch state {
            case .running, .paused, .overtime:
                LiveActivityController.shared.start(with: manager)
            case .finished, .idle:
                LiveActivityController.shared.end()
            }
        }
        .onChange(of: manager.currentSpeakerIndex) { _, _ in
            LiveActivityController.shared.update(with: manager)
        }
        .onReceive(liveActivityTicker) { _ in
            guard manager.isActive else { return }
            LiveActivityController.shared.update(with: manager)
        }
    }

    /// A 1 Hz tick that advances the Live Activity chrono while a standup runs.
    private let liveActivityTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Home

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                durationCard
                teamHeader
                participantList
                addButton
            }
            .padding(.horizontal, PulseSpacing.xl)
            .padding(.top, PulseSpacing.sm)
            // Leave room for the pinned CTA below.
            .padding(.bottom, PulseSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        // The "Démarrer" CTA stays pinned and reachable however long the team is.
        .safeAreaInset(edge: .bottom) {
            startButton
                .padding(.horizontal, PulseSpacing.xl)
                .padding(.top, PulseSpacing.sm)
                .padding(.bottom, PulseSpacing.xs)
                .background(
                    PulseColor.canvas.color(for: colorScheme)
                        .opacity(0.94)
                        .ignoresSafeArea(edges: .bottom)
                )
        }
    }

    @ViewBuilder
    private var planPill: some View {
        if proAccess.isPurchased {
            PulseStatusPill("PRO", tone: .signal)
        } else {
            Button {
                Haptics.light()
                proAccess.presentPaywall(.upgrade)
            } label: {
                PulseStatusPill("FREE", tone: .neutral)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Duration card

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack(alignment: .center, spacing: PulseSpacing.md) {
                VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                    Text("Durée du standup")
                        .pulseText(.heading)
                        .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                    Text(durationSubtitle)
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                }
                Spacer(minLength: PulseSpacing.sm)
                durationStepper
            }

            PulseSegmentedControl(
                selection: $manager.meeting.durationMode,
                options: DurationMode.allCases.map { ($0, $0.label) }
            )
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                .fill(PulseColor.surface.color(for: colorScheme))
        )
    }

    /// The stepper edits the ACTIVE value: whole minutes in `.total`, 30-second
    /// steps (0:30–10:00) per speaker in `.perSpeaker`.
    @ViewBuilder
    private var durationStepper: some View {
        switch manager.meeting.durationMode {
        case .total:
            PulseStepper(value: durationMinutes, in: 1...60) { "\($0) min" }
        case .perSpeaker:
            PulseStepper(value: perSpeakerSeconds, in: 30...600, step: 30) {
                TimeFormatter.format(Double($0))
            }
        }
    }

    /// The subtitle shows the DERIVED other quantity.
    private var durationSubtitle: String {
        let present = presentCount
        switch manager.meeting.durationMode {
        case .total:
            guard present > 0 else { return "Aucun présent" }
            let per = TimeFormatter.format(manager.meeting.totalDuration / Double(present))
            return "\(per) / personne · \(present) présent\(present > 1 ? "s" : "")"
        case .perSpeaker:
            let total = manager.meeting.perSpeakerDuration * Double(max(1, present))
            return "Total ≈ \(TimeFormatter.format(total)) · \(present) présent\(present > 1 ? "s" : "")"
        }
    }

    /// In `.total` mode the stepper edits minutes via the shared `totalDuration`.
    private var durationMinutes: Binding<Int> {
        Binding(
            get: { Int((manager.meeting.totalDuration / 60).rounded()) },
            set: { manager.meeting.totalDuration = Double($0) * 60 }
        )
    }

    /// In `.perSpeaker` mode the stepper edits the fixed per-speaker seconds.
    private var perSpeakerSeconds: Binding<Int> {
        Binding(
            get: { Int(manager.meeting.perSpeakerDuration.rounded()) },
            set: { manager.meeting.perSpeakerDuration = Double($0) }
        )
    }

    // MARK: - Team

    private var teamHeader: some View {
        HStack {
            Text("ÉQUIPE · \(presentCount) PRÉSENT\(presentCount > 1 ? "S" : "")")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            Spacer()
            Button {
                Haptics.selection()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    rotationSpin += 360
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    manager.meeting.rotateParticipants()
                }
            } label: {
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .rotationEffect(.degrees(rotationSpin))
                    Text("ROTATION")
                }
                .pulseText(.label)
                .foregroundStyle(PulseColor.signal.color(for: colorScheme))
            }
            .buttonStyle(.plain)
            .disabled(manager.meeting.participants.count < 2)
            .opacity(manager.meeting.participants.count < 2 ? 0.4 : 1)
        }
        .padding(.top, PulseSpacing.xs)
    }

    private var participantList: some View {
        VStack(spacing: PulseSpacing.sm) {
            ForEach($manager.meeting.participants) { $participant in
                let id = participant.id
                HomeParticipantCard(participant: $participant) {
                    Haptics.light()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        manager.meeting.participants.removeAll { $0.id == id }
                    }
                }
                // New members drop in from the top; deleted ones collapse away.
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.85).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.meeting.participants.count)
    }

    private var addButton: some View {
        Button {
            addParticipant()
        } label: {
            HStack(spacing: PulseSpacing.xs) {
                Image(systemName: "plus.circle.fill")
                Text("Ajouter un participant")
            }
            .pulseText(.callout)
            .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, PulseSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                    .strokeBorder(
                        PulseColor.inkMuted.color(for: colorScheme).opacity(0.25),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.top, PulseSpacing.xxs)
    }

    // MARK: - CTA

    private var startButton: some View {
        Button {
            Haptics.light()
            manager.startMeeting()
        } label: {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: "play.fill")
                Text("Démarrer le standup")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pulse(.primary, accent: .signal, size: .large))
        .disabled(presentCount == 0)
    }

    // MARK: - Derived

    private var presentCount: Int {
        manager.meeting.participants.filter(\.isPresent).count
    }

    private func addParticipant() {
        guard proAccess.isProUnlocked
            || manager.meeting.participants.count < ProAccessManager.freeParticipantLimit else {
            proAccess.presentPaywall(.participantsLimit)
            return
        }
        Haptics.selection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            manager.meeting.participants.append(Participant())
        }
    }
}

// MARK: - Participant card

/// A single team member on the home screen: accent avatar disc, an inline-
/// editable name, and a Pulse presence toggle. Absent members are dimmed (but
/// their toggle stays legible), matching the mockup.
private struct HomeParticipantCard: View {
    @Binding var participant: Participant
    var onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    /// Resting horizontal offset of the card: 0 = closed, `-revealWidth` = the
    /// delete button is held open after a partial swipe.
    @State private var offset: CGFloat = 0

    /// Axis lock for the active drag: `nil` until the first movement decides,
    /// then `true` for a horizontal swipe (we own it) or `false` for a vertical
    /// pan (we ignore it so the enclosing ScrollView scrolls unhijacked).
    @State private var isHorizontalDrag: Bool?

    /// Width of the revealed trailing delete button.
    private let revealWidth: CGFloat = 88
    /// Swipe far enough past the button and we delete outright (iOS full-swipe).
    private var commitThreshold: CGFloat { revealWidth + 60 }

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteAction
            card
                .background(
                    RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                        .fill(PulseColor.surface.color(for: colorScheme))
                )
                .offset(x: offset)
                .gesture(swipe)
        }
        .clipShape(RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private var card: some View {
        HStack(spacing: PulseSpacing.md) {
            HStack(spacing: PulseSpacing.md) {
                AvatarDisc(participant: participant, size: 44)
                TextField("Nom", text: $participant.name)
                    .pulseText(.heading)
                    .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                    .textInputAutocapitalization(.words)
            }
            .opacity(participant.isPresent ? 1 : 0.5)
            .animation(.easeInOut(duration: PulseDuration.micro), value: participant.isPresent)

            Spacer(minLength: PulseSpacing.sm)

            Toggle("", isOn: $participant.isPresent)
                .labelsHidden()
                .toggleStyle(.pulse)
                .fixedSize()
                // A crisp tick confirms flipping someone in or out of today's round.
                .onChange(of: participant.isPresent) { _, _ in Haptics.selection() }
        }
        .padding(PulseSpacing.md)
    }

    /// Red delete button revealed behind the card as it slides left.
    private var deleteAction: some View {
        Button(role: .destructive) {
            withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
            onDelete()
        } label: {
            Image(systemName: "trash.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: revealWidth)
                .frame(maxHeight: .infinity)
                .background(Color.red)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Supprimer \(participant.name.isEmpty ? "ce participant" : participant.name)")
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                // Decide the axis on the first meaningful movement. A vertical
                // pan is left to the ScrollView; only a horizontal swipe drives
                // the card, so scrolling never fights the delete gesture.
                if isHorizontalDrag == nil {
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontalDrag == true else { return }
                // Track leftward drag, anchored to the resting offset.
                let base = offset == 0 ? 0 : -revealWidth
                offset = min(0, base + value.translation.width)
            }
            .onEnded { value in
                let wasHorizontal = isHorizontalDrag == true
                isHorizontalDrag = nil
                guard wasHorizontal else { return }
                // Snap from the live position so a held-open row resolves correctly.
                if value.translation.width < -commitThreshold {
                    withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                    onDelete()
                } else if offset < -revealWidth / 2 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = -revealWidth }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                }
            }
    }
}

/// Circular identity avatar: the participant's photo when set, otherwise white
/// initials on their stable per-person accent (``PulseAccent``).
struct AvatarDisc: View {
    let participant: Participant
    var size: CGFloat = 40
    var fontSize: CGFloat = 13

    var body: some View {
        ZStack {
            Circle().fill(PulseAccent.color(for: participant.id))
            #if canImport(UIKit)
            if let data = participant.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                initials
            }
            #else
            initials
            #endif
        }
        .frame(width: size, height: size)
    }

    private var initials: some View {
        Text(participant.initials)
            .font(.custom(PulseFontFamily.ui, size: fontSize).weight(.semibold))
            .foregroundStyle(.white)
    }
}
