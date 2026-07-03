import Foundation

// MARK: - Tier

/// Visual/rarity tier of a badge. Maps to the "metal" palette decided in BADGES.md
/// (Commun → Peu commun → Rare → Légendaire), plus a separate Secret track.
public enum BadgeTier: String, Codable, CaseIterable, Sendable {
    case common      // Commun
    case uncommon    // Peu commun
    case rare        // Rare
    case legendary   // Légendaire
    case secret      // Secret (hidden until unlocked)

    /// Working-title French label (owner replaces artwork/labels later).
    public var label: String {
        switch self {
        case .common:    return String(localized: "Commun", bundle: .standupKit)
        case .uncommon:  return String(localized: "Peu commun", bundle: .standupKit)
        case .rare:      return String(localized: "Rare", bundle: .standupKit)
        case .legendary: return String(localized: "Légendaire", bundle: .standupKit)
        case .secret:    return String(localized: "Secret", bundle: .standupKit)
        }
    }

    /// Sort/strength order (used by the future grid #43).
    public var order: Int {
        switch self {
        case .common:    return 0
        case .uncommon:  return 1
        case .rare:      return 2
        case .legendary: return 3
        case .secret:    return 4
        }
    }
}

// MARK: - Computed stats

/// Deterministic snapshot of everything the badge rules need, derived purely from
/// the meeting history. No persistence here — recomputed from `StatsStore.records`.
public struct BadgeStats: Sendable {
    public let totalMeetings: Int
    public let currentStreak: Int          // consecutive days up to today/yesterday
    public let longestStreak: Int          // best consecutive-days run ever
    public let perfectMeetings: Int        // meetings where nobody went overtime
    public let longestPerfectStreak: Int   // best run of consecutive perfect meetings
    public let distinctParticipants: Int   // unique speaker names ever seen
    public let maxParticipantsInMeeting: Int
    public let shortestMeetingDuration: TimeInterval  // .greatestFiniteMagnitude if none
    public let totalSpeakingTime: TimeInterval        // cumulative actual speaking time
    public let earliestStartHour: Int      // 0-23, or 99 if no records
    public let latestStartHour: Int        // 0-23, or -1 if no records
    public let hasWeekendMeeting: Bool

    public init(records: [MeetingRecord], calendar: Calendar = .current) {
        totalMeetings = records.count

        // Perfect = no speaker overran their slot.
        let perfectFlags = records
            .sorted { $0.date < $1.date }
            .map { $0.speakers.allSatisfy { !$0.wasOvertime } }
        perfectMeetings = perfectFlags.filter { $0 }.count

        // Longest run of consecutive perfect meetings (chronological).
        var bestPerfect = 0, runPerfect = 0
        for flag in perfectFlags {
            if flag { runPerfect += 1; bestPerfect = max(bestPerfect, runPerfect) }
            else { runPerfect = 0 }
        }
        longestPerfectStreak = bestPerfect

        // Day-based streaks.
        currentStreak = Self.computeCurrentStreak(records: records, calendar: calendar)
        longestStreak = Self.computeLongestStreak(records: records, calendar: calendar)

        let allSpeakers = records.flatMap(\.speakers)
        distinctParticipants = Set(allSpeakers.map(\.participantName)).count
        maxParticipantsInMeeting = records.map { $0.speakers.count }.max() ?? 0
        shortestMeetingDuration = records.map(\.totalDuration).min() ?? .greatestFiniteMagnitude
        totalSpeakingTime = allSpeakers.map(\.actualTime).reduce(0, +)

        let hours = records.map { calendar.component(.hour, from: $0.date) }
        earliestStartHour = hours.min() ?? 99
        latestStartHour = hours.max() ?? -1
        hasWeekendMeeting = records.contains { record in
            let weekday = calendar.component(.weekday, from: record.date)
            return weekday == 1 || weekday == 7 // Sunday / Saturday
        }
    }

