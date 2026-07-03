import Foundation

/// Lightweight streak helper kept for the stats banner.
///
/// The old individual awards ("Bavard", "MVP", per-person trophies) were removed in
/// favour of the tiered badge system — see `Badges.swift` (`Badge`, `BadgeCatalog`,
/// `BadgeStore`). Day-streak figures live here because the banner surfaces them directly;
/// the badge rules compute their own streaks via `BadgeStats`.
@Observable
@MainActor
public final class GamificationStore {
    private var store: StatsStore

    public init(store: StatsStore) {
        self.store = store
    }

    public var currentStreak: Int {
        BadgeStats.computeCurrentStreak(records: store.records, calendar: .current)
    }

    public var longestStreak: Int {
        BadgeStats.computeLongestStreak(records: store.records, calendar: .current)
    }
}
