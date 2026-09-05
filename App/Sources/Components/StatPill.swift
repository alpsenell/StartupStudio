import SwiftUI

/// Small labeled stat chip: an SF Symbol plus a value, on a capsule fill.
/// Used in the HUD and inside cards. Value changes animate with a numeric
/// text transition.
struct StatPill: View {
    let systemImage: String
    let value: String
    var tint: Color = .primary

    /// A pill is a figure on one line — until the reader's text is big
    /// enough that one line is three characters and an ellipsis, at which
    /// point the figure matters more than the shape.
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(Theme.Typography.number(.subheadline))
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.xs + 1)
        .background(Theme.chipBackground, in: Capsule())
        .animation(Theme.Motion.valueChange, value: value)
        .accessibilityElement(children: .combine)
    }
}
