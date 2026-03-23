import SwiftUI

struct TimeDisplay: View {
    let time: TimeInterval
    let isOvertime: Bool
    let overtimeElapsed: TimeInterval

    var body: some View {
        if isOvertime {
            Text(TimeFormatter.formatOvertime(overtimeElapsed))
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
        } else {
            Text(TimeFormatter.format(time))
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}
