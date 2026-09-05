import SwiftUI

/// Reusable card container with a small section header (title + optional
/// SF Symbol) above arbitrary content.
struct CardView<Content: View>: View {
    private let title: String
    private let systemImage: String?
    private let content: Content

    init(
        _ title: String,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
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
