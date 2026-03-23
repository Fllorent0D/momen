import SwiftUI

struct OverlayView: View {
    @Environment(MeetingManager.self) private var manager

    private var theme: ColorTheme { manager.meeting.colorTheme }

    private var fillColor: Color {
        if manager.isOvertime { return theme.overtimeColor }
        let t = manager.remainingTime
        if t > 10 { return theme.inTimeColor }
        let ratio = t / 10.0
        let hue = theme.inTimeHue * ratio + theme.overtimeHue * (1.0 - ratio)
        let sat = 0.8 + (1.0 - ratio) * 0.1
        let bri = 0.8 + (1.0 - ratio) * 0.15
        return Color(hue: hue, saturation: sat, brightness: bri)
    }

    @State private var overtimeFill: Double = 0
    @State private var shakeOffset: CGFloat = 0

    private var nextSpeakerName: String? {
        let next = manager.currentSpeakerIndex + 1
        guard next < manager.activeParticipants.count else { return nil }
        return manager.activeParticipants[next].name
    }

    private var fillFraction: Double {
        if manager.isOvertime { return overtimeFill }
        return 1.0 - manager.progress
    }

    var body: some View {
        Group {
            if manager.isCountingDown {
                countdownContent
            } else if manager.isActive || manager.timerState == .finished {
                if manager.timerState == .finished {
                    finishedContent
                } else {
                    timerContent
                }
            }
        }
        .frame(width: 750)
        .offset(x: shakeOffset)
        .animation(.easeInOut(duration: 0.5), value: manager.isOvertime)
        .onChange(of: manager.isOvertime) { _, isOvertime in
            if isOvertime {
                overtimeFill = 0
                withAnimation(.easeOut(duration: 0.5)) { overtimeFill = 1.0 }
                if manager.meeting.overtimeShake { startShake() }
            } else {
                overtimeFill = 0
                shakeOffset = 0
            }
        }
    }

    // MARK: - Countdown 3-2-1

    private var countdownContent: some View {
        Text("\(manager.countdownValue)")
            .font(.system(size: 64, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 120, height: 120)
            .background(theme.inTimeColor, in: Circle())
            .contentTransition(.numericText())
            .animation(.bouncy(duration: 0.4), value: manager.countdownValue)
    }

    // MARK: - Timer Content

    private var timerContent: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width * fillFraction

            VStack(spacing: 0) {
                ZStack {
                    Color.clear
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 0) {
                        fillColor.frame(width: barWidth)
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    contentRow(textColor: .white, subtitleColor: .white.opacity(0.75))
                        .mask {
                            HStack(spacing: 0) { Color.white.frame(width: barWidth); Color.clear }
                        }

                    contentRow(textColor: .primary, subtitleColor: .secondary)
                        .mask {
                            HStack(spacing: 0) { Color.clear.frame(width: barWidth); Color.white }
                        }
                }
                .animation(.linear(duration: 0.1), value: manager.progress)
                .animation(.easeOut(duration: 0.5), value: overtimeFill)

                if manager.meeting.speakerDots && manager.totalParticipants > 1 {
                    dotsView
                }
            }
        }
        .frame(height: manager.meeting.speakerDots && manager.totalParticipants > 1 ? 80 : 64)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Speaker Dots

