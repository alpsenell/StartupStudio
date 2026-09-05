import SwiftUI

/// A 5×7 bitmap font, authored as pixel rows exactly like PixelKit's
/// sprites, so the chrome (HUD cash, dates, card titles) is drawn from the
/// same material as the office scene instead of a rounded system face.
///
/// Glyphs are 5 px wide, 7 px tall, with one column of tracking between
/// them. Lowercase input is folded to uppercase — the font is a display
/// face for short labels, never for body copy (body text stays SF with
/// Dynamic Type).
enum PixelFont {
    /// Glyph cell width in pixels, excluding tracking.
    static let glyphWidth = 5
    /// Glyph cell height in pixels.
    static let glyphHeight = 7
    /// Blank columns inserted between glyphs.
    static let tracking = 1

    /// Pixel rows for one glyph: 7 strings of 5 characters, `#` = ink.
    typealias Glyph = [String]

    /// Every glyph the font can draw. Anything else renders as `missing`.
    static let glyphs: [Character: Glyph] = {
        var table: [Character: Glyph] = [:]
        for (character, rows) in rawGlyphs {
            table[character] = rows
        }
        return table
    }()

    /// Drawn for characters outside the table: a hollow box, so a missing
    /// glyph is visible in review rather than silently swallowed.
    static let missing: Glyph = [
        "#####",
        "#   #",
        "#   #",
        "#   #",
        "#   #",
        "#   #",
        "#####",
    ]

    /// The glyph for `character`, folding lowercase to uppercase.
    static func glyph(for character: Character) -> Glyph {
        if let exact = glyphs[character] { return exact }
        let upper = Character(String(character).uppercased())
        return glyphs[upper] ?? missing
    }

    /// Whether the font has a real (non-fallback) glyph for `character`.
    static func hasGlyph(for character: Character) -> Bool {
        glyphs[character] != nil
            || glyphs[Character(String(character).uppercased())] != nil
    }

    /// Whether every character of `string` has a real glyph — the test a
    /// label from outside the game (a store price: "€4,99", "4,99 €",
    /// a non-breaking space) must pass before it is drawn in the face,
    /// or the customer sees hollow boxes. An empty string draws nothing
    /// and passes.
    static func canDraw(_ string: String) -> Bool {
        string.allSatisfy(hasGlyph(for:))
    }

    /// Width in pixels of `string` at scale 1, including tracking between
    /// glyphs but not after the last one.
    static func width(of string: String) -> Int {
        guard !string.isEmpty else { return 0 }
        let count = string.count
        return count * glyphWidth + (count - 1) * tracking
    }

    /// The ink rectangles (in glyph-space pixels) for `string`, ready to be
    /// scaled and filled. Runs of set pixels on a row are merged into one
    /// rect so a label costs a few dozen fills rather than a few hundred.
    static func pixelRuns(of string: String) -> [(x: Int, y: Int, width: Int)] {
        var runs: [(x: Int, y: Int, width: Int)] = []
        var originX = 0
        for character in string {
            let rows = glyph(for: character)
            for (y, row) in rows.enumerated() {
                var runStart: Int?
                for (x, pixel) in row.enumerated() {
                    if pixel == "#" {
                        if runStart == nil { runStart = x }
                    } else if let start = runStart {
                        runs.append((originX + start, y, x - start))
                        runStart = nil
                    }
                }
                if let start = runStart {
                    runs.append((originX + start, y, row.count - start))
                }
            }
            originX += glyphWidth + tracking
        }
        return runs
    }

    // MARK: - Glyph data

