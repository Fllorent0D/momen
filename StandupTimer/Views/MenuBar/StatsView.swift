import SwiftUI
import Charts

struct StatsView: View {
    @Environment(MeetingManager.self) private var manager

    @State private var selectedTab = 0

    private var store: StatsStore { manager.statsStore }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.records.isEmpty {
                emptyState
            } else {
                summaryCards

                // Streak + MVP banner
                gamificationBanner

                Picker("", selection: $selectedTab) {
                    Text("Participants").tag(0)
                    Text("Historique").tag(1)
                    Text("Tendances").tag(2)
                    Text("Awards").tag(3)
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case 0: participantsTab
                case 1: historyTab
                case 2: trendsTab
                case 3: awardsTab
                default: EmptyView()
                }

                // Export
                HStack {
                    Spacer()
                    Button {
                        manager.saveCSVToFile()
                    } label: {
                        Label("Exporter CSV", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Aucune donnée")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Les statistiques apparaîtront après votre première réunion.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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

        return HStack(spacing: 12) {
            statCard(value: "\(totalMeetings)", label: "réunions", icon: "calendar")
            statCard(value: TimeFormatter.format(avgDuration), label: "moy./réunion", icon: "clock")
            statCard(value: "\(Int(overtimeRate * 100))%", label: "dépassements", icon: "exclamationmark.triangle",
                     color: overtimeRate > 0.3 ? .red : overtimeRate > 0.1 ? .orange : .green)
            statCard(value: formatTotalTime(totalTime), label: "temps total", icon: "hourglass")
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Participants Tab

    private var participantsTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(rankedParticipants, id: \.name) { p in
                    participantRow(p)
                }
            }
        }
        .frame(maxHeight: 250)
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
        VStack(spacing: 6) {
            HStack {
                // Rank badge
                let rank = (rankedParticipants.firstIndex(where: { $0.name == p.name }) ?? 0) + 1
                Text("\(rank)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(rank <= 3 ? Color.orange : Color.gray, in: Circle())

                Text(p.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(p.totalSessions)x")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(TimeFormatter.format(p.avgTime))
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))

                // Overtime badge
                overtimeBadge(rate: p.overtimeRate)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func overtimeBadge(rate: Double) -> some View {
        let pct = Int(rate * 100)
        return Text("\(pct)%")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(barColor(for: rate), in: Capsule())
    }

    private func barColor(for rate: Double) -> Color {
        rate > 0.5 ? .red : rate > 0.2 ? .orange : .green
    }

    // MARK: - History Tab

    private var historyTab: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(store.records.reversed()) { record in
                    meetingRow(record)
                }
            }
        }
        .frame(maxHeight: 250)
    }

    private func meetingRow(_ record: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.date, style: .date)
                    .font(.caption.weight(.medium))
                Text(record.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let preset = record.presetName {
                    Text(preset)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                }

                Spacer()

                Text(TimeFormatter.format(record.totalDuration))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
            }

            // Speaker pills
            HStack(spacing: 4) {
                ForEach(record.speakers) { speaker in
                    HStack(spacing: 3) {
                        Text(String(speaker.participantName.prefix(8)))
                            .font(.system(size: 9))
                        Text(TimeFormatter.format(speaker.actualTime))
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        speaker.wasOvertime ? Color.red.opacity(0.15) : Color.green.opacity(0.15),
                        in: Capsule()
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Trends Tab

    private var trendsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.records.count >= 2 {
                // Meeting duration trend
                Text("Durée des réunions")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Chart(store.records.suffix(20)) { record in
                    BarMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Durée", record.totalDuration / 60)
                    )
                    .foregroundStyle(.green.gradient)
                    .cornerRadius(3)
                }
                .chartYAxisLabel("minutes")
                .frame(height: 120)

                // Overtime trend
                Text("Taux de dépassement")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Chart(overtimeTrendData.suffix(20)) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Taux", point.rate * 100)
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Taux", point.rate * 100)
                    )
                    .foregroundStyle(.orange.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxisLabel("%")
                .frame(height: 120)
            } else {
                Text("Il faut au moins 2 réunions pour voir les tendances.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
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
        return HStack(spacing: 12) {
            // Streak
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(gam.currentStreak >= 3 ? .orange : .secondary)
                Text("\(gam.currentStreak)j")
                    .font(.subheadline.bold())
            }
            .help("Streak : \(gam.currentStreak) jours consécutifs (record : \(gam.longestStreak))")

            Divider().frame(height: 16)

            // MVP
            if let mvp = gam.weeklyMVP {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill").foregroundStyle(.yellow)
                    Text(mvp.name).font(.subheadline.bold())
                    Text(TimeFormatter.format(mvp.avgTime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .help("MVP de la semaine — le plus rapide")
            }

            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Awards Tab

    private var awardsTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                let awards = manager.gamification.awards
                if awards.isEmpty {
                    Text("Pas encore de trophées. Continuez les standups !")
                        .font(.caption).foregroundStyle(.tertiary)
                        .padding(.vertical, 20)
                } else {
                    ForEach(awards) { award in
                        HStack(spacing: 10) {
                            Image(systemName: award.icon)
                                .font(.title3)
                                .foregroundStyle(.yellow)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(award.title).font(.subheadline.bold())
                                Text(award.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .frame(maxHeight: 250)
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
