import SwiftUI
import StandupKit

/// Native iOS configuration screen (issue #15).
///
/// The macOS `ConfigurationView` is a 420 pt menu-bar popover built from custom
/// collapsible cards. On iOS the same settings read far better as a grouped
/// `Form` inside a `NavigationStack`, so this screen re-expresses every setting
/// with native controls (`Stepper`, `Slider`, `Toggle`, `Picker`, an editable
/// `List`) across five sections: Réunion · Participants · Presets ·
/// Personnalisation · Système.
///
/// It binds directly to the shared StandupKit stores (`Meeting`, `PresetStore`,
/// `ProAccessManager`) so it is self-contained and buildable on its own — no
/// `MeetingManager` required. The app shell injects the live stores and wires
/// the paywall through ``onPaywall``; the timer/start flow lives elsewhere.
public struct IOSConfigurationView: View {

    @Bindable private var meeting: Meeting
    @Bindable private var presetStore: PresetStore
    @Bindable private var proAccess: ProAccessManager

    /// Called when an action is gated behind Pro (adding a 5th participant,
    /// loading an oversized preset, discovering the customization section). The
    /// shell presents the real paywall; defaults to a no-op so the screen
    /// compiles and previews in isolation.
    private let onPaywall: (PaywallReason) -> Void

    @State private var newPresetName = ""
    @State private var showNewPresetAlert = false
    @Environment(\.dismiss) private var dismiss

    public init(
        meeting: Meeting,
        presetStore: PresetStore,
        proAccess: ProAccessManager,
        onPaywall: @escaping (PaywallReason) -> Void = { _ in }
    ) {
        self.meeting = meeting
        self.presetStore = presetStore
        self.proAccess = proAccess
        self.onPaywall = onPaywall
    }

    public var body: some View {
        NavigationStack {
            Form {
                overviewSection
                meetingSection
                participantsSection
                presetsSection
                systemSection
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Terminé") { dismiss() }
                        .tint(PulseColor.signal)
                }
            }
            .alert("Nouveau preset", isPresented: $showNewPresetAlert) {
                TextField("Nom du preset", text: $newPresetName)
                Button("Annuler", role: .cancel) { newPresetName = "" }
                Button("Enregistrer") { saveNewPreset() }
            } message: {
                Text("Sauvegardez la configuration actuelle pour la réutiliser.")
            }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        let presentCount = meeting.participants.filter(\.isPresent).count
        let perSpeaker = presentCount > 0
            ? TimeFormatter.format(meeting.timePerPerson(forCount: presentCount))
            : "0:00"

        return Section {
            LabeledContent("Réunion", value: TimeFormatter.format(meeting.effectiveTotalDuration(forCount: presentCount)))
            LabeledContent("Participants", value: "\(meeting.participants.count)")
            LabeledContent("Présents", value: "\(presentCount)")
            LabeledContent("Par personne", value: perSpeaker)
        } header: {
            HStack {
                Text("Aperçu")
                Spacer()
                planBadge
            }
        }
    }

    // MARK: - Réunion

