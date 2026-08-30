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

    // MARK: - Pixel chrome

    // The pixel tokens are hardcoded hex values taken from PixelKit's
    // master palette (the office outline, the loft wall cream, and the
    // indigo shirt ramp) so the chrome and the scene share one world.
    // They are deliberately literal rather than asset-backed: the pixel
    // face must land on exactly these colors in both appearances, and each
    // token carries its own light/dark pair below.

    /// Ink for pixel glyphs and 9-slice borders — PixelKit's sprite
    /// outline (32, 30, 42) in light mode, its paper tone in dark.
    static let pixelInk = dynamic(
        light: (r: 32, g: 30, b: 42),
        dark: (r: 226, g: 224, b: 236)
    )

    /// Paper behind a pixel panel — the loft's warm cream, deepened in
    /// dark mode so the panel still reads as a lit surface.
    static let pixelPaper = dynamic(
        light: (r: 244, g: 238, b: 226),
        dark: (r: 40, g: 38, b: 52)
    )

    /// The indigo the founder's hoodie and the accent shirt ramp share.
    static let pixelAccent = dynamic(
        light: (r: 78, g: 74, b: 168),
        dark: (r: 142, g: 138, b: 232)
    )

    /// The 1-pixel drop shadow the scene puts under every sprite.
    static let pixelShadow = dynamic(
        light: (r: 32, g: 30, b: 42, a: 0.28),
        dark: (r: 0, g: 0, b: 0, a: 0.5)
    )

    /// Builds a `Color` that resolves per appearance. Used only for the
    /// pixel tokens, whose exact values come from the sprite palette.
    private static func dynamic(
        light: (r: Int, g: Int, b: Int, a: Double) ,
        dark: (r: Int, g: Int, b: Int, a: Double)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let pick = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(pick.r) / 255,
                green: CGFloat(pick.g) / 255,
                blue: CGFloat(pick.b) / 255,
                alpha: CGFloat(pick.a)
            )
        })
    }

    private static func dynamic(
        light: (r: Int, g: Int, b: Int),
        dark: (r: Int, g: Int, b: Int)
    ) -> Color {
        dynamic(
            light: (light.r, light.g, light.b, 1.0),
            dark: (dark.r, dark.g, dark.b, 1.0)
        )
    }

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
