import Foundation

/// What the map needs to know about one district to draw it.
public struct CityDistrictInfo: Sendable, Equatable, Hashable {
    public var style: DistrictStyle
    public var selected: Bool
    public var hasPlayerOffice: Bool
    /// Appearance seeds of rivals headquartered here (their buildings and
    /// pins are capped at three).
    public var rivalSeeds: [UInt64]
    // MARK: K6 (home and rooms)
    /// The founder lives here: a small house beside the flag. Defaults to
    /// no, so every existing caller draws the map it always drew.
    public var hasPlayerHome: Bool
    // MARK: end K6

    public init(
        style: DistrictStyle, selected: Bool, hasPlayerOffice: Bool, rivalSeeds: [UInt64],
        hasPlayerHome: Bool = false
    ) {
        self.style = style
        self.selected = selected
        self.hasPlayerOffice = hasPlayerOffice
        self.rivalSeeds = rivalSeeds
        self.hasPlayerHome = hasPlayerHome
    }
}

/// Pure layout for the scrollable city map: a fixed 320×224 scene of five
/// districts on a street grid — the spine between the two rows, three
/// avenues, the Suburbs' lane, the river along the south with its quay,
/// bridge and far bank. Each district is a set of authored lots (`lots`)
/// holding buildings in the district's own character, the player's HQ and
/// the rivals' HQs; the founder's places (venues, the hospital, the
/// courthouse, the school, the old office) stand on lots of their own.
///
/// `compose` returns the back-to-front placement list the shared
/// `PixelSceneView` draws; `layers` splits it so the app can run the
/// traffic off the scene clock; `hitTest(x:y:)` maps a tap to a district
/// (district *rects* partition the map), and `target(atX:y:in:)` maps it
/// to the thing under it — a building, a pin — using the regions `layers`
/// returns alongside the sprites, so what is drawn and what is tapped can
/// never disagree.
public enum CityMapComposer {
    /// An integer rect in scene pixels.
    public struct Rect: Sendable, Equatable, Hashable {
        public let x: Int, y: Int, width: Int, height: Int

        public init(x: Int, y: Int, width: Int, height: Int) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public func contains(x px: Int, y py: Int) -> Bool {
            px >= x && px < x + width && py >= y && py < y + height
        }

        /// The rect grown by `amount` on every side (a pin is small; the
        /// finger that taps it is not).
        func padded(_ amount: Int) -> Rect {
            Rect(x: x - amount, y: y - amount, width: width + amount * 2, height: height + amount * 2)
        }
    }

    // MARK: S4 (city) — the scene grew from 224×160 to hold the new city
    public static func sceneSize() -> (width: Int, height: Int) { (320, 224) }

    /// District blocks, tiling the map up to the road centerlines so every
    /// tap lands in exactly one district.
    static let frames: [DistrictStyle: Rect] = [
        .suburbs: Rect(x: 0, y: 0, width: 107, height: 108),
        .midtown: Rect(x: 107, y: 0, width: 108, height: 108),
        .techPark: Rect(x: 215, y: 0, width: 105, height: 108),
        .oldTown: Rect(x: 0, y: 108, width: 129, height: 116),
        .downtown: Rect(x: 129, y: 108, width: 191, height: 116),
    ]
    // MARK: end S4

    public static func districtFrame(_ district: DistrictStyle) -> Rect {
        frames[district] ?? Rect(x: 0, y: 0, width: 0, height: 0)
    }

    /// The district under a scene-pixel point (nil outside the map).
    public static func hitTest(x: Int, y: Int) -> DistrictStyle? {
        DistrictStyle.allCases.first { frames[$0]?.contains(x: x, y: y) == true }
    }

    // MARK: - Compose

    /// The map at midday in high summer, with the player still in a garage.
    public static func compose(districts: [CityDistrictInfo]) -> [PlacedSprite] {
        compose(districts: districts, ambience: .noon)
    }

