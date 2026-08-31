import SwiftUI

/// The card a section shows when it has nothing in it.
///
/// The app had two ways of saying "nothing here": `ContentUnavailableView`
/// on the eight screens that go full-bleed when empty, and — everywhere
/// else — a bare grey sentence on a card. The bare sentence has no anchor,
/// so on a screen of six cards the empty one reads as a card that failed to
/// load rather than as a section with nothing in it yet.
///
/// This gives the sentence a symbol to sit against, in the section's own
/// tint, and a second line for the thing the player can actually do about
/// it. It stays deliberately quiet — an empty state is a signpost, not a
/// hero — and it keeps `cardStyle()` so it lines up with the cards around
/// it instead of introducing a fourth surface.
struct EmptyStateCard: View {
    /// What is empty, in a sentence.
    let message: String
    /// The symbol for the *section*, not a generic "nothing" glyph: an
    /// empty contracts card should still look like contracts.
    var systemImage: String = "tray"
    /// What the player can do next, if there is something. One short line.
    var hint: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        EmptyStateCard(
            message: "No active contracts — accept an offer to get to work.",
            systemImage: "briefcase",
            hint: "New clients call every week.",
            tint: Theme.accent
        )
        EmptyStateCard(message: "Nothing posted yet.", systemImage: "list.bullet.rectangle")
    }
    .padding()
    .background(Theme.screenBackground)
}

// MARK: - Empty text inside a card

private struct EmptySectionText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Spacing.sm)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// The "nothing here yet" line *inside* a `CardView`.
    ///
    /// These do not get an `EmptyStateCard`: the card header above them is
    /// already a symbol and a title, and a second icon two lines under it
    /// reads as a broken layout. What they were missing is each other —
    /// fourteen of them had drifted into four fonts and three colours, so
    /// an empty Reviews card and an empty Ledger card did not look like the
    /// same kind of nothing. This is that one treatment.
    func emptySectionText() -> some View {
        modifier(EmptySectionText())
    }
}
