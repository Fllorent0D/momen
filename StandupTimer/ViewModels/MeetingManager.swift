import Foundation
import SwiftUI
import ServiceManagement
import UserNotifications

@Observable
@MainActor
final class MeetingManager {
    var meeting = Meeting()
    var presetStore = PresetStore()
    var statsStore = StatsStore()
    private(set) var gamification = GamificationStore(store: StatsStore())
    var timerState: TimerState = .idle
    var remainingTime: TimeInterval = 0
    var elapsedOvertime: TimeInterval = 0
    var totalElapsed: TimeInterval = 0
    var showOverlay = false

    // Countdown
    var countdownValue: Int = 0 // 3, 2, 1, 0=go

    // Meeting summary (set on finish)
    var lastMeetingRecord: MeetingRecord?

    private(set) var activeParticipants: [Participant] = []
    private var speakerStartDate: Date?
    private var speakerTimes: [(name: String, time: TimeInterval)] = []

    private var timer: Timer?
    private var targetEndDate: Date?
    private var overtimeStartDate: Date?
    private var hasPlayedWarning = false
    private let keyboardManager = KeyboardShortcutManager()
    private let overlayPanel = OverlayPanel()
    let peerService = HostPeerService()
    private var meetingStartDate: Date?

    init() {
        gamification = GamificationStore(store: self.statsStore)
        keyboardManager.onNext = { [weak self] in self?.nextSpeaker() }
        keyboardManager.onPause = { [weak self] in self?.togglePause() }
        keyboardManager.onCancel = { [weak self] in self?.cancel() }
        peerService.onCommandReceived = { [weak self] cmd in
            switch cmd {
            case .start: self?.startMeeting()
            case .next: self?.nextSpeaker()
            case .previous: self?.previousSpeaker()
            case .pause: self?.togglePause()
            case .cancel: self?.cancel()
            }
        }
        peerService.start()
        setupReminder()
    }

    // MARK: - Theme Colors

    var themeInTimeColor: Color { meeting.colorTheme.inTimeColor }
    var themeOvertimeColor: Color { meeting.colorTheme.overtimeColor }

    func showOverlayPanel() {
        overlayPanel.show(
            ribbonContent: RibbonView().environment(self),
            controlContent: OverlayView().environment(self),
            showRibbon: meeting.ribbonEnabled
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
        case .running, .overtime: return true
        default: return false
        }
    }

    var isActive: Bool {
        switch timerState {
        case .running, .paused, .overtime: return true
        default: return false
        }
    }

    var isCountingDown: Bool { countdownValue > 0 }

    var timePerPerson: TimeInterval {
        guard !activeParticipants.isEmpty else { return meeting.totalDuration }
        return meeting.totalDuration / Double(activeParticipants.count)
    }

    var progress: Double {
        guard timePerPerson > 0 else { return 0 }
        let elapsed = timePerPerson - remainingTime
        return min(max(elapsed / timePerPerson, 0), 1)
    }

    var totalParticipants: Int { activeParticipants.count }

    var menuBarLabel: String {
        guard isActive else { return "" }
        if isOvertime {
            return "⏱ +\(TimeFormatter.format(elapsedOvertime))"
        }
        return "⏱ \(TimeFormatter.format(remainingTime))"
    }

    // MARK: - Sound helper

    private func playSound(_ action: () -> Void) {
        guard meeting.soundEnabled else { return }
        action()
    }

    // MARK: - Actions

    func startMeeting() {
        activeParticipants = meeting.participants.filter(\.isPresent)
        guard !activeParticipants.isEmpty else { return }

        if meeting.randomizeOrder { activeParticipants.shuffle() }

        speakerTimes = []
        meetingStartDate = nil
        totalElapsed = 0
        remainingTime = timePerPerson
        elapsedOvertime = 0
        hasPlayedWarning = false
        speakerStartDate = nil
        lastMeetingRecord = nil
        showOverlay = true
        keyboardManager.start()

        showOverlayPanel()

        if meeting.countdownEnabled {
            startCountdown()
        } else if meeting.autoPlay {
            beginTimer(at: 0)
        } else {
            timerState = .paused(speakerIndex: 0)
        }
    }

