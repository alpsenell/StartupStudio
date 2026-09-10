import Foundation

/// Generates the city map's ground layer as one big sprite: district ground
/// (Suburbs lawns, Old Town cobbles, Midtown concrete, Tech Park slate,
/// Downtown asphalt-grey) with a deterministic speckle, asphalt roads with
/// dashed centrelines and zebra crossings, pavements along every road edge,
/// the Midtown park with its pond and paths, the Tech Park car park, the
/// Downtown plaza, the river with its quay, bridge and far bank, and a 1px
/// outline frame. The hour darkens the whole plate, so buildings and
/// traffic sit in the same light; the season recolors every lawn. No
/// randomness. The composer caches one plate per (hour, season).
enum CityMapBuilder {
    // MARK: S4 (city) — the street plan

    /// The east–west spine between the two rows of districts: ten rows,
    /// an eastbound lane on top and a westbound lane under it.
    static let spine = 103..<113
    /// The two avenues north of the spine.
    static let northAvenues = [104..<110, 212..<218]
    /// The avenue south of the spine, which crosses the river as a bridge.
    static let southAvenue = 126..<132
    /// The Suburbs' residential lane, west of the first avenue.
    static let suburbsLane = 50..<54
    /// The quay, the river and the far bank (the last row is the frame).
    static let quay = 199..<202
    static let river = 202..<216
    static let farBank = 216..<223
    /// The Midtown park, its pond (an ellipse) and its paths.
    static let parkX = 150..<208, parkY = 5..<50
    static let pondCenter = (x: 165, y: 18), pondRadius = (x: 9, y: 5)
    /// The Tech Park car park.
    static let carParkX = 220..<250, carParkY = 66..<101
    /// The Downtown plaza between the south towers.
    static let plazaX = 174..<211, plazaY = 155..<199

    /// Whether a scene pixel is on a road (the bridge included).
    static func isRoad(_ x: Int, _ y: Int) -> Bool {
        if spine.contains(y) { return true }
        if y < spine.lowerBound, northAvenues.contains(where: { $0.contains(x) }) { return true }
        if y >= spine.upperBound, y < farBank.upperBound, southAvenue.contains(x) { return true }
        if suburbsLane.contains(y), x < northAvenues[0].lowerBound { return true }
        return false
    }

