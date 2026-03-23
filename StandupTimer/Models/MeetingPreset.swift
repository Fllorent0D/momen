import Foundation

struct MeetingPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var totalDuration: TimeInterval
    var participants: [Participant]
    var overtimeMode: OvertimeMode
    var randomizeOrder: Bool

    init(
        name: String,
        totalDuration: TimeInterval = 900,
        participants: [Participant] = [],
        overtimeMode: OvertimeMode = .optional,
        randomizeOrder: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.totalDuration = totalDuration
        self.participants = participants
        self.overtimeMode = overtimeMode
        self.randomizeOrder = randomizeOrder
    }
}

@Observable
final class PresetStore {
    var presets: [MeetingPreset] = []
    var selectedPresetId: UUID?

    private static let key = "meeting.presets"
    private static let selectedKey = "meeting.selectedPresetId"

    init() {
        load()
    }

    var selectedPreset: MeetingPreset? {
        guard let id = selectedPresetId else { return presets.first }
        return presets.first { $0.id == id } ?? presets.first
    }

    func savePreset(from meeting: Meeting, name: String) {
        let preset = MeetingPreset(
            name: name,
            totalDuration: meeting.totalDuration,
            participants: meeting.participants,
            overtimeMode: meeting.overtimeMode,
            randomizeOrder: meeting.randomizeOrder
        )
        presets.append(preset)
        selectedPresetId = preset.id
        save()
    }

    func updatePreset(_ id: UUID, from meeting: Meeting) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[index].totalDuration = meeting.totalDuration
        presets[index].participants = meeting.participants
        presets[index].overtimeMode = meeting.overtimeMode
        presets[index].randomizeOrder = meeting.randomizeOrder
        save()
    }

    func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
        if selectedPresetId == id {
            selectedPresetId = presets.first?.id
        }
        save()
    }

    func selectPreset(_ id: UUID, into meeting: Meeting) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        selectedPresetId = id
        meeting.totalDuration = preset.totalDuration
        meeting.participants = preset.participants
        meeting.overtimeMode = preset.overtimeMode
        meeting.randomizeOrder = preset.randomizeOrder
        save()
    }

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([MeetingPreset].self, from: data) {
            presets = saved
        }
        if let idString = defaults.string(forKey: Self.selectedKey) {
            selectedPresetId = UUID(uuidString: idString)
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: Self.key)
        }
        defaults.set(selectedPresetId?.uuidString, forKey: Self.selectedKey)
    }
}
