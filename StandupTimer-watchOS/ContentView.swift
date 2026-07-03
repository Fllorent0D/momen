import SwiftUI
import StandupKit

/// Scaffold root view for watchOS. Shows the meeting's current speaker / time so
/// the wiring to ``MeetingManager`` is proven; the real Pulse-native watch timer
/// (ring + Digital Crown + Start/Next controls) replaces it later.
struct ContentView: View {
    @Bindable var manager: MeetingManager
    @Bindable var proAccess: ProAccessManager

    var body: some View {
        VStack(spacing: 8) {
            Text(manager.currentParticipant?.name ?? "Standup Timer")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(TimeFormatter.format(manager.remainingTime))
                .font(.system(.largeTitle, design: .monospaced))
                .monospacedDigit()

            Button(manager.isRunning ? "Suivant" : "Démarrer") {
                if manager.isRunning {
                    manager.nextSpeaker()
                } else {
                    manager.startMeeting()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
