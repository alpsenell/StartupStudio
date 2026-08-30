/// Sprite factory: composed people (body + hair + accessories + palette),
/// desks, monitors, status bubbles, room dressing, windows that know the
/// hour, and the lighting overlay that sells it.
///
/// Every color here comes from `Palettes` — see `PaletteTests`.

/// The accessory that tells a role apart at a glance. `.none` is the plain
/// sprite; the rest add one unmistakable silhouette cue on top of whatever
/// pose the person is in.
public enum RoleLook: String, Sendable, Equatable, Codable, CaseIterable {
    case none, founder, qa, designer, marketer, lawyer, hr, ops
}

public enum SpriteLibrary {
    // MARK: - People

    /// The seated, animated person sprite for an appearance.
    /// Three frames: typing A, typing B, typing A with a blink.
    public static func person(appearance: CharacterAppearance) -> PixelSprite {
        person(appearance: appearance, isFounder: false)
    }

    /// Founder variant adds the indigo hoodie.
    public static func person(appearance: CharacterAppearance, isFounder: Bool) -> PixelSprite {
        person(appearance: appearance, pose: .seated, isFounder: isFounder, role: isFounder ? .founder : .none)
    }

    // MARK: - Furniture

    /// A warm wooden desk, 24×7, with a contact shadow along its foot.
    public static func desk() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWWWO",
            "OwwwwwwwwwwwwwwwwwwwwwwO",
            "OOOOOOOOOOOOOOOOOOOOOOOO",
            "  OwO              OwO  ",
            "  OwO              OwO  ",
            "  OwOssssssssssssssOwO  ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": Palettes.sand[2],
            "w": Palettes.sand[3],
            "s": Palettes.translucent(Palettes.ink[4], 90),
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
            "M": Palettes.ink[2],
            "G": Palettes.translucent(Palettes.sky[1], 110),
            "F": Palettes.translucent(Palettes.stone[0], 215),
            "L": Palettes.moss[1],
            "l": Palettes.moss[3],
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
            "W": Palettes.stone[0],
            "I": Palettes.indigo[2],
            "N": Palettes.sand[3],
            "R": Palettes.plum[1],
            "M": Palettes.gold[2],
            "F": Palettes.sky[1],
            "L": Palettes.moss[1],
            "U": Palettes.ember[3],
            "K": Palettes.ink[3],
            "Q": Palettes.stone[3],
            "S": Palettes.skinTones[1].base,
            "G": Palettes.stone[4],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    // MARK: - Props

    /// Room dressing. The first six are the original props; the rest are the
    /// per-tier dressing `RoomBuilder` bakes into the room background —
    /// garage clutter, loft comforts, studio kit, campus lobby.
    public enum PropName: String, CaseIterable, Sendable {
        case plant, garageDoor, toolbox, whiteboard, coffeeMachine, windowDay
        // Garage
        case poster, pegboard, bulb, cardboardBoxes, pizzaBoxes
        // Loft
        case wallClock, bookshelfOffice, beanbag, bike
        // Studio
        case serverRack, kitchenette, framedReviews, pingPongTable
        // Campus
        case ledSign, receptionDesk, elevatorDoors, atriumPlant
    }

