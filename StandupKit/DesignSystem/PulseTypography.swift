import SwiftUI

/// Pulse type families. The actual font *files* are added in issue #45; these
/// string constants are the names views and the `PulseTextStyle` roles below
/// reference, so wiring the bundled fonts later needs no view changes.
///
/// - `ui`   — Space Grotesk, for interface and titles.
/// - `mono` — JetBrains Mono, for everything that "counts": the chrono,
///            percentages, technical labels.
public enum PulseFontFamily {
    public static let ui = "Space Grotesk"
    public static let mono = "JetBrains Mono"
}

/// A Pulse text role: a family, point size, weight and letter-spacing (tracking).
///
/// `.custom(_:size:)` references the family by name and gracefully falls back to
/// the system font until issue #45 bundles the real files, so adopting these
/// roles now is safe and additive.
///
///     Text("STANDUP TIMER").pulseText(.label)
///     Text(timeString).pulseText(.chrono)
public struct PulseTextStyle: Sendable {

    public let family: String
    public let size: CGFloat
    public let weight: Font.Weight
    /// Letter-spacing in points (maps to SwiftUI `.tracking(_:)`).
    public let tracking: CGFloat

    public init(family: String, size: CGFloat, weight: Font.Weight, tracking: CGFloat = 0) {
        self.family = family
        self.size = size
        self.weight = weight
        self.tracking = tracking
    }

    /// The SwiftUI `Font` for this role (tracking is applied separately via
    /// ``SwiftUI/View/pulseText(_:)`` or `.tracking(_:)`).
    public var font: Font {
        .custom(family, size: size).weight(weight)
    }
}

// MARK: - Type scale
//
// Sizes and weights are taken from the Pulse spec specimens (92 / 52 / 46 / 38 /
// 26 / 18 / 15 / 13 / 11 px) and its weight set: Space Grotesk 400–700,
// JetBrains Mono 400/500/700/800. Weight mapping: 800 → .heavy, 700 → .bold,
// 600 → .semibold, 500 → .medium, 400 → .regular.

public extension PulseTextStyle {

    /// The hero mono chrono read-out.            JetBrains Mono · 92 · 800
    static let chrono = PulseTextStyle(family: PulseFontFamily.mono, size: 92, weight: .heavy, tracking: -2)

    /// Compact chrono (menu bar / overlay).      JetBrains Mono · 46 · 700
    static let chronoCompact = PulseTextStyle(family: PulseFontFamily.mono, size: 46, weight: .bold, tracking: -1)

    /// Display heading.                          Space Grotesk · 52 · 700
    static let display = PulseTextStyle(family: PulseFontFamily.ui, size: 52, weight: .bold, tracking: -2.5)

    /// Section title.                            Space Grotesk · 38 · 700
    static let title = PulseTextStyle(family: PulseFontFamily.ui, size: 38, weight: .bold, tracking: -1.2)

    /// Sub-heading.                              Space Grotesk · 26 · 600
    static let heading = PulseTextStyle(family: PulseFontFamily.ui, size: 26, weight: .semibold, tracking: -0.5)

    /// Lead paragraph.                           Space Grotesk · 18 · 400
    static let bodyLarge = PulseTextStyle(family: PulseFontFamily.ui, size: 18, weight: .regular)

    /// Body text.                                Space Grotesk · 15 · 400
    static let body = PulseTextStyle(family: PulseFontFamily.ui, size: 15, weight: .regular)

    /// Small emphasis / row title.               Space Grotesk · 13 · 500
    static let callout = PulseTextStyle(family: PulseFontFamily.ui, size: 13, weight: .medium)

    /// Inline mono value (percentages, counts).  JetBrains Mono · 13 · 500
    static let mono = PulseTextStyle(family: PulseFontFamily.mono, size: 13, weight: .medium)

    /// Uppercase technical label.                JetBrains Mono · 11 · 500 · tracked
    static let label = PulseTextStyle(family: PulseFontFamily.mono, size: 11, weight: .medium, tracking: 2)
}

// MARK: - View sugar

public extension View {
    /// Applies a Pulse text role: font + letter-spacing in one call.
    func pulseText(_ style: PulseTextStyle) -> some View {
        self.font(style.font).tracking(style.tracking)
    }
}
