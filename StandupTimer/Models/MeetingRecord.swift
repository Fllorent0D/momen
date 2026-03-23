import Foundation

struct SpeakerRecord: Codable, Identifiable {
    let id: UUID
    let participantName: String
    let allocatedTime: TimeInterval
    let actualTime: TimeInterval

    var overtime: TimeInterval {
        max(actualTime - allocatedTime, 0)
    }

    var wasOvertime: Bool {
        actualTime > allocatedTime
    }

    init(participantName: String, allocatedTime: TimeInterval, actualTime: TimeInterval) {
        self.id = UUID()
        self.participantName = participantName
        self.allocatedTime = allocatedTime
        self.actualTime = actualTime
    }
}

struct MeetingRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let presetName: String?
    let speakers: [SpeakerRecord]
    let totalDuration: TimeInterval

    init(presetName: String?, speakers: [SpeakerRecord], totalDuration: TimeInterval) {
        self.id = UUID()
        self.date = Date()
        self.presetName = presetName
        self.speakers = speakers
        self.totalDuration = totalDuration
    }
}

@Observable
final class StatsStore {
    var records: [MeetingRecord] = []

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("StandupTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    init() {
        load()
    }

    func clearAll() {
        records.removeAll()
        save()
    }

    func addRecord(_ record: MeetingRecord) {
        records.append(record)
        if records.count > 500 {
            records = Array(records.suffix(500))
        }
        save()
    }

    func averageTime(for name: String) -> TimeInterval? {
        let entries = records.flatMap { $0.speakers }.filter { $0.participantName == name }
        guard !entries.isEmpty else { return nil }
        return entries.map(\.actualTime).reduce(0, +) / Double(entries.count)
    }

    func overtimeRate(for name: String) -> Double? {
        let entries = records.flatMap { $0.speakers }.filter { $0.participantName == name }
        guard !entries.isEmpty else { return nil }
        let overtimeCount = entries.filter(\.wasOvertime).count
        return Double(overtimeCount) / Double(entries.count)
    }

    var allParticipantNames: [String] {
        Array(Set(records.flatMap { $0.speakers.map(\.participantName) })).sorted()
    }

    private func load() {
        // Migrate from UserDefaults if file doesn't exist yet
        let url = Self.fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let saved = try? JSONDecoder().decode([MeetingRecord].self, from: data) {
                records = saved
            }
        } else if let data = UserDefaults.standard.data(forKey: "meeting.records"),
                  let saved = try? JSONDecoder().decode([MeetingRecord].self, from: data) {
            // One-time migration from UserDefaults
            records = saved
            save()
            UserDefaults.standard.removeObject(forKey: "meeting.records")
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
