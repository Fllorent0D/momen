import ActivityKit
import WidgetKit
import SwiftUI
import StandupKit

/// The standup Live Activity (issue #52): the running standup followed from the
/// Lock Screen, the Dynamic Island and the StandBy banner.
///
/// It is deliberately a thin presentation layer over ``StandupActivityAttributes``
/// — the iOS app drives every value (speaker, chrono, ring fraction, overtime)
/// by `update`-ing the activity's `ContentState`. Here we only paint it, reusing
/// the Pulse design system from `StandupKit`: the conic ``SignalRing`` (#46),
/// `PulseColor`, and the JetBrains-Mono chrono typography. Everything tips from
/// signal green to over-red the instant `isOvertime` is set, exactly like the
/// in-app timer.
struct StandupLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StandupActivityAttributes.self) { context in
            // Lock Screen / StandBy / banner presentation.
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(PulseColor.canvas.color(for: .dark))
                .activitySystemActionForegroundColor(PulseColor.ink.color(for: .dark))
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                // Expanded — speaker + chrono + ring + "suivant".
                DynamicIslandExpandedRegion(.leading) {
                    MiniRing(state: state, side: 38)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ChronoText(state.timeText, size: 30, isOvertime: state.isOvertime)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(state.speaker)
                            .pulseText(.heading)
                            .foregroundStyle(PulseColor.ink.color(for: .dark))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(state.index)/\(state.total)")
                            .pulseText(.label)
                            .foregroundStyle(PulseColor.inkMuted.color(for: .dark))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let next = state.next {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("SUIVANT · \(next)")
                                .pulseText(.label)
                                .lineLimit(1)
                        }
                        .foregroundStyle(accent(state).color(for: .dark))
                        .frame(maxWidth: .infinity)
                    }
                }
            } compactLeading: {
                MiniRing(state: state, side: 20)
            } compactTrailing: {
                ChronoText(state.timeText, size: 15, isOvertime: state.isOvertime)
            } minimal: {
                MiniRing(state: state, side: 22)
            }
            .keylineTint(accent(state).color(for: .dark))
        }
    }
}

// MARK: - Lock Screen

/// The Lock Screen / banner layout: a compact Pulse row — a small ``SignalRing``,
/// the speaker name with the "suivant" hint, and the big mono chrono. Forced to
/// the dark Pulse palette so it reads against the dark banner background on every
/// device appearance.
private struct LockScreenLiveActivityView: View {
    let state: StandupActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            SignalRing(fraction: state.fraction, timeText: "", state: signalState(state))
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.speaker)
                    .pulseText(.heading)
                    .foregroundStyle(PulseColor.ink.color(for: .dark))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let next = state.next {
                    Text("SUIVANT · \(next)")
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.inkMuted.color(for: .dark))
                        .lineLimit(1)
                } else {
                    Text("DERNIER · \(state.index)/\(state.total)")
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.inkMuted.color(for: .dark))
                }
            }

            Spacer(minLength: PulseSpacing.sm)

            ChronoText(state.timeText, size: 34, isOvertime: state.isOvertime)
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.md)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Shared bits

/// The mono chrono read-out at an arbitrary size, tinted over-red in overtime.
/// Uses the Pulse JetBrains-Mono family so it matches the in-app chrono.
private struct ChronoText: View {
    let text: String
    let size: CGFloat
    let isOvertime: Bool

    init(_ text: String, size: CGFloat, isOvertime: Bool) {
        self.text = text
        self.size = size
        self.isOvertime = isOvertime
    }

    var body: some View {
        Text(text)
            .font(.custom(PulseFontFamily.mono, size: size).weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(
                (isOvertime ? PulseColor.over : PulseColor.signal).color(for: .dark)
            )
    }
}

/// A lightweight conic ring for the Dynamic Island's compact/minimal slots,
/// where the full ``SignalRing`` (halo + blur) is too heavy. Same Pulse spectrum:
/// green → amber → red as the sweep shrinks, full red in overtime.
private struct MiniRing: View {
    let state: StandupActivityAttributes.ContentState
    let side: CGFloat

    var body: some View {
        let resolved = signalState(state)
        let sweep = resolved == .over ? 1 : max(0.02, min(state.fraction, 1))
        ZStack {
            Circle()
                .stroke(PulseColor.surface2.color(for: .dark), lineWidth: side * 0.16)
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(
                    tint(resolved),
                    style: StrokeStyle(lineWidth: side * 0.16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: side, height: side)
    }

    private func tint(_ s: SignalRing.SignalState) -> Color {
        switch s {
        case .normal: return PulseColor.signal.color(for: .dark)
        case .warn:   return PulseColor.warn.color(for: .dark)
        case .over:   return PulseColor.over.color(for: .dark)
        }
    }
}

/// Resolve the Pulse signal state from the live payload: explicit overtime wins,
/// otherwise it is derived from the ring fraction (mirrors ``SignalRing``).
private func signalState(_ state: StandupActivityAttributes.ContentState) -> SignalRing.SignalState {
    state.isOvertime ? .over : .forFraction(state.fraction)
}

/// The dominant accent for the current payload — signal green, over-red once over.
private func accent(_ state: StandupActivityAttributes.ContentState) -> PulseColor {
    state.isOvertime ? .over : .signal
}
