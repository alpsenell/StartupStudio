import Foundation

// MARK: Iteration 18 — the studio mark

/// A studio's generated pixel glyph: a 16×16 mark built deterministically
/// from a `UInt64` seed, in two master-palette ramps.
///
/// The grammar is three shapes and nothing else — a **field** (the
/// silhouette the eye reads first), a **figure** punched through it, and a
/// **notch** on one corner — because the whole job of a mark is to be
/// told apart from its neighbours at 16 px on a box-art corner. Twelve
/// fields × fourteen figures × four notches × sixteen ramp pairs is the
/// space; the fields carry the silhouette, the figures carry the inside,
/// and the ramp pair carries the colour, so two marks have to lose all
/// three to collide.
///
/// Colour comes only from `Palettes` (`PaletteTests` gates that), and the
/// pairs are chosen for contrast: every one is a deep step under a light
/// step, at least 0.3 apart in perceived luminance, so the figure reads
/// at any size and in either appearance.
///
/// Nothing in here draws unless somebody hands it a seed. A company with
/// no `markSeed` renders exactly the game it always rendered.
public enum StudioMarkBuilder {
    /// Every mark is square and this wide. Small on purpose: the corner of
    /// a box art and the masthead's byline are the sizes that matter.
    public static let size = 16

    /// The mark for `seed`.
    public static func sprite(seed: UInt64) -> PixelSprite {
        SpriteCache.shared("studioMark.\(seed)") { build(recipe(for: seed)) }
    }

    /// The mark reduced to `side` pixels a side, by nearest-neighbour
    /// sampling of the same masks — for the plates too small to carry the
    /// whole glyph, like the sign band on the city map's HQ. Below about
    /// five pixels only the field's silhouette and the two inks survive,
    /// which is still the thing that finds your building on the map.
    public static func sprite(seed: UInt64, side: Int) -> PixelSprite {
        guard side < size else { return sprite(seed: seed) }
        return SpriteCache.shared("studioMark.\(seed).\(side)") { reduce(recipe(for: seed), to: max(1, side)) }
    }

    /// A rival's mark: derived from its name, so it costs no state and two
    /// runs that meet the same studio see the same glyph.
    public static func sprite(forName name: String) -> PixelSprite {
        sprite(seed: seed(forName: name))
    }

