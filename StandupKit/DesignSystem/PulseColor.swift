import SwiftUI

/// Pulse — « Le Signal » — semantic color tokens.
///
/// A `PulseColor` carries both its dark- and light-appearance values and
/// resolves automatically against the current `ColorScheme`. Because it
/// conforms to `ShapeStyle`, it can be handed straight to `foregroundStyle`,
/// `fill`, `background`, `tint`, … and SwiftUI picks the right variant per
/// environment — no asset catalog required:
///
///     Text("12:00").foregroundStyle(PulseColor.signal)
///     RoundedRectangle(cornerRadius: PulseRadius.card).fill(PulseColor.surface)
///
/// When a plain `Color` is needed (gradients, interpolation, stroke gradients),
/// call ``color(for:)`` with the active scheme.
///
/// These eight tokens are the single source of truth for app chrome: views
/// should never reach for a raw hex value.
public struct PulseColor: ShapeStyle, Sendable {

    /// Value used when the environment resolves to `.dark`.
    public let dark: Color
    /// Value used when the environment resolves to `.light`.
    public let light: Color

    public init(dark: Color, light: Color) {
        self.dark = dark
        self.light = light
    }

    /// The concrete `Color` for a given appearance.
    public func color(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }

    // ShapeStyle conformance: resolve against the environment's color scheme so
    // the token tracks system appearance on both macOS and iOS automatically.
    public func resolve(in environment: EnvironmentValues) -> Color {
        color(for: environment.colorScheme)
    }
}

// MARK: - Semantic tokens

public extension PulseColor {

    /// App background.                              SOMBRE #0A0B0D · CLAIR #F4F6F5
    static let canvas = PulseColor(dark: Color(pulseHex: 0x0A0B0D), light: Color(pulseHex: 0xF4F6F5))

    /// Cards, lists, popovers.                      SOMBRE #131519 · CLAIR #E6EAE7
    static let surface = PulseColor(dark: Color(pulseHex: 0x131519), light: Color(pulseHex: 0xE6EAE7))

    /// Icon buttons, raised controls (surface-2).   SOMBRE #1A1D22 · CLAIR #F1F3F1
    static let surface2 = PulseColor(dark: Color(pulseHex: 0x1A1D22), light: Color(pulseHex: 0xF1F3F1))

    /// Primary text.                                SOMBRE #F4F6F5 · CLAIR #0B0D10
    static let ink = PulseColor(dark: Color(pulseHex: 0xF4F6F5), light: Color(pulseHex: 0x0B0D10))

    /// Secondary text (ink-muted).                  SOMBRE #AAB2AE · CLAIR #5A635D
    static let inkMuted = PulseColor(dark: Color(pulseHex: 0xAAB2AE), light: Color(pulseHex: 0x5A635D))

    /// Running · primary accent.                    SOMBRE #00E08A · CLAIR #00C878
    static let signal = PulseColor(dark: Color(pulseHex: 0x00E08A), light: Color(pulseHex: 0x00C878))

    /// Limit imminent.                              SOMBRE #FFC53D · CLAIR #E0A11F
    static let warn = PulseColor(dark: Color(pulseHex: 0xFFC53D), light: Color(pulseHex: 0xE0A11F))

    /// Overtime / over-budget.                      SOMBRE #FF4D4D · CLAIR #F5392F
    static let over = PulseColor(dark: Color(pulseHex: 0xFF4D4D), light: Color(pulseHex: 0xF5392F))
}

// MARK: - Hex helper (module-internal)

extension Color {
    /// AppKit/UIKit-free initializer from a 24-bit RGB hex literal, e.g.
    /// `Color(pulseHex: 0x00E08A)`. Kept internal so token files remain the only
    /// place raw hex appears.
    init(pulseHex hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
