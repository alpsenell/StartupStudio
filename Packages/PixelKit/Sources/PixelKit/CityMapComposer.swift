import Foundation

/// What the map needs to know about one district to draw it.
public struct CityDistrictInfo: Sendable, Equatable {
    public var style: DistrictStyle
    public var selected: Bool
    public var hasPlayerOffice: Bool
    /// Appearance seeds of rivals headquartered here (drawn as pins, capped
    /// at three).
    public var rivalSeeds: [UInt64]

    public init(style: DistrictStyle, selected: Bool, hasPlayerOffice: Bool, rivalSeeds: [UInt64]) {
        self.style = style
        self.selected = selected
        self.hasPlayerOffice = hasPlayerOffice
        self.rivalSeeds = rivalSeeds
    }
}

/// Pure layout for the scrollable city map: a fixed 224×160 scene divided
/// into five district blocks by roads. `compose` returns the back-to-front
/// placement list the shared `PixelSceneView` draws; `hitTest` maps a tap
/// in scene pixels to a district — hit-testing is district *rects* (every
/// tappable thing belongs to exactly one district), independent of the
/// sprites.
public enum CityMapComposer {
    /// An integer rect in scene pixels.
    public struct Rect: Sendable, Equatable {
        public let x: Int, y: Int, width: Int, height: Int

        public func contains(x px: Int, y py: Int) -> Bool {
            px >= x && px < x + width && py >= y && py < y + height
        }
    }

    public static func sceneSize() -> (width: Int, height: Int) { (224, 160) }

    /// District blocks, tiling the map up to the road centerlines so every
    /// tap lands in exactly one district.
    static let frames: [DistrictStyle: Rect] = [
        .suburbs: Rect(x: 0, y: 0, width: 75, height: 79),
        .midtown: Rect(x: 75, y: 0, width: 74, height: 79),
        .techPark: Rect(x: 149, y: 0, width: 75, height: 79),
        .oldTown: Rect(x: 0, y: 79, width: 89, height: 81),
        .downtown: Rect(x: 89, y: 79, width: 135, height: 81),
    ]

    public static func districtFrame(_ district: DistrictStyle) -> Rect {
        frames[district] ?? Rect(x: 0, y: 0, width: 0, height: 0)
    }

    /// The district under a scene-pixel point (nil outside the map).
    public static func hitTest(x: Int, y: Int) -> DistrictStyle? {
        DistrictStyle.allCases.first { frames[$0]?.contains(x: x, y: y) == true }
    }

    // MARK: - Compose

    public static func compose(districts: [CityDistrictInfo]) -> [PlacedSprite] {
        var placements: [PlacedSprite] = [
            PlacedSprite(
                sprite: CityMapBuilder.ground(),
                x: 0, y: 0, kind: .room, animation: .still, phase: 0
            )
        ]

        // Buildings and landmarks, in a fixed back-to-front order per
        // district (order of `buildingSpots` is authored top-down).
        for info in districts {
            for (index, spot) in buildingSpots(for: info.style).enumerated() {
                placements.append(PlacedSprite(
                    sprite: CitySpriteLibrary.building(
                        width: spot.width, height: spot.height, district: info.style
                    ),
                    x: spot.x, y: spot.y,
                    kind: .cityProp("building"),
                    animation: .glow,
                    phase: index * 3
                ))
            }
            if let landmark = landmark(for: info.style) {
                placements.append(landmark)
            }
        }

        // Markers over the rooftops.
        for info in districts {
            let anchor = markerAnchor(for: info.style)
            var x = anchor.x
            if info.hasPlayerOffice {
                placements.append(PlacedSprite(
                    sprite: CitySpriteLibrary.officeMarker(),
                    x: x, y: anchor.y,
                    kind: .cityProp("officeMarker"),
                    animation: .toggle(period: 2), phase: 0
                ))
                x += 9
            }
            for (index, _) in info.rivalSeeds.prefix(3).enumerated() {
                placements.append(PlacedSprite(
                    sprite: CitySpriteLibrary.rivalMarker(),
                    x: x + index * 7, y: anchor.y + 1,
                    kind: .cityProp("rivalMarker"),
                    animation: .toggle(period: 3), phase: index
                ))
            }
        }

        // Selection pulse on top.
        for info in districts where info.selected {
            let frame = districtFrame(info.style)
            placements.append(PlacedSprite(
                sprite: CitySpriteLibrary.selectionBorder(width: frame.width, height: frame.height),
                x: frame.x, y: frame.y,
                kind: .cityProp("selection"),
                animation: .toggle(period: 2), phase: 0
            ))
        }
        return placements
    }

