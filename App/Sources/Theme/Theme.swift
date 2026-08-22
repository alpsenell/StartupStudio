import SwiftUI
import UIKit

/// Central design tokens for Startup Studio.
/// All colors are semantic or asset-backed so every screen works in both
/// light and dark mode — never hardcode `.white`/`.black` backgrounds.
enum Theme {
    // MARK: - Colors

    /// Brand accent (indigo/violet), defined in the asset catalog with
    /// light and dark variants.
    static let accent = Color("AccentColor")

    /// Positive cash flow / healthy values.
    static let positiveCash = Color(uiColor: .systemGreen)

    /// Negative cash / danger.
    static let negativeCash = Color(uiColor: .systemRed)

    /// Warnings (low runway, bankruptcy warnings, ...).
    static let warning = Color(uiColor: .systemOrange)

    /// Card surface on top of the grouped screen background.
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

    /// Screen background behind cards.
    static let screenBackground = Color(uiColor: .systemGroupedBackground)

    /// Subtle fill for chips, pills, and segmented tracks.
    static let chipBackground = Color(uiColor: .tertiarySystemFill)

    // MARK: - Development phases

    /// Design phase (progress bars, focus editor).
    static let designPhase = Color(uiColor: .systemPurple)

    /// Code phase.
    static let codePhase = Color(uiColor: .systemBlue)

    /// Polish phase.
    static let polishPhase = Color(uiColor: .systemTeal)

    /// Tint for a 0–100 review/quality score band:
    /// green at 80+, warning at 60+, red below.
    static func scoreTint(_ score: Int) -> Color {
        if score >= 80 {
            positiveCash
        } else if score >= 60 {
            warning
        } else {
            negativeCash
        }
    }

    // MARK: - Metrics

    /// Corner radius shared by all cards.
    static let cornerRadius: CGFloat = 16

    /// Spacing scale. Prefer these over ad-hoc values.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

// MARK: - Card style

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
    }
}

extension View {
    /// The shared card container look: padded content on a rounded surface.
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Money formatting

extension Int {
    /// Formats an amount of whole dollars: `12400` -> `"$12,400"`,
    /// `-1200` -> `"-$1,200"`.
    var money: String {
        let sign = self < 0 ? "-" : ""
        let digits = String(self.magnitude)
        var grouped = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset != 0, offset.isMultiple(of: 3) {
                grouped.append(",")
            }
            grouped.append(character)
        }
        return sign + "$" + String(grouped.reversed())
    }
}
