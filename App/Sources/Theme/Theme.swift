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

    /// The locale every in-game figure is formatted with. Money is the
    /// game's currency, not the player's, and `Int.money` hard-codes its
    /// separators; anything that goes through `.formatted(...)` should pass
    /// this so "$5,100" and "×0.93" agree on what a comma means. Iteration 4
    /// seam — adopted site by site.
    static let gameLocale = Locale(identifier: "en_US_POSIX")

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

    /// Readable ink for a label sitting on a filled `tint` — a selected
    /// pill, a score badge, a speed button.
    ///
    /// The app assumed white at six call sites, and on one of them that is
    /// wrong: white on the warning orange of a mid-band score is under 3:1,
    /// and being read is the one thing a score badge exists to do. So the
    /// ink is chosen from the fill's own perceived luminance instead. Both
    /// inks are fixed rather than semantic — they have to stay correct
    /// against the tint, which does not change with the appearance.
    static func ink(on tint: Color) -> Color {
        // Resolve in light mode: a dynamic tint's two variants are the same
        // hue at different depths, so either one picks the same ink, and
        // this way the choice does not flip when the player switches theme.
        let resolved = UIColor(tint)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        // Rec. 601 luma, the same measure the pixel palette's own gate uses.
        let luma = 0.299 * red + 0.587 * green + 0.114 * blue
        return luma > 0.62 ? onLightTint : onTint
    }

    /// White, for a label on a tint dark enough to carry it.
    static let onTint = Color.white

    /// The sprite outline ink, for a label on a light tint (the warning
    /// band, gold, sand).
    static let onLightTint = Color(red: 32 / 255, green: 30 / 255, blue: 42 / 255)

    /// Romance: the partner card, affection meters, a date night. Was
    /// `Color(uiColor: .systemPink)` copy-pasted at three call sites.
    static let romance = Color(uiColor: .systemPink)

    /// The one drop shadow the chrome casts, under a toast or a floating
    /// panel. Two different hand-rolled recipes existed before this.
    static let shadow = Color.black.opacity(0.12)

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

// MARK: - Motion

extension Theme {
    /// The app's whole motion vocabulary: four durations, and one curve per
    /// *job* rather than one per call site.
    ///
    /// Before this there were eleven ad-hoc timings and `.spring` was the
    /// default for everything, including fades and number changes — which is
    /// why a cash figure used to wobble. A spring models mass, so it belongs
    /// only where something moves as an object: a sheet arriving, a pill the
    /// thumb just pushed, a toast landing. A meter filling or a digit
    /// re-rolling has no mass, and reads as a mistake when it overshoots.
    ///
    /// Every token is `Animation?` so it can be handed to both
    /// `.animation(_:value:)` and `withAnimation(_:_:)`, and so reduced
    /// motion can flatten it to `nil` — no animation at all — rather than a
    /// fast one.
    ///
    /// The reduced-motion flag is read from `UIAccessibility` rather than
    /// the SwiftUI environment because the acknowledgement layer
    /// (`ToastCenter`) animates from outside any view. It is the same trait
    /// `\.accessibilityReduceMotion` is derived from; the tokens are
    /// computed properties, so a change to the setting is picked up by the
    /// next animated change rather than needing the view tree rebuilt.
    enum Motion {
        /// Whether the player has asked the system for less movement.
        ///
        /// `MainActor.assumeIsolated` rather than an `await`: every caller
        /// is a `body` or a `withAnimation`, both of which are already on
        /// the main actor, and a motion token has to be readable inline.
        static var isReduced: Bool {
            MainActor.assumeIsolated { UIAccessibility.isReduceMotionEnabled }
        }

        // MARK: Durations

        /// Press feedback and chip swaps — under two frames of thought.
        static let quick: TimeInterval = 0.18
        /// The default: anything appearing, dismissing or re-laying out.
        static let standard: TimeInterval = 0.26
        /// Values settling — long enough that the eye follows the digits.
        static let value: TimeInterval = 0.32
        /// A sheet or a phase change: the only tier allowed to feel weighty.
        static let emphasized: TimeInterval = 0.42

