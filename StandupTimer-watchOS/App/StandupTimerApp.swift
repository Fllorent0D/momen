import SwiftUI
import StandupKit

/// watchOS entry point (scaffold).
///
/// Mirrors the iOS shell: one ``MeetingManager`` wired to the watch platform
/// stubs, plus the ``ProAccessManager`` for Pro-gated flows. The real watch UI
/// (compact timer + Digital Crown + complications) comes later.
@main
struct StandupTimerWatchApp: App {
    @State private var manager: MeetingManager
    @State private var proAccess = ProAccessManager()

    init() {
        _manager = State(initialValue: MeetingManager(
            sound: WatchSoundPlayer(),
            export: WatchExportService(),
            overlay: WatchOverlayPresenting(),
            launchAtLogin: WatchLaunchAtLogin()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager, proAccess: proAccess)
        }
    }
}