    /// The seed a name folds down to (FNV-1a, then mixed), so "Ironwood"
    /// is always the same mark.
    public static func seed(forName name: String) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in name.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01B3
        }
        return mix(value)
    }

    /// The three comps the naming step offers on shuffle `shuffle` of a
    /// run seeded `runSeed`.
    ///
    /// Pure arithmetic on the two numbers — it draws from no generator the
    /// simulation owns, so shuffling the picker cannot move a single die
    /// in the game that follows.
    public static func comps(runSeed: UInt64, shuffle: Int) -> [UInt64] {
        let base = mix(runSeed &+ 0x5744_444C_4500 &+ UInt64(bitPattern: Int64(shuffle)) &* 0x9E37_79B9_7F4A_7C15)
        return (0..<3).map { mix(base &+ UInt64($0) &* 0xD129_2B5F) }
    }

    // MARK: - The grammar

    /// What a seed spells out.
    struct Recipe: Equatable {
        var field: Field
        var figure: Figure
        var notch: Notch
        var ramp: RampPair
        /// Whether the figure is drawn in the light ink or the deep one —
        /// a mark and its inverse read as two different marks.
        var inverted: Bool
    }

    /// The silhouette. Twelve of them, chosen so no two share an outline
    /// at 16 px: the sheet check is what grew this list from five.
    enum Field: Int, CaseIterable {
        case block, disc, shield, diamond, hexagon, arch, banner, chevronPlate
        case ring, tower, wedge, cross
    }

    /// What is punched through the field. Fourteen, each a shape rather
    /// than a letter — a mark is not a monogram.
    enum Figure: Int, CaseIterable {
        case bolt, bar, bars, dot, ring, slash, cross, arrow
        case stair, split, crescent, spark, brick, notchOut
    }

    /// The corner bitten out of the field, which is most of what separates
    /// two marks that share a field.
    enum Notch: Int, CaseIterable {
        case none, topLeft, bottomRight, bothTop
    }

    /// A deep ink and a light one. Both master colours; the pair always
    /// clears 0.3 of perceived luminance, which is what the "same smudge
    /// at 16 px" failure comes down to.
    struct RampPair: Equatable {
        var deep: RGBA
        var light: RGBA
    }

    /// The sixteen sanctioned pairs. Every colour is a `Palettes` step —
    /// nothing here invents one — and every pair is a hue's own deep step
    /// under a light step, so a mark looks like it belongs to this world.
    static let rampPairs: [RampPair] = [
        RampPair(deep: Palettes.indigo[4], light: Palettes.indigo[0]),
        RampPair(deep: Palettes.indigo[3], light: Palettes.gold[0]),
        RampPair(deep: Palettes.ember[4], light: Palettes.ember[0]),
        RampPair(deep: Palettes.ember[3], light: Palettes.sand[0]),
        RampPair(deep: Palettes.teal[4], light: Palettes.teal[0]),
        RampPair(deep: Palettes.teal[3], light: Palettes.stone[0]),
        RampPair(deep: Palettes.moss[4], light: Palettes.moss[0]),
        RampPair(deep: Palettes.moss[3], light: Palettes.gold[0]),
        RampPair(deep: Palettes.plum[4], light: Palettes.plum[0]),
        RampPair(deep: Palettes.plum[3], light: Palettes.sky[0]),
        RampPair(deep: Palettes.sky[4], light: Palettes.sky[0]),
        RampPair(deep: Palettes.sky[3], light: Palettes.stone[0]),
        RampPair(deep: Palettes.gold[4], light: Palettes.gold[0]),
        RampPair(deep: Palettes.sand[4], light: Palettes.sand[0]),
        RampPair(deep: Palettes.ink[4], light: Palettes.stone[0]),
        RampPair(deep: Palettes.ink[3], light: Palettes.teal[0]),
    ]

    /// The recipe a seed spells. Each choice takes its own slice of the
    /// mixed word, so neighbouring seeds do not land on neighbouring
    /// marks.
    static func recipe(for seed: UInt64) -> Recipe {
        let word = mix(seed)
        func slice(_ shift: UInt64, _ count: Int) -> Int {
            Int((word >> shift) & 0xFFFF) % max(1, count)
        }
        return Recipe(
            field: Field(rawValue: slice(0, Field.allCases.count)) ?? .block,
            figure: Figure(rawValue: slice(13, Figure.allCases.count)) ?? .bolt,
            notch: Notch(rawValue: slice(27, Notch.allCases.count)) ?? .none,
            ramp: rampPairs[slice(37, rampPairs.count)],
            inverted: (word >> 48) & 1 == 1
        )
    }

    // MARK: - Drawing

    static func build(_ recipe: Recipe) -> PixelSprite {
        var canvas = PixelCanvas(width: size, height: size)
        let fieldInk = recipe.inverted ? recipe.ramp.light : recipe.ramp.deep
        let figureInk = recipe.inverted ? recipe.ramp.deep : recipe.ramp.light

        // The notch is cut out of the field before anything is painted —
        // cutting rather than painting is the point, because it changes
        // the outline, which is the thing that survives being shrunk.
        let field = bite(recipe.notch, from: mask(recipe.field))
        for y in 0..<size where field[y] != 0 {
            for x in 0..<size where field[y] & (1 << (size - 1 - x)) != 0 {
                canvas.set(x: x, y: y, fieldInk)
            }
        }

        // The figure only marks pixels the field already holds, so it can
        // never break the silhouette the eye reads first.
        let figure = mask(recipe.figure)
        for y in 0..<size where figure[y] != 0 {
            for x in 0..<size where figure[y] & (1 << (size - 1 - x)) != 0 {
                if field[y] & (1 << (size - 1 - x)) != 0 {
                    canvas.set(x: x, y: y, figureInk)
                }
            }
        }
        return canvas.sprite()
    }

    /// The same recipe at `side` pixels a side. Each output pixel takes
    /// the centre of the 16×16 cell it stands for, so the silhouette
    /// survives and the two inks stay the two inks.
    static func reduce(_ recipe: Recipe, to side: Int) -> PixelSprite {
        var canvas = PixelCanvas(width: side, height: side)
        let fieldInk = recipe.inverted ? recipe.ramp.light : recipe.ramp.deep
        let figureInk = recipe.inverted ? recipe.ramp.deep : recipe.ramp.light
        let field = bite(recipe.notch, from: mask(recipe.field))
        let figure = mask(recipe.figure)
        for y in 0..<side {
            let sourceY = min(size - 1, (y * 2 + 1) * size / (side * 2))
            for x in 0..<side {
                let sourceX = min(size - 1, (x * 2 + 1) * size / (side * 2))
                let bit = UInt16(1) << UInt16(size - 1 - sourceX)
                guard field[sourceY] & bit != 0 else { continue }
                canvas.set(x: x, y: y, figure[sourceY] & bit != 0 ? figureInk : fieldInk)
            }
        }
        return canvas.sprite()
    }

    /// The field with the notch's corner taken out of it.
    static func bite(_ notch: Notch, from field: [UInt16]) -> [UInt16] {
        var out = field
        func clear(x0: Int, y0: Int, side: Int) {
            for y in max(0, y0)..<min(size, y0 + side) {
                for x in max(0, x0)..<min(size, x0 + side) {
                    out[y] &= ~(UInt16(1) << UInt16(size - 1 - x))
                }
            }
        }
        switch notch {
        case .none: break
        case .topLeft: clear(x0: 0, y0: 0, side: 5)
        case .bottomRight: clear(x0: size - 5, y0: size - 5, side: 5)
        case .bothTop:
            clear(x0: 0, y0: 0, side: 4)
            clear(x0: size - 4, y0: 0, side: 4)
        }
        return out
    }

    // MARK: - The shapes, as 16-wide bitmasks

    /// Rows of a 16×16 shape, written as text so the art is readable.
    /// `#` is set, anything else is clear.
    private static func rows(_ art: [String]) -> [UInt16] {
        art.map { row in
            var bits: UInt16 = 0
            for (index, character) in row.enumerated() where index < size && character == "#" {
                bits |= UInt16(1) << UInt16(size - 1 - index)
            }
            return bits
        }
    }

    static func mask(_ field: Field) -> [UInt16] {
        switch field {
        case .block:
            rows([
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                "################", "################", "################", "################",
            ])
        case .disc:
            rows([
                "     ######     ", "   ##########   ", "  ############  ", " ############## ",
                " ############## ", "################", "################", "################",
                "################", "################", "################", " ############## ",
                " ############## ", "  ############  ", "   ##########   ", "     ######     ",
            ])
        case .shield:
            rows([
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                "################", " ############## ", " ############## ", "  ############  ",
                "   ##########   ", "    ########    ", "     ######     ", "       ##       ",
            ])
        case .diamond:
            rows([
                "       ##       ", "      ####      ", "     ######     ", "    ########    ",
                "   ##########   ", "  ############  ", " ############## ", "################",
                "################", " ############## ", "  ############  ", "   ##########   ",
                "    ########    ", "     ######     ", "      ####      ", "       ##       ",
            ])
        case .hexagon:
            rows([
                "    ########    ", "   ##########   ", "  ############  ", " ############## ",
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                " ############## ", "  ############  ", "   ##########   ", "    ########    ",
            ])
        case .arch:
            rows([
                "    ########    ", "   ##########   ", "  ############  ", " ############## ",
                " ############## ", "################", "################", "################",
                "################", "################", "################", "################",
                "################", "################", "################", "################",
            ])
        case .banner:
            rows([
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                "################", "###  ######  ###", "##    ####    ##", "#      ##      #",
            ])
        case .chevronPlate:
            rows([
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                " ############## ", "  ############  ", "   ##########   ", "    ########    ",
            ])
        case .ring:
            rows([
                "     ######     ", "   ##########   ", "  ############  ", " #####    ##### ",
                " ####      #### ", "####        ####", "###          ###", "###          ###",
                "###          ###", "###          ###", "####        ####", " ####      #### ",
                " #####    ##### ", "  ############  ", "   ##########   ", "     ######     ",
            ])
        case .tower:
            rows([
                "     ######     ", "     ######     ", "    ########    ", "    ########    ",
                "   ##########   ", "   ##########   ", "  ############  ", "  ############  ",
                " ############## ", " ############## ", "################", "################",
                "################", "################", "################", "################",
            ])
        case .wedge:
            rows([
                "################", "################", "################", "############### ",
                "##############  ", "#############   ", "############    ", "###########     ",
                "###########     ", "############    ", "#############   ", "##############  ",
                "############### ", "################", "################", "################",
            ])
        case .cross:
            rows([
                "     ######     ", "     ######     ", "     ######     ", "     ######     ",
                "################", "################", "################", "################",
                "################", "################", "################", "################",
                "     ######     ", "     ######     ", "     ######     ", "     ######     ",
            ])
        }
    }

    static func mask(_ figure: Figure) -> [UInt16] {
        switch figure {
        case .bolt:
            rows([
                "                ", "         ###    ", "        ###     ", "       ###      ",
                "      ###       ", "     #####      ", "    ######      ", "      ####      ",
                "      ###       ", "     ###        ", "    ###         ", "   ###          ",
                "  ###           ", "                ", "                ", "                ",
            ])
        case .bar:
            rows([
                "                ", "                ", "                ", "                ",
                "                ", "                ", "   ##########   ", "   ##########   ",
                "   ##########   ", "   ##########   ", "                ", "                ",
                "                ", "                ", "                ", "                ",
            ])
        case .bars:
            rows([
                "                ", "                ", "   ##########   ", "   ##########   ",
                "                ", "                ", "   ##########   ", "   ##########   ",
                "                ", "                ", "   ##########   ", "   ##########   ",
                "                ", "                ", "                ", "                ",
            ])
        case .dot:
            rows([
                "                ", "                ", "                ", "                ",
                "     ######     ", "    ########    ", "   ##########   ", "   ##########   ",
                "   ##########   ", "   ##########   ", "    ########    ", "     ######     ",
                "                ", "                ", "                ", "                ",
            ])
        case .ring:
            rows([
                "                ", "                ", "     ######     ", "    ########    ",
                "   ###    ###   ", "  ###      ###  ", "  ###      ###  ", "  ###      ###  ",
                "  ###      ###  ", "  ###      ###  ", "   ###    ###   ", "    ########    ",
                "     ######     ", "                ", "                ", "                ",
            ])
        case .slash:
            rows([
                "                ", "            ### ", "           ###  ", "          ###   ",
                "         ###    ", "        ###     ", "       ###      ", "      ###       ",
                "     ###        ", "    ###         ", "   ###          ", "  ###           ",
                " ###            ", "                ", "                ", "                ",
            ])
        case .cross:
            rows([
                "                ", "  ##        ##  ", "  ###      ###  ", "   ###    ###   ",
                "    ###  ###    ", "     ######     ", "      ####      ", "      ####      ",
                "     ######     ", "    ###  ###    ", "   ###    ###   ", "  ###      ###  ",
                "  ##        ##  ", "                ", "                ", "                ",
            ])
        case .arrow:
            rows([
                "                ", "       ##       ", "      ####      ", "     ######     ",
                "    ########    ", "   ##########   ", "  ############  ", "     ######     ",
                "     ######     ", "     ######     ", "     ######     ", "     ######     ",
                "                ", "                ", "                ", "                ",
            ])
        case .stair:
            rows([
                "                ", "                ", "          ####  ", "          ####  ",
                "       #######  ", "       #######  ", "    ##########  ", "    ##########  ",
                "  ############  ", "  ############  ", "                ", "                ",
                "                ", "                ", "                ", "                ",
            ])
        case .split:
            rows([
                "                ", "                ", "                ", "                ",
                "                ", "                ", "                ", "################",
                "################", "                ", "                ", "                ",
                "                ", "                ", "                ", "                ",
            ])
        case .crescent:
            rows([
                "                ", "                ", "     #####      ", "   #######      ",
                "  ####   ##     ", "  ###           ", " ###            ", " ###            ",
                " ###            ", "  ###           ", "  ####   ##     ", "   #######      ",
                "     #####      ", "                ", "                ", "                ",
            ])
        case .spark:
            rows([
                "                ", "       ##       ", "       ##       ", "   #   ##   #   ",
                "    #  ##  #    ", "     # ## #     ", "  ############  ", "  ############  ",
                "     # ## #     ", "    #  ##  #    ", "   #   ##   #   ", "       ##       ",
                "       ##       ", "                ", "                ", "                ",
            ])
        case .brick:
            rows([
                "                ", "                ", "  ####  ######  ", "  ####  ######  ",
                "                ", "  ######  ####  ", "  ######  ####  ", "                ",
                "  ####  ######  ", "  ####  ######  ", "                ", "  ######  ####  ",
                "  ######  ####  ", "                ", "                ", "                ",
            ])
        case .notchOut:
            rows([
                "                ", "                ", "   ##########   ", "   ##########   ",
                "   ###          ", "   ###          ", "   ###          ", "   ########     ",
                "   ########     ", "   ###          ", "   ###          ", "   ###          ",
                "   ###          ", "                ", "                ", "                ",
            ])
        }
    }

    // MARK: - Mixing

    /// SplitMix64's finalizer. A pure function of the word, so nothing
    /// here consumes a generator the simulation owns.
    static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