    /// The map at an hour, in a season, with the player's HQ drawn at the
    /// size their office tier has earned.
    public static func compose(districts: [CityDistrictInfo], ambience: CityAmbience) -> [PlacedSprite] {
        compose(districts: districts, ambience: ambience, landmarks: .none)
    }

    // MARK: S4 (city)

    /// The whole map as one list, with the traffic parked where it stands
    /// at the scene's first frame.
    public static func compose(
        districts: [CityDistrictInfo], ambience: CityAmbience, landmarks: CityLandmarks
    ) -> [PlacedSprite] {
        let layers = layers(districts: districts, ambience: ambience, landmarks: landmarks)
        return layers.base + layers.parkedTraffic + layers.overlay
    }

    /// The map split for a live view: `base` (ground, buildings, trees,
    /// lamps) goes under the traffic, `overlay` (weather, pins, selection)
    /// over it. `parkedTraffic` is the traffic as a still — the two spine
    /// lanes and the avenue cars at t = 0 — for callers that draw one list;
    /// a live view draws `traffic(at:pace:time:)` in its place. `regions`
    /// are the tappable things, back to front.
    public struct CityMapLayers: Sendable, Equatable {
        public let base: [PlacedSprite]
        public let parkedTraffic: [PlacedSprite]
        public let overlay: [PlacedSprite]
        public let regions: [CityHitRegion]
    }

