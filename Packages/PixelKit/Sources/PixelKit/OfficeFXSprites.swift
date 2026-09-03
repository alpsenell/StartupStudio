import Foundation

/// Sprites the animation runtime owns: the small props the director needs
/// to stage office life (a flip-chart easel, a kitchenette, a leaving-day
/// box, a sticky note), the transient bubbles people think in, the
/// celebration particles, the weather, and a 3×5 pixel font for name tags.
///
/// WS-D owns the room, the people and the furniture; this file only holds
/// art that exists because something *moves*. Everything is authored at the
/// same 1 px scale and with the shared outline colour so it sits inside the
/// same world.
enum OfficeFXSprites {
    typealias RGBA = PixelSprite.RGBA

    // MARK: - Shared colours

    static let outline = RGBA(r: 44, g: 42, b: 54)
    private static let paperWhite = RGBA(r: 248, g: 248, b: 250)
    private static let paperShade = RGBA(r: 214, g: 214, b: 222)
    private static let ink = RGBA(r: 94, g: 96, b: 206)
    private static let inkWarm = RGBA(r: 214, g: 86, b: 110)
    private static let woodBase = RGBA(r: 168, g: 132, b: 88)
    private static let steel = RGBA(r: 112, g: 118, b: 138)

    // MARK: - Props

    /// A flip-chart easel, 16×22, that the director wheels into the front
    /// corridor for a huddle. Two frames: the top sheet flutters a pixel.
    ///
    /// Standing the huddle in the open floor instead of against the back
    /// wall keeps the group clear of the desk grid and reads better — you
    /// see three people from the front, gathered round a board.
    static func easel() -> PixelSprite {
        func frame(_ tick: Int) -> [String] {
            var rows = [
                " OOOOOOOOOOOOOO ",
                " OWWWWWWWWWWWWO ",
                " OWIIIIWWWWWWWO ",
                " OWWWWWWWRRRWWO ",
                " OWIIIIIIWWWWWO ",
                " OWWWWWWWWWWWWO ",
                " OWWRRRWWIIIWWO ",
                " OWWWWWWWWWWWWO ",
                " OWIIIWWWWWWWWO ",
                " OWWWWWWWWWWWWO ",
                " OOOOOOOOOOOOOO ",
                "   O        O   ",
                "   O        O   ",
                "  O          O  ",
                "  O          O  ",
                "  O          O  ",
                " O            O ",
                " O            O ",
                " O            O ",
                "O              O",
                "O              O",
                "OO            OO",
            ]
            if tick == 1 {
                // The marker line the huddle is arguing about gets redrawn.
                rows[6] = " OWWRRRRRWIIWWO "
                rows[8] = " OWIIIIIWWWWWWO "
            }
            return rows
        }
        return PixelSprite(
            frames: [frame(0), frame(1)],
            palette: ["O": outline, "W": paperWhite, "I": ink, "R": inkWarm]
        )
    }

    /// A counter-top kitchenette, 12×14: a filter machine, a pot and two
    /// mugs. Tiers without WS-D's wall-mounted coffee machine (garage,
    /// loft) get this so a coffee run has somewhere to go.
    /// Two frames: the brew light blinks.
    static func kitchenette() -> PixelSprite {
        func frame(_ lit: Bool) -> [String] {
            [
                " OOOOOOOOOO ",
                " OMMMMMMMMO ",
                " OM" + (lit ? "R" : "r") + "MMMMMMO ",
                " OMMMMMMMMO ",
                " OOOOOOOOOO ",
                " OKKKKKKKKO ",
                " OKCCCCCCKO ",
                " OKCCCCCCKO ",
                " OOOOOOOOOO ",
                "OWWWWWWWWWWO",
                "OWOSSOOSSOWO",
                "OWOSSOOSSOWO",
                "OWOOOOOOOOWO",
                "OOOOOOOOOOOO",
            ]
        }
        return PixelSprite(
            frames: [frame(false), frame(true)],
            palette: [
                "O": outline,
                "M": RGBA(r: 108, g: 104, b: 116),
                "K": RGBA(r: 52, g: 50, b: 60),
                "C": RGBA(r: 150, g: 96, b: 50),
                "R": RGBA(r: 240, g: 96, b: 78),
                "r": RGBA(r: 132, g: 56, b: 50),
                "W": woodBase,
                "S": paperWhite,
            ]
        )
    }

