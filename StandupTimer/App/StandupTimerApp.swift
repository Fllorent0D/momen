import SwiftUI

@main
struct StandupTimerApp: App {
    @State private var manager = MeetingManager()

    var body: some Scene {
        MenuBarExtra {
            ConfigurationView()
                .environment(manager)
        } label: {
            if manager.isActive {
                Text(manager.menuBarLabel)
            } else {
                Label("Standup Timer", systemImage: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
