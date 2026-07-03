import SwiftUI

/// Pulse — per-person **identity accents**.
///
/// Every participant gets a stable, distinct tint drawn from a curated palette
/// that harmonises with the Pulse chrome. These accents are used purely for
/// *identity* — avatars, queue position, row highlights — never for time state.
///
/// IMPORTANT: the palette is deliberately built from cool jewel tones plus a
/// couple of pinks/magentas, all kept clear of the signal green (`PulseColor.signal`),
/// the warn amber (`PulseColor.warn`) and the over red (`PulseColor.over`). An
/// accent must never read as "the timer is running / nearly up / over budget".
///
/// The mapping is **deterministic**: the same `UUID` (or name) always resolves to
/// the same accent, so a participant looks identical across every view and every
/// launch. We fold the key's bytes with FNV-1a (a stable, seed-free hash — unlike
/// `Swift.Hasher`, whose seed is randomised per process) into a palette index.
///
///     AvatarView background → PulseAccent.color(for: participant.id)
///
/// AppKit/UIKit-free by construction: `import SwiftUI` only.
public enum PulseAccent {

    /// Curated identity palette — 10 Pulse-harmonious hues, each visually distinct
    /// from one another and from the signal/warn/over time-state colors. Mid-tone
    /// saturation/brightness so white initials stay legible on both light and dark.
    public static let palette: [Color] = [
        Color(accentHex: 0x3B82F6), // blue
        Color(accentHex: 0x06B6D4), // cyan
        Color(accentHex: 0x6366F1), // indigo
        Color(accentHex: 0x8B5CF6), // violet
        Color(accentHex: 0xA855F7), // purple
        Color(accentHex: 0xD946EF), // fuchsia
        Color(accentHex: 0xEC4899), // pink
        Color(accentHex: 0x0EA5E9), // sky
        Color(accentHex: 0x7C3AED), // deep violet
        Color(accentHex: 0xC026D3), // magenta
    ]

    /// The accent for a participant, keyed by their stable `id`.
    public static func color(for id: UUID) -> Color {
        color(for: index(forKey: id.uuidString))
    }

    /// The accent for a given palette index (wraps and stays in-range).
    public static func color(for index: Int) -> Color {
        let n = palette.count
        return palette[((index % n) + n) % n]
    }

    /// The accent for a bare name — used where only a participant's name is on
    /// hand (e.g. persisted stats records that don't carry the `UUID`).
    public static func color(forName name: String) -> Color {
        color(for: index(forKey: name))
    }

    /// Deterministic, process-stable FNV-1a fold of a key into a palette index.
    private static func index(forKey key: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325 // FNV-1a 64-bit offset basis
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3 // FNV prime
        }
        return Int(hash % UInt64(palette.count))
    }
}

// MARK: - Hex helper (file-local)

private extension Color {
    /// AppKit/UIKit-free initializer from a 24-bit RGB hex literal.
    init(accentHex hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
