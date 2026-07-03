import ServiceManagement
import StandupKit

/// macOS implementation of `LaunchAtLoginManaging`, backed by `SMAppService`.
///
/// Registers or unregisters the main app as a login item. Failures are
/// swallowed silently — matching the prior in-`MeetingManager` behaviour — since
/// there is no useful recovery for a denied login-item registration.
@MainActor
struct MacLaunchAtLogin: LaunchAtLoginManaging {
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch { /* silently fail */ }
    }
}
