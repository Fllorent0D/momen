import SwiftUI
import UIKit
import StandupKit

/// iOS statistics screen (Pulse redesign).
///
/// Surfaces the same figures as the macOS popover — a summary, meeting history,
/// per-speaker detail and an unlocked-badge list — but rendered with the Pulse
/// design system (cards on the canvas, mono numbers, accent dots, `.pulse`
/// chrome) instead of a native grouped `List`. Self-contained: it binds to
/// StandupKit stores directly (a `StatsStore` and an optional `BadgeStore`) so
/// it compiles and previews on its own, and exports via a share sheet.
public struct IOSStatsView: View {

    private let store: StatsStore
    private let badgeStore: BadgeStore?

    @State private var exportPayload: ExportPayload?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    public init(store: StatsStore, badgeStore: BadgeStore? = nil) {
        self.store = store
        self.badgeStore = badgeStore
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                PulseColor.canvas.color(for: colorScheme).ignoresSafeArea()
                if store.records.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Statistiques")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                        .tint(PulseColor.signal)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportPayload = ExportPayload(csv: exportCSV())
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .tint(PulseColor.signal)
                    .disabled(store.records.isEmpty)
                }
            }
            .sheet(item: $exportPayload) { payload in
                ShareSheet(items: [payload.csv])
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: PulseSpacing.md) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            Text("Aucune donnée")
                .pulseText(.heading)
                .foregroundStyle(PulseColor.ink.color(for: colorScheme))
            Text("Les statistiques apparaîtront après votre première réunion.")
                .pulseText(.body)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(PulseSpacing.xxl)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseSpacing.xl) {
                summaryGrid
                historySection
                badgesSection
            }
            .padding(PulseSpacing.xl)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Summary

    private var summaryGrid: some View {
        let records = store.records
        let allSpeakers = records.flatMap(\.speakers)
        let overtimeCount = allSpeakers.filter(\.wasOvertime).count
        let overtimeRate = allSpeakers.isEmpty ? 0 : Double(overtimeCount) / Double(allSpeakers.count)
        let streak = GamificationStore(store: store).currentStreak
        let totalTime = records.map(\.totalDuration).reduce(0, +)

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: PulseSpacing.sm),
                                   GridItem(.flexible(), spacing: PulseSpacing.sm)],
                         spacing: PulseSpacing.sm) {
            statTile(icon: "calendar", label: "Réunions",
                     value: "\(records.count)", tint: .ink)
            statTile(icon: "flame.fill", label: "Série en cours",
                     value: "\(streak) j", tint: streak >= 3 ? .warn : .inkMuted)
            statTile(icon: "exclamationmark.triangle", label: "Dépassement",
                     value: "\(Int(overtimeRate * 100)) %", tint: overrunTint(overtimeRate))
            statTile(icon: "hourglass", label: "Temps total",
                     value: formatTotalTime(totalTime), tint: .ink)
        }
    }

    private func statTile(icon: String, label: String, value: String, tint: PulseColor) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint.color(for: colorScheme))
            Text(value)
                .pulseText(.chronoCompact)
                .foregroundStyle(tint.color(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label.uppercased())
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                .fill(PulseColor.surface.color(for: colorScheme))
        )
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("HISTORIQUE")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            // Most recent first, mirroring the macOS reversed list.
            ForEach(store.records.reversed()) { record in
                NavigationLink {
                    MeetingDetailView(record: record)
                } label: {
                    meetingRow(record)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func meetingRow(_ record: MeetingRecord) -> some View {
        HStack(spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                HStack(spacing: PulseSpacing.xs) {
                    Text(record.date, style: .date)
                        .pulseText(.callout)
                        .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                    if let preset = record.presetName {
                        PulseStatusPill(preset, tone: .signal)
                    }
                }
                HStack(spacing: PulseSpacing.xs) {
                    Text(record.date, style: .time)
                    Text("·")
                    Image(systemName: "person.2")
                    Text("\(record.speakers.count)")
                }
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            }
            Spacer()
            Text(TimeFormatter.format(record.totalDuration))
                .pulseText(.mono)
                .foregroundStyle(PulseColor.ink.color(for: colorScheme))
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                .fill(PulseColor.surface.color(for: colorScheme))
        )
    }

    // MARK: - Badges

    /// The full badge collection (issue #43): every catalogue badge as an
    /// `AchievementMedallion` in a tiered grid on the canvas — unlocked in full
    /// colour with its unlock date, locked non-secrets desaturated with "X/N"
    /// progress, locked secrets reduced to "???" — plus a completion counter.
    private var badgesSection: some View {
        let unlockedCount = BadgeCatalog.all.filter { isUnlocked($0.id) }.count
        let total = badgeStore?.totalCount ?? BadgeCatalog.all.count
        // One stats snapshot feeds every progress caption (and the no-store fallback).
        let stats = BadgeStats(records: store.records)
        return VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("BADGES \(unlockedCount)/\(total)")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: PulseSpacing.md)],
                spacing: PulseSpacing.lg
            ) {
                ForEach(orderedBadges) { badge in
                    badgeCell(badge, stats: stats)
                }
            }
            .padding(PulseSpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                    .fill(PulseColor.surface.color(for: colorScheme))
            )
        }
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

    private func badgeCell(_ badge: Badge, stats: BadgeStats) -> some View {
        let unlocked = isUnlocked(badge.id)
        return VStack(spacing: PulseSpacing.xs) {
            AchievementMedallion(badge: badge, unlocked: unlocked, size: 72, progress: badge.progress(stats))

            if unlocked {
                Text(badge.title)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let date = badgeStore?.unlockDate(badge.id) {
                    Text(date, style: .date)
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                }
            } else if badge.isSecret {
                Text("???")
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            } else {
                Text(badge.title)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(min(badge.currentValue(stats), badge.target))/\(badge.target)")
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    /// Falls back to recomputing unlock state from history when no `BadgeStore`
    /// is supplied (e.g. in previews), so the section is always populated.
    private func isUnlocked(_ id: String) -> Bool {
        if let badgeStore { return badgeStore.isUnlocked(id) }
        let stats = BadgeStats(records: store.records)
        return BadgeCatalog.badge(id: id)?.isUnlocked(by: stats) ?? false
    }

    private func overrunTint(_ rate: Double) -> PulseColor {
        rate > 0.3 ? .over : rate > 0.1 ? .warn : .signal
    }

    private func formatTotalTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(minutes > 0 ? String(format: "%02d", minutes) : "")"
        }
        return "\(minutes)m"
    }

    /// Same column layout as the macOS CSV export so the two stay interchangeable.
    private func exportCSV() -> String {
        var csv = "Date,Preset,Durée totale,Participant,Temps alloué,Temps réel,Dépassement\n"
        let formatter = ISO8601DateFormatter()
        for record in store.records {
            let dateStr = formatter.string(from: record.date)
            let preset = record.presetName ?? ""
            for s in record.speakers {
                csv += "\(dateStr),\(preset),\(Int(record.totalDuration)),\(s.participantName),\(Int(s.allocatedTime)),\(Int(s.actualTime)),\(Int(s.overtime))\n"
            }
        }
        return csv
    }
}

