import SwiftUI

/// Small labeled stat chip: an SF Symbol plus a value, on a capsule fill.
/// Used in the HUD and inside cards. Value changes animate with a numeric
/// text transition.
struct StatPill: View {
    let systemImage: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.xs + 1)
        .background(Theme.chipBackground, in: Capsule())
        .animation(.spring(duration: 0.35), value: value)
        .accessibilityElement(children: .combine)
    }
}