    public static func prop(_ name: PropName) -> PixelSprite {
        switch name {
        case .plant: plantSprite()
        case .garageDoor: garageDoorSprite()
        case .toolbox: toolboxSprite()
        case .whiteboard: whiteboardSprite()
        case .coffeeMachine: coffeeMachineSprite()
        case .windowDay: window(style: .office, time: .day)
        case .poster: posterSprite()
        case .pegboard: pegboardSprite()
        case .bulb: bulbSprite()
        case .cardboardBoxes: cardboardBoxesSprite()
        case .pizzaBoxes: pizzaBoxesSprite()
        case .wallClock: wallClockSprite()
        case .bookshelfOffice: bookshelfOfficeSprite()
        case .beanbag: beanbagSprite()
        case .bike: bikeSprite()
        case .serverRack: serverRackSprite()
        case .kitchenette: kitchenetteSprite()
        case .framedReviews: framedReviewsSprite()
        case .pingPongTable: pingPongTableSprite()
        case .ledSign: ledSignSprite()
        case .receptionDesk: receptionDeskSprite()
        case .elevatorDoors: elevatorDoorsSprite()
        case .atriumPlant: atriumPlantSprite()
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
            "L": Palettes.moss[2],
            "l": Palettes.moss[3],
            "U": Palettes.ember[3],
            "u": Palettes.ember[4],
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
        var handleRow = Array(rows[13])
        handleRow[13] = "H"
        handleRow[14] = "H"
        rows[13] = String(handleRow)
        rows.append(String(repeating: "O", count: width))
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "G": Palettes.clay[2],
            "g": Palettes.clay[3],
            "H": Palettes.ink[3],
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
            "R": Palettes.ember[3],
            "r": Palettes.ember[4],
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
            "W": Palettes.stone[0],
            "I": Palettes.indigo[2],
            "R": Palettes.plum[1],
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
            "M": Palettes.ink[0],
            "K": Palettes.ink[3],
            "C": Palettes.sand[3],
            "R": Palettes.ember[3],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    // MARK: Garage dressing

    /// A band poster, 12×15: a bold shape on colored stock, taped at the
    /// corners because nobody in a garage owns a frame.
    private static func posterSprite() -> PixelSprite {
        let grid = [
            "T          T",
            "OOOOOOOOOOOO",
            "OPPPPPPPPPPO",
            "OPPPPIIPPPPO",
            "OPPPIIIIPPPO",
            "OPPIIIIIIPPO",
            "OPIIIIIIIIPO",
            "OPPIIIIIIPPO",
            "OPPPIIIIPPPO",
            "OPPPPIIPPPPO",
            "OPPPPPPPPPPO",
            "OPGGGPPGGGPO",
            "OPPPPPPPPPPO",
            "OOOOOOOOOOOO",
            "T          T",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "P": Palettes.plum[3],
            "I": Palettes.gold[1],
            "G": Palettes.plum[1],
            "T": Palettes.translucent(Palettes.stone[0], 150),
        ])
    }

    /// Pegboard with hanging tools, 16×13.
    private static func pegboardSprite() -> PixelSprite {
        var rows = [String(repeating: "O", count: 16)]
        for y in 0..<11 {
            var row = "O"
            for x in 0..<14 {
                row.append((x % 3 == 1 && y % 3 == 1) ? "h" : "B")
            }
            rows.append(row + "O")
        }
        rows.append(String(repeating: "O", count: 16))
        var grid = rows
        // A wrench, a screwdriver and a saw hung on the pegs.
        grid = PixelGrid.overlay(base: grid, top: [
            " MM   S   NN ",
            " MM   S   NN ",
            " M    S   NNN",
            " MM   K   NNN",
        ], offsetX: 2, offsetY: 3)
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "B": Palettes.sand[3],
            "h": Palettes.sand[4],
            "M": Palettes.stone[2],
            "S": Palettes.stone[1],
            "K": Palettes.ember[3],
            "N": Palettes.stone[3],
        ])
    }

    /// Bare bulb on a cord, 5×6, with a warm halo.
    private static func bulbSprite() -> PixelSprite {
        let grid = [
            " ggg ",
            "gYYYg",
            "gYYYg",
            " OYO ",
            " OMO ",
            "  g  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "Y": Palettes.gold[0],
            "M": Palettes.stone[3],
            "g": Palettes.translucent(Palettes.gold[1], 80),
        ])
    }

    /// A stack of moving boxes, 18×20, one lid flapping open.
    private static func cardboardBoxesSprite() -> PixelSprite {
        let grid = [
            "   OOOOOOOOO   ",
            "  OBBBBBBBBBO  ",
            "  OBBbbbbbBBO  ",
            "  OBBBBBBBBBO  ",
            "  OBBBBBBBBBO  ",
            "  OOOOOOOOOOO  ",
            "OOOOOOOOOOOOOOO",
            "OBBBBBBBBBBBBBO",
            "OBBbbbbbbbbbBBO",
            "OBBBBBBBBBBBBBO",
            "OBBBBBBBBBBBBBO",
            "OBBBBBBBBBBBBBO",
            "OOOOOOOOOOOOOOO",
            "OBBBBBBBBBBBBBO",
            "OBBbbbbbbbbbBBO",
            "OBBBBBBBBBBBBBO",
            "OBBBBBBBBBBBBBO",
            "OBBBBBBBBBBBBBO",
            "OBBBBBBBBBBBBBO",
            "OOOOOOOOOOOOOOO",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "B": Palettes.sand[1],
            "b": Palettes.sand[2],
        ])
    }

    /// Two pizza boxes and a can, 18×7 — the garage's true fuel.
    private static func pizzaBoxesSprite() -> PixelSprite {
        let grid = [
            "            OOOOO ",
            "            OCCCO ",
            " OOOOOOOOOO OCcCO ",
            " OWWWWWWWWO OCCCO ",
            "OOOOOOOOOOOOOCCCO ",
            "OWWWWWWWWWWO OOOO ",
            "OOOOOOOOOOOO      ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.sand[1],
            "C": Palettes.ember[3],
            "c": Palettes.stone[0],
        ])
    }

    // MARK: Loft dressing

    /// Round wall clock, 9×9.
    private static func wallClockSprite() -> PixelSprite {
        let grid = [
            "  OOOOO  ",
            " OWWWWWO ",
            "OWWWKWWWO",
            "OWWWKWWWO",
            "OWWWKKKWO",
            "OWWWWWWWO",
            "OWWWWWWWO",
            " OWWWWWO ",
            "  OOOOO  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.stone[0],
            "K": Palettes.ink[3],
        ])
    }

    /// Low office bookshelf, 20×14, spines in the master accents.
    private static func bookshelfOfficeSprite() -> PixelSprite {
        let plank = "O" + String(repeating: "W", count: 18) + "O"
        var grid = [String(repeating: "O", count: 20), plank]
        for spines in ["RRGGBBYYRRPPGGBBYY", "BBYYRRGGPPBBYYRRGG"] {
            for row in 0..<4 {
                let visible = row == 0 ? " " + spines.dropLast() : Substring(spines)
                grid.append("O" + visible + "O")
            }
            grid.append(plank)
        }
        grid.append(String(repeating: "O", count: 20))
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.sand[2],
            "R": Palettes.ember[3],
            "G": Palettes.teal[2],
            "B": Palettes.indigo[2],
            "Y": Palettes.gold[2],
            "P": Palettes.plum[2],
        ])
    }

    /// Slouched beanbag, 16×10.
    private static func beanbagSprite() -> PixelSprite {
        let grid = [
            "     OOOO       ",
            "   OOBBBBOO     ",
            "  OBBBBBBBBO    ",
            " OBBBBBBBBBBO   ",
            "OBBBBBBBBBBBBO  ",
            "OBBbbBBBBBBBBBO ",
            "OBbbbbBBBBBBBBO ",
            "OBbbbbbbBBBBBBO ",
            " OObbbbbbbbbbO  ",
            "   OOOOOOOOOO   ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "B": Palettes.teal[2],
            "b": Palettes.teal[3],
        ])
    }

    /// A bike leaning on the wall, 22×16.
    private static func bikeSprite() -> PixelSprite {
        let grid = [
            "               OOO    ",
            "              OMMMO   ",
            "       OOOOOOOOMOO    ",
            "      OFO     OFO     ",
            "     OFO     OFO      ",
            "    OFO     OFO       ",
            "   OFOOOOOOOFO        ",
            "  OFO      OFO        ",
            " OFO       OFO        ",
            "OOOO      OOOOO       ",
            "OKKO      OKKKO       ",
            "OKKO      OKKKO       ",
            "OKKO      OKKKO       ",
            "OKKO      OKKKO       ",
            " OO        OOO        ",
            "                      ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "F": Palettes.ember[2],
            "M": Palettes.ink[2],
            "K": Palettes.ink[3],
        ])
    }

    // MARK: Studio dressing

    /// Server rack, 14×24, with blinking-looking status LEDs.
    private static func serverRackSprite() -> PixelSprite {
        var grid = [String(repeating: "O", count: 14)]
        for unit in 0..<7 {
            grid.append("O" + String(repeating: "K", count: 12) + "O")
            let led = unit.isMultiple(of: 2) ? "G" : "Y"
            grid.append("OK" + led + "K" + (unit.isMultiple(of: 3) ? "R" : "G") + "KKKKKKKKO")
            grid.append("O" + String(repeating: "k", count: 12) + "O")
        }
        grid.append(String(repeating: "O", count: 14))
        grid.append(" OO        OO ")
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "K": Palettes.ink[2],
            "k": Palettes.ink[3],
            "G": Palettes.moss[1],
            "Y": Palettes.gold[1],
            "R": Palettes.ember[2],
        ])
    }

    /// Kitchenette counter with a sink and a kettle, 26×16.
    private static func kitchenetteSprite() -> PixelSprite {
        let grid = [
            "        OOOO              ",
            "        OMMO              ",
            "       OOMMOO             ",
            "OOOOOOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWSSSSSSWWWWWWKKWWWWO",
            "OWWWWWWSssssSWWWWWWKKWWWWO",
            "OwwwwwwSSSSSSwwwwwwwwwwwwO",
            "OOOOOOOOOOOOOOOOOOOOOOOOOO",
            "OCCCCCOCCCCCCOCCCCCOCCCCCO",
            "OCcccCOCccccCOCcccCOCcccCO",
            "OCCCCCOCCCCCCOCCCCCOCCCCCO",
            "OCCCCCOCCCCCCOCCCCCOCCCCCO",
            "OCCCCCOCCCCCCOCCCCCOCCCCCO",
            "OCcccCOCccccCOCcccCOCcccCO",
            "OCCCCCOCCCCCCOCCCCCOCCCCCO",
            "OOOOOOOOOOOOOOOOOOOOOOOOOO",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.stone[1],
            "w": Palettes.stone[2],
            "S": Palettes.stone[3],
            "s": Palettes.stone[4],
            "M": Palettes.stone[2],
            "K": Palettes.ember[3],
            "C": Palettes.sand[2],
            "c": Palettes.sand[3],
        ])
    }

    /// Three framed press clippings, 26×12 — the studio's wall of reviews.
    private static func framedReviewsSprite() -> PixelSprite {
        func frame(_ accent: Character) -> [String] {
            [
                "OOOOOOOO",
                "OWWWWWWO",
                "OW\(accent)\(accent)\(accent)\(accent)WO",
                "OWWWWWWO",
                "OWKKKKWO",
                "OWWWWWWO",
                "OWKKKWWO",
                "OWWWWWWO",
                "OOOOOOOO",
            ]
        }
        var canvas = PixelCanvas(width: 26, height: 12)
        let stars = frame("Y")
        let quote = frame("I")
        let award = frame("R")
        func stamp(_ rows: [String], x: Int, y: Int) {
            let sprite = PixelSprite(frames: [rows], palette: [
                "O": Palettes.outline,
                "W": Palettes.stone[0],
                "K": Palettes.stone[2],
                "Y": Palettes.gold[2],
                "I": Palettes.indigo[2],
                "R": Palettes.ember[2],
            ])
            canvas.stamp(sprite, x: x, y: y)
        }
        stamp(stars, x: 0, y: 1)
        stamp(quote, x: 9, y: 0)
        stamp(award, x: 18, y: 2)
        return canvas.sprite()
    }

    /// Ping-pong table seen from the side, 34×14, net and a stray ball.
    private static func pingPongTableSprite() -> PixelSprite {
        let grid = [
            "                b                 ",
            "                                  ",
            "               OOO                ",
            "OOOOOOOOOOOOOOOONOOOOOOOOOOOOOOOOO",
            "OTTTTTTTTTTTTTTTNTTTTTTTTTTTTTTTTO",
            "OTTTTTTTTTTTTTTTNTTTTTTTTTTTTTTTTO",
            "OttttttttttttttttttttttttttttttttO",
            "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO",
            "  OtO                        OtO  ",
            "  OtO                        OtO  ",
            "  OtO                        OtO  ",
            "  OtO                        OtO  ",
            "  OtO                        OtO  ",
            "  OOO                        OOO  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "T": Palettes.teal[3],
            "t": Palettes.teal[4],
            "N": Palettes.stone[0],
            "b": Palettes.gold[1],
        ])
    }

    // MARK: Campus dressing

    /// Backlit lobby sign, 22×10: the company initial in indigo on a light
    /// panel, with a glow bleeding onto the wall.
    private static func ledSignSprite() -> PixelSprite {
        let grid = [
            "gggggggggggggggggggggg",
            "gOOOOOOOOOOOOOOOOOOOOg",
            "gOWWWWWWWWWWWWWWWWWWOg",
            "gOWWIIWWWWIIWWWIIIIWOg",
            "gOWWIIWWWWIIWWWIWWWWOg",
            "gOWWIIWWWWIIWWWIIIWWOg",
            "gOWWIIWWWWIIWWWIWWWWOg",
            "gOWWIIIIWIIWWWWIIIIWOg",
            "gOOOOOOOOOOOOOOOOOOOOg",
            "gggggggggggggggggggggg",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.stone[0],
            "I": Palettes.indigo[2],
            "g": Palettes.translucent(Palettes.indigo[1], 70),
        ])
    }

    /// Reception desk with a monitor and a visitor badge tray, 22×14.
    private static func receptionDeskSprite() -> PixelSprite {
        let grid = [
            "      OOOOOOOO        ",
            "      OMMMMMMO        ",
            "      OMkkkkMO        ",
            "      OOOOOOOO        ",
            "OOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OwwwwwwwwwwwwwwwwwwwwO",
            "OOOOOOOOOOOOOOOOOOOOOO",
            "OIIIIIIIIIIIIIIIIIIIIO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OOOOOOOOOOOOOOOOOOOOOO",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "M": Palettes.ink[2],
            "k": Palettes.sky[2],
            "W": Palettes.stone[1],
            "w": Palettes.stone[2],
            "I": Palettes.indigo[2],
        ])
    }

    /// Elevator doors with a call panel and a floor indicator, 20×26.
    private static func elevatorDoorsSprite() -> PixelSprite {
        var grid = [
            "OOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWO",
            "OWWWWWWYYYYWWWWWWWWO",
            "OWWWWWWWWWWWWWWWWWWO",
            "OOOOOOOOOOOOOOOOOOOO",
        ]
        for row in 0..<20 {
            let seam = row == 0 || row == 19
            grid.append("O" + (seam ? String(repeating: "M", count: 18)
                                    : "MMMMMMMMOOMMMMMMMM") + "O")
        }
        grid.append("OOOOOOOOOOOOOOOOOOOO")
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.stone[1],
            "Y": Palettes.gold[1],
            "M": Palettes.stone[2],
        ])
    }

    /// Tall atrium fig in a white planter, 12×22.
    private static func atriumPlantSprite() -> PixelSprite {
        let grid = [
            "    LL      ",
            "   LLLL  LL ",
            "  LLlLLLLLLL",
            " LLLLLLlLLL ",
            "LLlLLLLLLL  ",
            " LLLLlLLLLL ",
            "  LLLLLLLL  ",
            "   LLlLL    ",
            "  LLLLLLL   ",
            " LLLLlLLLL  ",
            "  LLLLLLL   ",
            "    lTl     ",
            "     T      ",
            "     T      ",
            "     T      ",
            "    OOOO    ",
            "   OWWWWO   ",
            "   OWWWWO   ",
            "   OWwwWO   ",
            "   OWWWWO   ",
            "    OWWO    ",
            "    OOOO    ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "L": Palettes.moss[2],
            "l": Palettes.moss[3],
            "T": Palettes.sand[3],
            "W": Palettes.stone[0],
            "w": Palettes.stone[1],
        ])
    }

    // MARK: - Windows and light

    /// The window for a scene at a time of day and weather, 12×14.
    ///
    /// Office windows look onto a skyline; home windows onto a nearer,
    /// lower street with a tree. Both share the frame, the mullions and the
    /// sill, so a scene that mixes them still reads as one building.
    public static func window(
        style: WindowStyle,
        time: TimeOfDay = .day,
        weather: Weather = .clear
    ) -> PixelSprite {
        let width = 12, height = 14
        var canvas = PixelCanvas(width: width, height: height)
        let sky = skyTones(for: time)

        // Glass.
        canvas.fill(x: 0, y: 0, width: width, height: height, sky.top)
        for y in 1..<(height - 3) {
            let t = Double(y) / Double(height - 4)
            canvas.hLine(x: 1, y: y, length: width - 2, t > 0.55 ? sky.bottom : sky.top)
        }

        // Sun / moon.
        switch time {
        case .morning, .day:
            canvas.fill(x: 2, y: 2, width: 3, height: 3, Palettes.gold[0])
        case .dusk:
            canvas.fill(x: 2, y: 6, width: 3, height: 2, Palettes.gold[1])
        case .night:
            canvas.fill(x: 2, y: 2, width: 3, height: 3, Palettes.stone[0])
            canvas.set(x: 4, y: 2, sky.top)
            for (x, y) in [(7, 2), (9, 4), (6, 5), (10, 1)] { canvas.set(x: x, y: y, Palettes.gold[0]) }
        }

        // Skyline / street below the horizon.
        let silhouette = time == .night ? Palettes.ink[3] : Palettes.blended(sky.bottom, toward: Palettes.ink[3], amount: 0.45)
        switch style {
        case .office:
            let tops = [9, 7, 10, 8, 6, 9]
            for (index, top) in tops.enumerated() {
                let x = 1 + index * 2
                canvas.fill(x: x, y: top, width: 2, height: height - 3 - top, silhouette)
                if time.needsArtificialLight, index.isMultiple(of: 2) {
                    canvas.set(x: x, y: top + 1, Palettes.gold[1])
                }
            }
        case .home:
            canvas.fill(x: 1, y: 9, width: width - 2, height: 2, silhouette)
            canvas.fill(x: 3, y: 6, width: 3, height: 4, Palettes.moss[3])  // street tree
            canvas.set(x: 4, y: 10, Palettes.sand[4])
            if time.needsArtificialLight {
                canvas.set(x: 9, y: 8, Palettes.gold[1])                    // street lamp
                canvas.set(x: 9, y: 9, Palettes.stone[3])
            }
        }

        // Weather, drawn over the glass only.
        switch weather {
        case .clear:
            break
        case .rain:
            for y in 1..<(height - 3) {
                for x in 1..<(width - 1) where (x * 3 + y * 5) % 11 == 0 {
                    canvas.set(x: x, y: y, Palettes.translucent(Palettes.sky[0], 140))
                }
            }
        case .snow:
            for y in 1..<(height - 3) {
                for x in 1..<(width - 1) where (x * 5 + y * 7) % 13 == 0 {
                    canvas.set(x: x, y: y, Palettes.stone[0])
                }
            }
        }

        // Frame, mullions and sill on top of everything.
        for x in 0..<width {
            canvas.set(x: x, y: 0, Palettes.outline)
            canvas.set(x: x, y: 6, Palettes.outline)
            canvas.set(x: x, y: height - 3, Palettes.outline)
            canvas.set(x: x, y: height - 1, Palettes.outline)
        }
        for y in 0..<height {
            canvas.set(x: 0, y: y, Palettes.outline)
            canvas.set(x: width - 1, y: y, Palettes.outline)
            canvas.set(x: 5, y: y, Palettes.outline)
        }
        canvas.hLine(x: 1, y: height - 2, length: width - 2, Palettes.clay[2])
        return canvas.sprite()
    }

    /// (top, bottom) sky tones for the hour.
    private static func skyTones(for time: TimeOfDay) -> (top: RGBA, bottom: RGBA) {
        switch time {
        case .morning: (Palettes.sky[1], Palettes.gold[1])
        case .day: (Palettes.sky[2], Palettes.sky[1])
        case .dusk: (Palettes.plum[2], Palettes.ember[1])
        case .night: (Palettes.indigo[4], Palettes.indigo[3])
        }
    }

    /// A translucent tint laid over a whole room to sell the hour: cool and
    /// almost invisible in the morning, amber at dusk, deep indigo at night,
    /// and nothing at all at midday. Denser toward the ceiling, so the light
    /// looks like it is coming from the windows and lamps rather than from
    /// nowhere.
    public static func lightingOverlay(width: Int, height: Int, time: TimeOfDay) -> PixelSprite {
        let w = max(1, width)
        let h = max(1, height)
        guard time != .day else {
            return PixelSprite(frames: [PixelGrid.blank(width: w, height: h)], palette: [:])
        }

        let (tint, peak): (RGBA, Double) = {
            switch time {
            case .morning: (Palettes.sky[1], 0.10)
            case .day: (Palettes.stone[0], 0)
            case .dusk: (Palettes.ember[3], 0.18)
            case .night: (Palettes.indigo[4], 0.26)
            }
        }()

        var palette: [Character: RGBA] = [:]
        var rows: [String] = []
        // Five density bands, strongest at the top.
        let bands = 5
        for band in 0..<bands {
            let character = Character(UnicodeScalar(UInt8(65 + band)))
            let falloff = 1.0 - Double(band) / Double(bands) * 0.55
            palette[character] = Palettes.translucent(tint, UInt8(min(255, peak * falloff * 255)))
        }
        for y in 0..<h {
            let band = min(bands - 1, y * bands / h)
            rows.append(String(repeating: Character(UnicodeScalar(UInt8(65 + band))), count: w))
        }
        return PixelSprite(frames: [rows], palette: palette)
    }
}
