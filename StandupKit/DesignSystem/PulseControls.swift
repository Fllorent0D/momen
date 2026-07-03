import SwiftUI

/// Pulse — « Le Signal » — the reusable control library.
///
/// A small kit of composable SwiftUI controls — buttons, switch, status pill,
/// segmented control, participant row, stepper and slider — that every Pulse
/// surface shares: the Mac menu-bar config + stats today, the iOS reskin
/// tomorrow. Each control is built **only** from the Pulse tokens
/// (`PulseColor`, `PulseSpacing`, `PulseRadius`, `PulseTypography`,
/// `PulseMotion`); there is no raw hex, point size or magic number here, and
/// nothing reaches for AppKit/UIKit, so the kit compiles untouched on macOS
/// and iOS.
///
/// Colours are resolved to a concrete `Color` against the active
/// `@Environment(\.colorScheme)` inside each control, exactly as `SignalRing`
/// does, so the tokens track system appearance automatically.

// MARK: - Sizing

/// Three control sizes shared across the kit, mapping to the Pulse spacing
/// rhythm and type scale.
public enum PulseControlSize: Sendable {
    case small, regular, large
}

// MARK: - Buttons

/// The five button intents from the spec: a bright `primary` call-to-action,
/// a bordered `secondary`, a chrome-less `neutral` text button, a `destructive`
/// red action, and a square `icon` chip.
public enum PulseButtonVariant: Sendable {
    case primary, secondary, neutral, destructive, icon
}

/// A `ButtonStyle` that renders the Pulse button intents. Use the
/// `.pulse(_:accent:size:)` sugar:
///
///     Button("Démarrer") { … }.buttonStyle(.pulse(.primary, size: .large))
///     Button("Supprimer") { … }.buttonStyle(.pulse(.destructive, size: .small))
///     Button { … } label: { Image(systemName: "power") }
///         .buttonStyle(.pulse(.icon))
///
/// `accent` (a `PulseColor`, default `.signal`) tints the `primary`/`secondary`
/// variants so a row of small actions can stay semantic — `.signal` to add,
/// `.warn` to rotate, `.over` to remove — while `destructive` always uses
/// `.over` and `neutral`/`icon` stay on the ink/surface tokens.
public struct PulseButtonStyle: ButtonStyle {
    public let variant: PulseButtonVariant
    public let accent: PulseColor
    public let size: PulseControlSize

    public init(_ variant: PulseButtonVariant = .primary,
                accent: PulseColor = .signal,
                size: PulseControlSize = .regular) {
        self.variant = variant
        self.accent = accent
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        PulseButtonBody(variant: variant, accent: accent, size: size, configuration: configuration)
    }
}

public extension ButtonStyle where Self == PulseButtonStyle {
    /// Pulse button style. See ``PulseButtonStyle``.
    static func pulse(_ variant: PulseButtonVariant = .primary,
                      accent: PulseColor = .signal,
                      size: PulseControlSize = .regular) -> PulseButtonStyle {
        PulseButtonStyle(variant, accent: accent, size: size)
    }
}

private struct PulseButtonBody: View {
    let variant: PulseButtonVariant
    let accent: PulseColor
    let size: PulseControlSize
    let configuration: ButtonStyleConfiguration

    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .pulseText(textStyle)
            .fontWeight(size == .large ? .semibold : nil)
            .foregroundStyle(foreground)
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background(background, in: RoundedRectangle(cornerRadius: PulseRadius.control))
            .overlay {
                if variant == .secondary {
                    RoundedRectangle(cornerRadius: PulseRadius.control)
                        .strokeBorder(effectiveAccent.color(for: scheme).opacity(0.45), lineWidth: 1)
                }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(PulseMotion.standard, value: configuration.isPressed)
    }

    /// `destructive` resolves to the `over` token regardless of `accent`.
    private var effectiveAccent: PulseColor {
        variant == .destructive ? .over : accent
    }