    /// A cardboard moving box, 10×8, carried in front of a leaver.
    static func cardboardBox() -> PixelSprite {
        let box = [
            "OOOOOOOOOO",
            "OBBBBBBBBO",
            "OBbbbbbbBO",
            "OBbOOOObBO",
            "OBbbbbbbBO",
            "OBbbbbbbBO",
            "OBBBBBBBBO",
            "OOOOOOOOOO",
        ]
        // 10×9 with a blank row, so the box can ride a pixel high on every
        // other step. A carried load is the clearest bit of secondary motion
        // there is: it lags the body that is carrying it, and a box that
        // tracks a walker perfectly reads as glued on.
        let blank = String(repeating: " ", count: 10)
        let low = box + [blank]
        let high = [blank] + box
        return PixelSprite(
            frames: [low, high],
            palette: [
                "O": outline,
                "B": RGBA(r: 198, g: 158, b: 106),
                "b": RGBA(r: 172, g: 132, b: 84),
            ]
        )
    }

    /// A sticky note left on an empty desk, 8×8. Two frames: it lifts a
    /// pixel in the draught.
    static func stickyNote() -> PixelSprite {
        func frame(_ lift: Int) -> [String] {
            var rows = [String](repeating: "        ", count: 8)
            let note = [
                "OOOOOOO ",
                "OYYYYYO ",
                "OYKKKYO ",
                "OYYYYYO ",
                "OYKKYYO ",
                "OYYYYYO ",
                "OOOOOOO ",
            ]
            for (index, row) in note.enumerated() {
                rows[index + (1 - lift)] = row
            }
            return rows
        }
        return PixelSprite(
            frames: [frame(0), frame(1)],
            palette: [
                "O": outline,
                "Y": RGBA(r: 250, g: 226, b: 120),
                "K": RGBA(r: 120, g: 104, b: 60),
            ]
        )
    }

    // MARK: - Transient bubbles

    /// Three dots that fill in one at a time: two people talking. 10×9,
    /// 3 frames, same silhouette as WS-D's status bubbles so they read as
    /// the same family.
    static func chatterBubble() -> PixelSprite {
        func frame(_ dots: Int) -> [String] {
            var chars = Array("      ")
            for i in 0..<dots { chars[i * 2] = "I" }
            return bubbleShell(rows: ["      ", String(chars), "      "])
        }
        return PixelSprite(
            frames: [frame(1), frame(2), frame(3)],
            palette: bubblePalette
        )
    }

    /// A steaming mug in a bubble — someone is on a coffee run. 10×9,
    /// 2 frames (the steam curls).
    static func mugBubble() -> PixelSprite {
        let a = bubbleShell(rows: [
            "  S   ",
            " CCCC ",
            " CCCC ",
        ])
        let b = bubbleShell(rows: [
            "   S  ",
            " CCCC ",
            " CCCC ",
        ])
        return PixelSprite(frames: [a, b], palette: bubblePalette)
    }

    /// A light bulb: research landed. 10×9, 2 frames (dim / bright).
    static func ideaBubble() -> PixelSprite {
        let dim = bubbleShell(rows: [
            "  yy  ",
            " yyyy ",
            "  OO  ",
        ])
        let bright = bubbleShell(rows: [
            " YyyY ",
            "YYYYYY",
            "  OO  ",
        ])
        return PixelSprite(frames: [dim, bright], palette: bubblePalette)
    }