        // MARK: Curves

        /// Something arriving. Ease-out: fast in, settles — never overshoots
        /// into content the player is already reading.
        static var entrance: Animation? { isReduced ? nil : .easeOut(duration: standard) }

        /// Something leaving. Quicker than its entrance and ease-in, because
        /// a dismissal the player asked for should not be a performance.
        static var exit: Animation? { isReduced ? nil : .easeIn(duration: quick) }

        /// A number, meter or progress bar changing. Ease-out, no bounce:
        /// the reading is the point, not the motion.
        static var valueChange: Animation? { isReduced ? nil : .easeOut(duration: value) }

        /// A control the thumb just moved — a segment pill, a toggle, a
        /// speed button. A short spring, because the player's own touch is
        /// the force and the response should feel physical.
        static var selection: Animation? { isReduced ? nil : .spring(duration: quick + 0.06) }

        /// Something with real mass arriving: a toast landing, a banner
        /// dropping in, a card expanding.
        static var weighted: Animation? { isReduced ? nil : .spring(duration: standard) }

        /// A moment the game wants the player to notice — a launch, a
        /// chapter opening, a phase completing.
        static var emphatic: Animation? {
            isReduced ? nil : .spring(duration: emphasized, bounce: 0.2)
        }

        /// Replaces a movement transition with a plain fade when the player
        /// has asked for reduced motion. Content still arrives and leaves —
        /// it just stops flying.
        static func transition(_ full: AnyTransition) -> AnyTransition {
            isReduced ? .opacity : full
        }
    }
}

// MARK: - Typography

extension Theme {
    /// The one type role the app was getting wrong in 24 different ways.
    ///
    /// Deliberately not a full scale: the screens' text sizes were already
    /// coherent, and a token per role that nobody reaches for is worse than
    /// no token. The size stays Dynamic Type-relative (`.system(.footnote,
    /// ...)`, never a fixed point size), and stays whatever the call site
    /// already chose — this fixes the *face*, not the hierarchy.
    ///
    /// The rule the app was missing: **a number the player reads is rounded
    /// and monospaced-digit; a word is not.** Rounded digits are the
    /// friendlier, more tabular face, and monospaced digits stop a figure
    /// jittering sideways as it counts — which matters here because almost
    /// every number on screen changes every game day.
    enum Typography {
        /// A figure the player reads and compares — cash, counts, scores,
        /// percentages. Always monospaced so it never shifts as it ticks.
        static func number(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
            .system(style, design: .rounded).weight(weight).monospacedDigit()
        }
    }
}

// MARK: - Press feedback

/// The press response for the app's custom-drawn controls: a small inward
/// scale and a dim, released with the same ease-out everything else uses.
///
/// `.buttonStyle(.plain)` gives a button *no* feedback at all — no
/// highlight, no dim, nothing. Most of this game's controls are drawn
/// rather than system-supplied (a roster row, an amenity tile, a district
/// on the map, a candidate card), so before this a third of the taps in
/// the game landed on something that never acknowledged the thumb. The
/// haptic fired and the screen sat still.
///
/// Under reduced motion the scale is dropped and only the dim remains: the
/// acknowledgement survives, the movement doesn't.
struct PressableButtonStyle: ButtonStyle {
    /// How far the control pulls in under the thumb. Large surfaces want
    /// less — a full-width row shrinking by 3% reads as the list glitching.
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .scaleEffect(pressed && !Theme.Motion.isReduced ? scale : 1)
            .opacity(pressed ? 0.72 : 1)
            .animation(Theme.Motion.exit, value: pressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Press feedback for a drawn control: chip, tile, pill, small card.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }

    /// Press feedback for a full-width row or a large card, which needs a
    /// gentler scale than a chip does to avoid reading as a layout jump.
    static var pressableRow: PressableButtonStyle { PressableButtonStyle(scale: 0.99) }
}
