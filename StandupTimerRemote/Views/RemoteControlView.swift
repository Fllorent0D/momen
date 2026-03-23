import SwiftUI

struct RemoteControlView: View {
    @Environment(RemoteManager.self) private var remote

    var body: some View {
        VStack(spacing: 0) {
            if remote.isConnected {
                if let status = remote.status {
                    statusView(status)
                } else {
                    waitingForMeeting
                }
            } else {
                connectingView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }

    // MARK: - Connecting

    private var connectingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Recherche du Mac...")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Assurez-vous que Standup Timer est lancé sur le Mac")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var waitingForMeeting: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Connecté à \(remote.hostName ?? "Mac")")
                .font(.title3)

            Button {
                remote.sendCommand(.start)
            } label: {
                Text("Démarrer le standup")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - Active Status

    private func statusView(_ status: TimerStatus) -> some View {
        VStack(spacing: 24) {
            // Speaker
            VStack(spacing: 8) {
                Text(status.speakerName)
                    .font(.system(size: 40, weight: .bold))
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.3), value: status.speakerName)

                if status.state == "countdown" {
                    Text("\(status.countdownValue)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.bouncy, value: status.countdownValue)
                } else if let next = status.nextSpeakerName {
                    Text("Suivant : \(next)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Dernier intervenant")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Timer
            if status.state != "countdown" {
                Text(status.isOvertime
                     ? "+\(formatTime(status.elapsedOvertime))"
                     : formatTime(status.remainingTime))
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .foregroundStyle(status.isOvertime ? .red : .primary)
                    .contentTransition(.numericText(countsDown: !status.isOvertime))
                    .animation(.snappy(duration: 0.3), value: Int(status.remainingTime))
            }

            // Progress
            if status.state != "finished" && status.state != "countdown" {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(status.isOvertime ? .red : .green)
                            .frame(width: geo.size.width * (1.0 - status.progress))
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)
            }

            // Dots
            if status.totalSpeakers > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<status.totalSpeakers, id: \.self) { i in
                        Circle()
                            .fill(i < status.speakerIndex ? .secondary
                                  : i == status.speakerIndex ? .primary
                                  : .quaternary)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            Spacer()

            // Controls
            if status.state == "finished" {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Réunion terminée")
                        .font(.title2.bold())
                    Text(formatTime(status.totalElapsed))
                        .font(.title3.monospaced())
                        .foregroundStyle(.secondary)
                }
            } else {
                controlButtons(status)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
    }

    private func controlButtons(_ status: TimerStatus) -> some View {
        VStack(spacing: 16) {
            // Main row: Previous | Pause | Next
            HStack(spacing: 20) {
                Button {
                    remote.sendCommand(.previous)
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(.bordered)
                .disabled(status.speakerIndex == 0)

                Button {
                    remote.sendCommand(.pause)
                } label: {
                    Image(systemName: status.state == "paused" ? "play.fill" : "pause.fill")
                        .font(.system(size: 32))
                        .frame(width: 80, height: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(status.state == "paused" ? .green : .orange)

                Button {
                    remote.sendCommand(.next)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // Cancel
            Button {
                remote.sendCommand(.cancel)
            } label: {
                Text("Annuler")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Helpers

    private var backgroundColor: Color {
        guard let status = remote.status else { return Color(.systemBackground) }
        if status.isOvertime { return .red.opacity(0.1) }
        if status.state == "running" { return .green.opacity(0.05) }
        return Color(.systemBackground)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let total = Int(abs(interval))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
