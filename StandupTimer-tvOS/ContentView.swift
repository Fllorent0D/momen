import SwiftUI
import StandupKit

/// Scaffold root view for tvOS. Shows the meeting's current speaker / time so the
/// wiring to ``MeetingManager`` is proven; the real Pulse-native big-screen timer
/// (room display + Siri Remote focus controls) replaces it later.
struct ContentView: View {
    @Bindable var manager: MeetingManager
    @Bindable var proAccess: ProAccessManager

    var body: some View {
        VStack(spacing: 40) {
            Text(manager.currentParticipant?.name ?? "Standup Timer")
                .font(.system(size: 64, weight: .bold))

            Text(TimeFormatter.format(manager.remainingTime))
                .font(.system(size: 160, weight: .bold, design: .monospaced))
                .monospacedDigit()

            Button(manager.isRunning ? "Suivant" : "Démarrer") {
                if manager.isRunning {
                    manager.nextSpeaker()
                } else {
                    manager.startMeeting()
                }
            }
        }
        .padding()
    }
}
