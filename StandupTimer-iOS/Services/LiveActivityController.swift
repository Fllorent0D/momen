import ActivityKit
import Foundation
import StandupKit

/// Drives the standup Live Activity (issue #52) from the iOS app side.
///
/// This is the only place that talks to `ActivityKit`: it `start`s a
/// `StandupActivity` when a meeting begins, `update`s its `ContentState` as the
/// speaker / chrono / overtime change, and `end`s it when the standup finishes or
/// is cancelled. It is a pure **observer** of ``MeetingManager`` — it reads the
/// manager's public state and never mutates it. `ContentView` wires it up via
/// `.onChange`/`.onReceive` (see there); nothing in `StandupKit` knows it exists.
///
/// Everything is guarded behind `ActivityAuthorizationInfo().areActivitiesEnabled`
/// so a device/user with Live Activities disabled is a silent no-op.
@MainActor
final class LiveActivityController {

    static let shared = LiveActivityController()

    private var activity: Activity<StandupActivityAttributes>?
    /// The last pushed state, so we can skip redundant `update`s (the 1 Hz tick
    /// fires every second but the chrono text only changes once per second, and
    /// pauses don't change it at all) — keeping us well under ActivityKit's
    /// update budget.
    private var lastState: StandupActivityAttributes.ContentState?

    private init() {}

    /// Begin the Live Activity for the running standup. Idempotent: if one is
    /// already live (e.g. the state flipped running → overtime → paused), this
    /// just forwards to ``update(with:)``.
    func start(with manager: MeetingManager) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { update(with: manager); return }

        let state = Self.state(from: manager)
        let attributes = StandupActivityAttributes(
            meetingTitle: manager.presetStore.selectedPreset?.name ?? "Standup"
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            lastState = state
        } catch {
            // A failed request (e.g. too many active activities) is non-fatal —
            // the in-app timer is the source of truth; the Live Activity is a
            // companion. Leave `activity` nil so a later tick can retry.
            activity = nil
        }
    }

    /// Push the manager's current state to the live activity, skipping no-op
    /// updates. Safe to call when no activity is live (it just returns).
    func update(with manager: MeetingManager) {
        guard let activity else { return }
        let state = Self.state(from: manager)
        guard state != lastState else { return }
        lastState = state
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    /// Tear down the Live Activity (meeting finished or cancelled).
    func end() {
        guard let activity else { return }
        self.activity = nil
        self.lastState = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - Snapshot

    /// Map the manager's public timer state into the activity payload. Mirrors the
    /// exact derivations `TimerView_iOS` uses for the ring fraction and chrono so
    /// the Live Activity and the in-app timer never disagree.
    private static func state(from manager: MeetingManager) -> StandupActivityAttributes.ContentState {
        let idx = manager.currentSpeakerIndex
        let speaker = manager.currentParticipant?.name ?? ""

        let nextName: String? = {
            let n = idx + 1
            guard n < manager.activeParticipants.count else { return nil }
            return manager.activeParticipants[n].name
        }()

        let fraction: Double
        if manager.isOvertime || manager.timePerPerson <= 0 {
            fraction = manager.isOvertime ? 0 : 1
        } else {
            fraction = min(max(manager.remainingTime / manager.timePerPerson, 0), 1)
        }

        let timeText = manager.isOvertime
            ? TimeFormatter.formatOvertime(manager.elapsedOvertime)
            : TimeFormatter.format(manager.remainingTime)

        return StandupActivityAttributes.ContentState(
            speaker: speaker,
            next: nextName,
            timeText: timeText,
            fraction: fraction,
            isOvertime: manager.isOvertime,
            index: idx + 1,
            total: manager.totalParticipants
        )
    }
}
