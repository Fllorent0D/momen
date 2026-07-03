import Foundation

public enum TimeFormatter {
    public static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(abs(interval))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let prefix = interval < 0 ? "-" : ""
        return "\(prefix)\(minutes):\(String(format: "%02d", seconds))"
    }

    public static func formatOvertime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "+\(minutes):\(String(format: "%02d", seconds))"
    }

    public static func formatDuration(minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)min" : "\(h)h"
        }
        return "\(minutes) min"
    }
}
