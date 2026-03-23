import SwiftUI

struct OverlayView: View {
    @Environment(MeetingManager.self) private var manager

    private var tintColor: Color {
        manager.isOvertime ? .red : .green
    }

    var body: some View {
        VStack(spacing: 0) {
            if manager.isActive || manager.timerState == .finished {
                mainContent
                OverlayTimerBar(progress: manager.progress, isOvertime: manager.isOvertime)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 750)
        .glassEffect(
            .regular.tint(tintColor),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .padding(12)
        .animation(.easeInOut(duration: 0.5), value: manager.isOvertime)
    }

    @ViewBuilder
    private var mainContent: some View {
        if manager.timerState == .finished {
            finishedContent
        } else {
            timerContent
        }
    }

    private var timerContent: some View {
        HStack(spacing: 16) {
            // Previous button
            Button {
                manager.previousSpeaker()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(manager.currentSpeakerIndex > 0 ? .primary : .tertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(manager.currentSpeakerIndex == 0)
            .help("Précédent")

            // Speaker initial
            if let participant = manager.currentParticipant {
                let initial = String(participant.name.prefix(1)).uppercased()
                Text(initial)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.tint(tintColor), in: Circle())
            }

            // Speaker info
            VStack(alignment: .leading, spacing: 4) {
                if let participant = manager.currentParticipant {
                    Text(participant.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Text("Intervenant \(manager.currentSpeakerIndex + 1) sur \(manager.totalParticipants)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Total elapsed
            VStack(spacing: 2) {
                Text("Total")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(TimeFormatter.format(manager.totalElapsed))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Timer display
            TimeDisplay(
                time: manager.remainingTime,
                isOvertime: manager.isOvertime,
                overtimeElapsed: manager.elapsedOvertime
            )

            // Pause button
            Button {
                manager.togglePause()
            } label: {
                Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .help(manager.isPaused ? "Reprendre (P)" : "Pause (P)")

            // Next button
            Button {
                manager.nextSpeaker()
            } label: {
                HStack(spacing: 6) {
                    Text("Suivant")
                        .font(.system(size: 18, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Suivant (N)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var finishedContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.primary)

            Text("Réunion terminée")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Text(TimeFormatter.format(manager.totalElapsed))
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
