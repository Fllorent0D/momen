import AppKit

final class SoundManager: Sendable {
    static let shared = SoundManager()

    private init() {}

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