    // MARK: Streak helpers (deterministic from record dates)

    static func computeCurrentStreak(records: [MeetingRecord], calendar: Calendar) -> Int {
        let days = Set(records.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard let latest = days.first else { return 0 }
        let today = calendar.startOfDay(for: Date())
        guard let gap = calendar.dateComponents([.day], from: latest, to: today).day, gap <= 1 else { return 0 }

        var streak = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i], to: days[i - 1]).day ?? 0
            if diff == 1 { streak += 1 } else { break }
        }
        return streak
    }

    static func computeLongestStreak(records: [MeetingRecord], calendar: Calendar) -> Int {
        let days = Set(records.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard days.count >= 2 else { return days.count }
        var longest = 1, current = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 0
            if diff == 1 { current += 1; longest = max(longest, current) }
            else { current = 1 }
        }
        return longest
    }
}

// MARK: - Badge

/// A single achievement. The unlock rule is expressed as a progress value compared
/// against `target`, so the same model drives both unlocking and future progress UI (#43).
public struct Badge: Identifiable, Sendable {
    public let id: String          // stable, e.g. "premier_standup"
    public let title: String       // working-title label
    public let subtitle: String
    public let systemImage: String // SF Symbol drawn (engraved) inside the medallion (#19)
    public let tier: BadgeTier
    public let isSecret: Bool
    public let target: Int         // threshold the progress value must reach

    /// Current progress toward `target` for the given stats (deterministic).
    let valueProvider: @Sendable (BadgeStats) -> Int

    init(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        tier: BadgeTier,
        isSecret: Bool = false,
        target: Int,
        value: @escaping @Sendable (BadgeStats) -> Int
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tier = tier
        self.isSecret = isSecret
        self.target = target
        self.valueProvider = value
    }

    /// Suggested asset name, kept for any legacy/optional artwork override.
    public var assetName: String { "badge_\(id)" }

    public func currentValue(_ stats: BadgeStats) -> Int { valueProvider(stats) }

    public func isUnlocked(by stats: BadgeStats) -> Bool { valueProvider(stats) >= target }

    /// 0…1 fraction toward unlock (for progress rings / "X/N" in the grid).
    public func progress(_ stats: BadgeStats) -> Double {
        guard target > 0 else { return 0 }
        return min(1, Double(valueProvider(stats)) / Double(target))
    }
}

// MARK: - Catalog