    public static func layers(
        districts: [CityDistrictInfo], ambience: CityAmbience, landmarks: CityLandmarks = .none
    ) -> CityMapLayers {
        let time = ambience.timeOfDay
        let season = ambience.season
        let (width, height) = sceneSize()

        var base: [PlacedSprite] = [
            PlacedSprite(
                sprite: SpriteCache.shared("city.ground.s4.\(time).\(season)") {
                    CityMapBuilder.ground(time: time, season: season)
                },
                x: 0, y: 0, kind: .room, animation: .still, phase: 0
            ),
            PlacedSprite(
                sprite: SpriteCache.shared("city.river.\(time).\(season)") {
                    CitySpriteLibrary.riverRipples(
                        width: width - 2, height: CityMapBuilder.river.count, time: time, season: season
                    )
                },
                x: 1, y: CityMapBuilder.river.lowerBound,
                kind: .cityProp("river"), animation: .toggle(period: 3), phase: 0
            ),
        ]

        // Everything that stands on the ground, sorted back to front by
        // the row it stands on.
        var standing: [(baseline: Int, placement: PlacedSprite, target: CityHitTarget?)] = []

        for info in districts {
            let lots = lots(for: info.style)
            var claims: [Int: CityHitTarget] = [:]
            if info.hasPlayerOffice, let index = tallestClaimableLot(in: lots) {
                claims[index] = .office(info.style)
            }
            for (offset, _) in info.rivalSeeds.prefix(3).enumerated() {
                guard let index = farthestFreeLot(in: lots, taken: Set(claims.keys)) else { break }
                claims[index] = .rival(info.style, index: offset)
            }

            for (index, lot) in lots.enumerated() {
                let (sprite, kind, animation, target) = lotContent(
                    lot, index: index, claim: claims[index], info: info,
                    ambience: ambience, landmarks: landmarks
                )
                let x = min(max(1, lot.centerX - sprite.width / 2), width - 1 - sprite.width)
                let y = max(1, lot.baseline - sprite.height)
                standing.append((lot.baseline, PlacedSprite(
                    sprite: sprite, x: x, y: y, kind: kind, animation: animation, phase: index % 4
                ), target))
            }

            for (thing, x, y) in scenery(for: info.style) {
                let placement = sceneryPlacement(thing, x: x, y: y, time: time, season: season)
                standing.append((y + placement.sprite.height, placement, nil))
            }
        }

        // Streetlights along the spine's north pavement.
        let lamp = SpriteCache.shared("city.lamp.\(time)") { CitySpriteLibrary.streetlight(time: time) }
        for (index, x) in spineLampXs.enumerated() {
            let y = CityMapBuilder.spine.lowerBound - lamp.height
            standing.append((CityMapBuilder.spine.lowerBound, PlacedSprite(
                sprite: lamp, x: x, y: y, kind: .cityProp("streetlight"),
                animation: .toggle(period: 5), phase: index % 2
            ), nil))
        }

        // Stable by row, then left to right: a taller building further
        // back is drawn before the shorter one in front of it.
        let ordered = standing.enumerated().sorted { lhs, rhs in
            if lhs.element.baseline != rhs.element.baseline { return lhs.element.baseline < rhs.element.baseline }
            return lhs.offset < rhs.offset
        }.map(\.element)
        base += ordered.map(\.placement)
        var regions: [CityHitRegion] = ordered.compactMap { entry in
            entry.target.map { target in
                CityHitRegion(target: target, rect: Rect(
                    x: entry.placement.x, y: entry.placement.y,
                    width: entry.placement.sprite.width, height: entry.placement.sprite.height
                ))
            }
        }

        // The traffic as a still: the two spine lanes (one each way), and
        // the avenue cars and the boat where they stand at t = 0.
        var parked: [PlacedSprite] = [
            PlacedSprite(
                sprite: SpriteCache.shared("city.lane.e.\(time)") {
                    CitySpriteLibrary.trafficLane(width: width - 2, eastbound: true, time: time)
                },
                x: 1, y: trafficRows.east, kind: .cityProp("traffic"), animation: .toggle(period: 1), phase: 0
            ),
            PlacedSprite(
                sprite: SpriteCache.shared("city.lane.w.\(time)") {
                    CitySpriteLibrary.trafficLane(width: width - 2, eastbound: false, time: time)
                },
                x: 1, y: trafficRows.west, kind: .cityProp("traffic"), animation: .toggle(period: 1), phase: 1
            ),
        ]
        parked += traffic(at: 0, pace: 0, time: time, includeSpine: false)

        // Weather, then the pins over the rooftops, then the selection.
        var overlay: [PlacedSprite] = []
        if let weather = CitySpriteLibrary.hasWeather(season) ? SpriteCache.shared("city.weather.\(season)", make: {
            CitySpriteLibrary.seasonal(width: width, height: height, season: season)
                ?? PixelSprite(frames: [[" "]], palette: [:])
        }) : nil {
            overlay.append(PlacedSprite(
                sprite: weather, x: 0, y: 0, kind: .cityProp("weather"),
                animation: .sequence(frames: [0, 1, 2, 3], fps: season == .winter ? 3 : 2, loop: true), phase: 0
            ))
        }

        for info in districts {
            let anchor = markerAnchor(for: info.style)
            var x = anchor.x
            if info.hasPlayerOffice {
                let flag = SpriteCache.shared("city.marker.office") { CitySpriteLibrary.officeMarker() }
                overlay.append(PlacedSprite(
                    sprite: flag, x: x, y: anchor.y, kind: .cityProp("officeMarker"),
                    animation: .toggle(period: 2), phase: 0
                ))
                regions.append(CityHitRegion(
                    target: .office(info.style),
                    rect: Rect(x: x, y: anchor.y, width: flag.width, height: flag.height).padded(2)
                ))
                x += 9
            }
            // MARK: K6 (home and rooms)
            if info.hasPlayerHome {
                let home = SpriteCache.shared("city.marker.home") { CitySpriteLibrary.homeMarker() }
                overlay.append(PlacedSprite(
                    sprite: home, x: x, y: anchor.y + 1, kind: .cityProp("homeMarker"),
                    animation: .still, phase: 0
                ))
                regions.append(CityHitRegion(
                    target: .home(info.style),
                    rect: Rect(x: x, y: anchor.y + 1, width: home.width, height: home.height).padded(2)
                ))
                x += 8
            }
            // MARK: end K6
            let pin = SpriteCache.shared("city.marker.rival") { CitySpriteLibrary.rivalMarker() }
            for (index, _) in info.rivalSeeds.prefix(3).enumerated() {
                overlay.append(PlacedSprite(
                    sprite: pin, x: x + index * 7, y: anchor.y + 1, kind: .cityProp("rivalMarker"),
                    animation: .toggle(period: 3), phase: index
                ))
                regions.append(CityHitRegion(
                    target: .rival(info.style, index: index),
                    rect: Rect(x: x + index * 7, y: anchor.y + 1, width: pin.width, height: pin.height).padded(1)
                ))
            }
        }

        for info in districts where info.selected {
            let frame = districtFrame(info.style)
            overlay.append(PlacedSprite(
                sprite: SpriteCache.shared("city.selection.\(frame.width)x\(frame.height)") {
                    CitySpriteLibrary.selectionBorder(width: frame.width, height: frame.height)
                },
                x: frame.x, y: frame.y, kind: .cityProp("selection"),
                animation: .toggle(period: 2), phase: 0
            ))
        }

        return CityMapLayers(base: base, parkedTraffic: parked, overlay: overlay, regions: regions)
    }

