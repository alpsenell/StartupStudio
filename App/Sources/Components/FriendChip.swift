import SwiftUI

/// Tiny "friends with" capsule: mini portrait + first name, tinted by how
/// strong the bond is.
struct FriendChip: View {
    let name: String
    let seed: UInt64
    /// 0...100 bond strength.
    let strength: Double

    private var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var body: some View {
        HStack(spacing: 4) {
            PixelPortrait(seed: seed, size: 20)
            Text(firstName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Image(systemName: strength >= 60 ? "heart.fill" : "heart")
                .font(.system(size: 8))
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, Theme.Spacing.xs + 2)
        .padding(.vertical, 2)
        .background(Theme.chipBackground, in: Capsule())
        .accessibilityLabel("Friends with \(name)")
    }
}
