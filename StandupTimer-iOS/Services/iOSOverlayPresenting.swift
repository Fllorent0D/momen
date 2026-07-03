import Foundation
import StandupKit

/// iOS implementation of `OverlayPresenting`.
///
/// On macOS the overlay is a floating, draggable panel rendered above other
/// windows. iOS has no equivalent free-floating panel model, so the "overlay"
/// instead becomes a full-screen takeover of the app's root view (per issue #12:
/// "bascule de vue racine").
///
/// Because the full-screen timer screen itself is built in issue #13, this type
/// is a clean observable state holder: it records whether the overlay should be
/// shown and at which `BannerPosition`. Issue #13's root view observes this
/// object and switches between the normal UI and the full-screen timer.
///
/// `resetPosition()` is a deliberate no-op: the iOS timer is full-screen and has
/// no draggable panel whose position could drift, so there is nothing to reset.
@MainActor
@Observable
final class iOSOverlayPresenting: OverlayPresenting {
    /// Whether the full-screen timer overlay should be presented. The root view
    /// (issue #13) observes this to switch the root view.
    private(set) var isPresented: Bool = false

    /// The requested banner position. Retained so #13 can honour the user's
    /// configured placement when it lays out the full-screen timer.
    private(set) var position: BannerPosition = .topCenter

    func show(position: BannerPosition) {
        self.position = position
        isPresented = true
    }

    func close() {
        isPresented = false
    }

    func resetPosition() {
        // No-op on iOS: the timer is full-screen with no draggable panel.
    }
}
