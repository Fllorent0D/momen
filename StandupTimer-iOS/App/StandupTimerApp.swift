import SwiftUI
import StandupKit

/// iOS entry point.
///
/// Issue #11 stood the target up with a smoke-test view; this is the real shell
/// (issue #13, parts A–C). It constructs a single ``MeetingManager`` wired to the
/// iOS platform services, holds the
/// ``iOSOverlayPresenting`` instance so the root view can observe its
/// `isPresented` flag (the iOS "overlay" = a full-screen root-view takeover), and
/// owns the ``ProAccessManager`` for the paywall/Pro-gated flows.
@main
struct StandupTimerApp: App {
    @State private var manager: MeetingManager
    @State private var proAccess = ProAccessManager()
    /// Retained so ``ContentView`` can observe `isPresented` to switch the root
    /// view between the home screen and the full-screen timer.
    private let overlay: iOSOverlayPresenting

    init() {
        ProAccessManager.configureRevenueCat()
        Analytics.configure()
        let overlay = iOSOverlayPresenting()
        self.overlay = overlay
        let manager = MeetingManager(
            sound: iOSSoundPlayer(),
            export: iOSExportService(),
            overlay: overlay,
            launchAtLogin: iOSLaunchAtLogin()
        )
        #if DEBUG
        manager.seedForSnapshotIfNeeded()
        #endif
        _manager = State(initialValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager, proAccess: proAccess, overlay: overlay)
        }
    }
}
