typealias RGBA = PixelSprite.RGBA

/// The master palette every PixelKit sprite draws from.
///
/// Art direction: eleven hue ramps of five steps each (light → deep) plus the
/// three character ramps (skin, hair, shirt). Nothing in the art packages
/// invents a color — every sprite palette entry is one of these, which is
/// what makes the office, the home, the city and the activity vignettes
/// look like one world. `PaletteTests` enforces it.
///
/// The plan asked for eight ramps; eleven shipped. `gold`, `plum` and
/// `clay` earn their places: without them lamplight and lit windows
/// collapse into `ember`, the lavender and pink accents collapse into
/// `indigo`, and warm concrete has to borrow a cold grey — which is
/// exactly what made the old garage and studio read as morgues.
///
/// Ramp roles:
/// - `ink` — outlines and neutral darks (night walls, shadow, pupils)
/// - `stone` — cool greys: metal, tile, paper, dark screens
/// - `clay` — warm greys: concrete, cardboard, plaster, taupe
/// - `sand` — warm neutrals: wood, cardboard, linen, brick
/// - `gold` — lamplight, lit windows, brass, mustard
/// - `moss` — foliage, felt, chalkboards
/// - `teal` — sea glass, mats, cool accents
/// - `sky` — daylight, glass, water, denim
/// - `indigo` — the brand accent (hoodie, HQ sign, kinship with the UI)
/// - `ember` — warm alerts, terracotta, fire, sunset
/// - `plum` — dusk skies, upholstery, soft accents
enum Palettes {
    /// A five-step hue ramp, index 0 lightest → index 4 deepest.
    struct Ramp: Sendable {
        let name: String
        private let steps: [RGBA]

        init(_ name: String, _ steps: [RGBA]) {
            precondition(steps.count == 5, "every master ramp has five steps")
            self.name = name
            self.steps = steps
        }

        /// The ramp step, clamped into range.
        subscript(index: Int) -> RGBA { steps[min(max(index, 0), steps.count - 1)] }

        var all: [RGBA] { steps }

        /// The step plus the one below it — the (base, shade) pair almost
        /// every sprite wants.
        func pair(_ index: Int) -> (base: RGBA, shade: RGBA) { (self[index], self[index + 1]) }
    }

    // MARK: - The eleven hue ramps

    static let ink = Ramp("ink", [
        RGBA(r: 110, g: 106, b: 124),
        RGBA(r: 86, g: 82, b: 102),
        RGBA(r: 64, g: 60, b: 80),
        RGBA(r: 46, g: 42, b: 60),
        RGBA(r: 32, g: 30, b: 42),
    ])

    static let stone = Ramp("stone", [
        RGBA(r: 238, g: 240, b: 244),
        RGBA(r: 200, g: 204, b: 214),
        RGBA(r: 160, g: 164, b: 178),
        RGBA(r: 118, g: 122, b: 138),
        RGBA(r: 78, g: 82, b: 98),
    ])

    static let sand = Ramp("sand", [
        RGBA(r: 242, g: 226, b: 198),
        RGBA(r: 216, g: 185, b: 138),
        RGBA(r: 172, g: 128, b: 88),
        RGBA(r: 126, g: 90, b: 60),
        RGBA(r: 84, g: 58, b: 40),
    ])

    static let gold = Ramp("gold", [
        RGBA(r: 255, g: 239, b: 192),
        RGBA(r: 255, g: 217, b: 142),
        RGBA(r: 232, g: 180, b: 76),
        RGBA(r: 184, g: 134, b: 46),
        RGBA(r: 122, g: 90, b: 32),
    ])

    /// Warm greys: raw concrete, cardboard, plaster, taupe upholstery.
    /// The ramp that lets the garage read as concrete without turning cold.
    static let clay = Ramp("clay", [
        RGBA(r: 226, g: 216, b: 206),
        RGBA(r: 190, g: 178, b: 166),
        RGBA(r: 150, g: 138, b: 128),
        RGBA(r: 112, g: 100, b: 92),
        RGBA(r: 76, g: 66, b: 60),
    ])

    static let moss = Ramp("moss", [
        RGBA(r: 200, g: 220, b: 186),
        RGBA(r: 146, g: 190, b: 132),
        RGBA(r: 94, g: 154, b: 94),
        RGBA(r: 62, g: 112, b: 72),
        RGBA(r: 40, g: 76, b: 52),
    ])

    static let teal = Ramp("teal", [
        RGBA(r: 190, g: 232, b: 222),
        RGBA(r: 126, g: 208, b: 190),
        RGBA(r: 62, g: 156, b: 138),
        RGBA(r: 42, g: 112, b: 104),
        RGBA(r: 26, g: 74, b: 70),
    ])

