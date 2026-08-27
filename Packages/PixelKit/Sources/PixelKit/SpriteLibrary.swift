/// Sprite factory: composed people (body + hair + shirt palette applied,
/// seated pose, 2-frame typing + occasional blink), desks, monitors with a
/// screen-glow animation, ambient props, and status bubbles.
public enum SpriteLibrary {
    // MARK: - People

    /// The seated, animated person sprite for an appearance.
    /// Three frames: typing A, typing B, typing A with a blink.
    public static func person(appearance: CharacterAppearance) -> PixelSprite {
        person(appearance: appearance, isFounder: false)
    }

    /// Founder variant adds a subtle indigo hoodie collar.
    public static func person(appearance: CharacterAppearance, isFounder: Bool) -> PixelSprite {
        let hair = PersonArt.hairOverlays[appearance.hairStyle % PersonArt.hairOverlays.count]
        let bases = [PersonArt.frameA, PersonArt.frameB, PersonArt.frameABlink]
        let frames = bases.enumerated().map { index, frame in
            // Frame B bobs the head one pixel lower, so the hair rides along.
            var composed = PixelGrid.overlay(base: frame, top: hair, offsetY: index == 1 ? 1 : 0)
            if isFounder {
                composed = PixelGrid.overlay(base: composed, top: PersonArt.hoodieOverlay)
            }
            return composed
        }

        let skin = Palettes.skinTones[appearance.skinTone % Palettes.skinTones.count]
        let hairColor = Palettes.hairColors[appearance.hairColor % Palettes.hairColors.count]
        let shirt = Palettes.shirtColors[appearance.shirtColor % Palettes.shirtColors.count]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "E": Palettes.eye,
            "P": Palettes.pants,
            "C": Palettes.chair,
            "D": Palettes.hoodie,
            "d": Palettes.hoodieShade,
            "S": skin.base, "s": skin.shade,
            "H": hairColor.base, "h": hairColor.shade,
            "T": shirt.base, "t": shirt.shade,
        ]
        return PixelSprite(frames: frames, palette: palette)
    }

    // MARK: - Furniture

    /// A warm wooden desk, 24×7.
    public static func desk() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWWWO",
            "OwwwwwwwwwwwwwwwwwwwwwwO",
            "OOOOOOOOOOOOOOOOOOOOOOOO",
            "  OwO              OwO  ",
            "  OwO              OwO  ",
            "  OwO              OwO  ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": RGBA(r: 196, g: 158, b: 110),
            "w": RGBA(r: 168, g: 132, b: 88),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Monitor seen from behind, 10×8, with a two-frame screen-glow halo
    /// (soft blue ↔ warmer white) and a blinking power LED.
    public static func monitor() -> PixelSprite {
        let dim = [
            " GGGGGGGG ",
            "GOOOOOOOOG",
            "GOMMMMMMOG",
            "GOMMMMMLOG",
            "GOOOOOOOOG",
            "    OO    ",
            "   OOOO   ",
            "  OOOOOO  ",
        ]
        let bright = [
            " FFFFFFFF ",
            "FOOOOOOOOF",
            "FOMMMMMMOF",
            "FOMMMMMlOF",
            "FOOOOOOOOF",
            "    OO    ",
            "   OOOO   ",
            "  OOOOOO  ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "M": RGBA(r: 70, g: 68, b: 84),
            "G": RGBA(r: 150, g: 180, b: 250, a: 110),
            "F": RGBA(r: 232, g: 240, b: 255, a: 215),
            "L": RGBA(r: 100, g: 220, b: 140),
            "l": RGBA(r: 60, g: 140, b: 90),
        ]
        return PixelSprite(frames: [dim, bright], palette: palette)
    }

    // MARK: - Status bubbles

    /// A small speech bubble with a status icon: `</>` for coding, a brush for
    /// designing, a megaphone for marketing, a flask for researching, a bug
    /// for testing, scales for legal, two people for people ops, a wrench for
    /// operations — and a fully transparent sprite for idle (idle people get
    /// no bubble).
    public static func statusBubble(_ status: WorkStatus) -> PixelSprite {
        let bubbleWidth = 10
        let bubbleHeight = 9

        guard status != .idle else {
            let empty = Array(repeating: String(repeating: " ", count: bubbleWidth), count: bubbleHeight)
            return PixelSprite(frames: [empty], palette: [:])
        }

        // 6×3 icon rows, drawn into the bubble interior.
        let icon: [String]
        switch status {
        case .idle:
            icon = ["      ", "      ", "      "]
        case .coding: // </>
            icon = [
                " I  I ",
                "I    I",
                " I  I ",
            ]
        case .designing: // brush, tip down-left
            icon = [
                "   NN ",
                "  NN  ",
                " RR   ",
            ]
        case .marketing: // megaphone with sound waves
            icon = [
                "MM  I ",
                "MMMM I",
                "MM  I ",
            ]
        case .researching: // flask
            icon = [
                "  FF  ",
                " FLLF ",
                "FLLLLF",
            ]
        case .testing: // beetle: red shell, dark wing seam, legs out
            icon = [
                "O UU O",
                " UKKU ",
                "O UU O",
            ]
        case .legal: // scales: silver beam and pans on a dark post
            icon = [
                "QQQQQQ",
                "Q OO Q",
                "QQOOQQ",
            ]
        case .peopleOps: // two people, shoulder to shoulder
            icon = [
                " S  S ",
                " I  R ",
                "IIIRRR",
            ]
        case .operations: // wrench, jaw up-right
            icon = [
                "   G G",
                "  GGGG",
                "GGG   ",
            ]
        }

        let grid = [
            " OOOOOOOO ",
            "OWWWWWWWWO",
            "OW" + icon[0] + "WO",
            "OW" + icon[1] + "WO",
            "OW" + icon[2] + "WO",
            "OWWWWWWWWO",
            " OOWWOOOO ",
            "  OWO     ",
            "   O      ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": RGBA(r: 250, g: 250, b: 252),
            "I": RGBA(r: 94, g: 96, b: 206),
            "N": RGBA(r: 140, g: 92, b: 52),
            "R": RGBA(r: 214, g: 86, b: 110),
            "M": RGBA(r: 217, g: 164, b: 65),
            "F": RGBA(r: 176, g: 205, b: 226),
            "L": RGBA(r: 110, g: 190, b: 120),
            "U": RGBA(r: 200, g: 60, b: 50),
            "K": RGBA(r: 52, g: 44, b: 48),
            "Q": RGBA(r: 112, g: 122, b: 150),
            "S": RGBA(r: 240, g: 196, b: 151),
            "G": RGBA(r: 78, g: 86, b: 112),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    // MARK: - Props

    public enum PropName: String, CaseIterable, Sendable {
        case plant, garageDoor, toolbox, whiteboard, coffeeMachine, windowDay
    }

    public static func prop(_ name: PropName) -> PixelSprite {
        switch name {
        case .plant: plantSprite()
        case .garageDoor: garageDoorSprite()
        case .toolbox: toolboxSprite()
        case .whiteboard: whiteboardSprite()
        case .coffeeMachine: coffeeMachineSprite()
        case .windowDay: windowDaySprite()
        }
    }

    private static func plantSprite() -> PixelSprite {
        let grid = [
            "  L  L  ",
            " LLLLLL ",
            "LLlLLlLL",
            " LlLLlL ",
            "  LLLL  ",
            " OUUUUO ",
            " OUuuUO ",
            "  OUUO  ",
            "  OuuO  ",
            "  OOOO  ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "L": RGBA(r: 96, g: 168, b: 96),
            "l": RGBA(r: 72, g: 138, b: 76),
            "U": RGBA(r: 188, g: 110, b: 74),
            "u": RGBA(r: 158, g: 88, b: 58),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    private static func garageDoorSprite() -> PixelSprite {
        let width = 28
        var rows: [String] = [String(repeating: "O", count: width)]
        for i in 1...14 {
            let fill = i.isMultiple(of: 3) ? "g" : "G"
            rows.append("O" + String(repeating: fill, count: width - 2) + "O")
        }
        // Handle, two dark pixels near the bottom center.
        var handleRow = Array(rows[13])
        handleRow[13] = "H"
        handleRow[14] = "H"
        rows[13] = String(handleRow)
        rows.append(String(repeating: "O", count: width))
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "G": RGBA(r: 168, g: 162, b: 154),
            "g": RGBA(r: 142, g: 136, b: 129),
            "H": RGBA(r: 84, g: 80, b: 76),
        ]
        return PixelSprite(frames: [rows], palette: palette)
    }

    private static func toolboxSprite() -> PixelSprite {
        let grid = [
            "  OOOOOO  ",
            "  O    O  ",
            "OOOOOOOOOO",
            "ORRRRRRRRO",
            "ORRROORRRO",
            "OrrrrrrrrO",
            "OOOOOOOOOO",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "R": RGBA(r: 192, g: 72, b: 60),
            "r": RGBA(r: 160, g: 55, b: 46),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    private static func whiteboardSprite() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OWIIIIIWWWRRRRWWWWWWWO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OWWIIIIIIIWWWWIIIWWWWO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OWWWRRRRRWWIIIIIIWWWWO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OWWIIIIWWWWWWWWWWWWWWO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OOOOOOOOOOOOOOOOOOOOOO",
            "   OOOOOOOOOOOOOOOO   ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": RGBA(r: 246, g: 246, b: 248),
            "I": RGBA(r: 94, g: 96, b: 206),
            "R": RGBA(r: 214, g: 86, b: 110),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    private static func coffeeMachineSprite() -> PixelSprite {
        let grid = [
            " OOOOOOO ",
            " OMMMMMO ",
            " OMRMMMO ",
            " OOOOOOO ",
            " OMKKKMO ",
            " OMKCKMO ",
            " OMKCKMO ",
            " OOOOOOO ",
            " OMMMMMO ",
            " OOOOOOO ",
            "  O   O  ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "M": RGBA(r: 108, g: 104, b: 116),
            "K": RGBA(r: 52, g: 50, b: 60),
            "C": RGBA(r: 150, g: 96, b: 50),
            "R": RGBA(r: 222, g: 84, b: 70),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    private static func windowDaySprite() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOO",
            "OYYBBOBBBBBO",
            "OYYBBOBBBBBO",
            "OBBBBOBBBBBO",
            "OBBBBOBWWBBO",
            "OBBBBOWWWWBO",
            "OOOOOOOOOOOO",
            "OBBBBOBBBBBO",
            "OBBBBOBBBBBO",
            "OBBBBOBBBBBO",
            "ObbbbObbbbbO",
            "ObbbbObbbbbO",
            "OOOOOOOOOOOO",
            "OOOOOOOOOOOO",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "B": RGBA(r: 150, g: 196, b: 232),
            "b": RGBA(r: 128, g: 172, b: 210),
            "W": RGBA(r: 244, g: 248, b: 252),
            "Y": RGBA(r: 250, g: 214, b: 110),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }
}