// MARK: - Meeting detail

/// Per-meeting breakdown: every `SpeakerRecord` with its allocated/actual time
/// and whether they ran over (dépassement) or stayed under budget — Pulse cards.
private struct MeetingDetailView: View {
    let record: MeetingRecord
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PulseColor.canvas.color(for: colorScheme).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.xl) {
                    summaryCard
                    speakersSection
                }
                .padding(PulseSpacing.xl)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                Text(record.date, style: .date)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                Text(record.date, style: .time)
                    .pulseText(.body)
                    .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                Spacer()
                Text(TimeFormatter.format(record.totalDuration))
                    .pulseText(.mono)
                    .foregroundStyle(PulseColor.ink.color(for: colorScheme))
            }
            if let preset = record.presetName {
                PulseStatusPill(preset, tone: .signal)
            }
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                .fill(PulseColor.surface.color(for: colorScheme))
        )
    }

    private var speakersSection: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("INTERVENANTS")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            ForEach(record.speakers) { speaker in
                speakerRow(speaker)
            }
        }
    }

    private func speakerRow(_ speaker: SpeakerRecord) -> some View {
        let tint: PulseColor = speaker.wasOvertime ? .over : .signal
        return HStack(spacing: PulseSpacing.md) {
            // Per-person identity accent (keyed by name — stats hold no UUID).
            Circle()
                .fill(PulseAccent.color(forName: speaker.participantName))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(speaker.participantName)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                Text("alloué \(TimeFormatter.format(speaker.allocatedTime))")
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: PulseSpacing.xxs) {
                Text(TimeFormatter.format(speaker.actualTime))
                    .pulseText(.mono)
                    .foregroundStyle(tint.color(for: colorScheme))
                if speaker.wasOvertime {
                    Text(TimeFormatter.formatOvertime(speaker.overtime))
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.over.color(for: colorScheme))
                } else {
                    Text("dans les temps")
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                }
            }
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                .fill(PulseColor.surface.color(for: colorScheme))
        )
    }
}

// MARK: - Share sheet

/// Wraps `UIActivityViewController` for the iOS share sheet. UIKit is fine here
/// because this file lives in the iOS app target, not in StandupKit.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so the exported CSV can drive `.sheet(item:)`.
private struct ExportPayload: Identifiable {
    let id = UUID()
    let csv: String
}

// MARK: - Preview

#Preview {
    let store = StatsStore()
    store.records = [
        MeetingRecord(
            presetName: "Daily",
            speakers: [
                SpeakerRecord(participantName: "Alice", allocatedTime: 120, actualTime: 95),
                SpeakerRecord(participantName: "Bob", allocatedTime: 120, actualTime: 180),
                SpeakerRecord(participantName: "Chloé", allocatedTime: 120, actualTime: 110)
            ],
            totalDuration: 385
        ),
        MeetingRecord(
            presetName: "Rétro",
            speakers: [
                SpeakerRecord(participantName: "Alice", allocatedTime: 90, actualTime: 88),
                SpeakerRecord(participantName: "Bob", allocatedTime: 90, actualTime: 72)
            ],
            totalDuration: 160
        )
    ]
    return IOSStatsView(store: store)
}
