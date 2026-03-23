import Foundation

enum OvertimeMode: String, CaseIterable, Identifiable, Codable {
    case optional = "Optionnel"
    case always = "Toujours"
    case never = "Jamais"

    var id: String { rawValue }
}

@Observable
final class Meeting {
    var totalDuration: TimeInterval = 900 {
        didSet { save() }
    }
    var participants: [Participant] = [] {
        didSet { save() }
    }
    var overtimeMode: OvertimeMode = .optional {
        didSet { save() }
    }
    var randomizeOrder: Bool = false {
        didSet { save() }
    }

    var timePerPerson: TimeInterval {
        guard !participants.isEmpty else { return totalDuration }
        return totalDuration / Double(participants.count)
    }

    // MARK: - Persistence

    private static let participantsKey = "meeting.participants"
    private static let durationKey = "meeting.totalDuration"
    private static let overtimeKey = "meeting.overtimeMode"
    private static let randomizeKey = "meeting.randomizeOrder"

    init() {
        load()
    }

    private func load() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: Self.participantsKey),
           let saved = try? JSONDecoder().decode([Participant].self, from: data) {
            participants = saved
        }

        if defaults.object(forKey: Self.durationKey) != nil {
            totalDuration = defaults.double(forKey: Self.durationKey)
        }

        if let raw = defaults.string(forKey: Self.overtimeKey),
           let mode = OvertimeMode(rawValue: raw) {
            overtimeMode = mode
        }

        randomizeOrder = defaults.bool(forKey: Self.randomizeKey)
    }

    private func save() {
        let defaults = UserDefaults.standard

        if let data = try? JSONEncoder().encode(participants) {
            defaults.set(data, forKey: Self.participantsKey)
        }

        defaults.set(totalDuration, forKey: Self.durationKey)
        defaults.set(overtimeMode.rawValue, forKey: Self.overtimeKey)
        defaults.set(randomizeOrder, forKey: Self.randomizeKey)
    }

    /// Move the first participant to the end of the list
    func rotateParticipants() {
        guard participants.count > 1 else { return }
        let first = participants.removeFirst()
        participants.append(first)
    }
}
