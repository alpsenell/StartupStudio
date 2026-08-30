import Foundation

/// Sprites for the city map: buildings (generated procedurally per size and
/// recolored per district — one generator, many looks), the player's own
/// headquarters growing tier by tier, rival HQs flying their founder's
/// portrait, a few hand-authored landmarks, and the traffic that makes the
/// place look inhabited.
public enum CitySpriteLibrary {
    // MARK: - Buildings

    /// A front-facing building: outlined wall block with a roof band and a
    /// window grid. Two frames — windows dark, windows lit — driven with
    /// `.glow`. Deterministic per (width, height, district, time).
    ///
    /// The hour changes the walls, not just the windows: at night the whole
    /// block drops toward ink and only the lit grid stays bright, which is
    /// what makes a night city read as a night city.
    public static func building(
        width: Int, height: Int, district: DistrictStyle, time: TimeOfDay = .day
    ) -> PixelSprite {
        let w = max(8, width)
        let h = max(10, height)
        var dark: [String] = []

        for y in 0..<h {
            var row = ""
            for x in 0..<w {
                let edge = x == 0 || x == w - 1 || y == 0 || y == h - 1
                if edge {
                    row.append("O")
                } else if y <= 2 {
                    row.append(y == 2 ? "r" : "R")
                } else if y >= h - 4, x >= w / 2 - 1, x <= w / 2 {
                    row.append("D")
                } else if y >= 4, y < h - 3, (y - 4) % 3 != 2, x >= 2, x <= w - 3,
                          (x - 2) % 3 != 2 {
                    row.append("G")
                } else {
                    row.append(x >= w - 3 ? "w" : "W")
                }
            }
            dark.append(row)
        }
        // At night most windows are lit; by day only a scattering.
        let lit = dark.enumerated().map { y, row in
            String(row.enumerated().map { x, character -> Character in
                guard character == "G" else { return character }
                return (x * 7 + y * 5) % 4 != 0 ? "L" : "G"
            })
        }

        let night = time.darkness
        let wall = district.wall
        let roof = district.roof
        return PixelSprite(frames: [dark, lit], palette: [
            "O": Palettes.outline,
            "W": Palettes.shaded(wall.base, by: night), "w": Palettes.shaded(wall.shade, by: night),
            "R": Palettes.shaded(roof.base, by: night), "r": Palettes.shaded(roof.shade, by: night),
            "G": Palettes.ink[2],
            "L": time.needsArtificialLight ? Palettes.gold[1] : Palettes.sky[1],
            "D": Palettes.sand[4],
        ])
    }

    // MARK: - Headquarters

