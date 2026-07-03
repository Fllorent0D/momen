import SwiftUI
import StandupKit
import Charts

/// The window chrome around ``StatsView``. The stats used to render inline in the
/// menu-bar popover where the participants / history / awards tabs were unreadably
/// cramped; hosting them in a real resizable window gives the content room.
struct StatsWindowView: View {
    var body: some View {
        StatsView()
            .padding(PulseSpacing.lg)
            .frame(minWidth: 520, minHeight: 480, maxHeight: .infinity, alignment: .top)
            .background(PulseColor.canvas)
    }
}

struct StatsView: View {
    @Environment(MeetingManager.self) private var manager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab = 0
    @State private var showResetConfirm = false

    private var store: StatsStore { manager.statsStore }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            if store.records.isEmpty {
                emptyState
            } else {
                summaryCards

                // Streak + MVP banner
                gamificationBanner

                PulseSegmentedControl(selection: $selectedTab, options: [
                    (0, "Participants"),
                    (1, "Historique"),
                    (2, "Tendances"),
                    (3, "Awards"),
                ])

                switch selectedTab {
                case 0: participantsTab
                case 1: historyTab
                case 2: trendsTab
                case 3: awardsTab
                default: EmptyView()
                }

                // Export + Reset
                if showResetConfirm {
                    HStack {
                        Text("Tout supprimer ?")
                            .pulseText(.callout)
                            .foregroundStyle(PulseColor.over)
                        Spacer()
                        Button("Annuler") {
                            showResetConfirm = false
                        }
                        .buttonStyle(.pulse(.secondary, accent: .inkMuted, size: .small))

                        Button("Supprimer") {
                            manager.statsStore.clearAll()
                            showResetConfirm = false
                        }
                        .buttonStyle(.pulse(.destructive, size: .small))
                    }
                    .padding(PulseSpacing.xs)
                    .background(PulseColor.over.color(for: colorScheme).opacity(0.1), in: RoundedRectangle(cornerRadius: PulseRadius.control))
                } else {
                    HStack {
                        Button {
                            showResetConfirm = true
                        } label: {
                            Label("Réinitialiser", systemImage: "trash")
                        }
                        .buttonStyle(.pulse(.secondary, accent: .over, size: .small))

                        Spacer()

                        Button {
                            manager.saveCSVToFile()
                        } label: {
                            Label("Exporter CSV", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.pulse(.secondary, accent: .inkMuted, size: .small))
                    }
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: PulseSpacing.xs) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundStyle(PulseColor.inkMuted)
            Text("Aucune donnée")
                .pulseText(.heading)
                .foregroundStyle(PulseColor.ink)
            Text("Les statistiques apparaîtront après votre première réunion.")
                .pulseText(.callout)
                .foregroundStyle(PulseColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseSpacing.lg)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        let records = store.records
        let totalMeetings = records.count
        let avgDuration = records.map(\.totalDuration).reduce(0, +) / Double(max(totalMeetings, 1))
        let allSpeakers = records.flatMap(\.speakers)
        let overtimeCount = allSpeakers.filter(\.wasOvertime).count
        let overtimeRate = allSpeakers.isEmpty ? 0 : Double(overtimeCount) / Double(allSpeakers.count)
        let totalTime = records.map(\.totalDuration).reduce(0, +)

        return HStack(spacing: PulseSpacing.sm) {
            statCard(value: "\(totalMeetings)", label: "réunions", icon: "calendar")
            statCard(value: TimeFormatter.format(avgDuration), label: "moy./réunion", icon: "clock")
            statCard(value: "\(Int(overtimeRate * 100))%", label: "dépassements", icon: "exclamationmark.triangle",
                     color: overtimeRate > 0.3 ? .over : overtimeRate > 0.1 ? .warn : .signal)
            statCard(value: formatTotalTime(totalTime), label: "temps total", icon: "hourglass")
        }
    }

    private func statCard(value: String, label: String, icon: String, color: PulseColor = .ink) -> some View {
        VStack(spacing: PulseSpacing.xxs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .pulseText(.mono)
                .foregroundStyle(color)
            Text(label)
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .pulseRow()
    }

    // MARK: - Participants Tab

    private var participantsTab: some View {
        ScrollView {
            VStack(spacing: PulseSpacing.xs) {
                ForEach(rankedParticipants, id: \.name) { p in
                    participantRow(p)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private struct ParticipantStat {
        let name: String
        let avgTime: TimeInterval
        let overtimeRate: Double
        let totalSessions: Int
        let totalOvertime: TimeInterval
    }

    private var rankedParticipants: [ParticipantStat] {
        store.allParticipantNames.map { name in
            let entries = store.records.flatMap(\.speakers).filter { $0.participantName == name }
            let avg = entries.map(\.actualTime).reduce(0, +) / Double(max(entries.count, 1))
            let otCount = entries.filter(\.wasOvertime).count
            let otRate = entries.isEmpty ? 0 : Double(otCount) / Double(entries.count)
            let totalOt = entries.map(\.overtime).reduce(0, +)
            return ParticipantStat(name: name, avgTime: avg, overtimeRate: otRate, totalSessions: entries.count, totalOvertime: totalOt)
        }
        .sorted { $0.avgTime > $1.avgTime }
    }

    private func participantRow(_ p: ParticipantStat) -> some View {
        VStack(spacing: PulseSpacing.xs) {
            HStack {
                // Rank badge
                let rank = (rankedParticipants.firstIndex(where: { $0.name == p.name }) ?? 0) + 1
                Text("\(rank)")
                    .font(.caption2.bold())
                    .foregroundStyle(PulseColor.canvas.color(for: colorScheme))
                    .frame(width: 20, height: 20)
                    .background(rank <= 3 ? PulseColor.warn : PulseColor.inkMuted, in: Circle())

                // Per-person identity accent (keyed by name — stats hold no UUID).
                Circle()
                    .fill(PulseAccent.color(forName: p.name))
                    .frame(width: 8, height: 8)

                Text(p.name)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink)

                Spacer()

                Text("\(p.totalSessions)x")
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted)

                Text(TimeFormatter.format(p.avgTime))
                    .pulseText(.mono)
                    .foregroundStyle(PulseColor.ink)

                // Overtime badge
                PulseStatusPill("\(Int(p.overtimeRate * 100))%", tone: tone(for: p.overtimeRate), filled: true)
            }

            // Time bar
            GeometryReader { geo in
                let maxTime = rankedParticipants.first?.avgTime ?? 1
                let width = geo.size.width * (p.avgTime / maxTime)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(for: p.overtimeRate))
                        .frame(width: max(width, 4))
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 6)
        }
        .pulseRow()
    }

    private func barColor(for rate: Double) -> PulseColor {
        rate > 0.5 ? .over : rate > 0.2 ? .warn : .signal
    }

    private func tone(for rate: Double) -> PulseTone {
        rate > 0.5 ? .over : rate > 0.2 ? .warn : .signal
    }

    // MARK: - History Tab

    private var historyTab: some View {
        ScrollView {
            VStack(spacing: PulseSpacing.xs) {
                ForEach(store.records.reversed()) { record in
                    meetingRow(record)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func meetingRow(_ record: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
            HStack {
                Text(record.date, style: .date)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink)
                Text(record.date, style: .time)
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted)

                if let preset = record.presetName {
                    PulseStatusPill(preset, tone: .neutral)
                }

                Spacer()

                Text(TimeFormatter.format(record.totalDuration))
                    .pulseText(.mono)
                    .foregroundStyle(PulseColor.ink)
            }

            // Speaker pills
            HStack(spacing: PulseSpacing.xxs) {
                ForEach(record.speakers) { speaker in
                    HStack(spacing: 3) {
                        Text(String(speaker.participantName.prefix(8)))
                            .font(.system(size: 9))
                        Text(TimeFormatter.format(speaker.actualTime))
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundStyle((speaker.wasOvertime ? PulseColor.over : PulseColor.signal))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        (speaker.wasOvertime ? PulseColor.over : PulseColor.signal).color(for: colorScheme).opacity(0.15),
                        in: Capsule()
                    )
                }
            }
        }
        .pulseRow()
    }

    // MARK: - Trends Tab

    private var trendsTab: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            if store.records.count >= 2 {
                // Meeting duration trend
                Text("Durée des réunions")
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted)

                Chart(store.records.suffix(20)) { record in
                    BarMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Durée", record.totalDuration / 60)
                    )
                    .foregroundStyle(PulseColor.signal.color(for: colorScheme).gradient)
                    .cornerRadius(3)
                }
                .chartYAxisLabel("minutes")
                .frame(height: 120)

                // Overtime trend
                Text("Taux de dépassement")
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted)

                Chart(overtimeTrendData.suffix(20)) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Taux", point.rate * 100)
                    )
                    .foregroundStyle(PulseColor.warn)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Taux", point.rate * 100)
                    )
                    .foregroundStyle(PulseColor.warn.color(for: colorScheme).opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxisLabel("%")
                .frame(height: 120)
            } else {
                Text("Il faut au moins 2 réunions pour voir les tendances.")
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PulseSpacing.lg)
            }
        }
    }

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let rate: Double
    }

    private var overtimeTrendData: [TrendPoint] {
        store.records.map { record in
            let otCount = record.speakers.filter(\.wasOvertime).count
            let rate = record.speakers.isEmpty ? 0 : Double(otCount) / Double(record.speakers.count)
            return TrendPoint(date: record.date, rate: rate)
        }
    }

    // MARK: - Gamification Banner

    private var gamificationBanner: some View {
        let gam = manager.gamification
        return HStack(spacing: PulseSpacing.sm) {
            // Streak
            HStack(spacing: PulseSpacing.xxs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(gam.currentStreak >= 3 ? PulseColor.warn : PulseColor.inkMuted)
                Text("\(gam.currentStreak)j")
                    .pulseText(.mono)
                    .foregroundStyle(PulseColor.ink)
            }
            .help("Streak : \(gam.currentStreak) jours consécutifs (record : \(gam.longestStreak))")

            Rectangle()
                .fill(PulseColor.inkMuted.color(for: colorScheme).opacity(0.3))
                .frame(width: 1, height: 16)

            // Badges unlocked
            HStack(spacing: PulseSpacing.xxs) {
                Image(systemName: "rosette").foregroundStyle(PulseColor.warn)
                Text("\(manager.badgeStore.unlockedCount)/\(manager.badgeStore.totalCount)")
                    .pulseText(.mono)
                    .foregroundStyle(PulseColor.ink)
            }
            .help("Badges débloqués")

            Spacer()
        }
        .pulseRow()
    }

    // MARK: - Badges Tab

    /// The full badge collection (issue #43): every catalogue badge as an
    /// `AchievementMedallion` in a tiered grid — unlocked in full colour with its
    /// unlock date, locked non-secrets desaturated with "X/N" progress, locked
    /// secrets reduced to "???". A counter header shows global completion.
    private var awardsTab: some View {
        let badgeStore = manager.badgeStore
        // One stats snapshot feeds every progress caption.
        let stats = BadgeStats(records: store.records)
        return ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                // Global completion counter.
                HStack(spacing: PulseSpacing.xxs) {
                    Image(systemName: "rosette")
                        .foregroundStyle(PulseColor.warn)
                    Text("\(badgeStore.unlockedCount) / \(badgeStore.totalCount) badges")
                        .pulseText(.mono)
                        .foregroundStyle(PulseColor.ink)
                    Spacer()
                }
                .pulseRow()

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 76), spacing: PulseSpacing.sm)],
                    spacing: PulseSpacing.md
                ) {
                    ForEach(orderedBadges) { badge in
                        badgeCell(badge, store: badgeStore, stats: stats)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// Catalogue ordered common → legendary with secrets last (stable within tier).
    private var orderedBadges: [Badge] {
        BadgeCatalog.all.enumerated()
            .sorted {
                $0.element.tier.order != $1.element.tier.order
                    ? $0.element.tier.order < $1.element.tier.order
                    : $0.offset < $1.offset
            }
            .map(\.element)
    }

    private func badgeCell(_ badge: Badge, store badgeStore: BadgeStore, stats: BadgeStats) -> some View {
        let unlocked = badgeStore.isUnlocked(badge.id)
        return VStack(spacing: PulseSpacing.xxs) {
            AchievementMedallion(badge: badge, unlocked: unlocked, size: 64, progress: badge.progress(stats))

            if unlocked {
                Text(badge.title)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let date = badgeStore.unlockDate(badge.id) {
                    Text(date, style: .date)
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.inkMuted)
                }
            } else if badge.isSecret {
                Text("???")
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.inkMuted)
            } else {
                Text(badge.title)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(min(badge.currentValue(stats), badge.target))/\(badge.target)")
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func formatTotalTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(minutes > 0 ? String(format: "%02d", minutes) : "")"
        }
        return "\(minutes)m"
    }
}
