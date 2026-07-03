import SwiftUI
import StandupKit

/// tvOS entry point (scaffold).
///
/// Mirrors the iOS / watchOS shells: one ``MeetingManager`` wired to the tvOS
/// platform stubs, plus the ``ProAccessManager`` for Pro-gated flows. The real
/// Apple TV UI (big-screen room display + Siri Remote focus controls) comes later.
@main
struct StandupTimerTVApp: App {
    @State private var manager: MeetingManager
    @State private var proAccess = ProAccessManager()

    init() {
        _manager = State(initialValue: MeetingManager(
            sound: TVSoundPlayer(),
            export: TVExportService(),
            overlay: TVOverlayPresenting(),
            launchAtLogin: TVLaunchAtLogin()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager, proAccess: proAccess)
        }
    }
}