    /// The player's headquarters, growing with the office tier: a lock-up
    /// with the shutter half open, a brick loft, a glass studio, and finally
    /// a tower. Every version carries the indigo sign, so the eye finds it
    /// on the map without a legend.
    public static func playerHQ(tier: OfficeTierStyle, time: TimeOfDay = .day) -> PixelSprite {
        let size: (width: Int, height: Int)
        switch tier {
        case .garage: size = (18, 16)
        case .loft: size = (20, 24)
        case .studio: size = (22, 34)
        case .campus: size = (26, 46)
        }
        var canvas = PixelCanvas(width: size.width, height: size.height)
        let night = time.darkness
        let body = Palettes.shaded(tier == .garage ? Palettes.clay[2] : Palettes.stone[1], by: night)
        let bodyShade = Palettes.shaded(tier == .garage ? Palettes.clay[3] : Palettes.stone[2], by: night)
        let glass = time.needsArtificialLight ? Palettes.gold[1] : Palettes.sky[2]

        canvas.fill(x: 0, y: 0, width: size.width, height: size.height, body)
        canvas.fill(x: size.width - 3, y: 0, width: 3, height: size.height, bodyShade)

        // Roof / crown.
        canvas.fill(x: 0, y: 0, width: size.width, height: 3, Palettes.shaded(Palettes.indigo[3], by: night))
        if tier == .campus {
            // A mast on the crown, so the tower reads as the tallest thing
            // on the block even at map scale.
            canvas.fill(x: size.width / 2 - 1, y: 0, width: 2, height: 2, Palettes.stone[3])
        }

        // The indigo sign band, with the company initial punched out.
        let signY = 4
        canvas.fill(x: 1, y: signY, width: size.width - 2, height: 5, Palettes.indigo[2])
        canvas.fill(x: 3, y: signY + 1, width: 2, height: 3, Palettes.stone[0])
        canvas.fill(x: 6, y: signY + 1, width: 1, height: 3, Palettes.stone[0])
        canvas.fill(x: 8, y: signY + 1, width: 2, height: 1, Palettes.stone[0])
        canvas.fill(x: 8, y: signY + 3, width: 2, height: 1, Palettes.stone[0])

        // Windows below the sign.
        var y = signY + 7
        while y < size.height - 6 {
            var x = 2
            while x < size.width - 3 {
                let lit = ((x + y) / 3) % 3 != 0
                canvas.fill(x: x, y: y, width: 2, height: 2, lit ? glass : Palettes.ink[2])
                x += 4
            }
            y += 4
        }

        // Door, or the garage's roller shutter.
        if tier == .garage {
            canvas.fill(x: 3, y: size.height - 7, width: size.width - 7, height: 6, Palettes.stone[3])
            for row in stride(from: size.height - 7, to: size.height - 1, by: 2) {
                canvas.hLine(x: 3, y: row, length: size.width - 7, Palettes.stone[4])
            }
        } else {
            canvas.fill(x: size.width / 2 - 2, y: size.height - 6, width: 4, height: 5, Palettes.sand[4])
            canvas.fill(x: size.width / 2 - 1, y: size.height - 5, width: 2, height: 3, glass)
        }

        // Outline last.
        for x in 0..<size.width {
            canvas.set(x: x, y: 0, Palettes.outline)
            canvas.set(x: x, y: size.height - 1, Palettes.outline)
        }
        for row in 0..<size.height {
            canvas.set(x: 0, y: row, Palettes.outline)
            canvas.set(x: size.width - 1, y: row, Palettes.outline)
        }

        // A second frame with the sign glow pulsing. `PixelCanvas` is a
        // value type, so copying it keeps the grid *and* the palette keys.
        var glowing = canvas
        glowing.fill(x: 1, y: signY, width: size.width - 2, height: 1, Palettes.indigo[1])
        glowing.fill(x: 1, y: signY + 4, width: size.width - 2, height: 1, Palettes.indigo[1])
        return canvas.sprite(followedBy: [glowing])
    }

    /// A rival's headquarters: a plain block under a red banner, with the
    /// rival founder's portrait pinned to the front. It is the same portrait
    /// the Rivals screen shows, so the map and the roster agree.
    public static func rivalHQ(seed: UInt64, district: DistrictStyle, time: TimeOfDay = .day) -> PixelSprite {
        let width = 20, height = 26
        var canvas = PixelCanvas(width: width, height: height)
        let night = time.darkness
        canvas.fill(x: 0, y: 0, width: width, height: height, Palettes.shaded(district.wall.base, by: night))
        canvas.fill(x: width - 3, y: 0, width: 3, height: height, Palettes.shaded(district.wall.shade, by: night))
        canvas.fill(x: 0, y: 0, width: width, height: 3, Palettes.ember[3])

        // Portrait pin: the founder's face on a small plaque.
        let portrait = SpriteLibrary.person(appearance: CharacterAppearance(seed: seed), pose: .portrait)
        canvas.fill(x: 3, y: 4, width: 12, height: 12, Palettes.stone[0])
        canvas.stamp(portrait, x: 4, y: 5)
        for x in 3..<15 {
            canvas.set(x: x, y: 4, Palettes.outline)
            canvas.set(x: x, y: 15, Palettes.outline)
        }
        for y in 4..<16 {
            canvas.set(x: 3, y: y, Palettes.outline)
            canvas.set(x: 14, y: y, Palettes.outline)
        }

        // Windows and door.
        let glass = time.needsArtificialLight ? Palettes.gold[2] : Palettes.sky[3]
        for x in stride(from: 2, to: width - 3, by: 4) {
            canvas.fill(x: x, y: 18, width: 2, height: 2, glass)
        }
        canvas.fill(x: width / 2 - 2, y: height - 5, width: 4, height: 4, Palettes.sand[4])

        for x in 0..<width {
            canvas.set(x: x, y: 0, Palettes.outline)
            canvas.set(x: x, y: height - 1, Palettes.outline)
        }
        for y in 0..<height {
            canvas.set(x: 0, y: y, Palettes.outline)
            canvas.set(x: width - 1, y: y, Palettes.outline)
        }

        var flapped = canvas
        flapped.fill(x: 1, y: 2, width: width - 2, height: 1, Palettes.ember[2])
        return canvas.sprite(followedBy: [flapped])
    }

