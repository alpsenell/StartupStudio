import SwiftUI

/// Small rounded badge for a 0–100 review/quality score, filled with the
/// score's band color (green / warning / red).
struct ScoreBadge: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(minWidth: 30)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                Theme.scoreTint(score),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityLabel("Score \(score) out of 100")
    }
}
