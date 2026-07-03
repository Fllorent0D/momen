import SwiftUI

/// Pulse spacing rhythm. Values mirror the dominant gaps and paddings in the
/// spec (4 / 6 / 10 / 14 / 18 / 24 / 40 / 80) so layouts share one cadence.
public enum PulseSpacing {
    /// 4 — hairline gap between tightly coupled elements.
    public static let xxs: CGFloat = 4
    /// 6 — chip / badge inner padding.
    public static let xs: CGFloat = 6
    /// 10 — default gap between sibling controls (the spec's most common gap).
    public static let sm: CGFloat = 10
    /// 14 — card / row inner padding.
    public static let md: CGFloat = 14
    /// 18 — group spacing.
    public static let lg: CGFloat = 18
    /// 24 — block spacing.
    public static let xl: CGFloat = 24
    /// 40 — major section padding.
    public static let xxl: CGFloat = 40
    /// 80 — full-bleed section vertical rhythm.
    public static let xxxl: CGFloat = 80
}

/// Pulse corner radii. The container/card family lives in the spec's signature
/// 13–18 px range; `pill` and `chip` cover the extremes.
public enum PulseRadius {
    /// 7 — small swatches, icon chips.
    public static let chip: CGFloat = 7
    /// 10 — buttons, list rows, pickers.
    public static let control: CGFloat = 10
    /// 14 — inner cards / list rows.
    public static let card: CGFloat = 14
    /// 16 — popovers, floating panels.
    public static let panel: CGFloat = 16
    /// 18 — outer containers / grouped tables.
    public static let container: CGFloat = 18
    /// 999 — fully rounded (pills, avatars when squared off).
    public static let pill: CGFloat = 999
}
