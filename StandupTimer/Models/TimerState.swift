import Foundation

enum TimerState: Equatable {
    case idle
    case running(speakerIndex: Int)
    case paused(speakerIndex: Int)
    case overtime(speakerIndex: Int)
    case finished
}
