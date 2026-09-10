import SwiftUI

/// Reusable card container with a small section header (title + optional
/// SF Symbol) above arbitrary content.
// Iteration 14 — V3 (weights). The three weights the audit asks for. The
// scaffold declares the contract so V1 and V2 can ask for `.row` and
// `.quiet` from day one; V3 gives the two new cases their look. Until
// then every weight renders as `.primary`, which is what every existing
// caller gets by default.
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
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
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
            content
        }
        .cardStyle()
    }
}
