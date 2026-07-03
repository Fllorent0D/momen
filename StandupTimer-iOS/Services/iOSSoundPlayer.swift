import AudioToolbox
import StandupKit

/// iOS implementation of `SoundPlaying`, backed by built-in system sounds.
///
/// Uses `AudioToolbox.AudioServicesPlaySystemSound` with system sound IDs so it
/// works with zero bundled assets. Each phase maps to a distinct, short system
/// cue. The IDs below come from the (undocumented but stable) `/System/Library/
/// Audio/UISounds` catalogue; they are intentionally short and non-intrusive.
final class iOSSoundPlayer: SoundPlaying, Sendable {
    /// Light tick — a speaker hands over to the next. (`Tink.caf`)
    private let transitionSound: SystemSoundID = 1103
    /// Gentle alert — the current speaker is approaching their limit. (`jbl_begin.caf`)
    private let warningSound: SystemSoundID = 1110
    /// More insistent tone — the speaker has gone over time. (`jbl_cancel.caf`)
    private let overtimeSound: SystemSoundID = 1112
    /// Completion chime — the whole meeting is finished. (`complete.caf` / fanfare)
    private let finishedSound: SystemSoundID = 1025

    func playTransition() {
        AudioServicesPlaySystemSound(transitionSound)
    }

    func playWarning() {
        AudioServicesPlaySystemSound(warningSound)
    }

    func playOvertime() {
        AudioServicesPlaySystemSound(overtimeSound)
    }

    func playFinished() {
        AudioServicesPlaySystemSound(finishedSound)
    }
}