    /// The tappable things on the map, back to front — the same regions
    /// `layers` returns with its sprites.
    public static func hitRegions(
        districts: [CityDistrictInfo], ambience: CityAmbience = .noon, landmarks: CityLandmarks = .none
    ) -> [CityHitRegion] {
        layers(districts: districts, ambience: ambience, landmarks: landmarks).regions
    }

    /// The thing under a scene-pixel point: the front-most region that
    /// contains it, else the district itself (nil outside the map).
    public static func target(atX x: Int, y: Int, in regions: [CityHitRegion]) -> CityHitTarget? {
        if let region = regions.last(where: { $0.rect.contains(x: x, y: y) }) { return region.target }
        return hitTest(x: x, y: y).map { .district($0) }
    }

    /// A pixel name plate over a thing on the map — its label, and what a
    /// second tap does — with its tail pointing at the thing, kept inside
    /// the scene.
    public static func nameTag(label: String, line: String?, over rect: Rect) -> PlacedSprite {
        let (width, _) = sceneSize()
        let probe = OfficeFXSprites.nameTag(name: label, line: line)
        let x = min(max(1, rect.x + rect.width / 2 - probe.width / 2), width - 1 - probe.width)
        let tail = Double(rect.x + rect.width / 2 - x - 2) / Double(max(1, probe.width))
        let tag = OfficeFXSprites.nameTag(name: label, line: line, tailX: min(max(0.05, tail), 0.9))
        let y = max(1, rect.y - tag.height + 1)
        return PlacedSprite(sprite: tag, x: x, y: y, kind: .bubble, animation: .still, phase: 0)
    }

    // MARK: Traffic

    /// The spine's two lanes (top rows of each).
    static let trafficRows = (east: 103, west: 109)