/// ~23 badges spanning the tiers. Labels are working titles; rules are deterministic
/// from `BadgeStats`. Boolean rules use `target: 1` with a 0/1 value.
public enum BadgeCatalog {
    public static let all: [Badge] = [

        // ── Commun ──────────────────────────────────────────────
        Badge(id: "premier_standup", title: String(localized: "Premier pas", bundle: .standupKit), subtitle: String(localized: "Ton tout premier standup", bundle: .standupKit),
              systemImage: "figure.walk", tier: .common, target: 1) { $0.totalMeetings },
        Badge(id: "trois_standups", title: String(localized: "Mise en route", bundle: .standupKit), subtitle: String(localized: "3 standups au compteur", bundle: .standupKit),
              systemImage: "play.circle.fill", tier: .common, target: 3) { $0.totalMeetings },
        Badge(id: "premiere_serie", title: String(localized: "En rythme", bundle: .standupKit), subtitle: String(localized: "2 jours d'affilée", bundle: .standupKit),
              systemImage: "calendar", tier: .common, target: 2) { $0.currentStreak },
        Badge(id: "premier_sans_faute", title: String(localized: "Pile à l'heure", bundle: .standupKit), subtitle: String(localized: "Un standup sans dépassement", bundle: .standupKit),
              systemImage: "checkmark.circle.fill", tier: .common, target: 1) { $0.perfectMeetings },
        Badge(id: "petite_equipe", title: String(localized: "En équipe", bundle: .standupKit), subtitle: String(localized: "Un standup à 3 ou plus", bundle: .standupKit),
              systemImage: "person.2.fill", tier: .common, target: 3) { $0.maxParticipantsInMeeting },

        // ── Peu commun ──────────────────────────────────────────
        Badge(id: "dix_standups", title: String(localized: "Habitué", bundle: .standupKit), subtitle: String(localized: "10 standups au compteur", bundle: .standupKit),
              systemImage: "flame.fill", tier: .uncommon, target: 10) { $0.totalMeetings },
        Badge(id: "serie_5j", title: String(localized: "Semaine pleine", bundle: .standupKit), subtitle: String(localized: "5 jours consécutifs", bundle: .standupKit),
              systemImage: "calendar.badge.clock", tier: .uncommon, target: 5) { $0.longestStreak },
        Badge(id: "cinq_sans_faute", title: String(localized: "Régularité", bundle: .standupKit), subtitle: String(localized: "5 standups sans dépassement", bundle: .standupKit),
              systemImage: "star.fill", tier: .uncommon, target: 5) { $0.perfectMeetings },
        Badge(id: "grande_equipe", title: String(localized: "Grande tablée", bundle: .standupKit), subtitle: String(localized: "Un standup à 6 ou plus", bundle: .standupKit),
              systemImage: "person.3.fill", tier: .uncommon, target: 6) { $0.maxParticipantsInMeeting },
        Badge(id: "eclair", title: String(localized: "Réunion éclair", bundle: .standupKit), subtitle: String(localized: "Un standup bouclé en moins de 3 min", bundle: .standupKit),
              systemImage: "bolt.fill", tier: .uncommon, target: 1) {
            $0.shortestMeetingDuration <= 180 ? 1 : 0
        },
        Badge(id: "dix_intervenants", title: String(localized: "Brasseur d'équipe", bundle: .standupKit), subtitle: String(localized: "10 intervenants différents", bundle: .standupKit),
              systemImage: "person.crop.circle.badge.plus", tier: .uncommon, target: 10) { $0.distinctParticipants },

        // ── Rare ────────────────────────────────────────────────
        Badge(id: "cinquante_standups", title: String(localized: "Pilier", bundle: .standupKit), subtitle: String(localized: "50 standups au compteur", bundle: .standupKit),
              systemImage: "building.columns.fill", tier: .rare, target: 50) { $0.totalMeetings },
        Badge(id: "serie_10j", title: String(localized: "Marathonien", bundle: .standupKit), subtitle: String(localized: "10 jours consécutifs", bundle: .standupKit),
              systemImage: "figure.run", tier: .rare, target: 10) { $0.longestStreak },
        Badge(id: "serie_parfaite_5", title: String(localized: "Sans accroc", bundle: .standupKit), subtitle: String(localized: "5 standups parfaits d'affilée", bundle: .standupKit),
              systemImage: "sparkles", tier: .rare, target: 5) { $0.longestPerfectStreak },
        Badge(id: "vingt_sans_faute", title: String(localized: "Maître du temps", bundle: .standupKit), subtitle: String(localized: "20 standups sans dépassement", bundle: .standupKit),
              systemImage: "timer", tier: .rare, target: 20) { $0.perfectMeetings },
        Badge(id: "dix_heures", title: String(localized: "Investi", bundle: .standupKit), subtitle: String(localized: "10 h de temps de parole cumulé", bundle: .standupKit),
              systemImage: "hourglass", tier: .rare, target: 36000) { Int($0.totalSpeakingTime) },

        // ── Légendaire ──────────────────────────────────────────
        Badge(id: "cent_standups", title: String(localized: "Légende du standup", bundle: .standupKit), subtitle: String(localized: "100 standups au compteur", bundle: .standupKit),
              systemImage: "crown.fill", tier: .legendary, target: 100) { $0.totalMeetings },
        Badge(id: "serie_30j", title: String(localized: "Increvable", bundle: .standupKit), subtitle: String(localized: "30 jours consécutifs", bundle: .standupKit),
              systemImage: "infinity", tier: .legendary, target: 30) { $0.longestStreak },
        Badge(id: "cinquante_sans_faute", title: String(localized: "Horloger suisse", bundle: .standupKit), subtitle: String(localized: "50 standups sans dépassement", bundle: .standupKit),
              systemImage: "clock.badge.checkmark.fill", tier: .legendary, target: 50) { $0.perfectMeetings },
        Badge(id: "serie_parfaite_15", title: String(localized: "Perfection absolue", bundle: .standupKit), subtitle: String(localized: "15 standups parfaits d'affilée", bundle: .standupKit),
              systemImage: "rosette", tier: .legendary, target: 15) { $0.longestPerfectStreak },

        // ── Secret ──────────────────────────────────────────────
        Badge(id: "leve_tot", title: String(localized: "Lève-tôt", bundle: .standupKit), subtitle: String(localized: "Un standup avant 7 h", bundle: .standupKit),
              systemImage: "sunrise.fill", tier: .secret, isSecret: true, target: 1) {
            $0.earliestStartHour < 7 ? 1 : 0
        },
        Badge(id: "couche_tard", title: String(localized: "Couche-tard", bundle: .standupKit), subtitle: String(localized: "Un standup à 20 h ou plus tard", bundle: .standupKit),
              systemImage: "moon.stars.fill", tier: .secret, isSecret: true, target: 1) {
            $0.latestStartHour >= 20 ? 1 : 0
        },
        Badge(id: "weekend_warrior", title: String(localized: "Guerrier du week-end", bundle: .standupKit), subtitle: String(localized: "Un standup le week-end", bundle: .standupKit),
              systemImage: "beach.umbrella.fill", tier: .secret, isSecret: true, target: 1) {
            $0.hasWeekendMeeting ? 1 : 0
        },
    ]

