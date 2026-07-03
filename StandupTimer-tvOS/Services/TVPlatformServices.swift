import Foundation
import AudioToolbox
import StandupKit

// Minimal tvOS platform-service implementations (scaffold, issue: tvOS target).
// They satisfy `MeetingManager`'s injected protocols so the core runs on the
// Apple TV; the real implementations (focus-engine controls, top-shelf, …) come
// later. The Apple TV is the "big screen on the wall" companion to the timer.

/// tvOS keeps `AudioToolbox` system sounds, so each phase plays a short cue.
final class TVSoundPlayer: SoundPlaying, Sendable {
    private let transitionSound: SystemSoundID = 1103
    private let warningSound: SystemSoundID = 1110
    private let overtimeSound: SystemSoundID = 1112
    private let finishedSound: SystemSoundID = 1025

    func playTransition() { AudioServicesPlaySystemSound(transitionSound) }
    func playWarning() { AudioServicesPlaySystemSound(warningSound) }
    func playOvertime() { AudioServicesPlaySystemSound(overtimeSound) }
    func playFinished() { AudioServicesPlaySystemSound(finishedSound) }
}

/// tvOS has no clipboard / save panel — export is a no-op for now.
@MainActor
final class TVExportService: ExportService {
    func copySummary(_ text: String) {}
    func saveCSV(_ csv: String, suggestedName: String) {}
}

/// The "overlay" on tvOS is the full-screen timer view itself; nothing floats.
@MainActor
final class TVOverlayPresenting: OverlayPresenting {
    func show(position: BannerPosition) {}
    func close() {}
    func resetPosition() {}
}

/// No launch-at-login concept on tvOS.
@MainActor
final class TVLaunchAtLogin: LaunchAtLoginManaging {
    func setEnabled(_ enabled: Bool) {}
}
