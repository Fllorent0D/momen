import Foundation

public struct MeetingPreset: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var totalDuration: TimeInterval
    public var durationMode: DurationMode
    public var perSpeakerDuration: TimeInterval
    public var participants: [Participant]
    public var overtimeMode: OvertimeMode
    public var randomizeOrder: Bool
    public var autoPlay: Bool
    public var speakerTransition: Bool
    public var speakerDots: Bool
    public var confetti: Bool
    public var soundEnabled: Bool
    public var countdownEnabled: Bool
    public var bannerPosition: BannerPosition

    // Backward-compatible decoding: older presets may omit fields or contain
    // ones that have since been removed. Any field that might be absent uses
    // decodeIfPresent with a sensible default so an older or partial
    // presets.json still loads without throwing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        totalDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .totalDuration) ?? 900
        durationMode = try c.decodeIfPresent(DurationMode.self, forKey: .durationMode) ?? .total
        perSpeakerDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .perSpeakerDuration) ?? 120
        participants = try c.decodeIfPresent([Participant].self, forKey: .participants) ?? []
        overtimeMode = try c.decodeIfPresent(OvertimeMode.self, forKey: .overtimeMode) ?? .optional
        randomizeOrder = try c.decodeIfPresent(Bool.self, forKey: .randomizeOrder) ?? false
        autoPlay = try c.decodeIfPresent(Bool.self, forKey: .autoPlay) ?? true
        speakerTransition = try c.decodeIfPresent(Bool.self, forKey: .speakerTransition) ?? true
        speakerDots = try c.decodeIfPresent(Bool.self, forKey: .speakerDots) ?? true
        confetti = try c.decodeIfPresent(Bool.self, forKey: .confetti) ?? true
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        countdownEnabled = try c.decodeIfPresent(Bool.self, forKey: .countdownEnabled) ?? true
        bannerPosition = try c.decodeIfPresent(BannerPosition.self, forKey: .bannerPosition) ?? .topCenter
    }

    public init(id: UUID = UUID(), from meeting: Meeting, name: String) {
        self.id = id
        self.name = name
        self.totalDuration = meeting.totalDuration
        self.durationMode = meeting.durationMode
        self.perSpeakerDuration = meeting.perSpeakerDuration
        self.participants = meeting.participants
        self.overtimeMode = meeting.overtimeMode
        self.randomizeOrder = meeting.randomizeOrder
        self.autoPlay = meeting.autoPlay
        self.speakerTransition = meeting.speakerTransition
        self.speakerDots = meeting.speakerDots
        self.confetti = meeting.confetti
        self.soundEnabled = meeting.soundEnabled
        self.countdownEnabled = meeting.countdownEnabled
        self.bannerPosition = meeting.bannerPosition
    }

    public func apply(to meeting: Meeting) {
        meeting.batchUpdate { m in
            m.totalDuration = totalDuration
            m.durationMode = durationMode
            m.perSpeakerDuration = perSpeakerDuration
            m.participants = participants
            m.overtimeMode = overtimeMode
            m.randomizeOrder = randomizeOrder
            m.autoPlay = autoPlay
            m.speakerTransition = speakerTransition
            m.speakerDots = speakerDots
            m.confetti = confetti
            m.soundEnabled = soundEnabled
            m.countdownEnabled = countdownEnabled
            m.bannerPosition = bannerPosition
        }
    }
}

@Observable
public final class PresetStore {
    public var presets: [MeetingPreset] = []
    public var selectedPresetId: UUID?

    private static let selectedKey = "meeting.selectedPresetId"

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("StandupTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("presets.json")
    }

    public init() { load() }

    public var selectedPreset: MeetingPreset? {
        guard let id = selectedPresetId else { return presets.first }
        return presets.first { $0.id == id } ?? presets.first
    }

    public func savePreset(from meeting: Meeting, name: String) {
        let preset = MeetingPreset(from: meeting, name: name)
        presets.append(preset)
        selectedPresetId = preset.id
        save()
    }

    public func updatePreset(_ id: UUID, from meeting: Meeting) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let name = presets[index].name
        presets[index] = MeetingPreset(id: id, from: meeting, name: name)
        selectedPresetId = id
        save()
    }

    public func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
        if selectedPresetId == id { selectedPresetId = presets.first?.id }
        save()
    }

    public func selectPreset(_ id: UUID, into meeting: Meeting) {
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