    /// The cars (and the river boat) at scene time `t`. `pace` is how fast
    /// the city runs: 0 parks everything where it stands (a paused game),
    /// 1 is the 1× game speed, and 2 and 4 follow the simulation's own
    /// speeds. Each lane wraps inside the map, so nothing is ever drawn off
    /// the edge of the scene.
    public static func traffic(
        at t: TimeInterval, pace: Double, time: TimeOfDay, includeSpine: Bool = true
    ) -> [PlacedSprite] {
        let (width, height) = sceneSize()
        let travel = max(0, t) * max(0, pace)
        var cars: [PlacedSprite] = []

        func wrap(_ value: Double, _ span: Double) -> Int {
            guard span > 0 else { return 0 }
            let r = value.truncatingRemainder(dividingBy: span)
            return Int((r < 0 ? r + span : r).rounded(.down))
        }

        if includeSpine {
            let span = Double(width - 2 - 11)
            for index in 0..<5 {
                let east = SpriteCache.shared("city.car.e.\(index % 5).\(time)") {
                    CitySpriteLibrary.car(eastbound: true, tint: index, time: time)
                }
                let west = SpriteCache.shared("city.car.w.\((index + 2) % 5).\(time)") {
                    CitySpriteLibrary.car(eastbound: false, tint: index + 2, time: time)
                }
                let slot = Double(index) * span / 5
                cars.append(PlacedSprite(
                    sprite: east, x: 1 + wrap(slot + travel * 7, span), y: trafficRows.east,
                    kind: .cityProp("car"), animation: .still, phase: 0
                ))
                cars.append(PlacedSprite(
                    sprite: west, x: 1 + Int(span) - wrap(slot + 23 + travel * 6, span), y: trafficRows.west,
                    kind: .cityProp("car"), animation: .still, phase: 0
                ))
            }
        }

        // The avenues: two cars each way on each.
        let northSpan = Double(CityMapBuilder.spine.lowerBound - 1 - 6)
        let southTop = CityMapBuilder.spine.upperBound
        let southSpan = Double(height - 1 - 6 - southTop)
        let avenues: [(x: Int, top: Int, span: Double, seed: Double)] =
            CityMapBuilder.northAvenues.enumerated().map { index, avenue in
                (avenue.lowerBound, 1, northSpan, Double(index) * 31)
            } + [(CityMapBuilder.southAvenue.lowerBound, southTop, southSpan, 57)]
        for (avenueIndex, avenue) in avenues.enumerated() {
            for index in 0..<2 {
                let tint = avenueIndex * 2 + index
                let down = SpriteCache.shared("city.acar.s.\(tint % 5).\(time)") {
                    CitySpriteLibrary.avenueCar(southbound: true, tint: tint, time: time)
                }
                let up = SpriteCache.shared("city.acar.n.\((tint + 3) % 5).\(time)") {
                    CitySpriteLibrary.avenueCar(southbound: false, tint: tint + 3, time: time)
                }
                let slot = avenue.seed + Double(index) * avenue.span / 2
                cars.append(PlacedSprite(
                    sprite: down, x: avenue.x, y: avenue.top + wrap(slot + travel * 5, avenue.span),
                    kind: .cityProp("car"), animation: .still, phase: 0
                ))
                cars.append(PlacedSprite(
                    sprite: up, x: avenue.x + 3,
                    y: avenue.top + Int(avenue.span) - wrap(slot + 17 + travel * 4, avenue.span),
                    kind: .cityProp("car"), animation: .still, phase: 0
                ))
            }
        }

        // The boat, slower than anything on the roads.
        let boat = SpriteCache.shared("city.boat.\(time)") { CitySpriteLibrary.boat(time: time) }
        let boatSpan = Double(width - 2 - boat.width)
        cars.append(PlacedSprite(
            sprite: boat, x: 1 + wrap(90 + travel * 2, boatSpan), y: CityMapBuilder.river.lowerBound + 4,
            kind: .cityProp("boat"), animation: .toggle(period: 3), phase: 0
        ))
        return cars
    }

    // MARK: Lots

    /// The tallest claimable lot — where a headquarters wants to stand.
    static func tallestClaimableLot(in lots: [CityLot]) -> Int? {
        lots.indices.filter { lots[$0].claimable }.max { lots[$0].height < lots[$1].height }
    }

    /// The next free claimable lot for a rival, walking from the far end so
    /// rivals and the player do not end up shoulder to shoulder.
    static func farthestFreeLot(in lots: [CityLot], taken: Set<Int>) -> Int? {
        lots.indices.reversed().first { lots[$0].claimable && !taken.contains($0) }
    }

