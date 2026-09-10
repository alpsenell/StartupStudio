import SwiftUI

/// Reusable card container with a small section header (title + optional
/// SF Symbol) above arbitrary content.
// Iteration 14 — V3 (weights). The three weights the audit asks for (C11),
// so a tab can say "this one first":
//
// - `.primary` is the card every caller has always had: header, padding,
//   the full type ramp. One per tab (Now, Your week, the desk).
// - `.row` is a 56 pt line on the card surface: an icon, the title, one
//   number (the content) and a chevron. It is something you tap into.
// - `.quiet` is a single secondary line on a lighter surface, for a
//   grouped list of things that are there but not asking for anything.
enum CardWeight: Equatable, Sendable {
    /// Full size, one per tab: Now, Your week, the desk.
    case primary
    /// Title, one number and a chevron, 56 pt.
    case row
    /// A single secondary line in a grouped list.
    case quiet
}

struct CardView<Content: View>: View {
    private let title: String
    private let systemImage: String?
    private let weight: CardWeight
    private let content: Content

    init(
        _ title: String,
        systemImage: String? = nil,
        weight: CardWeight = .primary,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.weight = weight
        self.content = content()
    }

    var body: some View {
        switch weight {
        case .primary:
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                CardHeader(title: title, systemImage: systemImage)
                content
            }
            .cardStyle()
        case .row:
            // The content is the row's one number.
            CardRowLabel(title, systemImage: systemImage) { content }
                .background(
                    Theme.cardBackground,
                    in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                )
        case .quiet:
            CardQuietLine(title, systemImage: systemImage) { content }
        }
    }
}

/// A card's small uppercase name, with its symbol. `.primary` cards draw
/// it above their content; a grouped list (HQ's Company card) draws it
/// above its rows.
struct CardHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(.secondary)
                // A card's own name is never the thing to truncate.
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The `.row` weight's line: icon, title (and an optional one-line
/// subtitle), one number, a chevron; 56 pt tall. Draws no surface of its
/// own, so several can share one (a grouped card) with dividers between.
/// The caller wraps it in the button or link it is.
struct CardRowLabel<Value: View>: View {
    private let title: String
    private let systemImage: String?
    private let subtitle: String?
    private let value: Value

    init(
        _ title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder value: () -> Value
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.value = value()
    }

    /// Where a divider between two rows starts: past the icon column.
    static var dividerInset: CGFloat { Theme.Spacing.lg + 22 + Theme.Spacing.md }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            value
                .font(Theme.Typography.number(.subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The `.quiet` weight: one secondary line, on a lighter, smaller surface,
/// meant to stack tightly with others like it.
struct CardQuietLine<Value: View>: View {
    private let title: String
    private let systemImage: String?
    private let value: Value

    init(_ title: String, systemImage: String? = nil, @ViewBuilder value: () -> Value) {
        self.title = title
        self.systemImage = systemImage
        self.value = value()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(width: 18)
            }
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            value
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(minHeight: 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.cardBackground.opacity(0.55),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius - 6, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