    /// A small rain cloud that sits directly over a slumped head, 10×8,
    /// 2 frames (the drops fall). Not a speech bubble — no tail.
    static func gloomCloud() -> PixelSprite {
        func frame(_ offset: Int) -> [String] {
            var rows = [
                "  OOOO    ",
                " OGGGGOO  ",
                "OGGGGGGGO ",
                "OGgggggGO ",
                " OOOOOOO  ",
                "          ",
                "          ",
                "          ",
            ]
            rows[5 + offset] = " B   B  B "
            rows[6 + offset] = "   B   B  "
            return rows
        }
        return PixelSprite(
            frames: [frame(0), frame(1)],
            palette: [
                "O": outline,
                "G": RGBA(r: 148, g: 152, b: 168),
                "g": RGBA(r: 116, g: 120, b: 138),
                "B": RGBA(r: 118, g: 162, b: 208),
            ]
        )
    }

    /// A coin sparkle for a delivered contract, 7×7, 3 frames: it pops
    /// open, spins, and shrinks away.
    static func coinSparkle() -> PixelSprite {
        let small = [
            "       ",
            "       ",
            "  YYY  ",
            "  YoY  ",
            "  YYY  ",
            "       ",
            "       ",
        ]
        let wide = [
            "   Y   ",
            " YYYYY ",
            "YYYoYYY",
            "YYoooYY",
            "YYYoYYY",
            " YYYYY ",
            "   Y   ",
        ]
        let fading = [
            "  Y Y  ",
            " Y   Y ",
            "Y     Y",
            "       ",
            "Y     Y",
            " Y   Y ",
            "  Y Y  ",
        ]
        return PixelSprite(
            frames: [small, wide, fading],
            palette: [
                "Y": RGBA(r: 250, g: 214, b: 110),
                "o": RGBA(r: 208, g: 152, b: 52),
            ]
        )
    }

    /// The shared 10×9 bubble shell with a tail, wrapped around a 6×3
    /// interior — the exact silhouette `SpriteLibrary.statusBubble` uses.
    private static func bubbleShell(rows interior: [String]) -> [String] {
        [
            " OOOOOOOO ",
            "OWWWWWWWWO",
            "OW" + interior[0] + "WO",
            "OW" + interior[1] + "WO",
            "OW" + interior[2] + "WO",
            "OWWWWWWWWO",
            " OOWWOOOO ",
            "  OWO     ",
            "   O      ",
        ]
    }

    private static let bubblePalette: [Character: RGBA] = [
        "O": outline,
        "W": paperWhite,
        "I": ink,
        "S": RGBA(r: 206, g: 210, b: 220),
        "C": RGBA(r: 150, g: 96, b: 50),
        "Y": RGBA(r: 250, g: 226, b: 120),
        "y": RGBA(r: 212, g: 180, b: 84),
    ]

    // MARK: - Celebration particles

    /// One 2×2 confetti chip. `variant` picks the colour so a burst is not
    /// monochrome; each has 4 frames of a lazy tumble (wide, thin, wide,
    /// thin) so a falling drift reads as paper, not as pixels.
    static func confetti(variant: Int) -> PixelSprite {
        let colors = [
            RGBA(r: 240, g: 96, b: 110),
            RGBA(r: 250, g: 202, b: 90),
            RGBA(r: 108, g: 200, b: 140),
            RGBA(r: 118, g: 156, b: 240),
            RGBA(r: 214, g: 140, b: 232),
        ]
        let color = colors[((variant % colors.count) + colors.count) % colors.count]
        return PixelSprite(
            frames: [
                ["CC", "CC"],
                [" C", " C"],
                ["CC", "  "],
                ["C ", "C "],
            ],
            palette: ["C": color]
        )
    }

    /// A 3-frame puff of floor dust kicked up under a walker's feet.
    static func dustPuff() -> PixelSprite {
        return PixelSprite(
            frames: [
                ["    ", " dd ", "    "],
                [" d  ", "dddd", "  d "],
                ["d  d", " dd ", "d  d"],
            ],
            palette: ["d": RGBA(r: 210, g: 206, b: 198, a: 150)]
        )
    }