    /// What stands on one lot: its sprite, kind, animation and the thing a
    /// tap on it reaches (nil for an ordinary building).
    private static func lotContent(
        _ lot: CityLot, index: Int, claim: CityHitTarget?, info: CityDistrictInfo,
        ambience: CityAmbience, landmarks: CityLandmarks
    ) -> (PixelSprite, PlacementKind, SpriteAnimation, CityHitTarget?) {
        let style = info.style
        let time = ambience.timeOfDay
        let season = ambience.season

        func building(_ variant: Int) -> (PixelSprite, PlacementKind, SpriteAnimation, CityHitTarget?) {
            let sprite = SpriteCache.shared("city.b.\(style).\(lot.width)x\(lot.height).\(variant).\(time).\(season)") {
                CitySpriteLibrary.districtBuilding(
                    district: style, width: lot.width, height: lot.height,
                    variant: variant, time: time, season: season
                )
            }
            return (sprite, .cityProp("building"), .toggle(period: 7 + variant), nil)
        }

        switch claim {
        case .office:
            let hq = SpriteCache.shared("city.hq.\(ambience.playerTier.rawValue).\(time)") {
                CitySpriteLibrary.playerHQ(tier: ambience.playerTier, time: time)
            }
            return (hq, .cityProp("playerHQ"), .toggle(period: 3), claim)
        case .rival(_, let offset):
            let seed = info.rivalSeeds[offset]
            let hq = SpriteCache.shared("city.rival.\(seed).\(style).\(time)") {
                CitySpriteLibrary.rivalHQ(seed: seed, district: style, time: time)
            }
            return (hq, .cityProp("rivalHQ"), .toggle(period: 4), claim)
        default:
            break
        }

        switch lot.use {
        case .building(let variant):
            return building(variant)
        case .cafe:
            let sprite = SpriteCache.shared("city.cafe.\(lot.width).\(index).\(time)") {
                CitySpriteLibrary.cafe(width: lot.width, variant: index, time: time)
            }
            return (sprite, .cityProp("cafe"), .toggle(period: 5), nil)
        case .venue:
            let open = landmarks.openVenue == style
            let sprite = SpriteCache.shared("city.venue.\(style).\(time).\(season).\(open)") {
                CitySpriteLibrary.venue(
                    style.venue, width: lot.width, height: lot.height, time: time, season: season, open: open
                )
            }
            return (sprite, .cityProp("venue"), .toggle(period: open ? 2 : 6), .venue(style))
        case .hospital:
            guard landmarks.hospital, style == hospitalDistrict else { return building(1) }
            let sprite = SpriteCache.shared("city.hospital.\(time)") {
                CitySpriteLibrary.hospital(width: lot.width, height: lot.height, time: time)
            }
            return (sprite, .cityProp("hospital"), .toggle(period: 2), .hospital)
        case .courthouse:
            guard landmarks.courthouse, style == courthouseDistrict else { return building(0) }
            let sprite = SpriteCache.shared("city.court.\(time).\(season)") {
                CitySpriteLibrary.courthouse(width: lot.width, height: lot.height, time: time, season: season)
            }
            return (sprite, .cityProp("courthouse"), .toggle(period: 6), .courthouse)
        case .school:
            guard landmarks.school, style == schoolDistrict else {
                let sprite = SpriteCache.shared("city.playground.\(time)") {
                    CitySpriteLibrary.playground(width: lot.width, height: 12, time: time)
                }
                return (sprite, .cityProp("playground"), .toggle(period: 4), nil)
            }
            let sprite = SpriteCache.shared("city.school.\(time).\(season)") {
                CitySpriteLibrary.school(width: lot.width, height: lot.height, time: time, season: season)
            }
            return (sprite, .cityProp("school"), .toggle(period: 5), .school)
        case .formerOffice:
            guard landmarks.formerOffice == style else { return building(2) }
            let sprite = SpriteCache.shared("city.former.\(style).\(time)") {
                CitySpriteLibrary.formerOffice(district: style, width: lot.width, height: lot.height, time: time)
            }
            return (sprite, .cityProp("formerOffice"), .toggle(period: 4), .formerOffice(style))
        }
    }

