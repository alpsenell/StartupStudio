import Foundation

/// Sprites for the market map: the ground plate the districts sit on, a
/// district block per standing band and size, the studio's own buildings,
/// the incumbent's fortress, the siege marker over a category fight, and
/// the weather the forecast is drawn as.
///
/// Every colour is a master palette colour — `MarketMapPaletteTests`
/// checks each of these against `Palettes.master`.
public enum MarketSpriteLibrary {
    // MARK: - Plate

    /// The ground layer, one sprite: a 1px frame, dark roads between the
    /// cells with a dashed centreline, a plot under each block area, and
    /// the name strip above it where the app lays the district's label.
    public static func plate() -> PixelSprite {
        let (width, height) = MarketMapLayout.sceneSize
        var canvas = PixelCanvas(width: width, height: height)
        canvas.fill(x: 0, y: 0, width: width, height: height, Palettes.ink[2])

        for index in 0..<MarketMapLayout.slots {
            guard let strip = MarketMapLayout.stripFrame(index: index),
                  let area = MarketMapLayout.blockAreaFrame(index: index)
            else { continue }
            // The plot: a shade lighter than the road, so a shrunk block
            // reads as a small district on its own lot.
            canvas.fill(x: area.x, y: area.y, width: area.width, height: area.height, Palettes.stone[4])
            // The strip, outlined so the label has a plate to sit on.
            canvas.fill(x: strip.x, y: strip.y, width: strip.width, height: strip.height, Palettes.ink[3])
            canvas.hLine(x: strip.x, y: strip.y, length: strip.width, Palettes.ink[4])
            canvas.hLine(x: strip.x, y: strip.y + strip.height - 1, length: strip.width, Palettes.ink[4])
            canvas.vLine(x: strip.x, y: strip.y, length: strip.height, Palettes.ink[4])
            canvas.vLine(x: strip.x + strip.width - 1, y: strip.y, length: strip.height, Palettes.ink[4])
        }

        // Dashed centrelines down the roads, the city map's own habit.
        let margin = MarketMapLayout.margin
        let gap = MarketMapLayout.gap
        for column in 1..<MarketMapLayout.columns {
            let x = margin + column * (MarketMapLayout.cellWidth + gap) - gap
            for y in stride(from: margin, to: height - margin, by: 4) {
                canvas.fill(x: x, y: y, width: gap, height: 2, Palettes.ink[1])
            }
        }
        for row in 1..<MarketMapLayout.rows {
            let y = margin + row * (MarketMapLayout.cellHeight + gap) - gap
            for x in stride(from: margin, to: width - margin, by: 4) {
                canvas.fill(x: x, y: y, width: 2, height: gap, Palettes.ink[1])
            }
        }

        // The frame last.
        canvas.hLine(x: 0, y: 0, length: width, Palettes.outline)
        canvas.hLine(x: 0, y: height - 1, length: width, Palettes.outline)
        canvas.vLine(x: 0, y: 0, length: height, Palettes.outline)
        canvas.vLine(x: width - 1, y: 0, length: height, Palettes.outline)
        return canvas.sprite()
    }

    // MARK: - Districts

    /// A district block: the band's ground with a bevel — lighter along
    /// the top and left, deeper along the bottom and right — a sparse
    /// speckle so a flat colour reads as ground, and the universal outline.
    public static func districtBlock(side: Int, band: StandingBand) -> PixelSprite {
        let side = max(4, side)
        var canvas = PixelCanvas(width: side, height: side)
        let ground = band.ground
        let light = Palettes.stepped(ground, by: -1)
        let deep = Palettes.stepped(ground, by: 1)

        canvas.fill(x: 0, y: 0, width: side, height: side, ground)
        for y in 2..<(side - 2) {
            for x in 2..<(side - 2) where (x * 7 + y * 13) % 29 == 0 {
                canvas.set(x: x, y: y, deep)
            }
        }
        canvas.hLine(x: 1, y: 1, length: side - 2, light)
        canvas.vLine(x: 1, y: 1, length: side - 2, light)
        canvas.hLine(x: 1, y: side - 2, length: side - 2, deep)
        canvas.vLine(x: side - 2, y: 1, length: side - 2, deep)

        canvas.hLine(x: 0, y: 0, length: side, Palettes.outline)
        canvas.hLine(x: 0, y: side - 1, length: side, Palettes.outline)
        canvas.vLine(x: 0, y: 0, length: side, Palettes.outline)
        canvas.vLine(x: side - 1, y: 0, length: side, Palettes.outline)
        return canvas.sprite()
    }

    // MARK: - Markers

