import Foundation
import SwiftUI

@Observable
@MainActor
final class MeetingManager {
    var meeting = Meeting()
    var presetStore = PresetStore()
    var statsStore = StatsStore()
    var timerState: TimerState = .idle
    var remainingTime: TimeInterval = 0
    var elapsedOvertime: TimeInterval = 0
    var totalElapsed: TimeInterval = 0
    var showOverlay = false

    /// The active (present-only) participants for the current meeting
    private(set) var activeParticipants: [Participant] = []
    /// Per-speaker elapsed time tracking for stats
    private var speakerStartDate: Date?
    private var speakerTimes: [(name: String, time: TimeInterval)] = []

    private var timer: Timer?
    private var targetEndDate: Date?
    private var hasPlayedWarning = false
    private let keyboardManager = KeyboardShortcutManager()
    private let overlayPanel = OverlayPanel()
    private var meetingStartDate: Date?

    init() {
        keyboardManager.onNext = { [weak self] in self?.nextSpeaker() }
        keyboardManager.onPause = { [weak self] in self?.togglePause() }
        keyboardManager.onCancel = { [weak self] in self?.cancel() }
    }

    func showOverlayPanel() {
        overlayPanel.show(
            ribbonContent: RibbonView().environment(self),
            controlContent: OverlayView().environment(self)
        )
    }

    func hideOverlayPanel() {
        overlayPanel.close()
    }

    // MARK: - Computed Properties

    var currentSpeakerIndex: Int {
        switch timerState {
        case .running(let idx), .paused(let idx), .overtime(let idx):
            return idx
        default:
            return 0
        }
    }

    var currentParticipant: Participant? {
        let idx = currentSpeakerIndex
        guard idx < activeParticipants.count else { return nil }
        return activeParticipants[idx]
    }

    var isOvertime: Bool {
        if case .overtime = timerState { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = timerState { return true }
        return false
    }

    var isRunning: Bool {
        switch timerState {
        case .running, .overtime:
            return true
        default:
            return false
        }
    }

    var isActive: Bool {
        switch timerState {
        case .running, .paused, .overtime:
            return true
        default:
            return false
        }
    }

    var timePerPerson: TimeInterval {
        guard !activeParticipants.isEmpty else { return meeting.totalDuration }
        return meeting.totalDuration / Double(activeParticipants.count)
    }

    var progress: Double {
        guard timePerPerson > 0 else { return 0 }
        let elapsed = timePerPerson - remainingTime
        return min(max(elapsed / timePerPerson, 0), 1)
    }

    var totalParticipants: Int {
        activeParticipants.count
    }

    /// Formatted menu bar label during meeting
    var menuBarLabel: String {
        guard isActive else { return "" }
        if isOvertime {
            return "⏱ +\(TimeFormatter.format(elapsedOvertime))"
        }
        return "⏱ \(TimeFormatter.format(remainingTime))"
    }

    // MARK: - Actions

    func startMeeting() {
        // Filter to present participants only
        activeParticipants = meeting.participants.filter(\.isPresent)
        guard !activeParticipants.isEmpty else { return }

        if meeting.randomizeOrder {
            activeParticipants.shuffle()
        }

        speakerTimes = []
        meetingStartDate = Date()
        totalElapsed = 0
        remainingTime = timePerPerson
        elapsedOvertime = 0
        hasPlayedWarning = false
        speakerStartDate = Date()
        timerState = .running(speakerIndex: 0)
        showOverlay = true
        showOverlayPanel()
        startTimer()
        keyboardManager.start()
        SoundManager.shared.playTransition()
    }

    func nextSpeaker() {
        recordCurrentSpeakerTime()

        let nextIndex = currentSpeakerIndex + 1
        if nextIndex >= activeParticipants.count {
            finishMeeting()
            return
        }

        remainingTime = timePerPerson
        elapsedOvertime = 0
        hasPlayedWarning = false
        speakerStartDate = Date()
        timerState = .running(speakerIndex: nextIndex)
        startTimer()
        SoundManager.shared.playTransition()
    }

    func previousSpeaker() {
        let prevIndex = currentSpeakerIndex - 1
        guard prevIndex >= 0 else { return }

        // Remove last recorded time since we're going back
        if !speakerTimes.isEmpty {
            speakerTimes.removeLast()
        }

        remainingTime = timePerPerson
        elapsedOvertime = 0
        hasPlayedWarning = false
        speakerStartDate = Date()
        timerState = .running(speakerIndex: prevIndex)
        startTimer()
        SoundManager.shared.playTransition()
    }

    func togglePause() {
        switch timerState {
        case .running(let idx):
            stopTimer()
            timerState = .paused(speakerIndex: idx)
        case .paused(let idx):
            timerState = .running(speakerIndex: idx)
            startTimer()
        case .overtime(let idx):
            stopTimer()
            timerState = .paused(speakerIndex: idx)
        default:
            break
        }
    }

    func cancel() {
        stopTimer()
        keyboardManager.stop()
        hideOverlayPanel()
        timerState = .idle
        remainingTime = 0
        elapsedOvertime = 0
        totalElapsed = 0
        showOverlay = false
    }

    func finishMeeting() {
        recordCurrentSpeakerTime()
        stopTimer()
        keyboardManager.stop()
        timerState = .finished
        SoundManager.shared.playFinished()

        // Save stats
        let speakers = speakerTimes.map { entry in
            SpeakerRecord(
                participantName: entry.name,
                allocatedTime: timePerPerson,
                actualTime: entry.time
            )
        }
        let record = MeetingRecord(
            presetName: presetStore.selectedPreset?.name,
            speakers: speakers,
            totalDuration: totalElapsed
        )
        statsStore.addRecord(record)

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.timerState == .finished else { return }
            self.hideOverlayPanel()
            self.timerState = .idle
            self.showOverlay = false
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        targetEndDate = Date().addingTimeInterval(remainingTime)

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        targetEndDate = nil
    }

    private func tick() {
        // Update total elapsed
        if let start = meetingStartDate {
            totalElapsed = Date().timeIntervalSince(start)
        }

        guard case .running(let idx) = timerState else {
            if case .overtime = timerState {
                elapsedOvertime += 0.1
                return
            }
            return
        }

        guard let targetEndDate else { return }

        remainingTime = max(targetEndDate.timeIntervalSinceNow, 0)

        // 10-second warning
        if remainingTime <= 10 && remainingTime > 9.9 && !hasPlayedWarning {
            hasPlayedWarning = true
            SoundManager.shared.playWarning()
        }

        // Time's up
        if remainingTime <= 0 {
            remainingTime = 0
            SoundManager.shared.playOvertime()

            switch meeting.overtimeMode {
            case .never:
                nextSpeaker()
            case .always, .optional:
                timerState = .overtime(speakerIndex: idx)
                self.targetEndDate = nil
                let overtimeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.elapsedOvertime += 0.1
                    }
                }
                self.timer?.invalidate()
                self.timer = overtimeTimer
            }
        }
    }

    private func recordCurrentSpeakerTime() {
        guard let start = speakerStartDate,
              let participant = currentParticipant else { return }
        let elapsed = Date().timeIntervalSince(start)
        speakerTimes.append((name: participant.name, time: elapsed))
    }
}