    private var textStyle: PulseTextStyle {
        switch size {
        case .small:   return .callout
        case .regular: return .callout
        case .large:   return .body
        }
    }

    private var foreground: Color {
        switch variant {
        // Dark ink on the bright accent fill — readable in both appearances.
        case .primary, .destructive: return PulseColor.canvas.color(for: .dark)
        case .secondary:             return effectiveAccent.color(for: scheme)
        case .neutral, .icon:        return PulseColor.inkMuted.color(for: scheme)
        }
    }

    private var background: Color {
        switch variant {
        case .primary, .destructive: return effectiveAccent.color(for: scheme)
        case .secondary, .icon:      return PulseColor.surface2.color(for: scheme)
        case .neutral:               return .clear
        }
    }

    private var hPadding: CGFloat {
        if variant == .icon { return PulseSpacing.xs }
        switch size {
        case .small:   return PulseSpacing.sm
        case .regular: return PulseSpacing.md
        case .large:   return PulseSpacing.md
        }
    }

    private var vPadding: CGFloat {
        if variant == .icon { return PulseSpacing.xs }
        switch size {
        case .small:   return PulseSpacing.xs
        case .regular: return PulseSpacing.xs
        case .large:   return PulseSpacing.sm
        }
    }
}

// MARK: - Toggle (Pulse switch)

/// A `ToggleStyle` rendering the Pulse switch: a capsule track that fills with
/// `.signal` when on, a light knob that slides across, with the label kept on
/// the leading edge. Apply once to a container and every descendant `Toggle`
/// inherits it:
///
///     VStack { Toggle("Sons", isOn: $sound) }.toggleStyle(.pulse)
public struct PulseToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PulseToggleBody(configuration: configuration)
    }
}

public extension ToggleStyle where Self == PulseToggleStyle {
    /// Pulse switch style. See ``PulseToggleStyle``.
    static var pulse: PulseToggleStyle { PulseToggleStyle() }
}

private struct PulseToggleBody: View {
    let configuration: ToggleStyleConfiguration

    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    // Track sized off the spacing rhythm: width ≈ 4·md/… kept compact.
    private let trackWidth: CGFloat = 42
    private let trackHeight: CGFloat = 24
    private let knob: CGFloat = 18

    var body: some View {
        HStack {
            configuration.label
                .pulseText(.body)
                .foregroundStyle(PulseColor.ink.color(for: scheme))
            Spacer(minLength: PulseSpacing.sm)
            track
        }
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(PulseMotion.standard) { configuration.isOn.toggle() }
        }
    }

    private var track: some View {
        Capsule()
            .fill((configuration.isOn ? PulseColor.signal : PulseColor.surface2).color(for: scheme))
            .frame(width: trackWidth, height: trackHeight)
            .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                Circle()
                    .fill(PulseColor.ink.color(for: .dark))
                    .frame(width: knob, height: knob)
                    .padding((trackHeight - knob) / 2)
            }
    }
}

// MARK: - Status pill / badge

/// The semantic tone of a ``PulseStatusPill``, mapped to the signal spectrum
/// plus a `neutral` ink-muted default.
public enum PulseTone: Sendable {
    case signal, warn, over, neutral

    var color: PulseColor {
        switch self {
        case .signal:  return .signal
        case .warn:    return .warn
        case .over:    return .over
        case .neutral: return .inkMuted
        }
    }
}

/// A compact status pill (« pastille d'état ») — an optional SF Symbol plus a
/// short label in a capsule. `tinted` (the default) paints a soft tone-coloured
/// wash with coloured text; `filled` paints the solid tone with dark text, for
/// loud counters like an overtime rate.
///
///     PulseStatusPill("Pro", tone: .signal)
///     PulseStatusPill("\(pct)%", tone: .over, filled: true)
public struct PulseStatusPill: View {
    private let title: String
    private let systemImage: String?
    private let tone: PulseTone
    private let filled: Bool