    /// One of the studio's own products on the market here: a 5×6 house
    /// with the indigo roof the player's HQ wears on the city map. Two
    /// frames — window dark, window lit — for `.glow`.
    public static func playerBuilding() -> PixelSprite {
        let dark = [
            " III ",
            "IIIII",
            "OWWWO",
            "OWGWO",
            "OWWWO",
            "OODOO",
        ]
        let lit = dark.map { $0.replacingOccurrences(of: "G", with: "L") }
        return PixelSprite(frames: [dark, lit], palette: [
            "O": Palettes.outline,
            "I": Palettes.indigo[3],
            "W": Palettes.stone[0],
            "G": Palettes.sky[2],
            "L": Palettes.gold[1],
            "D": Palettes.sand[4],
        ])
    }

    /// A rival selling here: the same red banner pin the city map plants
    /// on a rival's HQ, so the two maps agree on what a rival looks like.
    public static func rivalFlag() -> PixelSprite {
        CitySpriteLibrary.rivalMarker()
    }

    /// The incumbent's fortress, 9×8: battlements, arrow slits and a gate,
    /// in the dark stone nothing else on the map is built from. Two
    /// frames — a slit lit, a slit dark — for `.glow`.
    public static func fortress() -> PixelSprite {
        let dark = [
            "M M M M M",
            "OMMMMMMMO",
            "OMSMMMSMO",
            "OMMMMMMMO",
            "OMSMMMSMO",
            "OMMOOOMMO",
            "OMOGGGOMO",
            "OOOOOOOOO",
        ]
        var lit = dark
        lit[2] = "OMLMMMSMO"
        lit[4] = "OMSMMMLMO"
        return PixelSprite(frames: [dark, lit], palette: [
            "O": Palettes.outline,
            "M": Palettes.stone[3],
            "S": Palettes.ink[3],
            "L": Palettes.gold[2],
            "G": Palettes.sand[4],
        ])
    }

    /// A category fight in progress: crossed swords over the district,
    /// 7×7, one blade steel and one the rival's red, clashing between the
    /// two frames.
    public static func siegeMarker() -> PixelSprite {
        let a = [
            "S     R",
            " S   R ",
            "  S R  ",
            "   H   ",
            "  R S  ",
            " R   S ",
            "R     S",
        ]
        let b = [
            "       ",
            "S    R ",
            " S  R  ",
            "  SH   ",
            "  R S  ",
            " R   S ",
            "R     S",
        ]
        return PixelSprite(frames: [a, b], palette: [
            "S": Palettes.stone[0],
            "R": Palettes.ember[2],
            "H": Palettes.gold[2],
        ])
    }

    // MARK: - Weather

    /// The forecast over a held district, 7×5, two frames each: the sun's
    /// rays turn, the cloud drifts, the rain falls, the lightning flashes.
    public static func weather(_ weather: MarketWeather) -> PixelSprite {
        switch weather {
        case .sunny:
            let a = [
                " R R R ",
                "  GGG  ",
                "RGGGGGR",
                "  GGG  ",
                " R R R ",
            ]
            let b = [
                "R  R  R",
                "  GGG  ",
                " GGGGG ",
                "  GGG  ",
                "R  R  R",
            ]
            return PixelSprite(frames: [a, b], palette: [
                "G": Palettes.gold[1],
                "R": Palettes.gold[2],
            ])
        case .overcast:
            let a = [
                "  CCC  ",
                " CCCCC ",
                "CCCCCCC",
                " ccccc ",
                "       ",
            ]
            let b = [
                "   CCC ",
                "  CCCCC",
                " CCCCCC",
                "  ccccc",
                "       ",
            ]
            return PixelSprite(frames: [a, b], palette: [
                "C": Palettes.stone[0],
                "c": Palettes.stone[1],
            ])
        case .rain:
            let a = [
                "  CCC  ",
                " CCCCC ",
                "CCCCCCC",
                " d d d ",
                "d d d  ",
            ]
            let b = [
                "  CCC  ",
                " CCCCC ",
                "CCCCCCC",
                "d d d  ",
                " d d d ",
            ]
            return PixelSprite(frames: [a, b], palette: [
                "C": Palettes.stone[2],
                "d": Palettes.sky[2],
            ])
        case .storm:
            let a = [
                "  CCC  ",
                " CCCCC ",
                "CCCCCCC",
                "   L   ",
                "  L    ",
            ]
            let b = [
                "  CCC  ",
                " CCCCC ",
                "CCCCCCC",
                "       ",
                "       ",
            ]
            return PixelSprite(frames: [a, b], palette: [
                "C": Palettes.ink[1],
                "L": Palettes.gold[1],
            ])
        }
    }
}