    /// The bright band that sweeps down the room when the office is
    /// upgraded. One row tall, stretched over the scene width.
    static func wipeBand(width: Int) -> PixelSprite {
        let w = max(1, width)
        func band(_ char: Character) -> String { String(repeating: char, count: w) }
        // A soft trailing glow, a hard bright crest, then a quick falloff:
        // the eye reads it as a sheet of light passing over the room.
        let rows: [String] = [
            band("a"), band("a"), band("b"), band("b"), band("c"),
            band("d"), band("c"), band("b"), band("b"), band("a"),
            band("a"),
        ]
        return PixelSprite(
            frames: [rows],
            palette: [
                "a": RGBA(r: 255, g: 246, b: 210, a: 46),
                "b": RGBA(r: 255, g: 248, b: 216, a: 110),
                "c": RGBA(r: 255, g: 252, b: 232, a: 190),
                "d": RGBA(r: 255, g: 255, b: 248, a: 245),
            ]
        )
    }

    // MARK: - Ambience

    /// A translucent tint for the whole room.
    ///
    /// WS-D's `SpriteLibrary.lightingOverlay` is still the placeholder
    /// transparent sheet, so the director falls back to this. Morning is a
    /// pale gold wash, day is nothing at all, dusk is amber, night is a
    /// cool blue that also darkens toward the floor — the window band stays
    /// lighter so it still reads as the light source.
    static func lightingTint(width: Int, height: Int, time: TimeOfDay, wallHeight: Int) -> PixelSprite? {
        let w = max(1, width)
        let h = max(1, height)
        let near: RGBA
        let far: RGBA
        switch time {
        case .day:
            return nil
        case .morning:
            near = RGBA(r: 255, g: 232, b: 176, a: 22)
            far = RGBA(r: 255, g: 214, b: 150, a: 40)
        case .dusk:
            near = RGBA(r: 255, g: 176, b: 108, a: 36)
            far = RGBA(r: 196, g: 118, b: 86, a: 58)
        case .night:
            near = RGBA(r: 44, g: 58, b: 118, a: 60)
            far = RGBA(r: 22, g: 30, b: 74, a: 108)
        }
        // Two bands: above the wall line the light is thinner (windows),
        // below it thickens toward the floor.
        var rows: [String] = []
        for y in 0..<h {
            rows.append(String(repeating: y < wallHeight ? "n" : "f", count: w))
        }
        return PixelSprite(frames: [rows], palette: ["n": near, "f": far])
    }

    /// A pane of falling rain, `width` × `height`, 3 frames that slide the
    /// streaks down so the loop never lines up with a walker's step.
    static func rainPane(width: Int, height: Int) -> PixelSprite {
        let w = max(1, width)
        let h = max(1, height)
        func frame(_ offset: Int) -> [String] {
            (0..<h).map { y in
                String((0..<w).map { x in
                    // A sparse diagonal lattice; the offset walks it downward.
                    (x * 3 + y * 2 + offset * 5) % 13 == 0 ? "R" : " "
                })
            }
        }
        return PixelSprite(
            frames: [frame(0), frame(1), frame(2)],
            palette: ["R": RGBA(r: 176, g: 206, b: 240, a: 170)]
        )
    }

    /// A pane of drifting snow, same idea as `rainPane` but slower and
    /// rounder: 2×1 flecks on a wider lattice.
    static func snowPane(width: Int, height: Int) -> PixelSprite {
        let w = max(1, width)
        let h = max(1, height)
        func frame(_ offset: Int) -> [String] {
            (0..<h).map { y in
                String((0..<w).map { x in
                    (x * 5 + y * 3 + offset * 7) % 23 == 0 ? "S" : " "
                })
            }
        }
        return PixelSprite(
            frames: [frame(0), frame(1), frame(2), frame(3)],
            palette: ["S": RGBA(r: 246, g: 249, b: 255, a: 210)]
        )
    }

    // MARK: - Pixel text

