import Foundation

enum OvertimeMode: String, CaseIterable, Identifiable, Codable {
    case optional = "Optionnel"
    case always = "Toujours"
    case never = "Jamais"

    var id: String { rawValue }
}

enum ColorTheme: String, CaseIterable, Identifiable, Codable {
    case greenRed = "Vert/Rouge"
    case blueOrange = "Bleu/Orange"
    case tealPink = "Sarcelle/Rose"
    case purpleYellow = "Violet/Jaune"

    var id: String { rawValue }
}

@Observable
final class Meeting {
    private var isBatching = false

    var totalDuration: TimeInterval = 900 { didSet { saveIfNeeded() } }
    var participants: [Participant] = [] { didSet { saveIfNeeded() } }
    var overtimeMode: OvertimeMode = .optional { didSet { saveIfNeeded() } }
    var randomizeOrder: Bool = false { didSet { saveIfNeeded() } }
    var ribbonEnabled: Bool = true { didSet { saveIfNeeded() } }
    var autoPlay: Bool = true { didSet { saveIfNeeded() } }

    // Visual effects
    var speakerTransition: Bool = true { didSet { saveIfNeeded() } }
    var speakerDots: Bool = true { didSet { saveIfNeeded() } }
    var ribbonGlow: Bool = true { didSet { saveIfNeeded() } }
    var ribbonThicken: Bool = true { didSet { saveIfNeeded() } }
    var confetti: Bool = true { didSet { saveIfNeeded() } }
    var overtimeShake: Bool = true { didSet { saveIfNeeded() } }

    // Sound
    var soundEnabled: Bool = true { didSet { saveIfNeeded() } }

    // Countdown
    var countdownEnabled: Bool = true { didSet { saveIfNeeded() } }

    // Theme
    var colorTheme: ColorTheme = .greenRed { didSet { saveIfNeeded() } }

    // Launch at login
    var launchAtLogin: Bool = false { didSet { saveIfNeeded() } }

    // Daily reminder
    var reminderEnabled: Bool = false { didSet { saveIfNeeded() } }
    var reminderHour: Int = 9 { didSet { saveIfNeeded() } }
    var reminderMinute: Int = 30 { didSet { saveIfNeeded() } }

    private func saveIfNeeded() { if !isBatching { save() } }

    func batchUpdate(_ block: (Meeting) -> Void) {
        isBatching = true
        block(self)
        isBatching = false
        save()
    }

    var timePerPerson: TimeInterval {
        guard !participants.isEmpty else { return totalDuration }
        return totalDuration / Double(participants.count)
    }

    // MARK: - Persistence

    init() {
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
        if let raw = d.string(forKey: "meeting.overtimeMode"),
           let mode = OvertimeMode(rawValue: raw) {
            overtimeMode = mode
        }
        if let raw = d.string(forKey: "meeting.colorTheme"),
           let theme = ColorTheme(rawValue: raw) {
            colorTheme = theme
        }
        randomizeOrder = d.bool(forKey: "meeting.randomizeOrder")
        loadBool(d, "meeting.ribbonEnabled", &ribbonEnabled)
        loadBool(d, "meeting.autoPlay", &autoPlay)
        loadBool(d, "meeting.speakerTransition", &speakerTransition)
        loadBool(d, "meeting.speakerDots", &speakerDots)
        loadBool(d, "meeting.ribbonGlow", &ribbonGlow)
        loadBool(d, "meeting.ribbonThicken", &ribbonThicken)
        loadBool(d, "meeting.confetti", &confetti)
        loadBool(d, "meeting.overtimeShake", &overtimeShake)
        loadBool(d, "meeting.soundEnabled", &soundEnabled)
        loadBool(d, "meeting.countdownEnabled", &countdownEnabled)
        loadBool(d, "meeting.launchAtLogin", &launchAtLogin)
        loadBool(d, "meeting.reminderEnabled", &reminderEnabled)
        if d.object(forKey: "meeting.reminderHour") != nil {
            reminderHour = d.integer(forKey: "meeting.reminderHour")
            reminderMinute = d.integer(forKey: "meeting.reminderMinute")
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
        d.set(overtimeMode.rawValue, forKey: "meeting.overtimeMode")
        d.set(randomizeOrder, forKey: "meeting.randomizeOrder")
        d.set(ribbonEnabled, forKey: "meeting.ribbonEnabled")
        d.set(autoPlay, forKey: "meeting.autoPlay")
        d.set(speakerTransition, forKey: "meeting.speakerTransition")
        d.set(speakerDots, forKey: "meeting.speakerDots")
        d.set(ribbonGlow, forKey: "meeting.ribbonGlow")
        d.set(ribbonThicken, forKey: "meeting.ribbonThicken")
        d.set(confetti, forKey: "meeting.confetti")
        d.set(overtimeShake, forKey: "meeting.overtimeShake")
        d.set(soundEnabled, forKey: "meeting.soundEnabled")
        d.set(countdownEnabled, forKey: "meeting.countdownEnabled")
        d.set(colorTheme.rawValue, forKey: "meeting.colorTheme")
        d.set(launchAtLogin, forKey: "meeting.launchAtLogin")
        d.set(reminderEnabled, forKey: "meeting.reminderEnabled")
        d.set(reminderHour, forKey: "meeting.reminderHour")
        d.set(reminderMinute, forKey: "meeting.reminderMinute")
    }

    func rotateParticipants() {
        guard participants.count > 1 else { return }
        let first = participants.removeFirst()
        participants.append(first)
    }
}
