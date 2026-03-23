import SwiftUI

@main
struct StandupTimerRemoteApp: App {
    @State private var remote = RemoteManager()

    var body: some Scene {
        WindowGroup {
            RemoteControlView()
                .environment(remote)
        }
    }
}
