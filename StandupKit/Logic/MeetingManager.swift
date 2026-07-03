import Foundation
import SwiftUI
import UserNotifications

@Observable
@MainActor
public final class MeetingManager {
    public var meeting = Meeting()
    public var presetStore = PresetStore()
    public var statsStore = StatsStore()
    public private(set) var gamification = GamificationStore(store: StatsStore())
    public var badgeStore = BadgeStore()

    /// Badges unlocked by the most recently finished meeting, awaiting a reveal (#42).
    public private(set) var newlyUnlockedBadges: [Badge] = []
    public var timerState: TimerState = .idle
    public var remainingTime: TimeInterval = 0
    public var elapsedOvertime: TimeInterval = 0
    public var totalElapsed: TimeInterval = 0
    public var showOverlay = false

    // Countdown
    public var countdownValue: Int = 0 // 3, 2, 1, 0=go

    // Meeting summary (set on finish)
    public var lastMeetingRecord: MeetingRecord?

    public private(set) var activeParticipants: [Participant] = []
    private var speakerStartDate: Date?
    private var speakerTimes: [(name: String, time: TimeInterval)] = []

    private var timer: Timer?
    private var targetEndDate: Date?
    private var overtimeStartDate: Date?
    private var hasPlayedWarning = false
    private var lastOvertimeSoundCount = 0
    private let sound: SoundPlaying
    private let export: ExportService
    private let overlayPanel: OverlayPresenting
    private let launchAtLogin: LaunchAtLoginManaging
    private var meetingStartDate: Date?

    public var openPaywall: (@MainActor (PaywallReason) -> Void)?
    public var isProUnlocked: (@MainActor () -> Bool)?

    public init(
        sound: SoundPlaying,
        export: ExportService,
        overlay: OverlayPresenting,
        launchAtLogin: LaunchAtLoginManaging
    ) {
        self.sound = sound
        self.export = export
        self.overlayPanel = overlay
        self.launchAtLogin = launchAtLogin
        gamification = GamificationStore(store: self.statsStore)
        setupReminder()
    }

    // MARK: - Signal Colors

    // The timer no longer carries a per-meeting palette — there is one signal.
    // In-time uses the Pulse signal (green); overtime uses Pulse over (red).
    // PulseColor is a ShapeStyle, so resolve it to a concrete Color (the overlay
    // is a dark floating panel) for the views that need a plain Color.
    public var themeInTimeColor: Color { PulseColor.signal.color(for: .dark) }
    public var themeOvertimeColor: Color { PulseColor.over.color(for: .dark) }

    public func showOverlayPanel() {
        overlayPanel.show(position: meeting.bannerPosition)
    }

    public func hideOverlayPanel() {
        overlayPanel.close()
    }

    public func resetOverlayPosition() {
        overlayPanel.resetPosition()
    }

    // MARK: - Computed Properties

    public var currentSpeakerIndex: Int {
        switch timerState {
        case .running(let idx), .paused(let idx), .overtime(let idx):
            return idx
        default:
            return 0
        }
    }

    public var currentParticipant: Participant? {
        let idx = currentSpeakerIndex
        guard idx < activeParticipants.count else { return nil }
        return activeParticipants[idx]
    }