    private static func sceneryPlacement(
        _ thing: CityScenery, x: Int, y: Int, time: TimeOfDay, season: Season
    ) -> PlacedSprite {
        switch thing {
        case .tree:
            PlacedSprite(
                sprite: SpriteCache.shared("city.tree.\(season).\(time)") { CitySpriteLibrary.shaded(CitySpriteLibrary.tree(season: season), for: time) },
                x: x, y: y, kind: .cityProp("tree"), animation: .still, phase: 0
            )
        case .gardenTree:
            PlacedSprite(
                sprite: SpriteCache.shared("city.gtree.\(season).\(time)") { CitySpriteLibrary.shaded(CitySpriteLibrary.gardenTree(season: season), for: time) },
                x: x, y: y, kind: .cityProp("tree"), animation: .still, phase: 0
            )
        case .bush:
            PlacedSprite(
                sprite: SpriteCache.shared("city.bush.\(season).\(time)") { CitySpriteLibrary.shaded(CitySpriteLibrary.bush(season: season), for: time) },
                x: x, y: y, kind: .cityProp("bush"), animation: .still, phase: 0
            )
        case .bench:
            PlacedSprite(
                sprite: SpriteCache.shared("city.bench.\(time)") { CitySpriteLibrary.shaded(CitySpriteLibrary.bench(), for: time) },
                x: x, y: y, kind: .cityProp("bench"), animation: .still, phase: 0
            )
        case .lamp:
            PlacedSprite(
                sprite: SpriteCache.shared("city.lamp.\(time)") { CitySpriteLibrary.streetlight(time: time) },
                x: x, y: y, kind: .cityProp("parkLamp"), animation: .toggle(period: 5), phase: 1
            )
        case .clockTower:
            PlacedSprite(
                sprite: SpriteCache.shared("city.clock.\(time)") { CitySpriteLibrary.shaded(CitySpriteLibrary.clockTower(), for: time) },
                x: x, y: y, kind: .cityProp("clockTower"), animation: .still, phase: 0
            )
        case .antenna:
            PlacedSprite(
                sprite: SpriteCache.shared("city.antenna.\(time)") { CitySpriteLibrary.shaded(CitySpriteLibrary.antenna(), for: time) },
                x: x, y: y, kind: .cityProp("antenna"), animation: .toggle(period: 3), phase: 0
            )
        case .fountain:
            PlacedSprite(
                sprite: SpriteCache.shared("city.fountain.\(time).\(season)") {
                    CitySpriteLibrary.fountain(time: time, season: season)
                },
                x: x, y: y, kind: .cityProp("fountain"), animation: .toggle(period: 2), phase: 0
            )
        }
    }
    // MARK: end S4

    /// The rectangle the player's own office marker occupies in a
    /// district, when that district is the one the office is in. The flag
    /// a sighted player looks for first.
    public static func officeMarkerFrame(for district: DistrictStyle) -> Rect {
        let anchor = markerAnchor(for: district)
        let sprite = CitySpriteLibrary.officeMarker()
        return Rect(x: anchor.x, y: anchor.y, width: sprite.width, height: sprite.height)
    }

    // MARK: K6 (home and rooms)
    /// The rectangle the founder's home marker occupies in the district
    /// they live in: after the office flag when both are there.
    public static func homeMarkerFrame(for district: DistrictStyle, besideOffice: Bool) -> Rect {
        let anchor = markerAnchor(for: district)
        let sprite = CitySpriteLibrary.homeMarker()
        return Rect(
            x: anchor.x + (besideOffice ? 9 : 0), y: anchor.y + 1,
            width: sprite.width, height: sprite.height
        )
    }
    // MARK: end K6

    /// Where the district's flag/pin cluster sits: an open patch of each
    /// district (the Suburbs' front gardens, above the hospital, over the
    /// demo hall, Old Town's top corner, the Downtown plaza).
    static func markerAnchor(for district: DistrictStyle) -> (x: Int, y: Int) {
        switch district {
        case .suburbs: (30, 4)
        case .midtown: (114, 6)
        case .techPark: (222, 6)
        case .oldTown: (18, 115)
        case .downtown: (180, 157)
        }
    }
}
