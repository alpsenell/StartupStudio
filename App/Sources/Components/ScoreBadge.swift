import SwiftUI

/// Small rounded badge for a 0–100 review/quality score, filled with the
/// score's band color (green / warning / red).
struct ScoreBadge: View {
    let score: Int

    var body: some View {
        let tint = Theme.scoreTint(score)
        Text("\(score)")
            .font(Theme.Typography.number(.subheadline, weight: .bold))
            // White on the warning-orange band is under 3:1 — the one
            // thing this badge exists to do is be read, so the ink is
            // picked from the fill it is sitting on.
            .foregroundStyle(Theme.ink(on: tint))
            .contentTransition(.numericText())
            .frame(minWidth: 30)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, Theme.Spacing.xs)
            .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            // A score crossing a band changes both the digits and the
            // fill; without this it is two jumps in the same frame.
            .animation(Theme.Motion.valueChange, value: score)
            .accessibilityLabel("Score \(score) out of 100")
    }
}
