import ActivityKit
import Foundation

/// The ActivityKit contract for the live-standup Live Activity (issue #52).
///
/// This single type is compiled into **both** the iOS app target and the
/// `StandupWidgets` extension (see `project.yml`, where the `StandupShared`
/// folder is listed in both targets' `sources`). That shared compilation is
/// what makes the attributes identical on both sides of the ActivityKit
/// boundary — the app `request`/`update`s an `Activity<StandupActivityAttributes>`
/// and the widget renders the very same `ContentState`.
///
/// `import ActivityKit` is iOS-only, which is why this lives on the iOS side and
/// **not** in the multi-platform `StandupKit` framework (which must keep
/// compiling for macOS).
struct StandupActivityAttributes: ActivityAttributes {

    /// The live, per-update payload mirrored from `MeetingManager` state.
    ///
    /// Everything the lock-screen banner and Dynamic Island need to draw a
    /// Pulse-styled snapshot of the running standup: who is speaking, who is up
    /// next, the chrono read-out, the ring sweep, and the overtime flag.
    public struct ContentState: Codable, Hashable {
        /// Current speaker's display name.
        var speaker: String
        /// The next speaker's name, or `nil` when the current one is last.
        var next: String?
        /// The chrono read-out — remaining `m:ss`, or `+m:ss` once over.
        var timeText: String
        /// Ring sweep, `1` (full) → `0` (limit / overtime). Clamped to `0…1`.
        var fraction: Double
        /// `true` once the speaker has run past their slice.
        var isOvertime: Bool
        /// 1-based position of the current speaker in the running order.
        var index: Int
        /// Total number of speakers in the running order.
        var total: Int
    }

    /// Static title shown for the activity (e.g. the preset name). Set once when
    /// the activity is requested and never changes for its lifetime.
    var meetingTitle: String
}