    /// A name plate: the person's name in a 3×5 pixel font on a card, with
    /// an optional second line under it. Shown for four seconds when the
    /// player taps someone.
    /// - Parameter tailX: where the tail hangs, as a fraction of the card's
    ///   width, so a plate shoved back inside the scene edges still points
    ///   at the person it belongs to.
    static func nameTag(name: String, line: String?, tailX: Double = 0.12) -> PixelSprite {
        let top = glyphRows(for: name.uppercased(), maxCharacters: 12)
        let bottom = line.map { glyphRows(for: $0.uppercased(), maxCharacters: 16) }
        let innerWidth = max(top.width, bottom?.width ?? 0)
        let innerHeight = bottom == nil ? 5 : 5 + 3 + 5
        let width = innerWidth + 6
        let height = innerHeight + 8

        func padded(_ prefix: String) -> String {
            prefix + String(repeating: " ", count: max(0, width - prefix.count))
        }

        var rows = [String](repeating: String(repeating: "W", count: width), count: height)
        rows[0] = String(repeating: "O", count: width)
        for y in 1..<(height - 4) {
            rows[y] = "O" + String(repeating: "W", count: width - 2) + "O"
        }
        // Bottom border with a two-pixel notch the tail hangs from.
        let tailLeft = min(max(2, Int(Double(width) * tailX)), width - 6)
        var bottomBorder = Array(String(repeating: "O", count: width))
        bottomBorder[tailLeft + 1] = "W"
        bottomBorder[tailLeft + 2] = "W"
        rows[height - 4] = String(bottomBorder)
        // Tail, tapering down toward the head it belongs to.
        let lead = String(repeating: " ", count: tailLeft)
        rows[height - 3] = padded(lead + "OWWO")
        rows[height - 2] = padded(lead + "OWO")
        rows[height - 1] = padded(lead + " O")

        func stamp(_ block: (rows: [String], width: Int), at originY: Int, ink: Character) {
            let originX = (width - block.width) / 2
            for (dy, row) in block.rows.enumerated() {
                var chars = Array(rows[originY + dy])
                for (dx, ch) in row.enumerated() where ch == "#" {
                    let x = originX + dx
                    guard x >= 0, x < width else { continue }
                    chars[x] = ink
                }
                rows[originY + dy] = String(chars)
            }
        }

        stamp(top, at: 3, ink: "K")
        if let bottom { stamp(bottom, at: 11, ink: "I") }

        return PixelSprite(
            frames: [rows],
            palette: [
                "O": outline,
                "W": paperWhite,
                "K": RGBA(r: 40, g: 40, b: 52),
                "I": ink,
                "S": paperShade,
                "M": steel,
            ]
        )
    }

    /// Rasterizes a string into 5 rows of `#` at 3 px per glyph with one
    /// pixel of tracking, truncated to `maxCharacters`.
    private static func glyphRows(for text: String, maxCharacters: Int) -> (rows: [String], width: Int) {
        let characters = Array(text.prefix(maxCharacters))
        guard !characters.isEmpty else { return (Array(repeating: "", count: 5), 0) }
        var rows = [String](repeating: "", count: 5)
        for (index, character) in characters.enumerated() {
            let glyph = font[character] ?? font[" "]!
            for row in 0..<5 {
                rows[row] += glyph[row]
                if index < characters.count - 1 { rows[row] += " " }
            }
        }
        return (rows, rows[0].count)
    }

