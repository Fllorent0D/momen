import SwiftUI
import StandupKit

/// The dedicated, resizable Settings window (⌘, / gear button). It hosts every
/// control that used to crowd the menu-bar popover: meeting behaviour, presets,
/// Pro personalisation and system options. Unlike the popover, this is a normal
/// macOS Settings window, so it uses native adaptive chrome (grouped forms in a
/// TabView) instead of the forced Pulse "night" surface.
struct SettingsView: View {
    @Environment(MeetingManager.self) private var manager
    @Environment(ProAccessManager.self) private var proAccess

    var body: some View {
        TabView {
            MeetingSettingsTab()
                .tabItem { Label("Réunion", systemImage: "person.2") }

            PresetsSettingsTab()
                .tabItem { Label("Presets", systemImage: "bookmark") }

            CustomizationSettingsTab()
                .tabItem { Label("Personnalisation", systemImage: "paintbrush") }

            SystemSettingsTab()
                .tabItem { Label("Système", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - Réunion

/// Overtime mode and timer behaviour — moved verbatim from the popover's
/// `meetingSection`; same `$manager.meeting.*` bindings.
private struct MeetingSettingsTab: View {
    @Environment(MeetingManager.self) private var manager

    var body: some View {
        @Bindable var manager = manager

        Form {
            Section("Dépassement") {
                Picker("Mode de dépassement", selection: $manager.meeting.overtimeMode) {
                    ForEach(OvertimeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Comportement du timer") {
                Toggle("Ordre aléatoire", isOn: $manager.meeting.randomizeOrder)
                Toggle("Démarrage auto", isOn: $manager.meeting.autoPlay)
                Toggle("Countdown 3-2-1", isOn: $manager.meeting.countdownEnabled)
                Toggle("Sons", isOn: $manager.meeting.soundEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Presets

/// Preset CRUD + selectable chips — moved from the popover's `presetsSection`;
/// same `presetStore` calls and Pro gating.
private struct PresetsSettingsTab: View {
    @Environment(MeetingManager.self) private var manager
    @Environment(ProAccessManager.self) private var proAccess

    @State private var showNewPresetField = false
    @State private var newPresetName = ""

    var body: some View {
        @Bindable var manager = manager

        Form {
            Section {
                if showNewPresetField {
                    HStack {
                        TextField("Nom du preset", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                        Button("Enregistrer") {
                            if !newPresetName.trimmingCharacters(in: .whitespaces).isEmpty {
                                manager.presetStore.savePreset(from: manager.meeting, name: newPresetName)
                                newPresetName = ""
                                showNewPresetField = false
                            }
                        }
                        Button("Annuler") {
                            showNewPresetField = false
                            newPresetName = ""
                        }
                    }
                } else {
                    HStack {
                        Button {
                            showNewPresetField = true
                        } label: {
                            Label("Nouveau", systemImage: "plus")
                        }

                        if let selected = manager.presetStore.selectedPreset {
                            Button {
                                manager.presetStore.updatePreset(selected.id, from: manager.meeting)
                            } label: {
                                Label("Mettre à jour", systemImage: "arrow.triangle.2.circlepath")
                            }

                            Button(role: .destructive) {
                                manager.presetStore.deletePreset(selected.id)
                                if let first = manager.presetStore.presets.first {
                                    selectPreset(first)
                                }
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Presets")
            } footer: {
                Text("Sauvegardez une configuration réutilisable.")
            }

            Section("Disponibles") {
                if manager.presetStore.presets.isEmpty {
                    Text("Aucun preset pour l’instant.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(manager.presetStore.presets) { preset in
                        let isSelected = manager.presetStore.selectedPresetId == preset.id
                        Button {
                            selectPreset(preset)
                        } label: {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                Text(preset.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func selectPreset(_ preset: MeetingPreset) {
        guard proAccess.isProUnlocked || preset.participants.count <= ProAccessManager.freeParticipantLimit else {
            proAccess.presentPaywall(.participantsLimit)
            return
        }

        manager.presetStore.selectPreset(preset.id, into: manager.meeting)
        manager.enforceFreePlanIfNeeded(isProUnlocked: proAccess.isProUnlocked)
    }
}

// MARK: - Personnalisation (Pro)

/// Banner position + visual effects, Pro-gated — moved from the popover's
/// `premiumCustomizationSection`; same bindings + lock overlay + paywall.
private struct CustomizationSettingsTab: View {
    @Environment(MeetingManager.self) private var manager
    @Environment(ProAccessManager.self) private var proAccess

    var body: some View {
        @Bindable var manager = manager

        Form {
            Section {
                Picker("Position du bandeau", selection: $manager.meeting.bannerPosition) {
                    ForEach(BannerPosition.allCases) { pos in
                        Text(pos.label).tag(pos)
                    }
                }

                Toggle("Transition speaker", isOn: $manager.meeting.speakerTransition)
                Toggle("Indicateurs speaker", isOn: $manager.meeting.speakerDots)
                Toggle("Confettis fin", isOn: $manager.meeting.confetti)
            } header: {
                HStack {
                    Text("Personnalisation")
                    Spacer()
                    Text("Pro")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("Position du bandeau et effets visuels.")
            }
            .disabled(!proAccess.isProUnlocked)
        }
        .formStyle(.grouped)
        .overlay {
            if !proAccess.isProUnlocked {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("La personnalisation complète est incluse dans Pro.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Découvrir Pro") {
                        proAccess.presentPaywall(.customization)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(maxWidth: 320)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Système

/// Launch at login + daily reminder — moved from the popover's `systemSection`;
/// same bindings and `updateLaunchAtLogin()` / `setupReminder()` onChange.
private struct SystemSettingsTab: View {
    @Environment(MeetingManager.self) private var manager

    var body: some View {
        @Bindable var manager = manager

        Form {
            Section {
                Toggle("Lancer au démarrage", isOn: $manager.meeting.launchAtLogin)
                    .onChange(of: manager.meeting.launchAtLogin) { _, _ in
                        manager.updateLaunchAtLogin()
                    }
            } footer: {
                Text("Comportement de l’app et rappels.")
            }

            Section("Rappel quotidien") {
                Toggle("Activer le rappel", isOn: $manager.meeting.reminderEnabled)
                    .onChange(of: manager.meeting.reminderEnabled) { _, _ in
                        manager.setupReminder()
                    }

                if manager.meeting.reminderEnabled {
                    HStack {
                        Text("Heure")
                        Spacer()
                        Picker("", selection: $manager.meeting.reminderHour) {
                            ForEach(6..<20, id: \.self) { h in
                                Text("\(h)h").tag(h)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                        .onChange(of: manager.meeting.reminderHour) { _, _ in manager.setupReminder() }

                        Picker("", selection: $manager.meeting.reminderMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        .onChange(of: manager.meeting.reminderMinute) { _, _ in manager.setupReminder() }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