    static let sky = Ramp("sky", [
        RGBA(r: 220, g: 238, b: 250),
        RGBA(r: 166, g: 206, b: 236),
        RGBA(r: 110, g: 164, b: 212),
        RGBA(r: 66, g: 122, b: 174),
        RGBA(r: 42, g: 80, b: 120),
    ])

    static let indigo = Ramp("indigo", [
        RGBA(r: 198, g: 200, b: 240),
        RGBA(r: 144, g: 146, b: 222),
        RGBA(r: 94, g: 96, b: 206),
        RGBA(r: 68, g: 70, b: 160),
        RGBA(r: 44, g: 46, b: 104),
    ])

    static let ember = Ramp("ember", [
        RGBA(r: 255, g: 196, b: 154),
        RGBA(r: 240, g: 168, b: 92),
        RGBA(r: 224, g: 120, b: 86),
        RGBA(r: 176, g: 80, b: 62),
        RGBA(r: 116, g: 48, b: 42),
    ])

    static let plum = Ramp("plum", [
        RGBA(r: 240, g: 200, b: 220),
        RGBA(r: 217, g: 140, b: 166),
        RGBA(r: 168, g: 94, b: 144),
        RGBA(r: 110, g: 62, b: 104),
        RGBA(r: 68, g: 40, b: 74),
    ])

    /// Every hue ramp, in art-direction order.
    static let ramps: [Ramp] = [ink, stone, clay, sand, gold, moss, teal, sky, indigo, ember, plum]

    // MARK: - Character ramps

    /// (base, shade) skin pairs, light to deep. Its own ramp: skin has to
    /// stay separable from wood and sand at a glance.
    static let skinTones: [(base: RGBA, shade: RGBA)] = [
        (RGBA(r: 255, g: 219, b: 182), RGBA(r: 233, g: 190, b: 152)),
        (RGBA(r: 240, g: 196, b: 151), RGBA(r: 216, g: 168, b: 124)),
        (RGBA(r: 208, g: 158, b: 110), RGBA(r: 183, g: 132, b: 88)),
        (RGBA(r: 166, g: 112, b: 74), RGBA(r: 140, g: 90, b: 58)),
        (RGBA(r: 118, g: 79, b: 54), RGBA(r: 96, g: 62, b: 42)),
    ]

    /// (base, shade) hair pairs: black, dark brown, chestnut, blonde,
    /// auburn, dyed indigo-grey.
    static let hairColors: [(base: RGBA, shade: RGBA)] = [
        (RGBA(r: 52, g: 48, b: 56), RGBA(r: 38, g: 35, b: 42)),
        (RGBA(r: 92, g: 64, b: 44), RGBA(r: 72, g: 49, b: 34)),
        (RGBA(r: 140, g: 92, b: 52), RGBA(r: 114, g: 73, b: 41)),
        (RGBA(r: 216, g: 180, b: 102), RGBA(r: 190, g: 152, b: 80)),
        (RGBA(r: 156, g: 74, b: 50), RGBA(r: 128, g: 58, b: 39)),
        (RGBA(r: 108, g: 110, b: 150), RGBA(r: 86, g: 88, b: 124)),
    ]

    /// Shirt (base, shade) pairs — each one is literally two neighbouring
    /// steps of a master hue ramp, which is why a crowd of employees reads
    /// as one wardrobe instead of eight unrelated dyes.
    static let shirtColors: [(base: RGBA, shade: RGBA)] = [
        indigo.pair(2),  // indigo
        ember.pair(2),   // coral
        gold.pair(2),    // mustard
        teal.pair(2),    // teal
        ember.pair(3),   // brick red
        plum.pair(1),    // dusty pink
        moss.pair(2),    // olive green
        sky.pair(2),     // slate blue
    ]

    // MARK: - Named fixtures

    /// The universal 1px outline. Everything in PixelKit is outlined in it.
    static let outline = ink[4]
    static let eye = ink[3]
    static let pants = ink[2]
    static let chair = ink[1]
    static let hoodie = indigo[3]
    static let hoodieShade = indigo[4]
    /// Lens glass on the glasses accessory.
    static let lens = sky[0]

    // MARK: - Gate support

    /// Every color the art is allowed to use, hue ramps and character ramps
    /// together. `PaletteTests` checks each sprite palette against it.
    static let master: [RGBA] = {
        var colors = ramps.flatMap(\.all)
        colors += skinTones.flatMap { [$0.base, $0.shade] }
        colors += hairColors.flatMap { [$0.base, $0.shade] }
        colors += shirtColors.flatMap { [$0.base, $0.shade] }
        return colors
    }()

    private static let masterRGB: Set<UInt32> = Set(master.map(rgbKey))

    private static func rgbKey(_ color: RGBA) -> UInt32 {
        (UInt32(color.r) << 16) | (UInt32(color.g) << 8) | UInt32(color.b)
    }

    /// Whether a color is a master color. Alpha is ignored on purpose:
    /// glows, halos and lighting overlays are master hues at reduced
    /// opacity, not new colors.
    static func isMaster(_ color: RGBA) -> Bool { masterRGB.contains(rgbKey(color)) }

