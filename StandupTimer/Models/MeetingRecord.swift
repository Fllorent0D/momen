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

    private static let key = "meeting.records"

    init() {
        load()
    }

    func addRecord(_ record: MeetingRecord) {
        records.append(record)
        // Keep last 100 meetings
        if records.count > 100 {
            records = Array(records.suffix(100))
        }
        save()
    }

    /// Average time per person across all meetings
    func averageTime(for name: String) -> TimeInterval? {
        let entries = records.flatMap { $0.speakers }.filter { $0.participantName == name }
        guard !entries.isEmpty else { return nil }
        return entries.map(\.actualTime).reduce(0, +) / Double(entries.count)
    }

    /// How often this person goes overtime (0.0–1.0)
    func overtimeRate(for name: String) -> Double? {
        let entries = records.flatMap { $0.speakers }.filter { $0.participantName == name }
        guard !entries.isEmpty else { return nil }
        let overtimeCount = entries.filter(\.wasOvertime).count
        return Double(overtimeCount) / Double(entries.count)
    }

    /// All unique participant names
    var allParticipantNames: [String] {
        Array(Set(records.flatMap { $0.speakers.map(\.participantName) })).sorted()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([MeetingRecord].self, from: data) {
            records = saved
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