    @Environment(\.colorScheme) private var scheme

    public init(_ title: String, systemImage: String? = nil, tone: PulseTone = .neutral, filled: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.filled = filled
    }

    public var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .pulseText(.label)
        .foregroundStyle(foreground)
        .padding(.horizontal, PulseSpacing.xs)
        .padding(.vertical, PulseSpacing.xxs)
        .background(background, in: Capsule())
    }

    private var foreground: Color {
        filled ? PulseColor.canvas.color(for: .dark) : tone.color.color(for: scheme)
    }

    private var background: Color {
        filled ? tone.color.color(for: scheme) : tone.color.color(for: scheme).opacity(0.16)
    }
}

// MARK: - Segmented control

/// A Pulse segmented control — a token-built stand-in for
/// `.pickerStyle(.segmented)`. Segments live in a `surface2` trough; the
/// selected one lifts onto a soft `signal` wash with ink text.
///
///     PulseSegmentedControl(selection: $tab, options: [
///         (0, "Participants"), (1, "Historique"),
///     ])
///
/// For a `String`-backed `CaseIterable` enum, the convenience initialiser reads
/// the cases and their `rawValue` labels directly:
///
///     PulseSegmentedControl(selection: $manager.meeting.overtimeMode)
public struct PulseSegmentedControl<T: Hashable>: View {
    private let options: [(value: T, label: String)]
    @Binding private var selection: T

    @Environment(\.colorScheme) private var scheme

    public init(selection: Binding<T>, options: [(value: T, label: String)]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: PulseSpacing.xxs) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Text(option.label)
                    .pulseText(.callout)
                    .foregroundStyle((isSelected ? PulseColor.ink : PulseColor.inkMuted).color(for: scheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PulseSpacing.xs)
                    .background(
                        isSelected ? PulseColor.signal.color(for: scheme).opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: PulseRadius.chip)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(PulseMotion.standard) { selection = option.value }
                    }
            }
        }
        .padding(PulseSpacing.xxs)
        .background(PulseColor.surface2.color(for: scheme), in: RoundedRectangle(cornerRadius: PulseRadius.control))
    }
}

public extension PulseSegmentedControl where T: CaseIterable & RawRepresentable, T.RawValue == String {
    /// Builds the segments from a `String`-backed `CaseIterable` enum, using
    /// each case's `rawValue` as its label.
    init(selection: Binding<T>) {
        self.init(selection: selection, options: T.allCases.map { ($0, $0.rawValue) })
    }
}

// MARK: - Stepper

/// A Pulse stepper — a `−` / value / `+` cluster in a `surface2` trough, built
/// from two ``PulseButtonStyle`` icon chips. Mirrors `Stepper(value:in:step:)`
/// semantics and disables each chip at its bound.
///
///     PulseStepper(value: $count, in: 1...10) { "\($0)" }
public struct PulseStepper: View {
    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let step: Int
    private let format: (Int) -> String

    @Environment(\.colorScheme) private var scheme

    public init(value: Binding<Int>,
                in range: ClosedRange<Int>,
                step: Int = 1,
                format: @escaping (Int) -> String = { "\($0)" }) {
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    public var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.pulse(.icon))
            .disabled(value <= range.lowerBound)

            Text(format(value))
                .pulseText(.mono)
                .foregroundStyle(PulseColor.ink.color(for: scheme))
                .frame(minWidth: PulseSpacing.xxl)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.pulse(.icon))
            .disabled(value >= range.upperBound)
        }
        .padding(PulseSpacing.xxs)
        .background(PulseColor.surface.color(for: scheme), in: RoundedRectangle(cornerRadius: PulseRadius.control))
    }
}

// MARK: - Slider