    private func startCountdown() {
        countdownValue = 3
        timerState = .paused(speakerIndex: 0)

        func countStep(_ val: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.showOverlay else { return }
                self.countdownValue = val
                if val > 0 {
                    countStep(val - 1)
                } else {
                    if self.meeting.autoPlay {
                        self.beginTimer(at: 0)
                    }
                }
            }
        }
        countStep(2)
    }

    private func beginTimer(at index: Int) {
        timerState = .running(speakerIndex: index)
        meetingStartDate = meetingStartDate ?? Date()
        speakerStartDate = Date()
        startTimer()
        playSound { SoundManager.shared.playTransition() }
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
        beginTimer(at: nextIndex)
    }

    func previousSpeaker() {
        let prevIndex = currentSpeakerIndex - 1
        guard prevIndex >= 0 else { return }
        if !speakerTimes.isEmpty { speakerTimes.removeLast() }
        remainingTime = timePerPerson
        elapsedOvertime = 0
        hasPlayedWarning = false
        beginTimer(at: prevIndex)
    }

    func togglePause() {
        switch timerState {
        case .running(let idx):
            stopTimer()
            timerState = .paused(speakerIndex: idx)
        case .paused(let idx):
            if meetingStartDate == nil { meetingStartDate = Date() }
            if speakerStartDate == nil { speakerStartDate = Date() }
            countdownValue = 0
            timerState = .running(speakerIndex: idx)
            startTimer()
        case .overtime(let idx):
            stopTimer()
            timerState = .paused(speakerIndex: idx)
        default: break
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
        countdownValue = 0
        showOverlay = false
    }

    func finishMeeting() {
        recordCurrentSpeakerTime()
        stopTimer()
        keyboardManager.stop()
        timerState = .finished
        playSound { SoundManager.shared.playFinished() }

        let speakers = speakerTimes.map { entry in
            SpeakerRecord(participantName: entry.name, allocatedTime: timePerPerson, actualTime: entry.time)
        }
        let record = MeetingRecord(presetName: presetStore.selectedPreset?.name, speakers: speakers, totalDuration: totalElapsed)
        statsStore.addRecord(record)
        lastMeetingRecord = record

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.timerState == .finished else { return }
            self.hideOverlayPanel()
            self.timerState = .idle
            self.showOverlay = false
        }
    }

    // MARK: - Summary

    func copySummaryToClipboard() {
        guard let record = lastMeetingRecord else { return }
        var lines: [String] = []
        lines.append("📋 Standup — \(record.date.formatted(date: .abbreviated, time: .shortened))")
        if let preset = record.presetName { lines.append("Preset: \(preset)") }
        lines.append("Durée: \(TimeFormatter.format(record.totalDuration))")
        lines.append("")
        for s in record.speakers {
            let flag = s.wasOvertime ? "🔴" : "🟢"
            lines.append("\(flag) \(s.participantName): \(TimeFormatter.format(s.actualTime))")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    // MARK: - CSV Export

    func exportCSV() -> String {
        var csv = "Date,Preset,Durée totale,Participant,Temps alloué,Temps réel,Dépassement\n"
        for record in statsStore.records {
            let dateStr = record.date.formatted(date: .numeric, time: .shortened)
            let preset = record.presetName ?? ""
            for s in record.speakers {
                csv += "\(dateStr),\(preset),\(Int(record.totalDuration)),\(s.participantName),\(Int(s.allocatedTime)),\(Int(s.actualTime)),\(Int(s.overtime))\n"
            }
        }
        return csv
    }

    func saveCSVToFile() {
        let csv = exportCSV()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "standup-stats.csv"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Launch at Login

    func updateLaunchAtLogin() {
        do {
            if meeting.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch { /* silently fail */ }
    }

    // MARK: - Daily Reminder

    func setupReminder() {
        let center = UNUserNotificationCenter.current()

        // Remove old
        center.removePendingNotificationRequests(withIdentifiers: ["standup-reminder"])

        guard meeting.reminderEnabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Standup Timer"
            content.body = "C'est l'heure du standup !"
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = self.meeting.reminderHour
            dateComponents.minute = self.meeting.reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(identifier: "standup-reminder", content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        targetEndDate = Date().addingTimeInterval(remainingTime)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        targetEndDate = nil
        overtimeStartDate = nil
    }

    private func tick() {
        if let start = meetingStartDate {
            totalElapsed = Date().timeIntervalSince(start)
        }

        broadcastStatus()

        guard case .running(let idx) = timerState else {
            if case .overtime = timerState, let otStart = overtimeStartDate {
                elapsedOvertime = Date().timeIntervalSince(otStart)
            }
            return
        }

        guard let targetEndDate else { return }
        remainingTime = max(targetEndDate.timeIntervalSinceNow, 0)

        if remainingTime <= 10 && remainingTime > 9.9 && !hasPlayedWarning {
            hasPlayedWarning = true
            playSound { SoundManager.shared.playWarning() }
        }

        if remainingTime <= 0 {
            remainingTime = 0
            playSound { SoundManager.shared.playOvertime() }

            switch meeting.overtimeMode {
            case .never: nextSpeaker()
            case .always, .optional:
                timerState = .overtime(speakerIndex: idx)
                self.targetEndDate = nil
                overtimeStartDate = Date()
            }
        }
    }

    private func recordCurrentSpeakerTime() {
        guard let start = speakerStartDate,
              let participant = currentParticipant else { return }
        let elapsed = Date().timeIntervalSince(start)
        speakerTimes.append((name: participant.name, time: elapsed))
    }

    // MARK: - Remote

    func broadcastStatus() {
        let stateStr: String
        switch timerState {
        case .idle: stateStr = "idle"
        case .running: stateStr = isCountingDown ? "countdown" : "running"
        case .paused: stateStr = isCountingDown ? "countdown" : "paused"
        case .overtime: stateStr = "overtime"
        case .finished: stateStr = "finished"
        }

        let nextIdx = currentSpeakerIndex + 1
        let nextName = nextIdx < activeParticipants.count ? activeParticipants[nextIdx].name : nil

        let status = TimerStatus(
            state: stateStr,
            speakerName: currentParticipant?.name ?? "",
            nextSpeakerName: nextName,
            speakerIndex: currentSpeakerIndex,
            totalSpeakers: totalParticipants,
            remainingTime: remainingTime,
            elapsedOvertime: elapsedOvertime,
            totalElapsed: totalElapsed,
            progress: progress,
            isOvertime: isOvertime,
            countdownValue: countdownValue
        )
        peerService.sendStatus(status)
    }
}
