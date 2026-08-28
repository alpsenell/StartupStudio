import Foundation

/// Generates the city map's ground layer as one big sprite: district ground
/// tints with a deterministic speckle, asphalt roads with dashed
/// centrelines between the blocks, pavements along every road edge, and a
/// 1px outline frame. The hour darkens the whole plate, so buildings and
/// traffic sit in the same light. No randomness.
enum CityMapBuilder {
    /// Whether a scene pixel is on a road.
    static func isRoad(_ x: Int, _ y: Int) -> Bool {
        if y >= 76, y < 82 { return true }                       // horizontal spine
        if y < 76, (x >= 72 && x < 78) || (x >= 146 && x < 152) { return true }
        if y >= 82, x >= 86, x < 92 { return true }
        return false
    }

    static func ground(time: TimeOfDay = .day, season: Season = .summer) -> PixelSprite {
        let (width, height) = CityMapComposer.sceneSize()
        let night = time.darkness

        func isDash(_ x: Int, _ y: Int) -> Bool {
            if y == 78 || y == 79 { return (x / 4) % 2 == 0 }
            if y < 76, x == 74 || x == 75 || x == 148 || x == 149 { return (y / 4) % 2 == 0 }
            if y >= 82, x == 88 || x == 89 { return (y / 4) % 2 == 0 }
            return false
        }
        /// The pavement strip: the pixel row/column just outside a road.
        func isPavement(_ x: Int, _ y: Int) -> Bool {
            guard !isRoad(x, y) else { return false }
            return isRoad(x + 1, y) || isRoad(x - 1, y) || isRoad(x, y + 1) || isRoad(x, y - 1)
        }

        let asphalt = Palettes.shaded(Palettes.ink[1], by: night)
        let dash = Palettes.shaded(Palettes.stone[1], by: night * 0.5)
        let pavement = Palettes.shaded(Palettes.stone[2], by: night)

        var canvas = PixelCanvas(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                if x == 0 || x == width - 1 || y == 0 || y == height - 1 {
                    canvas.set(x: x, y: y, Palettes.outline)
                } else if isRoad(x, y) {
                    canvas.set(x: x, y: y, isDash(x, y) ? dash : asphalt)
                } else if isPavement(x, y) {
                    canvas.set(x: x, y: y, pavement)
                } else if let district = CityMapComposer.hitTest(x: x, y: y) {
                    let base = groundTone(for: district, season: season)
                    let speckled = (x * 7 + y * 13) % 37 == 0
                    canvas.set(x: x, y: y, Palettes.shaded(speckled ? base.shade : base.base, by: night))
                } else {
                    canvas.set(x: x, y: y, asphalt)
                }
            }
        }
        return canvas.sprite()
    }

    /// A district's ground, with the suburbs' lawns following the season —
    /// the one block where the colour of the grass is the whole character.
    private static func groundTone(for district: DistrictStyle, season: Season) -> (base: RGBA, shade: RGBA) {
        guard district == .suburbs else {
            return (district.ground, Palettes.shaded(district.ground, by: 0.16))
        }
        switch season {
        case .spring: return (Palettes.moss[1], Palettes.moss[2])
        case .summer: return (Palettes.moss[2], Palettes.moss[3])
        case .autumn: return (Palettes.gold[3], Palettes.sand[3])
        case .winter: return (Palettes.stone[1], Palettes.stone[2])
        }
    }
}
