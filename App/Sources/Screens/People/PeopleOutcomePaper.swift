import SwiftUI
import TycoonEngine

/// Iteration 11 — N2. What just happened, on pixel paper: their face, the
/// line they came back with, and the number the bar actually moved.
///
/// It is the one place the menu stops being a list of buttons and becomes
/// a person answering you, so it gets the pixel panel rather than a card.
struct PeopleOutcomePaper: View {
    let engine: GameEngine
    let target: InteractionTarget
    let outcome: InteractionOutcome

    var body: some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                if let seed = engine.state.interactionSeed(target, content: engine.content) {
                    PixelPortrait(seed: seed, size: 44)
                        .padding(3)
                        .background(Theme.pixelPaper)
                        .overlay { PixelPanelBorder(thickness: 2, corner: 2).fill(Theme.pixelInk) }
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(outcome.line)
                        .font(.callout)
                        .foregroundStyle(Theme.pixelInk)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(deltaText)
                            .font(Theme.Typography.number(.caption).weight(.semibold))
                            .foregroundStyle(deltaTint)
                        Text(whenText)
                            .font(.caption2)
                            .foregroundStyle(Theme.pixelInk.opacity(0.55))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(outcome.line). \(deltaText).")
    }

    /// The number that actually landed after the clamp, not the number the
    /// button promised — a bond already at 100 moved by nothing.
    private var deltaText: String {
        let rounded = Int(outcome.delta.rounded())
        if rounded == 0 { return "\(outcome.barLabel) unchanged" }
        return "\(outcome.barLabel) \(rounded > 0 ? "+" : "")\(rounded)"
    }

    /// A grudge going *up* is bad news drawn in warning colours; every
    /// other bar reads the ordinary way round.
    private var deltaTint: Color {
        let rising = outcome.delta > 0
        let wantsHigh = target.kind != .rival
        if outcome.delta == 0 { return Theme.pixelInk.opacity(0.6) }
        return rising == wantsHigh ? Theme.positiveCash : Theme.negativeCash
    }

    private var whenText: String {
        let days = engine.state.day - outcome.day
        if days <= 0 { return "Just now" }
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}
