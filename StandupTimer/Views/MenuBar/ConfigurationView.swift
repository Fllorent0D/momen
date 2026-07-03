import SwiftUI
import StandupKit

struct ConfigurationView: View {
    @Environment(MeetingManager.self) private var manager
    @Environment(ProAccessManager.self) private var proAccess
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("ui.section.participantsExpanded") private var participantsExpanded = true

    var body: some View {
        @Bindable var manager = manager

        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            headerView

            hairline

            if manager.isActive {
                activeSessionView
            } else {
                configurationForm
            }
        }
        .padding(PulseSpacing.lg)
        .frame(width: 420)
        // The popover tracks the system appearance like the iOS app: tokens
        // resolve to their light variant in Light mode and dark in Dark mode,
        // so the menu-bar chrome feels native on macOS. (The floating overlay
        // stays fixed-dark — it sits over arbitrary screen content.)
        .background(PulseColor.canvas)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: PulseSpacing.sm) {
            Text("Momen")
                .pulseText(.heading)
                .foregroundStyle(PulseColor.ink)
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(1)

            if proAccess.isPurchased {
                planBadge(title: "Pro", tone: .signal)
            }
            Spacer()

            if !manager.isActive {
                Button {
                    openStats()
                } label: {
                    Image(systemName: "chart.bar")
                }
                .buttonStyle(.pulse(.icon))
                .help("Statistiques")
            }

            Button {
                proAccess.presentPaywall(.upgrade)
            } label: {
                Image(systemName: "sparkles")
            }
            .buttonStyle(.pulse(.icon))
            .help("Momen Pro")

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.pulse(.icon))
            .help("Réglages")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.pulse(.icon))
            .help("Quitter Momen")
        }
    }

    // MARK: - Configuration Form

    private var configurationForm: some View {
        @Bindable var manager = manager

        return VStack(alignment: .leading, spacing: PulseSpacing.md) {
            durationSection
            participantsSection
            startSection
        }
        .padding(.vertical, 2)
    }

    // MARK: - Duration

    private var durationSection: some View {
        @Bindable var manager = manager
        let present = manager.meeting.participants.filter(\.isPresent).count

        return sectionCard {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                HStack(spacing: PulseSpacing.sm) {
                    Text("DURÉE")
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.inkMuted)

                    Spacer()

                    durationStepper
                }

                PulseSegmentedControl(
                    selection: $manager.meeting.durationMode,
                    options: DurationMode.allCases.map { ($0, $0.label) }
                )

                Text(durationSubtitle(present: present))
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted)
            }
        }
    }

    private var durationStepper: some View {
        HStack(spacing: PulseSpacing.sm) {
            Button {
                adjustDuration(-1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.pulse(.icon))
            .disabled(!canDecrementDuration)

            Text(durationValueText)
                .pulseText(.mono)
                .foregroundStyle(PulseColor.signal)
                .frame(minWidth: 64)
                .multilineTextAlignment(.center)

            Button {
                adjustDuration(1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.pulse(.icon))
            .disabled(!canIncrementDuration)
        }
        .padding(PulseSpacing.xxs)
        .background(PulseColor.surface2, in: RoundedRectangle(cornerRadius: PulseRadius.control))
    }

    /// The mono-green value shows the active quantity for the current mode.
    private var durationValueText: String {
        switch manager.meeting.durationMode {
        case .total:
            return TimeFormatter.formatDuration(minutes: Int(manager.meeting.totalDuration / 60))
        case .perSpeaker:
            return TimeFormatter.format(manager.meeting.perSpeakerDuration)
        }
    }

    /// The subtitle shows the DERIVED other quantity.
    private func durationSubtitle(present: Int) -> String {
        let plural = present > 1 ? "s" : ""
        switch manager.meeting.durationMode {
        case .total:
            guard present > 0 else { return "Ajoutez des présents pour répartir le temps." }
            let per = TimeFormatter.format(manager.meeting.totalDuration / Double(present))
            return "≈ \(per) / personne · \(present) présent\(plural)"
        case .perSpeaker:
            let total = manager.meeting.perSpeakerDuration * Double(max(1, present))
            return "Total ≈ \(TimeFormatter.format(total)) · \(present) présent\(plural)"
        }
    }

    private var canDecrementDuration: Bool {
        switch manager.meeting.durationMode {
        case .total:      return manager.meeting.totalDuration > 60
        case .perSpeaker: return manager.meeting.perSpeakerDuration > 30
        }
    }

    private var canIncrementDuration: Bool {
        switch manager.meeting.durationMode {
        case .total:      return manager.meeting.totalDuration < 3600
        case .perSpeaker: return manager.meeting.perSpeakerDuration < 600
        }
    }

    /// The ± stepper edits the ACTIVE value: whole minutes in `.total`, 30-second
    /// steps (0:30–10:00) per speaker in `.perSpeaker`.
    private func adjustDuration(_ delta: Double) {
        switch manager.meeting.durationMode {
        case .total:
            let minutes = (manager.meeting.totalDuration / 60).rounded()
            manager.meeting.totalDuration = min(60, max(1, minutes + delta)) * 60
        case .perSpeaker:
            let stepped = manager.meeting.perSpeakerDuration + delta * 30
            manager.meeting.perSpeakerDuration = min(600, max(30, stepped))
        }
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
        @Bindable var manager = manager

        let presentCount = manager.meeting.participants.filter(\.isPresent).count

        return collapsibleSection(
            "Participants",
            subtitle: presentCount > 0
                ? "\(presentCount) présent\(presentCount > 1 ? "s" : "") · \(TimeFormatter.format(manager.meeting.timePerPerson(forCount: presentCount))) chacun"
                : "Choisissez qui participe aujourd’hui.",
            isExpanded: $participantsExpanded,
            trailing: {
                HStack(spacing: PulseSpacing.xs) {
                    iconActionButton("Ajouter", systemImage: "plus", accent: .signal) {
                        addParticipant()
                    }

                    if manager.meeting.participants.count > 1 {
                        iconActionButton("Rotation", systemImage: "arrow.trianglehead.swap", accent: .warn) {
                            manager.meeting.rotateParticipants()
                        }
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {

                if participantLimitExceeded {
                    Text("Free est limité à 4 participants. Retirez-en un ou passez à Pro.")
                        .pulseText(.callout)
                        .foregroundStyle(PulseColor.warn)
                        .padding(.horizontal, PulseSpacing.sm)
                        .padding(.vertical, PulseSpacing.xs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PulseColor.warn.color(for: colorScheme).opacity(0.12), in: RoundedRectangle(cornerRadius: PulseRadius.control))
                }

                if manager.meeting.participants.isEmpty {
                    emptyHint("Ajoutez des participants pour commencer.")
                } else {
                    ForEach(Array(manager.meeting.participants.enumerated()), id: \.element.id) { index, participant in
                        participantRow(index: index, participant: participant)
                    }
                }
            }
        }
    }

    private func participantRow(index: Int, participant: Participant) -> some View {
        @Bindable var manager = manager

        return HStack(spacing: PulseSpacing.sm) {
            VStack(spacing: 0) {
                Button {
                    guard index > 0 else { return }
                    manager.meeting.participants.swapAt(index, index - 1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(index > 0 ? PulseColor.inkMuted.color(for: colorScheme) : PulseColor.inkMuted.color(for: colorScheme).opacity(0.3))
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)

                Button {
                    guard index < manager.meeting.participants.count - 1 else { return }
                    manager.meeting.participants.swapAt(index, index + 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(index < manager.meeting.participants.count - 1 ? PulseColor.inkMuted.color(for: colorScheme) : PulseColor.inkMuted.color(for: colorScheme).opacity(0.3))
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index >= manager.meeting.participants.count - 1)
            }
            .frame(width: 24)

            AvatarPickerButton(participant: $manager.meeting.participants[index])

            TextField("Nom", text: $manager.meeting.participants[index].name)
                .textFieldStyle(.plain)
                .pulseText(.body)
                .foregroundStyle(PulseColor.ink)
                .opacity(participant.isPresent ? 1.0 : 0.45)

            Spacer(minLength: PulseSpacing.xs)

            if proAccess.isProUnlocked,
               let rate = manager.statsStore.overtimeRate(for: participant.name),
               !participant.name.isEmpty {
                let pct = Int(rate * 100)
                if pct > 0 {
                    Text("\(pct)%")
                        .pulseText(.mono)
                        .foregroundStyle(overtimeColor(for: rate))
                        .help("Dépasse \(pct)% du temps")
                }
            }

            Button {
                manager.meeting.participants[index].isPresent.toggle()
            } label: {
                Image(systemName: participant.isPresent ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(participant.isPresent ? PulseColor.signal : PulseColor.inkMuted)
            }
            .buttonStyle(.plain)

            Button {
                manager.meeting.participants.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(PulseColor.inkMuted)
            }
            .buttonStyle(.plain)
        }
        .pulseRow()
    }

    private func overtimeColor(for rate: Double) -> PulseColor {
        rate > 0.5 ? .over : rate > 0.2 ? .warn : .signal
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        VStack(spacing: PulseSpacing.sm) {
            if let participant = manager.currentParticipant {
                HStack {
                    Circle()
                        .fill(manager.isOvertime ? PulseColor.over : PulseColor.signal)
                        .frame(width: 10, height: 10)
                    Text(participant.name)
                        .pulseText(.callout)
                        .foregroundStyle(PulseColor.ink)
                    Spacer()
                    Text("Intervenant \(manager.currentSpeakerIndex + 1)/\(manager.totalParticipants)")
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.inkMuted)
                }
            }

            // Total elapsed
            HStack {
                Text("Temps total")
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted)
                Spacer()
                Text(TimeFormatter.format(manager.totalElapsed))
                    .pulseText(.mono)
                    .foregroundStyle(PulseColor.inkMuted)
            }

            HStack {
                Button("Annuler") {
                    manager.cancel()
                }
                .buttonStyle(.pulse(.secondary, accent: .inkMuted, size: .small))

                Spacer()

                if manager.activeParticipants.count - manager.currentSpeakerIndex > 1 {
                    Button {
                        manager.moveCurrentToEnd()
                    } label: {
                        Label("Reporter", systemImage: "arrow.uturn.down")
                    }
                    .buttonStyle(.pulse(.secondary, accent: .warn, size: .small))
                }

                Button(manager.isPaused ? "Reprendre" : "Pause") {
                    manager.togglePause()
                }
                .buttonStyle(.pulse(.secondary, accent: .inkMuted, size: .small))

                Button("Suivant") {
                    manager.nextSpeaker()
                }
                .buttonStyle(.pulse(.primary, size: .small))
            }
        }
    }

    private var startSection: some View {
        VStack(spacing: PulseSpacing.sm) {
            Button {
                manager.startMeeting()
                NSApp.keyWindow?.close()
            } label: {
                Label("Démarrer", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pulse(.primary, accent: .signal, size: .large))
            .disabled(!canStartMeeting)
        }
    }

    // MARK: - Helpers

    private var hairline: some View {
        Rectangle()
            .fill(PulseColor.ink.color(for: colorScheme).opacity(0.08))
            .frame(height: 1)
    }

    private var participantLimitExceeded: Bool {
        !proAccess.isProUnlocked && manager.meeting.participants.count > ProAccessManager.freeParticipantLimit
    }

    private var canStartMeeting: Bool {
        let hasPresentParticipants = !manager.meeting.participants.filter(\.isPresent).isEmpty
        let hasNamedPresentParticipants = !manager.meeting.participants.filter(\.isPresent).allSatisfy {
            $0.name.trimmingCharacters(in: .whitespaces).isEmpty
        }

        return hasPresentParticipants && hasNamedPresentParticipants && !participantLimitExceeded
    }

    private func planBadge(title: String, tone: PulseTone) -> some View {
        PulseStatusPill(title, tone: tone)
    }

    private func openStats() {
        guard proAccess.isProUnlocked else {
            proAccess.presentPaywall(.stats)
            return
        }

        openWindow(id: "stats")
    }

    private func addParticipant() {
        guard proAccess.isProUnlocked || manager.meeting.participants.count < ProAccessManager.freeParticipantLimit else {
            proAccess.presentPaywall(.participantsLimit)
            return
        }

        manager.meeting.participants.append(Participant())
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(PulseSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: PulseRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: PulseRadius.card)
                    .strokeBorder(PulseColor.ink.opacity(0.06))
            )
    }

    private func collapsibleSection<Content: View, Trailing: View>(
        _ title: String,
        subtitle: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                // The title/subtitle/chevron toggle expansion; the trailing
                // actions (Ajouter / Rotation) sit OUTSIDE that button — nesting
                // buttons inside a Button label makes them un-hittable and
                // renders them invisible on macOS.
                HStack(alignment: .center, spacing: PulseSpacing.sm) {
                    Button {
                        withAnimation(PulseMotion.standard) {
                            isExpanded.wrappedValue.toggle()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .pulseText(.callout)
                                .foregroundStyle(PulseColor.ink)
                            Text(subtitle)
                                .pulseText(.label)
                                .foregroundStyle(PulseColor.inkMuted)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(0)

                    // The greedy space lives in the OUTER HStack, not inside the
                    // toggle button — otherwise the button grows to full width and
                    // squeezes the trailing actions until they truncate to nothing.
                    Spacer(minLength: PulseSpacing.sm)

                    // `.fixedSize()` locks Ajouter / Rotation to their ideal size
                    // so width pressure can never compress them away (the “boutons
                    // pas visibles” bug).
                    trailing()
                        .fixedSize()
                        .layoutPriority(1)

                    Button {
                        withAnimation(PulseMotion.standard) {
                            isExpanded.wrappedValue.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(PulseColor.inkMuted)
                            .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(1)
                }

                if isExpanded.wrappedValue {
                    hairline
                    content()
                }
            }
        }
    }

    private func smallActionButton(_ title: String, systemImage: String, accent: PulseColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.pulse(.secondary, accent: accent, size: .small))
    }

    /// Icon-only variant of ``smallActionButton``: a compact accent-tinted chip.
    /// The header row is tight, so Ajouter / Rotation drop their text labels (kept
    /// as tooltips) to leave room for the section title on the left.
    private func iconActionButton(_ title: String, systemImage: String, accent: PulseColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(.pulse(.secondary, accent: accent, size: .small))
        .help(title)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .pulseText(.callout)
            .foregroundStyle(PulseColor.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.sm)
            .background(PulseColor.surface2, in: RoundedRectangle(cornerRadius: PulseRadius.control))
    }
}
