import Foundation

struct MeetingPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var totalDuration: TimeInterval
    var participants: [Participant]
    var overtimeMode: OvertimeMode
    var randomizeOrder: Bool
    var ribbonEnabled: Bool
    var autoPlay: Bool
    var speakerTransition: Bool
    var speakerDots: Bool
    var ribbonGlow: Bool
    var ribbonThicken: Bool
    var confetti: Bool
    var overtimeShake: Bool
    var soundEnabled: Bool
    var countdownEnabled: Bool
    var colorTheme: ColorTheme

    init(from meeting: Meeting, name: String) {
        self.id = UUID()
        self.name = name
        self.totalDuration = meeting.totalDuration
        self.participants = meeting.participants
        self.overtimeMode = meeting.overtimeMode
        self.randomizeOrder = meeting.randomizeOrder
        self.ribbonEnabled = meeting.ribbonEnabled
        self.autoPlay = meeting.autoPlay
        self.speakerTransition = meeting.speakerTransition
        self.speakerDots = meeting.speakerDots
        self.ribbonGlow = meeting.ribbonGlow
        self.ribbonThicken = meeting.ribbonThicken
        self.confetti = meeting.confetti
        self.overtimeShake = meeting.overtimeShake
        self.soundEnabled = meeting.soundEnabled
        self.countdownEnabled = meeting.countdownEnabled
        self.colorTheme = meeting.colorTheme
    }

    func apply(to meeting: Meeting) {
        meeting.batchUpdate { m in
            m.totalDuration = totalDuration
            m.participants = participants
            m.overtimeMode = overtimeMode
            m.randomizeOrder = randomizeOrder
            m.ribbonEnabled = ribbonEnabled
            m.autoPlay = autoPlay
            m.speakerTransition = speakerTransition
            m.speakerDots = speakerDots
            m.ribbonGlow = ribbonGlow
            m.ribbonThicken = ribbonThicken
            m.confetti = confetti
            m.overtimeShake = overtimeShake
            m.soundEnabled = soundEnabled
            m.countdownEnabled = countdownEnabled
            m.colorTheme = colorTheme
        }
    }
}

@Observable
final class PresetStore {
    var presets: [MeetingPreset] = []
    var selectedPresetId: UUID?

    private static let selectedKey = "meeting.selectedPresetId"

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("StandupTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("presets.json")
    }

    init() { load() }

    var selectedPreset: MeetingPreset? {
        guard let id = selectedPresetId else { return presets.first }
        return presets.first { $0.id == id } ?? presets.first
    }

    func savePreset(from meeting: Meeting, name: String) {
        let preset = MeetingPreset(from: meeting, name: name)
        presets.append(preset)
        selectedPresetId = preset.id
        save()
    }

    func updatePreset(_ id: UUID, from meeting: Meeting) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let name = presets[index].name
        presets[index] = MeetingPreset(from: meeting, name: name)
        save()
    }

    func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
        if selectedPresetId == id { selectedPresetId = presets.first?.id }
        save()
    }

    func selectPreset(_ id: UUID, into meeting: Meeting) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        selectedPresetId = id
        preset.apply(to: meeting)
        save()
    }

    private func load() {
        let url = Self.fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let saved = try? JSONDecoder().decode([MeetingPreset].self, from: data) {
                presets = saved
            }
        } else if let data = UserDefaults.standard.data(forKey: "meeting.presets"),
                  let saved = try? JSONDecoder().decode([MeetingPreset].self, from: data) {
            presets = saved
            save()
            UserDefaults.standard.removeObject(forKey: "meeting.presets")
        }
        if let idString = UserDefaults.standard.string(forKey: Self.selectedKey) {
            selectedPresetId = UUID(uuidString: idString)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
        UserDefaults.standard.set(selectedPresetId?.uuidString, forKey: Self.selectedKey)
    }
}
