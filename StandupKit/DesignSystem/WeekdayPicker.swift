import SwiftUI

/// Sélecteur de jours de la semaine (pastilles) pour le rappel de standup.
/// Lie un `Set<Int>` de weekdays Apple (1 = dimanche … 7 = samedi). L'ordre des
/// pastilles et les libellés suivent la locale (premier jour + symboles courts).
public struct WeekdayPicker: View {
    @Binding private var selection: Set<Int>
    private let onChange: () -> Void
    @Environment(\.colorScheme) private var scheme

    public init(selection: Binding<Set<Int>>, onChange: @escaping () -> Void = {}) {
        self._selection = selection
        self.onChange = onChange
    }

    /// Weekdays ordonnés selon le premier jour de la locale (lun-first en fr/de…).
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday   // 1 = dimanche
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private func symbol(for weekday: Int) -> String {
        let syms = Calendar.current.veryShortStandaloneWeekdaySymbols   // index 0 = dimanche
        return syms[(weekday - 1) % syms.count]
    }

    public var body: some View {
        HStack(spacing: PulseSpacing.xs) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                Button {
                    if isOn { selection.remove(weekday) } else { selection.insert(weekday) }
                    onChange()
                } label: {
                    Text(symbol(for: weekday))
                        .pulseText(.label)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(
                                isOn ? PulseColor.signal.color(for: scheme)
                                     : PulseColor.surface2.color(for: scheme))
                        )
                        .foregroundStyle(
                            isOn ? PulseColor.canvas.color(for: .dark)
                                 : PulseColor.inkMuted.color(for: scheme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[(weekday - 1) % 7])
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
    }
}
