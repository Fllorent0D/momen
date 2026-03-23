import SwiftUI

extension ColorTheme {
    var inTimeColor: Color {
        switch self {
        case .greenRed: return .green
        case .blueOrange: return .blue
        case .tealPink: return .teal
        case .purpleYellow: return .purple
        }
    }

    var overtimeColor: Color {
        switch self {
        case .greenRed: return .red
        case .blueOrange: return .orange
        case .tealPink: return .pink
        case .purpleYellow: return .yellow
        }
    }

    var inTimeHue: Double {
        switch self {
        case .greenRed: return 0.33
        case .blueOrange: return 0.6
        case .tealPink: return 0.5
        case .purpleYellow: return 0.8
        }
    }

    var overtimeHue: Double {
        switch self {
        case .greenRed: return 0.0
        case .blueOrange: return 0.08
        case .tealPink: return 0.92
        case .purpleYellow: return 0.16
        }
    }
}
