import Foundation

/// Commands sent from iPhone → Mac
enum TimerCommand: String, Codable {
    case start
    case next
    case previous
    case pause
    case cancel
}

/// Status sent from Mac → iPhone
struct TimerStatus: Codable {
    let state: String  // "idle", "running", "paused", "overtime", "finished", "countdown"
    let speakerName: String
    let nextSpeakerName: String?
    let speakerIndex: Int
    let totalSpeakers: Int
    let remainingTime: TimeInterval
    let elapsedOvertime: TimeInterval
    let totalElapsed: TimeInterval
    let progress: Double
    let isOvertime: Bool
    let countdownValue: Int
}

/// Message wrapper for peer communication
struct PeerMessage: Codable {
    enum Kind: String, Codable {
        case command
        case status
    }
    let kind: Kind
    let command: TimerCommand?
    let status: TimerStatus?

    static func fromCommand(_ cmd: TimerCommand) -> PeerMessage {
        PeerMessage(kind: .command, command: cmd, status: nil)
    }

    static func fromStatus(_ status: TimerStatus) -> PeerMessage {
        PeerMessage(kind: .status, command: nil, status: status)
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> PeerMessage? {
        try? JSONDecoder().decode(PeerMessage.self, from: data)
    }
}
