import SwiftUI

struct ConfigurationView: View {
    @Environment(MeetingManager.self) private var manager

    @State private var durationMinutes: Double = 15
    @State private var showNewPresetField = false
    @State private var newPresetName = ""
    @State private var showStats = false

    var body: some View {
        @Bindable var manager = manager

        VStack(alignment: .leading, spacing: 16) {
            headerView

            Divider()

            if showStats {
                statsView
            } else if manager.isActive {
                activeSessionView
            } else {
                configurationForm
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            durationMinutes = manager.meeting.totalDuration / 60
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.green)
            Text("Standup Timer")
                .font(.title2.bold())
            Spacer()

            if !manager.isActive {
                Button {
                    showStats.toggle()
                } label: {
                    Image(systemName: showStats ? "gearshape" : "chart.bar")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(showStats ? "Configuration" : "Statistiques")
            }
        }
    }

    // MARK: - Configuration Form

    private var configurationForm: some View {
        @Bindable var manager = manager

        return VStack(alignment: .leading, spacing: 16) {
            // Presets
            presetsSection

            // Duration
            VStack(alignment: .leading, spacing: 6) {
                Text("Durée de la réunion")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack {
                    Slider(value: $durationMinutes, in: 1...60, step: 1)
                    Text(TimeFormatter.formatDuration(minutes: Int(durationMinutes)))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .onChange(of: durationMinutes) { _, newValue in
                manager.meeting.totalDuration = newValue * 60
            }

            // Participants
            participantsSection

            // Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Dépassement")
                    Spacer()
                    Picker("", selection: $manager.meeting.overtimeMode) {
                        ForEach(OvertimeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }

                Toggle("Ordre aléatoire", isOn: $manager.meeting.randomizeOrder)
                Toggle("Démarrage auto", isOn: $manager.meeting.autoPlay)
                Toggle("Countdown 3-2-1", isOn: $manager.meeting.countdownEnabled)
                Toggle("Ruban écran", isOn: $manager.meeting.ribbonEnabled)
                Toggle("Sons", isOn: $manager.meeting.soundEnabled)

                // Color theme
                HStack {
                    Text("Thème")
                    Spacer()
                    Picker("", selection: $manager.meeting.colorTheme) {
                        ForEach(ColorTheme.allCases) { t in
                            HStack(spacing: 4) {
                                Circle().fill(t.inTimeColor).frame(width: 8, height: 8)
                                Circle().fill(t.overtimeColor).frame(width: 8, height: 8)
                                Text(t.rawValue)
                            }.tag(t)
                        }
                    }
                    .frame(width: 180)
                }
            }

            // Visual effects
            DisclosureGroup {
                Toggle("Transition speaker", isOn: $manager.meeting.speakerTransition)
                Toggle("Indicateurs speaker", isOn: $manager.meeting.speakerDots)
                Toggle("Halo ruban", isOn: $manager.meeting.ribbonGlow)
                Toggle("Épaisseur ruban", isOn: $manager.meeting.ribbonThicken)
                Toggle("Confettis fin", isOn: $manager.meeting.confetti)
                Toggle("Tremblement overtime", isOn: $manager.meeting.overtimeShake)
            } label: {
                Text("Effets visuels")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            // System
            DisclosureGroup {
                Toggle("Lancer au démarrage", isOn: $manager.meeting.launchAtLogin)
                    .onChange(of: manager.meeting.launchAtLogin) { _, _ in
                        manager.updateLaunchAtLogin()
                    }

                Toggle("Rappel quotidien", isOn: $manager.meeting.reminderEnabled)
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
                        .frame(width: 70)
                        Picker("", selection: $manager.meeting.reminderMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .frame(width: 60)
                    }
                    .onChange(of: manager.meeting.reminderHour) { _, _ in manager.setupReminder() }
                    .onChange(of: manager.meeting.reminderMinute) { _, _ in manager.setupReminder() }
                }
            } label: {
                Text("Système")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Start button
            Button {
                manager.startMeeting()
                NSApp.keyWindow?.close()
            } label: {
                Text("Démarrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(manager.meeting.participants.filter(\.isPresent).isEmpty
                      || manager.meeting.participants.filter(\.isPresent).allSatisfy {
                          $0.name.trimmingCharacters(in: .whitespaces).isEmpty
                      })

            // Shortcuts legend
            HStack(spacing: 12) {
                Spacer()
                shortcutLabel("⌘⇧S", "Lancer")
                shortcutLabel("N", "Suivant")
                shortcutLabel("P", "Pause")
                shortcutLabel("C", "Annuler")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        @Bindable var manager = manager

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Preset")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()

                if showNewPresetField {
                    HStack(spacing: 4) {
                        TextField("Nom", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        Button("OK") {
                            if !newPresetName.trimmingCharacters(in: .whitespaces).isEmpty {
                                manager.presetStore.savePreset(from: manager.meeting, name: newPresetName)
                                newPresetName = ""
                                showNewPresetField = false
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button {
                            showNewPresetField = false
                            newPresetName = ""
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .controlSize(.small)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button {
                            showNewPresetField = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.green)
                        .help("Sauvegarder comme preset")

                        if let selected = manager.presetStore.selectedPreset {
                            Button {
                                manager.presetStore.updatePreset(selected.id, from: manager.meeting)
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            .help("Mettre à jour le preset")

                            Button {
                                manager.presetStore.deletePreset(selected.id)
                                if let first = manager.presetStore.presets.first {
                                    manager.presetStore.selectPreset(first.id, into: manager.meeting)
                                    durationMinutes = manager.meeting.totalDuration / 60
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .help("Supprimer le preset")
                        }
                    }
                }
            }

            if !manager.presetStore.presets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(manager.presetStore.presets) { preset in
                            Button {
                                manager.presetStore.selectPreset(preset.id, into: manager.meeting)
                                durationMinutes = manager.meeting.totalDuration / 60
                            } label: {
                                Text(preset.name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        manager.presetStore.selectedPresetId == preset.id
                                            ? Color.green.opacity(0.2) : Color.clear,
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                manager.presetStore.selectedPresetId == preset.id
                                                    ? Color.green : Color.secondary.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
        @Bindable var manager = manager

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Participants")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()

                let presentCount = manager.meeting.participants.filter(\.isPresent).count
                if presentCount > 0 {
                    Text("\(presentCount) présent\(presentCount > 1 ? "s" : "") · \(TimeFormatter.format(manager.meeting.totalDuration / Double(presentCount))) chacun")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(Array(manager.meeting.participants.enumerated()), id: \.element.id) { index, participant in
                HStack(spacing: 6) {
                    // Move up/down
                    VStack(spacing: 0) {
                        Button {
                            guard index > 0 else { return }
                            manager.meeting.participants.swapAt(index, index - 1)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(index > 0 ? .secondary : .quaternary)
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)

                        Button {
                            guard index < manager.meeting.participants.count - 1 else { return }
                            manager.meeting.participants.swapAt(index, index + 1)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(index < manager.meeting.participants.count - 1 ? .secondary : .quaternary)
                        }
                        .buttonStyle(.plain)
                        .disabled(index >= manager.meeting.participants.count - 1)
                    }
                    .frame(width: 16)

                    // Present toggle
                    Button {
                        manager.meeting.participants[index].isPresent.toggle()
                    } label: {
                        Image(systemName: participant.isPresent ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(participant.isPresent ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(participant.isPresent ? "Marquer absent" : "Marquer présent")

                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)

                    TextField("Nom", text: $manager.meeting.participants[index].name)
                        .textFieldStyle(.plain)
                        .opacity(participant.isPresent ? 1.0 : 0.4)

                    // Stats badge
                    if let rate = manager.statsStore.overtimeRate(for: participant.name),
                       !participant.name.isEmpty {
                        let pct = Int(rate * 100)
                        if pct > 0 {
                            Text("\(pct)%⏱")
                                .font(.caption2)
                                .foregroundStyle(rate > 0.5 ? .red : .orange)
                                .help("Dépasse \(pct)% du temps")
                        }
                    }

                    Button {
                        manager.meeting.participants.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Button {
                    manager.meeting.participants.append(Participant())
                } label: {
                    Label("Ajouter", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)

                Spacer()

                if manager.meeting.participants.count > 1 {
                    Button {
                        manager.meeting.rotateParticipants()
                    } label: {
                        Label("Rotation", systemImage: "arrow.trianglehead.swap")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .help("Déplacer le premier à la fin")
                }
            }
        }
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        VStack(spacing: 12) {
            if let participant = manager.currentParticipant {
                HStack {
                    Circle()
                        .fill(manager.isOvertime ? .red : .green)
                        .frame(width: 10, height: 10)
                    Text(participant.name)
                        .font(.headline)
                    Spacer()
                    Text("Intervenant \(manager.currentSpeakerIndex + 1)/\(manager.totalParticipants)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Total elapsed
            HStack {
                Text("Temps total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimeFormatter.format(manager.totalElapsed))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Annuler") {
                    manager.cancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(manager.isPaused ? "Reprendre" : "Pause") {
                    manager.togglePause()
                }
                .buttonStyle(.bordered)

                Button("Suivant") {
                    manager.nextSpeaker()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }

    // MARK: - Stats View

    private var statsView: some View {
        StatsView()
            .environment(manager)
    }

    // MARK: - Helpers

    private func shortcutLabel(_ key: String, _ action: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
            Text(action)
        }
    }
}