    private var dotsView: some View {
        HStack(spacing: 6) {
            ForEach(0..<manager.totalParticipants, id: \.self) { index in
                Circle()
                    .fill(index < manager.currentSpeakerIndex ? .white.opacity(0.6)
                          : index == manager.currentSpeakerIndex ? .white
                          : .white.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 4).padding(.bottom, 6)
    }

    // MARK: - Content Row

    private func contentRow(textColor: Color, subtitleColor: Color) -> some View {
        HStack(spacing: 16) {
            Button {
                manager.previousSpeaker()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(manager.currentSpeakerIndex > 0 ? textColor : textColor.opacity(0.15))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(textColor.opacity(manager.currentSpeakerIndex > 0 ? 0.15 : 0.05), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(manager.currentSpeakerIndex == 0)

            // Avatar
            if let participant = manager.currentParticipant {
                AvatarView(participant: participant, size: 40, backgroundColor: textColor.opacity(0.2))
            }

            VStack(alignment: .leading, spacing: 1) {
                if let participant = manager.currentParticipant {
                    Group {
                        if manager.meeting.speakerTransition {
                            Text(participant.name).id(participant.id).transition(.push(from: .bottom))
                        } else {
                            Text(participant.name)
                        }
                    }
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.3), value: manager.currentSpeakerIndex)
                }
                if let nextName = nextSpeakerName {
                    Text("Suivant : \(nextName)")
                        .font(.system(size: 11)).foregroundStyle(subtitleColor)
                } else {
                    Text("Dernier intervenant")
                        .font(.system(size: 11)).foregroundStyle(subtitleColor)
                }
            }

            Spacer()

            VStack(spacing: 1) {
                Text("Total").font(.system(size: 9)).foregroundStyle(subtitleColor)
                Text(TimeFormatter.format(manager.totalElapsed))
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(subtitleColor)
            }

            Text(manager.isOvertime
                 ? TimeFormatter.formatOvertime(manager.elapsedOvertime)
                 : TimeFormatter.format(manager.remainingTime))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(textColor)
                .contentTransition(.numericText(countsDown: !manager.isOvertime))
                .animation(.snappy(duration: 0.3), value: manager.isOvertime
                           ? Int(manager.elapsedOvertime) : Int(manager.remainingTime))

            Button { manager.togglePause() } label: {
                Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 22)).foregroundStyle(textColor).frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Button { manager.nextSpeaker() } label: {
                HStack(spacing: 5) {
                    Text("Suivant").font(.system(size: 16, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(textColor)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(textColor.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Finished with Summary

    private var finishedContent: some View {
        VStack(spacing: 10) {
            ZStack {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundStyle(theme.inTimeColor)
                    Text("Réunion terminée").font(.system(size: 22, weight: .bold)).foregroundStyle(.primary)
                    Spacer()
                    Text(TimeFormatter.format(manager.totalElapsed))
                        .font(.system(size: 20, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)

                    Button { manager.copySummaryToClipboard() } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(.quaternary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Copier le résumé")
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                if manager.meeting.confetti {
                    ConfettiView().allowsHitTesting(false)
                }
            }

            // Per-speaker breakdown
            if let record = manager.lastMeetingRecord {
                HStack(spacing: 6) {
                    ForEach(record.speakers) { s in
                        VStack(spacing: 2) {
                            Text(String(s.participantName.prefix(6)))
                                .font(.system(size: 10, weight: .medium))
                            Text(TimeFormatter.format(s.actualTime))
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundStyle(s.wasOvertime ? theme.overtimeColor : .primary)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Shake

    private func startShake() {
        let seq: [(CGFloat, Double)] = [
            (8, 0.05), (-8, 0.05), (6, 0.05), (-6, 0.05),
            (4, 0.05), (-4, 0.05), (2, 0.05), (0, 0.05)
        ]
        var delay = 0.0
        for (offset, dur) in seq {
            delay += dur
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: dur)) { shakeOffset = offset }
            }
        }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isActive = true

    var body: some View {
        if isActive {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    var alive = 0
                    for p in particles {
                        let age = now - p.startTime
                        guard age > 0, age < p.lifetime else {
                            if age <= 0 { alive += 1 }; continue
                        }
                        alive += 1
                        let x = p.startX + p.velocityX * age
                        let y = p.startY + p.velocityY * age + 300 * age * age
                        context.opacity = 1.0 - (age / p.lifetime)
                        context.translateBy(x: x, y: y)
                        context.rotate(by: .degrees(p.rotation * age))
                        context.fill(
                            Rectangle().path(in: CGRect(x: -p.size/2, y: -p.size/2, width: p.size, height: p.size * 0.6)),
                            with: .color(p.color))
                        context.rotate(by: .degrees(-p.rotation * age))
                        context.translateBy(x: -x, y: -y)
                        context.opacity = 1
                    }
                    if alive == 0 && !particles.isEmpty {
                        DispatchQueue.main.async { isActive = false }
                    }
                }
            }
            .onAppear { spawnParticles() }
        }
    }

    private func spawnParticles() {
        let colors: [Color] = [.red, .green, .blue, .yellow, .orange, .purple, .pink, .mint]
        let now = Date.now.timeIntervalSinceReferenceDate
        particles = (0..<40).map { _ in
            ConfettiParticle(
                startX: .random(in: 100...650), startY: .random(in: -20...0),
                velocityX: .random(in: -80...80), velocityY: .random(in: -200 ... -50),
                size: .random(in: 6...12), color: colors.randomElement()!,
                rotation: .random(in: -400...400), lifetime: .random(in: 1.5...2.5),
                startTime: now + .random(in: 0...0.3))
        }
    }
}

struct ConfettiParticle {
    let startX, startY, velocityX, velocityY, size: CGFloat
    let color: Color
    let rotation, lifetime, startTime: Double
}