    static func ground(time: TimeOfDay = .day, season: Season = .summer) -> PixelSprite {
        let (width, height) = CityMapComposer.sceneSize()
        let night = time.darkness
        let lampsOn = time.needsArtificialLight

        func shade(_ color: RGBA) -> RGBA { Palettes.shaded(color, by: night) }

        let asphalt = shade(Palettes.ink[1])
        let dash = Palettes.shaded(Palettes.stone[1], by: night * 0.5)
        let zebra = Palettes.shaded(Palettes.stone[0], by: night * 0.6)
        let pavement = shade(Palettes.stone[2])
        let lampPool = Palettes.gold[3]
        let grass = lawn(season)
        let hedge = shade(Palettes.stepped(grass.shade, by: 1))
        let path = shade(season == .winter ? Palettes.stone[2] : Palettes.sand[1])
        let water = (base: shade(Palettes.sky[3]), ripple: shade(Palettes.sky[2]))
        let ice = (base: shade(Palettes.sky[1]), ripple: shade(Palettes.stone[0]))
        let railing = shade(Palettes.stone[3])

        // Pools of lamplight on the spine's north pavement after dark.
        let lampColumns: Set<Int> = lampsOn
            ? Set(CityMapComposer.spineLampXs.flatMap { [$0 - 1, $0, $0 + 1, $0 + 2, $0 + 3] })
            : []

        func isDash(_ x: Int, _ y: Int) -> Bool {
            if y == 107 || y == 108 {
                if northAvenues.contains(where: { $0.contains(x) }) || southAvenue.contains(x) { return false }
                return (x / 4) % 2 == 0
            }
            if y < spine.lowerBound {
                for avenue in northAvenues where x == avenue.lowerBound + 2 || x == avenue.lowerBound + 3 {
                    return (y / 4) % 2 == 0
                }
            }
            if y >= spine.upperBound, x == southAvenue.lowerBound + 2 || x == southAvenue.lowerBound + 3 {
                return (y / 4) % 2 == 0
            }
            return false
        }

        /// Zebra crossings: across each avenue where it meets the spine,
        /// and across the spine beside each junction.
        func isZebra(_ x: Int, _ y: Int) -> Bool {
            if (97..<102).contains(y), northAvenues.contains(where: { $0.contains(x) }) { return x % 2 == 0 }
            if (114..<119).contains(y), southAvenue.contains(x) { return x % 2 == 0 }
            if spine.contains(y), (96..<102).contains(x) || (204..<210).contains(x) || (118..<124).contains(x) {
                return y % 2 == 1
            }
            return false
        }

        func isRiverSide(_ y: Int) -> Bool { y >= quay.lowerBound }

        /// The pixel row/column just outside a road.
        func isPavement(_ x: Int, _ y: Int) -> Bool {
            guard !isRoad(x, y), !isRiverSide(y) else { return false }
            return isRoad(x + 1, y) || isRoad(x - 1, y) || isRoad(x, y + 1) || isRoad(x, y - 1)
        }

        var canvas = PixelCanvas(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                let color: RGBA
                if x == 0 || x == width - 1 || y == 0 || y == height - 1 {
                    color = Palettes.outline
                } else if (quay.lowerBound..<(farBank.lowerBound + 1)).contains(y),
                          x == southAvenue.lowerBound - 1 || x == southAvenue.upperBound {
                    color = railing                                  // the bridge's parapets
                } else if isRoad(x, y) {
                    color = isZebra(x, y) ? zebra : (isDash(x, y) ? dash : asphalt)
                } else if river.contains(y) {
                    color = riverPixel(x, y, season: season, time: time, water: water, ice: ice)
                } else if quay.contains(y) {
                    color = shade([Palettes.stone[1], Palettes.stone[2], Palettes.stone[3]][y - quay.lowerBound])
                } else if farBank.contains(y) {
                    if y == farBank.lowerBound {
                        color = shade(Palettes.stone[3])
                    } else if y == farBank.lowerBound + 4 {
                        color = path
                    } else {
                        color = shade((x * 5 + y * 3) % 17 == 0 ? grass.shade : grass.base)
                    }
                } else if isPavement(x, y) {
                    color = (y == spine.lowerBound - 1 && lampColumns.contains(x)) ? lampPool : pavement
                } else if parkX.contains(x), parkY.contains(y) {
                    color = parkPixel(x, y, season: season, grass: grass, hedge: hedge, path: path, shade: shade)
                } else if carParkX.contains(x), carParkY.contains(y) {
                    color = carParkPixel(x, y, shade: shade, asphalt: asphalt)
                } else if plazaX.contains(x), plazaY.contains(y) {
                    let joint = x % 4 == 0 || y % 4 == 0
                    color = shade(joint ? Palettes.stone[2] : Palettes.stone[1])
                } else if let district = CityMapComposer.hitTest(x: x, y: y) {
                    color = districtPixel(x, y, district: district, season: season, shade: shade)
                } else {
                    color = asphalt
                }
                canvas.set(x: x, y: y, color)
            }
        }
        return canvas.sprite()
    }

    // MARK: Pieces

    private static func riverPixel(
        _ x: Int, _ y: Int, season: Season, time: TimeOfDay,
        water: (base: RGBA, ripple: RGBA), ice: (base: RGBA, ripple: RGBA)
    ) -> RGBA {
        // In winter the river freezes along both banks; the channel keeps
        // running down the middle.
        let frozenEdge = season == .winter && (y < river.lowerBound + 3 || y >= river.upperBound - 3)
        let tone = frozenEdge ? ice : water
        // After dark the lit windows of the quay throw gold onto the water.
        if time.needsArtificialLight, !frozenEdge, y < river.lowerBound + 5, (x * 5 + y * 3) % 23 == 0 {
            return Palettes.gold[2]
        }
        return (x * 3 + y * 7) % 11 == 0 ? tone.ripple : tone.base
    }

    private static func parkPixel(
        _ x: Int, _ y: Int, season: Season, grass: (base: RGBA, shade: RGBA), hedge: RGBA, path: RGBA,
        shade: (RGBA) -> RGBA
    ) -> RGBA {
        if x == parkX.lowerBound || x == parkX.upperBound - 1 || y == parkY.lowerBound || y == parkY.upperBound - 1 {
            // A hedge all round, with a gate where each path meets it.
            let gate = (178..<180).contains(x) || (28..<30).contains(y)
            return gate ? path : hedge
        }
        let dx = Double(x - pondCenter.x) / Double(pondRadius.x)
        let dy = Double(y - pondCenter.y) / Double(pondRadius.y)
        let pond = dx * dx + dy * dy
        if pond <= 1 {
            if season == .winter { return shade(pond > 0.55 ? Palettes.stone[1] : Palettes.sky[0]) }
            return shade(pond > 0.55 ? Palettes.sky[3] : ((x + y) % 5 == 0 ? Palettes.sky[1] : Palettes.sky[2]))
        }
        if pond <= 1.35 { return shade(Palettes.sand[2]) }                // the pond's muddy rim
        if (178..<180).contains(x) || (28..<30).contains(y) { return path }
        // Fallen leaves in autumn, blossom in spring.
        if season == .autumn, (x * 7 + y * 11) % 19 == 0 { return shade(Palettes.ember[3]) }
        if season == .spring, (x * 7 + y * 11) % 23 == 0 { return shade(Palettes.plum[1]) }
        return shade((x * 7 + y * 13) % 29 == 0 ? grass.shade : grass.base)
    }

    private static func carParkPixel(_ x: Int, _ y: Int, shade: (RGBA) -> RGBA, asphalt: RGBA) -> RGBA {
        let left = carParkX.lowerBound, right = carParkX.upperBound - 1
        let top = carParkY.lowerBound, bottom = carParkY.upperBound - 1
        if x == left || x == right || y == top || y == bottom { return shade(Palettes.stone[2]) }
        // Two rows of bays either side of a central aisle.
        let rows = [(top + 2)..<(top + 11), (bottom - 10)..<(bottom - 1)]
        for (rowIndex, rowY) in rows.enumerated() where rowY.contains(y) {
            let bayX = x - (left + 2)
            guard bayX >= 0 else { return asphalt }
            if bayX % 6 == 0 { return shade(Palettes.stone[1]) }       // the painted line
            // A parked car (seen from above) in most bays.
            let bay = bayX / 6
            guard (bay * 7 + rowIndex * 3) % 4 != 0 else { return asphalt }
            let inBay = bayX % 6
            let dy = y - rowY.lowerBound
            guard (1...4).contains(inBay), (1...7).contains(dy) else { return asphalt }
            let bodies = [Palettes.ember[2], Palettes.teal[2], Palettes.stone[0], Palettes.indigo[2], Palettes.gold[2]]
            let body = bodies[(bay + rowIndex * 2) % bodies.count]
            if dy == 2 || dy == 6 { return shade(Palettes.ink[3]) }    // wind- and rear screens
            return shade(inBay == 4 ? Palettes.stepped(body, by: 1) : body)
        }
        return asphalt
    }

    private static func districtPixel(
        _ x: Int, _ y: Int, district: DistrictStyle, season: Season, shade: (RGBA) -> RGBA
    ) -> RGBA {
        switch district {
        case .oldTown:
            // Cobbles: staggered 4×3 setts with a darker joint.
            let joint = y % 3 == 0 || (x + (y / 3 % 2) * 2) % 4 == 0
            // In winter the snow lies in the joints between the setts.
            if joint, season == .winter, (x * 3 + y) % 4 != 0 { return shade(Palettes.stone[0]) }
            return shade(joint ? Palettes.sand[2] : Palettes.sand[1])
        case .suburbs:
            let tone = lawn(season)
            return shade((x * 7 + y * 13) % 37 == 0 ? tone.shade : tone.base)
        default:
            let base = district.ground
            let speckled = (x * 7 + y * 13) % 37 == 0
            return shade(speckled ? Palettes.shaded(base, by: 0.16) : base)
        }
    }
    // MARK: end S4

    /// A lawn's colour for the season — the Suburbs, the park and the far
    /// bank all follow it.
    static func lawn(_ season: Season) -> (base: RGBA, shade: RGBA) {
        switch season {
        case .spring: (Palettes.moss[1], Palettes.moss[2])
        case .summer: (Palettes.moss[2], Palettes.moss[3])
        case .autumn: (Palettes.gold[3], Palettes.sand[3])
        case .winter: (Palettes.stone[1], Palettes.stone[2])
        }
    }
}