    // MARK: - Traffic

    /// A lane of traffic: cars spaced along a strip as wide as the road,
    /// nudged a few pixels between the two frames so the flow reads as
    /// movement rather than as a jump.
    public static func trafficLane(width: Int, eastbound: Bool, time: TimeOfDay = .day) -> PixelSprite {
        let spacing = 34
        let carWidth = 11
        let height = 4

        func paint(into canvas: inout PixelCanvas, offset: Int) {
            var x = eastbound ? offset : width - offset - carWidth
            let step = eastbound ? spacing : -spacing
            while x > -carWidth && x < width {
                car(into: &canvas, x: x, y: 0, tint: (abs(x) / spacing) % 3, time: time)
                x += step
            }
        }

        func car(into canvas: inout PixelCanvas, x: Int, y: Int, tint: Int, time: TimeOfDay) {
            let body = [Palettes.ember[2], Palettes.teal[2], Palettes.stone[0]][tint % 3]
            canvas.fill(x: x + 1, y: y + 1, width: carWidth - 2, height: 2, body)
            canvas.fill(x: x + 3, y: y, width: 5, height: 1, Palettes.blended(body, toward: Palettes.ink[4], amount: 0.3))
            canvas.hLine(x: x + 1, y: y + 3, length: carWidth - 2, Palettes.ink[4])
            // Headlights lead the way; tail lights trail it.
            let front = eastbound ? x + carWidth - 1 : x
            let back = eastbound ? x : x + carWidth - 1
            canvas.set(x: front, y: y + 1, time.needsArtificialLight ? Palettes.gold[0] : Palettes.stone[1])
            canvas.set(x: back, y: y + 1, Palettes.ember[3])
        }

        var a = PixelCanvas(width: max(carWidth, width), height: height)
        paint(into: &a, offset: 0)
        var b = PixelCanvas(like: a)
        paint(into: &b, offset: 5)
        return a.sprite(followedBy: [b])
    }

    /// A streetlight, 3×10, dark by day and pooling gold at night.
    public static func streetlight(time: TimeOfDay = .day) -> PixelSprite {
        let lampOn = time.needsArtificialLight
        var canvas = PixelCanvas(width: 3, height: 10)
        canvas.vLine(x: 1, y: 2, length: 8, Palettes.stone[4])
        canvas.fill(x: 0, y: 0, width: 3, height: 2, lampOn ? Palettes.gold[0] : Palettes.stone[2])
        var pulsed = canvas
        if lampOn {
            pulsed.fill(x: 0, y: 2, width: 3, height: 1, Palettes.translucent(Palettes.gold[1], 120))
        }
        return canvas.sprite(followedBy: [pulsed])
    }

    // MARK: - Landmarks