    /// Perceived (Rec. 601) luminance, 0…1. Used by the room-contrast gate.
    static func luminance(_ color: RGBA) -> Double {
        (0.299 * Double(color.r) + 0.587 * Double(color.g) + 0.114 * Double(color.b)) / 255
    }

    /// Where a master color sits: which hue ramp, and how far down it.
    /// `nil` for the character ramps (skin, hair, shirts), which are not
    /// part of a five-step hue ladder.
    private static let ladder: [UInt32: (ramp: Int, step: Int)] = {
        var map: [UInt32: (ramp: Int, step: Int)] = [:]
        for (rampIndex, ramp) in ramps.enumerated() {
            for (step, color) in ramp.all.enumerated() {
                map[rgbKey(color), default: (rampIndex, step)] = (rampIndex, step)
            }
        }
        return map
    }()

    /// The same color moved `steps` along its own hue ramp — positive is
    /// deeper, negative is lighter — clamped at both ends of the ramp.
    ///
    /// This is how surface shading has to be done here. `blended` snaps to
    /// the nearest master color, which for a small amount usually rounds
    /// straight back to where it started, so a 20% darkening simply does
    /// not appear. A ramp step always lands somewhere else, and always
    /// somewhere the palette already contains — which is what lets a
    /// lighting pass dither between two adjacent steps instead of inventing
    /// a tone between them.
    ///
    /// Returns the color unchanged if it isn't on a hue ramp (a person's
    /// skin or shirt), so a lighting pass never recolors somebody.
    static func stepped(_ color: RGBA, by steps: Int) -> RGBA {
        guard steps != 0, let at = ladder[rgbKey(color)] else { return color }
        var moved = ramps[at.ramp][at.step + steps]
        moved.a = color.a
        return moved
    }

    /// A master color darkened toward `ink[4]` by `amount` (0…1), snapped
    /// back onto the nearest master color so depth shading never leaves the
    /// palette. Used for floor depth bands and night tints.
    static func shaded(_ color: RGBA, by amount: Double) -> RGBA {
        blended(color, toward: ink[4], amount: amount)
    }

    /// `color` mixed `amount` of the way toward `target`, snapped back onto
    /// the nearest master color. Alpha follows `color`.
    static func blended(_ color: RGBA, toward target: RGBA, amount: Double) -> RGBA {
        let t = min(max(amount, 0), 1)
        return nearestMaster(RGBA(
            r: UInt8((Double(color.r) * (1 - t) + Double(target.r) * t).rounded()),
            g: UInt8((Double(color.g) * (1 - t) + Double(target.g) * t).rounded()),
            b: UInt8((Double(color.b) * (1 - t) + Double(target.b) * t).rounded()),
            a: color.a
        ))
    }

    /// The master color closest to `color` in RGB space, keeping alpha.
    static func nearestMaster(_ color: RGBA) -> RGBA {
        var best = master[0]
        var bestDistance = Int.max
        for candidate in master {
            let dr = Int(candidate.r) - Int(color.r)
            let dg = Int(candidate.g) - Int(color.g)
            let db = Int(candidate.b) - Int(color.b)
            let distance = dr * dr + dg * dg + db * db
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return RGBA(r: best.r, g: best.g, b: best.b, a: color.a)
    }

    /// A master color at reduced opacity — the only sanctioned way to make
    /// a glow, halo or tint.
    static func translucent(_ color: RGBA, _ alpha: UInt8) -> RGBA {
        RGBA(r: color.r, g: color.g, b: color.b, a: alpha)
    }
}

/// Small grid utilities for composing authored pixel art.
enum PixelGrid {
    /// Lays `top` over `base` (top-left aligned, optionally shifted down by
    /// `offsetY`). Space pixels in the overlay keep the base pixel; anything
    /// else replaces it.
    static func overlay(base: [String], top: [String], offsetY: Int = 0) -> [String] {
        overlay(base: base, top: top, offsetX: 0, offsetY: offsetY)
    }

    /// `overlay` with a horizontal shift as well, for accessories that sit
    /// off-center (a mug in a raised hand, a clipboard at the hip).
    static func overlay(base: [String], top: [String], offsetX: Int, offsetY: Int) -> [String] {
        var out = base
        for (sourceY, row) in top.enumerated() {
            let y = sourceY + offsetY
            guard (0..<out.count).contains(y) else { continue }
            var chars = Array(out[y])
            for (x, ch) in row.enumerated() where ch != " " {
                let px = x + offsetX
                if (0..<chars.count).contains(px) { chars[px] = ch }
            }
            out[y] = String(chars)
        }
        return out
    }

    /// A blank grid of the given size.
    static func blank(width: Int, height: Int) -> [String] {
        Array(repeating: String(repeating: " ", count: width), count: height)
    }
}