    // swiftlint:disable:next large_tuple
    private static let rawGlyphs: [(Character, Glyph)] = [
        ("A", ["  #  ", " # # ", "#   #", "#   #", "#####", "#   #", "#   #"]),
        ("B", ["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "]),
        ("C", [" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "]),
        ("D", ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "]),
        ("E", ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"]),
        ("F", ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "]),
        ("G", [" ### ", "#   #", "#    ", "#  ##", "#   #", "#   #", " ####"]),
        ("H", ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"]),
        ("I", [" ### ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "]),
        ("J", ["   ##", "    #", "    #", "    #", "    #", "#   #", " ### "]),
        ("K", ["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"]),
        ("L", ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"]),
        ("M", ["#   #", "## ##", "# # #", "#   #", "#   #", "#   #", "#   #"]),
        ("N", ["#   #", "##  #", "# # #", "#  ##", "#   #", "#   #", "#   #"]),
        ("O", [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "]),
        ("P", ["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "]),
        ("Q", [" ### ", "#   #", "#   #", "#   #", "# # #", "#  # ", " ## #"]),
        ("R", ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"]),
        ("S", [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "]),
        ("T", ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "]),
        ("U", ["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "]),
        ("V", ["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "]),
        ("W", ["#   #", "#   #", "#   #", "#   #", "# # #", "## ##", "#   #"]),
        ("X", ["#   #", "#   #", " # # ", "  #  ", " # # ", "#   #", "#   #"]),
        ("Y", ["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "]),
        ("Z", ["#####", "    #", "   # ", "  #  ", " #   ", "#    ", "#####"]),
        ("0", [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "]),
        ("1", ["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "]),
        ("2", [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"]),
        ("3", ["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "]),
        ("4", ["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "]),
        ("5", ["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "]),
        ("6", ["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "]),
        ("7", ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "]),
        ("8", [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "]),
        ("9", [" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "]),
        (" ", ["     ", "     ", "     ", "     ", "     ", "     ", "     "]),
        ("$", ["  #  ", " ####", "# #  ", " ### ", "  # #", "#### ", "  #  "]),
        (".", ["     ", "     ", "     ", "     ", "     ", " ##  ", " ##  "]),
        (",", ["     ", "     ", "     ", "     ", " ##  ", " ##  ", " #   "]),
        (":", ["     ", " ##  ", " ##  ", "     ", " ##  ", " ##  ", "     "]),
        ("-", ["     ", "     ", "     ", "#### ", "     ", "     ", "     "]),
        ("+", ["     ", "  #  ", "  #  ", "#####", "  #  ", "  #  ", "     "]),
        ("/", ["    #", "    #", "   # ", "  #  ", " #   ", "#    ", "#    "]),
        ("!", ["  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "     ", "  #  "]),
        ("?", [" ### ", "#   #", "    #", "   # ", "  #  ", "     ", "  #  "]),
        ("'", ["  #  ", "  #  ", "     ", "     ", "     ", "     ", "     "]),
        ("%", ["##  #", "##  #", "   # ", "  #  ", " #   ", "#  ##", "#  ##"]),
        ("(", ["   # ", "  #  ", " #   ", " #   ", " #   ", "  #  ", "   # "]),
        (")", [" #   ", "  #  ", "   # ", "   # ", "   # ", "  #  ", " #   "]),
        ("×", ["     ", "#   #", " # # ", "  #  ", " # # ", "#   #", "     "]),
        ("·", ["     ", "     ", "     ", " ##  ", " ##  ", "     ", "     "]),
        ("▶", ["#    ", "##   ", "###  ", "#### ", "###  ", "##   ", "#    "]),
        ("♥", ["     ", " # # ", "#####", "#####", " ### ", "  #  ", "     "]),
        ("★", ["  #  ", "  #  ", "#####", " ### ", " # # ", "#   #", "     "]),
    ]
}

/// Draws a short string in the game's 5×7 bitmap face.
///
/// Use it for numbers, dates, and small caps titles in the chrome. It is a
/// display face: it ignores Dynamic Type by design (the pixels must stay on
/// a whole-pixel grid), so it is always paired with an accessibility label
/// carrying the same text for VoiceOver.
struct PixelText: View {
    /// The text to draw. Lowercase is folded to uppercase.
    let text: String
    /// Pixels per glyph pixel. 2 for captions, 3 for headline numbers.
    var scale: CGFloat = 2
    /// Ink color; defaults to the theme's pixel ink.
    var color: Color = Theme.pixelInk
    /// Draws a 1-pixel drop shadow under the glyphs, as the office sprites
    /// have, so the label sits on the panel instead of floating on it.
    /// Ignored above scale 2, where a whole-pixel offset stops reading as
    /// a shadow and starts reading as a second, ghosted copy of the text.
    var shadow: Bool = false

    private var drawsShadow: Bool { shadow && scale <= 2 }

    private var displayText: String { text.uppercased() }

    var body: some View {
        let runs = PixelFont.pixelRuns(of: displayText)
        let pixelWidth = CGFloat(PixelFont.width(of: displayText))
        let pixelHeight = CGFloat(PixelFont.glyphHeight) + (drawsShadow ? 1 : 0)
        Canvas(rendersAsynchronously: false) { context, _ in
            if drawsShadow {
                for run in runs {
                    context.fill(
                        Path(rect(for: run, scale: scale, offsetX: 1, offsetY: 1)),
                        with: .color(Theme.pixelShadow)
                    )
                }
            }
            for run in runs {
                context.fill(
                    Path(rect(for: run, scale: scale, offsetX: 0, offsetY: 0)),
                    with: .color(color)
                )
            }
        }
        .frame(width: (pixelWidth + (drawsShadow ? 1 : 0)) * scale, height: pixelHeight * scale)
        .accessibilityLabel(text)
    }

    private func rect(
        for run: (x: Int, y: Int, width: Int),
        scale: CGFloat,
        offsetX: Int,
        offsetY: Int
    ) -> CGRect {
        CGRect(
            x: CGFloat(run.x + offsetX) * scale,
            y: CGFloat(run.y + offsetY) * scale,
            width: CGFloat(run.width) * scale,
            height: scale
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        PixelText(text: "$12,400", scale: 3, color: Theme.pixelAccent, shadow: true)
        PixelText(text: "Mar W2 · Y1", scale: 2)
        PixelText(text: "Launch Day!", scale: 2, color: Theme.positiveCash)
    }
    .padding()
}
