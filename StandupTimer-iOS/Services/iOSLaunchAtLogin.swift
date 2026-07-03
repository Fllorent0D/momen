import StandupKit

/// iOS implementation of `LaunchAtLoginManaging`.
///
/// iOS has no launch-at-login concept (apps cannot register themselves to run at
/// device boot), so this is a deliberate no-op. It exists so the protocol is
/// satisfiable on iOS; the iOS shell will inject it once it constructs the core
/// (issue #13). The corresponding setting is simply hidden on iOS.
@MainActor
struct iOSLaunchAtLogin: LaunchAtLoginManaging {
    func setEnabled(_ enabled: Bool) {
        // No-op on iOS: there is no launch-at-login mechanism.
    }
}
