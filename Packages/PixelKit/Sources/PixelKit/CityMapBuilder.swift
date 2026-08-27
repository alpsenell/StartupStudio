import Foundation

/// Generates the city map's ground layer as one big sprite, the
/// `RoomBuilder` way: a pure per-pixel character function — district
/// ground tints with a deterministic speckle, asphalt roads with dashed
/// centerlines between the blocks, and a 1px outline frame. No randomness.
enum CityMapBuilder {
    static func ground() -> PixelSprite {
        let (width, height) = CityMapComposer.sceneSize()

        // Road bands between the district blocks (the district rects meet
        // on these centerlines).
        func isRoad(_ x: Int, _ y: Int) -> Bool {
            if y >= 76, y < 82 { return true }                       // horizontal spine
            if y < 76, (x >= 72 && x < 78) || (x >= 146 && x < 152) { return true }
            if y >= 82, x >= 86, x < 92 { return true }
            return false
        }

        func isDash(_ x: Int, _ y: Int) -> Bool {
            if y == 78 || y == 79 { return (x / 4) % 2 == 0 }        // horizontal centerline
            if y < 76, x == 74 || x == 75 || x == 148 || x == 149 { return (y / 4) % 2 == 0 }
            if y >= 82, x == 88 || x == 89 { return (y / 4) % 2 == 0 }
            return false
        }

        // District ground characters, keyed per style.
        let groundChar: [DistrictStyle: Character] = [
            .oldTown: "1", .suburbs: "2", .midtown: "3", .techPark: "4", .downtown: "5",
        ]
        let shadeChar: [DistrictStyle: Character] = [
            .oldTown: "6", .suburbs: "7", .midtown: "8", .techPark: "9", .downtown: "0",
        ]

        var rows: [String] = []
        rows.reserveCapacity(height)
        for y in 0..<height {
            var row = ""
            for x in 0..<width {
                if x == 0 || x == width - 1 || y == 0 || y == height - 1 {
                    row.append("O")
                } else if isRoad(x, y) {
                    row.append(isDash(x, y) ? "d" : "A")
                } else if let district = CityMapComposer.hitTest(x: x, y: y) {
                    // Deterministic speckle so blocks don't read flat.
                    let speckled = (x * 7 + y * 13) % 37 == 0
                    row.append(speckled ? shadeChar[district]! : groundChar[district]!)
                } else {
                    row.append("A")
                }
            }
            rows.append(row)
        }

        var palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "A": RGBA(r: 92, g: 92, b: 104),   // asphalt
            "d": RGBA(r: 214, g: 210, b: 190), // dashed centerline
        ]
        for style in DistrictStyle.allCases {
            let ground = style.ground
            palette[groundChar[style]!] = ground
            palette[shadeChar[style]!] = RGBA(
                r: UInt8(max(0, Int(ground.r) - 18)),
                g: UInt8(max(0, Int(ground.g) - 18)),
                b: UInt8(max(0, Int(ground.b) - 18))
            )
        }
        return PixelSprite(frames: [rows], palette: palette)
    }
}