    private var meetingSection: some View {
        Section("Réunion") {
            Picker("Mode de durée", selection: $meeting.durationMode) {
                ForEach(DurationMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch meeting.durationMode {
            case .total:
                Stepper(value: durationMinutes, in: 1...60, step: 1) {
                    LabeledContent("Durée totale", value: TimeFormatter.formatDuration(minutes: Int(durationMinutes.wrappedValue)))
                }

                Slider(value: durationMinutes, in: 1...60, step: 1) {
                    Text("Durée")
                } minimumValueLabel: {
                    Text("1")
                } maximumValueLabel: {
                    Text("60")
                }
            case .perSpeaker:
                Stepper(value: perSpeakerSeconds, in: 30...600, step: 30) {
                    LabeledContent("Par intervenant", value: TimeFormatter.format(perSpeakerSeconds.wrappedValue))
                }

                Slider(value: perSpeakerSeconds, in: 30...600, step: 30) {
                    Text("Par intervenant")
                } minimumValueLabel: {
                    Text("0:30")
                } maximumValueLabel: {
                    Text("10:00")
                }
            }

            Picker("Dépassement", selection: $meeting.overtimeMode) {
                ForEach(OvertimeMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Toggle("Ordre aléatoire", isOn: $meeting.randomizeOrder)
            Toggle("Démarrage auto", isOn: $meeting.autoPlay)
            Toggle("Countdown 3-2-1", isOn: $meeting.countdownEnabled)
            Toggle("Sons", isOn: $meeting.soundEnabled)
        }
    }

    // MARK: - Participants

    private var participantsSection: some View {
        Section {
            if participantLimitExceeded {
                Label("Free est limité à \(ProAccessManager.freeParticipantLimit) participants. Retirez-en un ou passez à Pro.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(PulseColor.warn)
            }

            if meeting.participants.isEmpty {
                Text("Ajoutez des participants pour commencer.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(meeting.participants.enumerated()), id: \.element.id) { index, _ in
                    ParticipantRow(
                        participant: $meeting.participants[index],
                        canMoveUp: index > 0,
                        canMoveDown: index < meeting.participants.count - 1,
                        onMoveUp: { meeting.participants.swapAt(index, index - 1) },
                        onMoveDown: { meeting.participants.swapAt(index, index + 1) },
                        onDelete: { meeting.participants.remove(at: index) }
                    )
                }
            }

            Button {
                addParticipant()
            } label: {
                Label("Ajouter un participant", systemImage: "plus.circle.fill")
            }

            if meeting.participants.count > 1 {
                Button {
                    meeting.rotateParticipants()
                } label: {
                    Label("Rotation", systemImage: "arrow.trianglehead.swap")
                }
                .tint(PulseColor.warn)
            }
        } header: {
            Text("Participants")
        } footer: {
            let presentCount = meeting.participants.filter(\.isPresent).count
            if presentCount > 0 {
                Text("\(presentCount) présent\(presentCount > 1 ? "s" : "") · \(TimeFormatter.format(meeting.timePerPerson(forCount: presentCount))) chacun")
            } else {
                Text("Choisissez qui participe aujourd’hui.")
            }
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        Section {
            if presetStore.presets.isEmpty {
                Text("Aucun preset pour l’instant.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presetStore.presets) { preset in
                    Button {
                        selectPreset(preset)
                    } label: {
                        HStack {
                            Image(systemName: presetStore.selectedPresetId == preset.id ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                                .foregroundStyle(presetStore.selectedPresetId == preset.id ? AnyShapeStyle(PulseColor.signal) : AnyShapeStyle(.secondary))
                            Text(preset.name)
                            Spacer()
                            Text("\(preset.participants.count) pers.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    for index in offsets {
                        presetStore.deletePreset(presetStore.presets[index].id)
                    }
                }
            }

            Button {
                showNewPresetAlert = true
            } label: {
                Label("Nouveau preset", systemImage: "plus")
            }

            if let selected = presetStore.selectedPreset {
                Button {
                    presetStore.updatePreset(selected.id, from: meeting)
                } label: {
                    Label("Mettre à jour « \(selected.name) »", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        } header: {
            Text("Presets")
        } footer: {
            Text("Sauvegardez une configuration réutilisable.")
        }
    }

    // MARK: - Système

    private var systemSection: some View {
        Section {
            Toggle("Rappel quotidien", isOn: $meeting.reminderEnabled)

            if meeting.reminderEnabled {
                DatePicker(
                    "Heure",
                    selection: reminderTime,
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text("Système")
        } footer: {
            Text("Recevez un rappel pour lancer le standup chaque jour.")
        }
    }

    // MARK: - Header badge

    @ViewBuilder
    private var planBadge: some View {
        if proAccess.isPurchased {
            badge("Pro", color: PulseColor.signal)
        } else {
            badge("Free", color: PulseColor.inkMuted)
        }
    }

    private func badge(_ title: String, color: PulseColor) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(color)
    }

    // MARK: - Bindings

    private var durationMinutes: Binding<Double> {
        Binding(
            get: { meeting.totalDuration / 60 },
            set: { meeting.totalDuration = $0 * 60 }
        )
    }

    /// Per-speaker fixed time, in seconds, for the `.perSpeaker` mode controls.
    private var perSpeakerSeconds: Binding<Double> {
        Binding(
            get: { meeting.perSpeakerDuration },
            set: { meeting.perSpeakerDuration = $0 }
        )
    }

    /// Bridges the model's hour/minute integers to a `Date` for the native
    /// `DatePicker`, so the reminder time edits in place without extra state.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = meeting.reminderHour
                comps.minute = meeting.reminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                meeting.reminderHour = comps.hour ?? meeting.reminderHour
                meeting.reminderMinute = comps.minute ?? meeting.reminderMinute
            }
        )
    }

    // MARK: - Gating

    private var participantLimitExceeded: Bool {
        !proAccess.isProUnlocked && meeting.participants.count > ProAccessManager.freeParticipantLimit
    }

    private func addParticipant() {
        guard proAccess.isProUnlocked || meeting.participants.count < ProAccessManager.freeParticipantLimit else {
            onPaywall(.participantsLimit)
            return
        }
        meeting.participants.append(Participant())
    }

    private func selectPreset(_ preset: MeetingPreset) {
        guard proAccess.isProUnlocked || preset.participants.count <= ProAccessManager.freeParticipantLimit else {
            onPaywall(.participantsLimit)
            return
        }
        presetStore.selectPreset(preset.id, into: meeting)
    }

    private func saveNewPreset() {
        let trimmed = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        presetStore.savePreset(from: meeting, name: trimmed)
        newPresetName = ""
    }
}

// MARK: - Participant row

/// A single editable participant: presence toggle, avatar, and name. Bound to
/// the live element so edits persist straight through the `Meeting`.
private struct ParticipantRow: View {
    @Binding var participant: Participant
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)
                .foregroundStyle(canMoveUp ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.secondary.opacity(0.3)))

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
                .foregroundStyle(canMoveDown ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.secondary.opacity(0.3)))
            }
            .frame(width: 18)

            Button {
                participant.isPresent.toggle()
            } label: {
                Image(systemName: participant.isPresent ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(participant.isPresent ? AnyShapeStyle(PulseColor.signal) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)

            AvatarBadge(participant: participant)

            TextField("Nom", text: $participant.name)
                .opacity(participant.isPresent ? 1 : 0.45)

            Spacer(minLength: 4)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Circular avatar: the participant's photo when one was set, otherwise their
/// initials on a tinted disc.
private struct AvatarBadge: View {
    let participant: Participant

    var body: some View {
        ZStack {
            // The participant's stable identity accent backs their initials disc.
            Circle()
                .fill(PulseAccent.color(for: participant.id))
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
        .frame(width: 30, height: 30)
    }

    private var initials: some View {
        Text(participant.initials)
            .font(.caption2.bold())
            .foregroundStyle(.white)
    }
}

#Preview {
    let meeting = Meeting()
    meeting.participants = [
        Participant(name: "Alice"),
        Participant(name: "Bob"),
        Participant(name: "Chloé", isPresent: false)
    ]
    return IOSConfigurationView(
        meeting: meeting,
        presetStore: PresetStore(),
        proAccess: ProAccessManager()
    )
}