    // MARK: - Authored spots

    struct BuildingSpot {
        let x: Int, y: Int, width: Int, height: Int
    }

    /// Hand-placed building anchors per district — sized to read as the
    /// district's character (suburb cottages, downtown towers).
    static func buildingSpots(for district: DistrictStyle) -> [BuildingSpot] {
        switch district {
        case .suburbs: [
            BuildingSpot(x: 8, y: 38, width: 14, height: 14),
            BuildingSpot(x: 30, y: 44, width: 14, height: 14),
            BuildingSpot(x: 50, y: 36, width: 14, height: 14),
        ]
        case .midtown: [
            BuildingSpot(x: 82, y: 28, width: 15, height: 24),
            BuildingSpot(x: 101, y: 20, width: 16, height: 32),
            BuildingSpot(x: 122, y: 30, width: 15, height: 22),
        ]
        case .techPark: [
            BuildingSpot(x: 154, y: 34, width: 18, height: 20),
            BuildingSpot(x: 176, y: 28, width: 18, height: 26),
            BuildingSpot(x: 199, y: 36, width: 16, height: 18),
        ]
        case .oldTown: [
            BuildingSpot(x: 26, y: 108, width: 13, height: 18),
            BuildingSpot(x: 44, y: 102, width: 14, height: 22),
            BuildingSpot(x: 64, y: 110, width: 13, height: 16),
        ]
        case .downtown: [
            BuildingSpot(x: 96, y: 94, width: 14, height: 34),
            BuildingSpot(x: 114, y: 86, width: 15, height: 42),
            BuildingSpot(x: 133, y: 98, width: 14, height: 30),
            BuildingSpot(x: 152, y: 88, width: 16, height: 40),
            BuildingSpot(x: 173, y: 96, width: 14, height: 32),
            BuildingSpot(x: 193, y: 90, width: 15, height: 38),
        ]
        }
    }

    private static func landmark(for district: DistrictStyle) -> PlacedSprite? {
        switch district {
        case .suburbs:
            PlacedSprite(
                sprite: CitySpriteLibrary.tree(), x: 12, y: 14,
                kind: .cityProp("tree"), animation: .still, phase: 0
            )
        case .midtown:
            PlacedSprite(
                sprite: CitySpriteLibrary.tree(), x: 134, y: 54,
                kind: .cityProp("tree"), animation: .still, phase: 0
            )
        case .techPark:
            PlacedSprite(
                sprite: CitySpriteLibrary.antenna(), x: 205, y: 6,
                kind: .cityProp("antenna"), animation: .toggle(period: 3), phase: 0
            )
        case .oldTown:
            PlacedSprite(
                sprite: CitySpriteLibrary.clockTower(), x: 8, y: 96,
                kind: .cityProp("clockTower"), animation: .still, phase: 0
            )
        case .downtown:
            nil
        }
    }

    /// Where the district's flag/pin cluster sits.
    private static func markerAnchor(for district: DistrictStyle) -> (x: Int, y: Int) {
        switch district {
        case .suburbs: (30, 12)
        case .midtown: (84, 8)
        case .techPark: (156, 12)
        case .oldTown: (8, 84)
        case .downtown: (96, 82)
        }
    }
}
