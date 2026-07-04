import Foundation

/// How the standup length is configured.
///
/// - `total`: the user sets the whole meeting length; each speaker gets
///   `totalDuration ÷ présents`.
/// - `perSpeaker`: the user sets a fixed time per speaker; the total is
///   `perSpeakerDuration × présents`.
public enum DurationMode: String, Codable, CaseIterable, Sendable {
    case total
    case perSpeaker

    /// Localized label for the segmented control (source language fr-BE).
    public var label: String {
        switch self {
        case .total:      return String(localized: "Durée totale", bundle: .standupKit)
        case .perSpeaker: return String(localized: "Par intervenant", bundle: .standupKit)
        }
    }
}

public enum OvertimeMode: String, CaseIterable, Identifiable, Codable {
    // NOTE: the rawValue is persisted (UserDefaults / presets JSON) and must NOT
    // change — display goes through `label` instead so it can be localized.
    case optional = "Optionnel"
    case always = "Toujours"
    case never = "Jamais"

    public var id: String { rawValue }

    /// Localized label for pickers (source language fr-BE).
    public var label: String {
        switch self {
        case .optional: return String(localized: "Optionnel", bundle: .standupKit)
        case .always:   return String(localized: "Toujours", bundle: .standupKit)
        case .never:    return String(localized: "Jamais", bundle: .standupKit)
        }
    }
}

public enum BannerPosition: String, CaseIterable, Identifiable, Codable {
    // NOTE: the rawValue is persisted and must NOT change — display goes through
    // `label` instead so it can be localized.
    case topCenter = "Haut centre"
    case topLeft = "Haut gauche"
    case topRight = "Haut droite"
    case bottomCenter = "Bas centre"
    case bottomLeft = "Bas gauche"
    case bottomRight = "Bas droite"

    public var id: String { rawValue }

    /// Localized label for pickers (source language fr-BE).
    public var label: String {
        switch self {
        case .topCenter:    return String(localized: "Haut centre", bundle: .standupKit)
        case .topLeft:      return String(localized: "Haut gauche", bundle: .standupKit)
        case .topRight:     return String(localized: "Haut droite", bundle: .standupKit)
        case .bottomCenter: return String(localized: "Bas centre", bundle: .standupKit)
        case .bottomLeft:   return String(localized: "Bas gauche", bundle: .standupKit)
        case .bottomRight:  return String(localized: "Bas droite", bundle: .standupKit)
        }
    }
}

@Observable
public final class Meeting {
    private var isBatching = false

    public var totalDuration: TimeInterval = 900 { didSet { saveIfNeeded() } }
    public var durationMode: DurationMode = .total { didSet { saveIfNeeded() } }
    public var perSpeakerDuration: TimeInterval = 120 { didSet { saveIfNeeded() } }
    public var participants: [Participant] = [] { didSet { saveIfNeeded() } }
    public var overtimeMode: OvertimeMode = .optional { didSet { saveIfNeeded() } }
    public var randomizeOrder: Bool = false { didSet { saveIfNeeded() } }
    public var autoPlay: Bool = true { didSet { saveIfNeeded() } }
    public var bannerPosition: BannerPosition = .topCenter { didSet { saveIfNeeded() } }

    // Visual effects
    public var speakerTransition: Bool = true { didSet { saveIfNeeded() } }
    public var speakerDots: Bool = true { didSet { saveIfNeeded() } }
    public var confetti: Bool = true { didSet { saveIfNeeded() } }

    // Sound
    public var soundEnabled: Bool = true { didSet { saveIfNeeded() } }

    // Countdown
    public var countdownEnabled: Bool = true { didSet { saveIfNeeded() } }

    // Launch at login
    public var launchAtLogin: Bool = false { didSet { saveIfNeeded() } }

    // Daily reminder
    public var reminderEnabled: Bool = false { didSet { saveIfNeeded() } }
    public var reminderHour: Int = 9 { didSet { saveIfNeeded() } }
    public var reminderMinute: Int = 30 { didSet { saveIfNeeded() } }
    /// Jours où le rappel se déclenche (weekday Apple : 1 = dimanche … 7 = samedi).
    /// Défaut : la semaine de travail (lun–ven). Vide = aucun jour.
    public var reminderWeekdays: Set<Int> = [2, 3, 4, 5, 6] { didSet { saveIfNeeded() } }

    private func saveIfNeeded() { if !isBatching { save() } }

    public func batchUpdate(_ block: (Meeting) -> Void) {
        isBatching = true
        block(self)
        isBatching = false
        save()
    }

    public var timePerPerson: TimeInterval {
        timePerPerson(forCount: participants.count)
    }

