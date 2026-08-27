import Foundation

/// Sprites for the city map: buildings (generated procedurally per size
/// and recolored per district — one generator, many looks), a few
/// hand-authored landmarks, HQ markers, and the selection border.
public enum CitySpriteLibrary {
    // MARK: - Buildings

    /// A front-facing building: outlined wall block with a roof band and a
    /// window grid. Two frames — windows dark, windows lit — driven with
    /// `.glow`. Deterministic per (width, height, district).
    ///
    /// Characters: `O` outline, `W`/`w` wall, `R`/`r` roof, `G` dark
    /// window, `L` lit window, `D` door.
    public static func building(width: Int, height: Int, district: DistrictStyle) -> PixelSprite {
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
                    // Roof band with a shaded underside.
                    row.append(y == 2 ? "r" : "R")
                } else if y >= h - 4, x >= w / 2 - 1, x <= w / 2 {
                    // Door, two pixels wide, centered.
                    row.append("D")
                } else if y >= 4, y < h - 3, (y - 4) % 3 != 2, x >= 2, x <= w - 3,
                          (x - 2) % 3 != 2 {
                    // 2×2 windows on a 3-pixel grid.
                    row.append("G")
                } else {
                    // Wall with a shaded right edge.
                    row.append(x >= w - 3 ? "w" : "W")
                }
            }
            dark.append(row)
        }
        let lit = dark.map { $0.replacingOccurrences(of: "G", with: "L") }

        let wall = district.wall
        let roof = district.roof
        return PixelSprite(frames: [dark, lit], palette: [
            "O": Palettes.outline,
            "W": wall.base, "w": wall.shade,
            "R": roof.base, "r": roof.shade,
            "G": RGBA(r: 62, g: 64, b: 84),
            "L": RGBA(r: 255, g: 224, b: 130),
            "D": RGBA(r: 70, g: 56, b: 46),
        ])
    }

    // MARK: - Landmarks

    /// A round-crown park tree (suburbs, midtown greens).
    public static func tree() -> PixelSprite {
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
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "F": RGBA(r: 96, g: 148, b: 86),
            "G": RGBA(r: 122, g: 174, b: 104),
            "T": RGBA(r: 118, g: 86, b: 58),
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
            "M": RGBA(r: 148, g: 154, b: 170),
            "B": RGBA(r: 90, g: 40, b: 44),
            "b": RGBA(r: 240, g: 84, b: 90),
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
            "R": RGBA(r: 152, g: 76, b: 62),
            "W": RGBA(r: 206, g: 176, b: 140),
            "C": RGBA(r: 240, g: 238, b: 224),
            "c": RGBA(r: 70, g: 66, b: 60),
            "G": RGBA(r: 62, g: 64, b: 84),
            "D": RGBA(r: 70, g: 56, b: 46),
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
            "P": RGBA(r: 120, g: 116, b: 130),
            "F": RGBA(r: 94, g: 96, b: 206),
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
            "P": RGBA(r: 120, g: 116, b: 130),
            "R": RGBA(r: 196, g: 87, b: 78),
            "w": RGBA(r: 236, g: 220, b: 210),
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
            "S": RGBA(r: 255, g: 236, b: 120),
        ])
    }
}