/// A Pulse slider — a token-built stand-in for `Slider(value:in:step:)`. A
/// `surface2` rail fills with `.signal` up to the value, topped by a light
/// draggable thumb. Snaps to `step` and clamps to `range`, so an existing
/// `.onChange(of:)` on the bound value keeps firing unchanged.
///
///     PulseSlider(value: $minutes, in: 1...60, step: 1)
public struct PulseSlider: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double

    @Environment(\.colorScheme) private var scheme

    private let thumb: CGFloat = 20
    private let rail: CGFloat = 6

    public init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1) {
        self._value = value
        self.range = range
        self.step = step
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = self.fraction
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PulseColor.surface2.color(for: scheme))
                    .frame(height: rail)
                Capsule()
                    .fill(PulseColor.signal.color(for: scheme))
                    .frame(width: thumb + (width - thumb) * fraction, height: rail)
                Circle()
                    .fill(PulseColor.ink.color(for: .dark))
                    .frame(width: thumb, height: thumb)
                    .offset(x: (width - thumb) * fraction)
            }
            .frame(height: thumb)
            .contentShape(Rectangle())
            // DragGesture n'existe pas sur tvOS (pilotage par focus/Siri Remote) ;
            // le slider tactile n'y est pas utilisé (scaffold « écran salle »).
            #if !os(tvOS)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        update(toX: gesture.location.x, width: width)
                    }
            )
            #endif
        }
        .frame(height: thumb)
    }

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((value - range.lowerBound) / span)
    }

    private func update(toX x: CGFloat, width: CGFloat) {
        guard width > thumb else { return }
        let f = min(max(0, (x - thumb / 2) / (width - thumb)), 1)
        let raw = range.lowerBound + Double(f) * (range.upperBound - range.lowerBound)
        let stepped = (raw / step).rounded() * step
        value = min(max(stepped, range.lowerBound), range.upperBound)
    }
}

// MARK: - Row container

public extension View {
    /// Wraps content in the Pulse list-row chrome: row padding over a `surface2`
    /// fill rounded to ``PulseRadius/card``. The shared backing for participant
    /// rows, history rows and stat tiles (« rangée participant »).
    func pulseRow(radius: CGFloat = PulseRadius.card) -> some View {
        modifier(PulseRowModifier(radius: radius))
    }
}

private struct PulseRowModifier: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, PulseSpacing.xs)
            .background(PulseColor.surface2.color(for: scheme), in: RoundedRectangle(cornerRadius: radius))
    }
}

#if DEBUG
#Preview("Pulse Controls") {
    @Previewable @State var on = true
    @Previewable @State var minutes: Double = 15
    @Previewable @State var count = 3
    @Previewable @State var tab = 0

    return ScrollView {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            HStack(spacing: PulseSpacing.sm) {
                Button("Primaire") {}.buttonStyle(.pulse(.primary))
                Button("Secondaire") {}.buttonStyle(.pulse(.secondary))
                Button("Neutre") {}.buttonStyle(.pulse(.neutral))
                Button("Suppr.") {}.buttonStyle(.pulse(.destructive, size: .small))
                Button { } label: { Image(systemName: "power") }.buttonStyle(.pulse(.icon))
            }

            Toggle("Sons", isOn: $on).toggleStyle(.pulse)

            HStack(spacing: PulseSpacing.sm) {
                PulseStatusPill("Pro", tone: .signal)
                PulseStatusPill("Essai", systemImage: "clock", tone: .warn)
                PulseStatusPill("80%", tone: .over, filled: true)
            }

            PulseSegmentedControl(selection: $tab, options: [(0, "Un"), (1, "Deux"), (2, "Trois")])
            PulseSlider(value: $minutes, in: 1...60, step: 1)
            PulseStepper(value: $count, in: 1...10) { "\($0) min" }

            Text("Rangée").pulseText(.body).frame(maxWidth: .infinity, alignment: .leading).pulseRow()
        }
        .padding(PulseSpacing.xl)
    }
    .background(PulseColor.canvas)
    .preferredColorScheme(.dark)
}
#endif
