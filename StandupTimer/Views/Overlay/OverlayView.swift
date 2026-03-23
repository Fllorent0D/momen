import SwiftUI

struct OverlayView: View {
    @Environment(MeetingManager.self) private var manager

    private var fillColor: Color {
        manager.isOvertime ? Color(red: 0.9, green: 0.15, blue: 0.15) : Color(red: 0.1, green: 0.85, blue: 0.3)
    }

    var body: some View {
        Group {
            if manager.isActive || manager.timerState == .finished {
                if manager.timerState == .finished {
                    finishedContent
                } else {
                    timerContent
                }
            }
        }
        .frame(width: 750)
        .animation(.easeInOut(duration: 0.5), value: manager.isOvertime)
    }

    // MARK: - Timer Content

    private var timerContent: some View {
        let fillFraction = manager.isOvertime ? 1.0 : (1.0 - manager.progress)

        return GeometryReader { geo in
            let barWidth = geo.size.width * fillFraction

            ZStack {
                // Glass background
                Color.clear
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                // Bright fill with sharp edge
                HStack(spacing: 0) {
                    fillColor
                        .frame(width: barWidth)
                    Color.clear
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .animation(.linear(duration: 0.1), value: manager.progress)

                // White text on the filled part
                contentRow(textColor: .white, subtitleColor: .white.opacity(0.75))
                    .mask {
                        HStack(spacing: 0) {
                            Color.white
                                .frame(width: barWidth)
                            Color.clear
                        }
                        .animation(.linear(duration: 0.1), value: manager.progress)
                    }

                // Dark text on the glass part
                contentRow(textColor: .primary, subtitleColor: .secondary)
                    .mask {
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: barWidth)
                            Color.white
                        }
                        .animation(.linear(duration: 0.1), value: manager.progress)
                    }
            }
        }
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Content Row

    private func contentRow(textColor: Color, subtitleColor: Color) -> some View {
        HStack(spacing: 16) {
            // Previous
            Button {
                manager.previousSpeaker()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(manager.currentSpeakerIndex > 0 ? .white : .white.opacity(0.3))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(manager.currentSpeakerIndex > 0 ? 0.5 : 0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(manager.currentSpeakerIndex == 0)

            // Speaker name
            VStack(alignment: .leading, spacing: 1) {
                if let participant = manager.currentParticipant {
                    Text(participant.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                }
                Text("Intervenant \(manager.currentSpeakerIndex + 1) sur \(manager.totalParticipants)")
                    .font(.system(size: 11))
                    .foregroundStyle(subtitleColor)
            }

            Spacer()

            // Total
            VStack(spacing: 1) {
                Text("Total")
                    .font(.system(size: 9))
                    .foregroundStyle(subtitleColor)
                Text(TimeFormatter.format(manager.totalElapsed))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(subtitleColor)
            }

            // Countdown
            Text(manager.isOvertime
                 ? TimeFormatter.formatOvertime(manager.elapsedOvertime)
                 : TimeFormatter.format(manager.remainingTime))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(textColor)

            // Pause
            Button {
                manager.togglePause()
            } label: {
                Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(textColor)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            // Next
            Button {
                manager.nextSpeaker()
            } label: {
                HStack(spacing: 5) {
                    Text("Suivant")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(textColor.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Finished

    private var finishedContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)

            Text("Réunion terminée")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            Text(TimeFormatter.format(manager.totalElapsed))
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