    /// A round-crown park tree, tinted for the season.
    public static func tree(season: Season = .summer) -> PixelSprite {
        let grid = [
            "   OOOO   ",
            "  OFFFFO  ",
            " OFFGFFFO ",
            " OFGFFFFO ",
            " OFFFFGFO ",
            "  OFFFFO  ",
            "   OOOO   ",
            "    OT    ",
            "    OT    ",
            "   OTTO   ",
        ]
        let foliage = season.foliage
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "F": foliage.base,
            "G": foliage.highlight,
            "T": Palettes.sand[3],
        ])
    }

    /// A blinking radio mast (tech park). Two frames: beacon off / on.
    public static func antenna() -> PixelSprite {
        let off = [
            "    B    ",
            "    O    ",
            "   OMO   ",
            "    M    ",
            "   OMO   ",
            "    M    ",
            "  O M O  ",
            "   OMO   ",
            "  OMMMO  ",
            " OMMMMMO ",
        ]
        let on = off.enumerated().map { index, row in
            index == 0 ? row.replacingOccurrences(of: "B", with: "b") : row
        }
        return PixelSprite(frames: [off, on], palette: [
            "O": Palettes.outline,
            "M": Palettes.stone[2],
            "B": Palettes.ember[4],
            "b": Palettes.ember[2],
        ])
    }

    /// An old-town clock tower.
    public static func clockTower() -> PixelSprite {
        let grid = [
            "   OO   ",
            "  ORRO  ",
            " ORRRRO ",
            " OWCCWO ",
            " OWCcWO ",
            " OWWWWO ",
            " OWGWGO ",
            " OWWWWO ",
            " OWGWGO ",
            " OWWWWO ",
            " OWWDWO ",
            " OOOOOO ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "R": Palettes.ember[3],
            "W": Palettes.sand[1],
            "C": Palettes.stone[0],
            "c": Palettes.ink[3],
            "G": Palettes.ink[2],
            "D": Palettes.sand[4],
        ])
    }

    // MARK: - Markers

    /// The player's HQ flag: indigo pennant on a pole, waving (2 frames).
    public static func officeMarker() -> PixelSprite {
        let a = [
            " PFFF  ",
            " PFFFF ",
            " PFFF  ",
            " P     ",
            " P     ",
            " P     ",
            "OPO    ",
        ]
        let b = [
            " PFF   ",
            " PFFFF ",
            " PFFF  ",
            " P F   ",
            " P     ",
            " P     ",
            "OPO    ",
        ]
        return PixelSprite(frames: [a, b], palette: [
            "O": Palettes.outline,
            "P": Palettes.stone[3],
            "F": Palettes.indigo[2],
        ])
    }

    /// A rival HQ pin: small red banner (2-frame bob).
    public static func rivalMarker() -> PixelSprite {
        let a = [
            " RRR ",
            " RRR ",
            " RwR ",
            "  P  ",
            "  P  ",
            " OPO ",
        ]
        let b = [
            "     ",
            " RRR ",
            " RwR ",
            "  RP ",
            "  P  ",
            " OPO ",
        ]
        return PixelSprite(frames: [a, b], palette: [
            "O": Palettes.outline,
            "P": Palettes.stone[3],
            "R": Palettes.ember[3],
            "w": Palettes.stone[0],
        ])
    }

    // MARK: - Selection

    /// A pulsing dashed border sized to a district rect. Two frames with
    /// the dash phase flipped, driven with `.toggle`.
    public static func selectionBorder(width: Int, height: Int) -> PixelSprite {
        func frame(phase: Int) -> [String] {
            (0..<height).map { y in
                String((0..<width).map { x -> Character in
                    let edge = x == 0 || x == width - 1 || y == 0 || y == height - 1
                    guard edge else { return " " }
                    return (x + y + phase) % 4 < 2 ? "S" : " "
                })
            }
        }
        return PixelSprite(frames: [frame(phase: 0), frame(phase: 2)], palette: [
            "S": Palettes.gold[1],
        ])
    }
}
