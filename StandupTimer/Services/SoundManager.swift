import AppKit
import StandupKit

/// macOS implementation of `SoundPlaying`, backed by system `NSSound`s.
final class MacSoundPlayer: SoundPlaying, Sendable {
    func playTransition() {
        NSSound(named: "Tink")?.play()
    }

    func playWarning() {
        NSSound(named: "Ping")?.play()
    }

    func playOvertime() {
        NSSound(named: "Basso")?.play()
    }

    func playFinished() {
        NSSound(named: "Glass")?.play()
    }
}