    public static func badge(id: String) -> Badge? { all.first { $0.id == id } }
}

// MARK: - Store

/// Persists the set of unlocked badges as `{ badgeId: unlockDate }` in a JSON file,
/// mirroring `StatsStore`/`PresetStore`. `evaluate` unlocks any newly-satisfied badges
/// and returns ONLY the new ones, so the caller can trigger a reveal (#42).
@Observable
public final class BadgeStore {
    /// badgeId → date first unlocked.
    public private(set) var unlocked: [String: Date] = [:]

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("StandupTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("badges.json")
    }

    public init() { load() }

    public var unlockedCount: Int { unlocked.count }
    public var totalCount: Int { BadgeCatalog.all.count }

    public func isUnlocked(_ id: String) -> Bool { unlocked[id] != nil }
    public func unlockDate(_ id: String) -> Date? { unlocked[id] }

    /// Unlocks any badge whose rule is now satisfied, persists its unlock date,
    /// and returns the newly-unlocked badges (empty if nothing changed).
    @discardableResult
    public func evaluate(stats: BadgeStats, now: Date = Date()) -> [Badge] {
        var newly: [Badge] = []
        for badge in BadgeCatalog.all where unlocked[badge.id] == nil {
            if badge.isUnlocked(by: stats) {
                unlocked[badge.id] = now
                newly.append(badge)
            }
        }
        if !newly.isEmpty { save() }
        return newly
    }

    /// Convenience overload: evaluate straight from the meeting history.
    @discardableResult
    public func evaluate(records: [MeetingRecord], now: Date = Date()) -> [Badge] {
        evaluate(stats: BadgeStats(records: records), now: now)
    }

    public func clearAll() {
        unlocked.removeAll()
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.fileURL.path),
              let data = try? Data(contentsOf: Self.fileURL),
              let saved = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return }
        unlocked = saved
    }

    private func save() {
        if let data = try? JSONEncoder().encode(unlocked) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
