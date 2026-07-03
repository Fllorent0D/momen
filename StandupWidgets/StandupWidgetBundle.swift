import WidgetKit
import SwiftUI

/// `@main` entry point for the iOS widget extension (issue #52).
///
/// The bundle currently vends a single widget — the standup Live Activity. It is
/// a `WidgetBundle` (rather than a bare `Widget`) so additional home-screen /
/// lock-screen widgets can be added here later without changing the extension's
/// wiring.
@main
struct StandupWidgetBundle: WidgetBundle {
    var body: some Widget {
        StandupLiveActivity()
    }
}
