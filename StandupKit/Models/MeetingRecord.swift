import Foundation

public struct SpeakerRecord: Codable, Identifiable {
    public let id: UUID
    public let participantName: String
    public let allocatedTime: TimeInterval
    public let actualTime: TimeInterval

    public var overtime: TimeInterval {
        max(actualTime - allocatedTime, 0)
    }

    public var wasOvertime: Bool {
        actualTime > allocatedTime
    }

    public init(participantName: String, allocatedTime: TimeInterval, actualTime: TimeInterval) {
        self.id = UUID()
        self.participantName = participantName
        self.allocatedTime = allocatedTime
        self.actualTime = actualTime
    }
}

public struct MeetingRecord: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let presetName: String?
    public let speakers: [SpeakerRecord]
    public let totalDuration: TimeInterval

    public init(presetName: String?, speakers: [SpeakerRecord], totalDuration: TimeInterval) {
        self.id = UUID()
        self.date = Date()
        self.presetName = presetName
        self.speakers = speakers
        self.totalDuration = totalDuration
    }
}

@Observable
@MainActor
public final class StatsStore {
    public var records: [MeetingRecord] = []

    /// Clé de synchro iCloud Pro (cf. `CloudSyncStore`).
    private static let cloudKey = "sync.stats"
    private static let maxRecords = 500

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("StandupTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    public init() {
        load()
        CloudSyncStore.shared.register(key: Self.cloudKey) { [weak self] data in
            self?.merge(data)
        }
    }

    /// Fusionne un blob distant : union par id (l'historique n'est jamais perdu),
    /// tri par date, cap à `maxRecords`. Re-persiste (donc re-pousse) uniquement
    /// si l'ensemble change, ce qui fait converger les appareils.
    private func merge(_ data: Data) {
        guard let remote = try? JSONDecoder().decode([MeetingRecord].self, from: data) else { return }
        var byId = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
        for record in remote where byId[record.id] == nil { byId[record.id] = record }
        let merged = Array(byId.values.sorted { $0.date < $1.date }.suffix(Self.maxRecords))
        guard Set(merged.map(\.id)) != Set(records.map(\.id)) else { return }
        records = merged
        save()
    }

    public func clearAll() {
        records.removeAll()
        save()
    }

    public func addRecord(_ record: MeetingRecord) {
        records.append(record)
        if records.count > 500 {
            records = Array(records.suffix(500))
        }
        save()
    }

    public func averageTime(for name: String) -> TimeInterval? {
        let entries = records.flatMap { $0.speakers }.filter { $0.participantName == name }
        guard !entries.isEmpty else { return nil }
        return entries.map(\.actualTime).reduce(0, +) / Double(entries.count)
    }

    public func overtimeRate(for name: String) -> Double? {
        let entries = records.flatMap { $0.speakers }.filter { $0.participantName == name }
        guard !entries.isEmpty else { return nil }
        let overtimeCount = entries.filter(\.wasOvertime).count
        return Double(overtimeCount) / Double(entries.count)
    }

    public var allParticipantNames: [String] {
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
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
        CloudSyncStore.shared.push(key: Self.cloudKey, data: data)
    }
}
