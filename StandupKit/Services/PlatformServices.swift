import Foundation

// Platform-agnostic service protocols consumed by the core (MeetingManager).
// Concrete macOS implementations live in the app target and are injected at
// construction time, keeping the core free of AppKit.

/// Plays the timer's transition / warning / overtime / finished sounds.
public protocol SoundPlaying {
    func playTransition()
    func playWarning()
    func playOvertime()
    func playFinished()
}

/// Handles platform-specific export side effects. The core builds the textual
/// content; the platform decides what to do with it (clipboard, file dialog…).
@MainActor
public protocol ExportService {
    /// Puts the given summary text on the system clipboard.
    func copySummary(_ text: String)
    /// Lets the user save the given CSV content (e.g. via a save dialog).
    func saveCSV(_ csv: String, suggestedName: String)
}

/// Presents the floating overlay banner. The platform owns rendering; the core
/// only drives visibility and position.
@MainActor
public protocol OverlayPresenting {
    func show(position: BannerPosition)
    func close()
    func resetPosition()
}

/// Manages whether the app launches automatically at login. The core only flips
/// the desired state; the platform owns the OS plumbing (the login-item service
/// on macOS). Platforms without a launch-at-login concept (iOS) provide a no-op.
@MainActor
public protocol LaunchAtLoginManaging {
    /// Registers or unregisters the app as a login item to match `enabled`.
    func setEnabled(_ enabled: Bool)
}