    public var isOvertime: Bool {
        if case .overtime = timerState { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = timerState { return true }
        return false
    }

    public var isRunning: Bool {
        switch timerState {
        case .running, .overtime: return true
        default: return false
        }
    }

    public var isActive: Bool {
        switch timerState {
        case .running, .paused, .overtime: return true
        default: return false
        }
    }

    public var isCountingDown: Bool { countdownValue > 0 }

    public var timePerPerson: TimeInterval {
        meeting.timePerPerson(forCount: activeParticipants.count)
    }

    /// The total length for display, honouring the duration mode:
    /// `.total` → the configured total; `.perSpeaker` → per-speaker × active.
    public var effectiveTotalDuration: TimeInterval {
        meeting.effectiveTotalDuration(forCount: activeParticipants.count)
    }

    public var progress: Double {
        guard timePerPerson > 0 else { return 0 }
        let elapsed = timePerPerson - remainingTime
        return min(max(elapsed / timePerPerson, 0), 1)
    }

    public var totalParticipants: Int { activeParticipants.count }

    public var menuBarLabel: String {
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

    public func startMeeting() {
        if meeting.participants.count > ProAccessManager.freeParticipantLimit,
           !(isProUnlocked?() ?? false) {
            openPaywall?(.participantsLimit)
            return
        }

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
        resetOverlayPosition()
        timerState = .running(speakerIndex: index)
        meetingStartDate = meetingStartDate ?? Date()
        speakerStartDate = Date()
        lastOvertimeSoundCount = 0
        startTimer()
        playSound { sound.playTransition() }
    }

    public func nextSpeaker() {
        guard isActive else { return }
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

    public func previousSpeaker() {
        let prevIndex = currentSpeakerIndex - 1
        guard prevIndex >= 0 else { return }
        if !speakerTimes.isEmpty { speakerTimes.removeLast() }
        remainingTime = timePerPerson
        elapsedOvertime = 0
        hasPlayedWarning = false
        beginTimer(at: prevIndex)
    }

    public func moveCurrentToEnd() {
        guard isActive else { return }
        let idx = currentSpeakerIndex
        let remainingCount = activeParticipants.count - idx
        guard remainingCount > 1 else { return }

        // Move current speaker to end without recording their time
        let deferred = activeParticipants.remove(at: idx)
        activeParticipants.append(deferred)

        // Reset and start timer for the new current speaker (same index)
        remainingTime = timePerPerson
        elapsedOvertime = 0
        hasPlayedWarning = false
        beginTimer(at: idx)
    }

    public func togglePause() {
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

    public func cancel() {
        stopTimer()
        hideOverlayPanel()
        timerState = .idle
        remainingTime = 0
        elapsedOvertime = 0
        totalElapsed = 0
        countdownValue = 0
        showOverlay = false
    }

    public func finishMeeting() {
        recordCurrentSpeakerTime()
        stopTimer()
        timerState = .finished
        playSound { sound.playFinished() }

        let speakers = speakerTimes.map { entry in
            SpeakerRecord(participantName: entry.name, allocatedTime: timePerPerson, actualTime: entry.time)
        }
        let record = MeetingRecord(presetName: presetStore.selectedPreset?.name, speakers: speakers, totalDuration: totalElapsed)
        statsStore.addRecord(record)
        lastMeetingRecord = record

        // Unlock any newly-earned badges; expose them for a future reveal (#42).
        newlyUnlockedBadges = badgeStore.evaluate(records: statsStore.records)

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.timerState == .finished else { return }
            self.hideOverlayPanel()
            self.timerState = .idle
            self.showOverlay = false
        }
    }

    // MARK: - Summary

    public func copySummaryToClipboard() {
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
        export.copySummary(lines.joined(separator: "\n"))
    }

    // MARK: - CSV Export

    public func exportCSV() -> String {
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

    public func saveCSVToFile() {
        guard isProUnlocked?() ?? false else {
            openPaywall?(.stats)
            return
        }

        export.saveCSV(exportCSV(), suggestedName: "standup-stats.csv")
    }

    // MARK: - Launch at Login

    public func updateLaunchAtLogin() {
        launchAtLogin.setEnabled(meeting.launchAtLogin)
    }

    // MARK: - Daily Reminder

    public func setupReminder() {
        // tvOS n'a pas de notifications utilisateur programmables (title/body/sound
        // indisponibles) → le rappel quotidien n'existe pas sur l'écran salle.
        #if os(tvOS)
        return
        #else
        let center = UNUserNotificationCenter.current()
        let reminderHour = meeting.reminderHour
        let reminderMinute = meeting.reminderMinute

        // Remove old
        center.removePendingNotificationRequests(withIdentifiers: ["standup-reminder"])

        guard meeting.reminderEnabled else { return }

        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Momen"
            content.body = String(localized: "C'est l'heure du standup !", bundle: .standupKit)
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = reminderHour
            dateComponents.minute = reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(identifier: "standup-reminder", content: content, trigger: trigger)
            try? await center.add(request)
        }
        #endif
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

        guard case .running(let idx) = timerState else {
            if case .overtime = timerState, let otStart = overtimeStartDate {
                elapsedOvertime = Date().timeIntervalSince(otStart)

                // Repeating overtime sound with escalating frequency
                if meeting.soundEnabled {
                    let interval: TimeInterval
                    if elapsedOvertime > 30 { interval = 5.0 }
                    else if elapsedOvertime > 15 { interval = 7.0 }
                    else { interval = 10.0 }
                    let count = Int(elapsedOvertime / interval)
                    if count > lastOvertimeSoundCount {
                        lastOvertimeSoundCount = count
                        sound.playOvertime()
                    }
                }
            }
            return
        }

        guard let targetEndDate else { return }
        remainingTime = max(targetEndDate.timeIntervalSinceNow, 0)

        if remainingTime <= 10 && remainingTime > 9.9 && !hasPlayedWarning {
            hasPlayedWarning = true
            playSound { sound.playWarning() }
        }

        if remainingTime <= 0 {
            remainingTime = 0
            playSound { sound.playOvertime() }

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

    public func enforceFreePlanIfNeeded(isProUnlocked: Bool) {
        guard !isProUnlocked else { return }
        meeting.applyFreePersonalizationDefaults()
    }
}