    /// Time allotted to a single speaker for a given present-count, honouring the
    /// duration mode: in `.total` it splits the whole length, in `.perSpeaker`
    /// it's the fixed per-speaker value regardless of count.
    public func timePerPerson(forCount count: Int) -> TimeInterval {
        switch durationMode {
        case .total:
            guard count > 0 else { return totalDuration }
            return totalDuration / Double(count)
        case .perSpeaker:
            return perSpeakerDuration
        }
    }

    /// The displayed total length for a given present-count: `totalDuration` in
    /// `.total`, or `perSpeakerDuration × count` in `.perSpeaker`.
    public func effectiveTotalDuration(forCount count: Int) -> TimeInterval {
        switch durationMode {
        case .total:      return totalDuration
        case .perSpeaker: return perSpeakerDuration * Double(max(1, count))
        }
    }

    // MARK: - Persistence

    public init() {
        isBatching = true
        load()
        isBatching = false
    }

    private func load() {
        let d = UserDefaults.standard

        if let data = d.data(forKey: "meeting.participants"),
           let saved = try? JSONDecoder().decode([Participant].self, from: data) {
            participants = saved
        }
        if d.object(forKey: "meeting.totalDuration") != nil {
            totalDuration = d.double(forKey: "meeting.totalDuration")
        }
        if let raw = d.string(forKey: "meeting.durationMode"),
           let mode = DurationMode(rawValue: raw) {
            durationMode = mode
        }
        if d.object(forKey: "meeting.perSpeakerDuration") != nil {
            perSpeakerDuration = d.double(forKey: "meeting.perSpeakerDuration")
        }
        if let raw = d.string(forKey: "meeting.overtimeMode"),
           let mode = OvertimeMode(rawValue: raw) {
            overtimeMode = mode
        }
        if let raw = d.string(forKey: "meeting.bannerPosition"),
           let pos = BannerPosition(rawValue: raw) {
            bannerPosition = pos
        }
        randomizeOrder = d.bool(forKey: "meeting.randomizeOrder")
        loadBool(d, "meeting.autoPlay", &autoPlay)
        loadBool(d, "meeting.speakerTransition", &speakerTransition)
        loadBool(d, "meeting.speakerDots", &speakerDots)
        loadBool(d, "meeting.confetti", &confetti)
        loadBool(d, "meeting.soundEnabled", &soundEnabled)
        loadBool(d, "meeting.countdownEnabled", &countdownEnabled)
        loadBool(d, "meeting.launchAtLogin", &launchAtLogin)
        loadBool(d, "meeting.reminderEnabled", &reminderEnabled)
        if d.object(forKey: "meeting.reminderHour") != nil {
            reminderHour = d.integer(forKey: "meeting.reminderHour")
            reminderMinute = d.integer(forKey: "meeting.reminderMinute")
        }
        if let days = d.array(forKey: "meeting.reminderWeekdays") as? [Int] {
            reminderWeekdays = Set(days)
        }
    }

    private func loadBool(_ d: UserDefaults, _ key: String, _ prop: inout Bool) {
        if d.object(forKey: key) != nil { prop = d.bool(forKey: key) }
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(participants) {
            d.set(data, forKey: "meeting.participants")
        }
        d.set(totalDuration, forKey: "meeting.totalDuration")
        d.set(durationMode.rawValue, forKey: "meeting.durationMode")
        d.set(perSpeakerDuration, forKey: "meeting.perSpeakerDuration")
        d.set(overtimeMode.rawValue, forKey: "meeting.overtimeMode")
        d.set(randomizeOrder, forKey: "meeting.randomizeOrder")
        d.set(autoPlay, forKey: "meeting.autoPlay")
        d.set(speakerTransition, forKey: "meeting.speakerTransition")
        d.set(speakerDots, forKey: "meeting.speakerDots")
        d.set(confetti, forKey: "meeting.confetti")
        d.set(soundEnabled, forKey: "meeting.soundEnabled")
        d.set(countdownEnabled, forKey: "meeting.countdownEnabled")
        d.set(bannerPosition.rawValue, forKey: "meeting.bannerPosition")
        d.set(launchAtLogin, forKey: "meeting.launchAtLogin")
        d.set(reminderEnabled, forKey: "meeting.reminderEnabled")
        d.set(reminderHour, forKey: "meeting.reminderHour")
        d.set(reminderMinute, forKey: "meeting.reminderMinute")
        d.set(Array(reminderWeekdays).sorted(), forKey: "meeting.reminderWeekdays")
    }

    public func rotateParticipants() {
        guard participants.count > 1 else { return }
        let first = participants.removeFirst()
        participants.append(first)
    }

    public func applyFreePersonalizationDefaults() {
        batchUpdate { meeting in
            meeting.bannerPosition = .topCenter
            meeting.speakerTransition = true
            meeting.speakerDots = true
            meeting.confetti = true
        }
    }
}
