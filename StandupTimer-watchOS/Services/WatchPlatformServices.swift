import Foundation
import WatchKit
import StandupKit

// Minimal watchOS platform-service implementations (scaffold, issue: watchOS
// target). They satisfy `MeetingManager`'s injected protocols so the core runs
// on the watch; the real implementations (audio, complications, …) come later.

/// Sound on watchOS goes through haptics — there is no `AudioServicesPlaySystemSound`.
/// Each timer phase maps to a distinct `WKHapticType`.
final class WatchSoundPlayer: SoundPlaying, Sendable {
    func playTransition() { WKInterfaceDevice.current().play(.click) }
    func playWarning() { WKInterfaceDevice.current().play(.directionUp) }
    func playOvertime() { WKInterfaceDevice.current().play(.failure) }
    func playFinished() { WKInterfaceDevice.current().play(.success) }
}

/// watchOS has no clipboard / save panel — export is a no-op for now.
@MainActor
final class WatchExportService: ExportService {
    func copySummary(_ text: String) {}
    func saveCSV(_ csv: String, suggestedName: String) {}
}

/// The "overlay" on watch is the full-screen timer view itself; nothing floats.
@MainActor
final class WatchOverlayPresenting: OverlayPresenting {
    func show(position: BannerPosition) {}
    func close() {}
    func resetPosition() {}
}

/// No launch-at-login concept on watchOS.
@MainActor
final class WatchLaunchAtLogin: LaunchAtLoginManaging {
    func setEnabled(_ enabled: Bool) {}
}
