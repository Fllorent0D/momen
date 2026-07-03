import Foundation

/// Anchor class used only to resolve StandupKit's own bundle.
///
/// User-facing strings vended by StandupKit (enum labels, badge titles,
/// paywall copy, productivity quotes…) localize against StandupKit's
/// `Localizable.xcstrings`, which is compiled into *this* framework bundle —
/// not the host app's `.main` bundle. `String(localized:)` defaults to
/// `Bundle.main`, so those call sites must pass `bundle: .standupKit`.
private final class KitBundleToken {}

extension Bundle {
    /// The bundle of the StandupKit framework, where its String Catalog lives.
    public static let standupKit = Bundle(for: KitBundleToken.self)
}