    /// A 3×5 uppercase pixel font. Small enough to sit over a 14 px person
    /// without swallowing the room, big enough to read at 3× and up.
    private static let font: [Character: [String]] = [
        "A": ["###", "# #", "###", "# #", "# #"],
        "B": ["## ", "# #", "## ", "# #", "## "],
        "C": [" ##", "#  ", "#  ", "#  ", " ##"],
        "D": ["## ", "# #", "# #", "# #", "## "],
        "E": ["###", "#  ", "## ", "#  ", "###"],
        "F": ["###", "#  ", "## ", "#  ", "#  "],
        "G": [" ##", "#  ", "# #", "# #", " ##"],
        "H": ["# #", "# #", "###", "# #", "# #"],
        "I": ["###", " # ", " # ", " # ", "###"],
        "J": ["  #", "  #", "  #", "# #", " # "],
        "K": ["# #", "# #", "## ", "# #", "# #"],
        "L": ["#  ", "#  ", "#  ", "#  ", "###"],
        "M": ["# #", "###", "###", "# #", "# #"],
        "N": ["# #", "## ", "###", " ##", "# #"],
        "O": [" # ", "# #", "# #", "# #", " # "],
        "P": ["## ", "# #", "## ", "#  ", "#  "],
        "Q": [" # ", "# #", "# #", " # ", "  #"],
        "R": ["## ", "# #", "## ", "# #", "# #"],
        "S": [" ##", "#  ", " # ", "  #", "## "],
        "T": ["###", " # ", " # ", " # ", " # "],
        "U": ["# #", "# #", "# #", "# #", " # "],
        "V": ["# #", "# #", "# #", "# #", " # "],
        "W": ["# #", "# #", "###", "###", "# #"],
        "X": ["# #", "# #", " # ", "# #", "# #"],
        "Y": ["# #", "# #", " # ", " # ", " # "],
        "Z": ["###", "  #", " # ", "#  ", "###"],
        "0": ["###", "# #", "# #", "# #", "###"],
        "1": [" # ", "## ", " # ", " # ", "###"],
        "2": ["## ", "  #", " # ", "#  ", "###"],
        "3": ["###", "  #", " ##", "  #", "###"],
        "4": ["# #", "# #", "###", "  #", "  #"],
        "5": ["###", "#  ", "## ", "  #", "## "],
        "6": [" ##", "#  ", "###", "# #", "###"],
        "7": ["###", "  #", " # ", " # ", " # "],
        "8": ["###", "# #", "###", "# #", "###"],
        "9": ["###", "# #", "###", "  #", "## "],
        " ": ["   ", "   ", "   ", "   ", "   "],
        ".": ["   ", "   ", "   ", "   ", " # "],
        ",": ["   ", "   ", "   ", " # ", "#  "],
        "'": [" # ", " # ", "   ", "   ", "   "],
        "!": [" # ", " # ", " # ", "   ", " # "],
        "?": ["## ", "  #", " # ", "   ", " # "],
        "-": ["   ", "   ", "###", "   ", "   "],
        ":": ["   ", " # ", "   ", " # ", "   "],
    ]
}

// MARK: - Pressure props

extension OfficeFXSprites {
    /// A pizza box on the founder's desk: the team is on crunch. 12×5.
    static func pizzaBox() -> PixelSprite {
        PixelSprite(
            frames: [[
                "OOOOOOOOOOOO",
                "OBBBBBBBBBBO",
                "OBbbBBBBbbBO",
                "OBBBBBBBBBBO",
                "OOOOOOOOOOOO",
            ]],
            palette: [
                "O": outline,
                "B": RGBA(r: 198, g: 158, b: 106),
                "b": RGBA(r: 172, g: 132, b: 84),
            ]
        )
    }

    /// Envelopes stacked on the founder's desk: runway under a month. 10×6.
    static func envelopePile() -> PixelSprite {
        PixelSprite(
            frames: [[
                "  OOOOOOO ",
                " OWWWWWWWO",
                "OWWWWWWWWO",
                "OWRRWWWWWO",
                "OWWWWWWWOO",
                "OOOOOOOOO ",
            ]],
            palette: [
                "O": outline,
                "W": paperWhite,
                "R": inkWarm,
            ]
        )
    }

    /// A flattened cardboard box under a desk: somebody is about to leave
    /// and has started packing. 12×3.
    static func flatBox() -> PixelSprite {
        PixelSprite(
            frames: [[
                "OOOOOOOOOOOO",
                "OBbBBbBBbBBO",
                "OOOOOOOOOOOO",
            ]],
            palette: [
                "O": outline,
                "B": RGBA(r: 198, g: 158, b: 106),
                "b": RGBA(r: 172, g: 132, b: 84),
            ]
        )
    }

    /// The envelope a courier holds out: an offer on the table. 8×5, two
    /// frames so it can be held up and lowered.
    static func envelope() -> PixelSprite {
        let held = [
            "OOOOOOOO",
            "OWiWWiWO",
            "OWWiiWWO",
            "OWWWWWWO",
            "OOOOOOOO",
        ]
        let blank = String(repeating: " ", count: 8)
        return PixelSprite(
            frames: [held, [blank] + Array(held.dropLast())],
            palette: [
                "O": outline,
                "W": paperWhite,
                "i": ink,
            ]
        )
    }
}
