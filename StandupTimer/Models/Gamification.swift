import Foundation

struct Award: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

@Observable
final class GamificationStore {
    private var store: StatsStore

    init(store: StatsStore) {
        self.store = store
    }

    // MARK: - Streak

    var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(store.records.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard let latest = days.first else { return 0 }

        // Check if latest is today or yesterday
        let today = calendar.startOfDay(for: Date())
        guard calendar.dateComponents([.day], from: latest, to: today).day! <= 1 else { return 0 }

        var streak = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i], to: days[i - 1]).day!
            if diff == 1 { streak += 1 } else { break }
        }
        return streak
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        let days = Set(store.records.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard days.count >= 2 else { return days.count }

        var longest = 1, current = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i - 1], to: days[i]).day!
            if diff == 1 { current += 1; longest = max(longest, current) }
            else { current = 1 }
        }
        return longest
    }

    // MARK: - MVP

    var weeklyMVP: (name: String, avgTime: TimeInterval)? {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let recentSpeakers = store.records
            .filter { $0.date >= weekAgo }
            .flatMap(\.speakers)

        let grouped = Dictionary(grouping: recentSpeakers, by: \.participantName)
        guard !grouped.isEmpty else { return nil }

        let fastest = grouped.mapValues { entries in
            entries.map(\.actualTime).reduce(0, +) / Double(entries.count)
        }
        .min(by: { $0.value < $1.value })

        guard let winner = fastest else { return nil }
        return (name: winner.key, avgTime: winner.value)
    }

    // MARK: - Awards

    var awards: [Award] {
        var result: [Award] = []
        let records = store.records
        guard !records.isEmpty else { return result }

        // Shortest meeting
        if let shortest = records.min(by: { $0.totalDuration < $1.totalDuration }) {
            result.append(Award(
                icon: "bolt.fill",
                title: "Réunion éclair",
                description: "Plus courte : \(TimeFormatter.format(shortest.totalDuration))"
            ))
        }

        // Perfect meeting (0% overtime)
        let perfectCount = records.filter { $0.speakers.allSatisfy { !$0.wasOvertime } }.count
        if perfectCount > 0 {
            result.append(Award(
                icon: "star.fill",
                title: "Perfection",
                description: "\(perfectCount) réunion\(perfectCount > 1 ? "s" : "") sans dépassement"
            ))
        }

        // Most meetings
        let totalMeetings = records.count
        if totalMeetings >= 5 {
            result.append(Award(
                icon: "flame.fill",
                title: "Assidu",
                description: "\(totalMeetings) réunions au compteur"
            ))
        }

        // Streak awards
        let streak = currentStreak
        if streak >= 3 {
            result.append(Award(
                icon: "trophy.fill",
                title: "Streak \(streak)j",
                description: "\(streak) jours consécutifs de standup"
            ))
        }

        // MVP
        if let mvp = weeklyMVP {
            result.append(Award(
                icon: "crown.fill",
                title: "MVP : \(mvp.name)",
                description: "Le plus rapide cette semaine (\(TimeFormatter.format(mvp.avgTime)))"
            ))
        }

        // Most overtime person
        let allSpeakers = records.flatMap(\.speakers)
        let grouped = Dictionary(grouping: allSpeakers, by: \.participantName)
        if let chattiest = grouped.max(by: {
            $0.value.map(\.overtime).reduce(0, +) < $1.value.map(\.overtime).reduce(0, +)
        }), chattiest.value.map(\.overtime).reduce(0, +) > 60 {
            let totalOt = chattiest.value.map(\.overtime).reduce(0, +)
            result.append(Award(
                icon: "mouth.fill",
                title: "Bavard : \(chattiest.key)",
                description: "\(TimeFormatter.format(totalOt)) de dépassement cumulé"
            ))
        }

        return result
    }
}
