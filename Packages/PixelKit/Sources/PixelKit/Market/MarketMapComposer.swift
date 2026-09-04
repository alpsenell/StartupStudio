import Foundation

/// Pure layout for the market map: the plate, then each district's block
/// and the markers on it, back to front, in the fixed order
/// `MarketMapLayout` gives every catalog index. `MarketMapView` and the
/// PNG preview both draw exactly this list. No randomness — the same input
/// composes the same scene, which `MarketMapPreviewPNGTests` asserts.
public enum MarketMapComposer {
    public static var sceneSize: (width: Int, height: Int) { MarketMapLayout.sceneSize }

    /// The most flags, buildings, and so on one district shows. Past this
    /// the district is crowded and the count is on the detail screen.
    public static let markerCap = 3

    public static func compose(_ input: MarketMapInput) -> [PlacedSprite] {
        var placements: [PlacedSprite] = [
            PlacedSprite(
                sprite: SpriteCache.shared("market.plate") { MarketSpriteLibrary.plate() },
                x: 0, y: 0, kind: .room, animation: .still, phase: 0
            ),
        ]

        for (index, district) in input.districts.prefix(MarketMapLayout.slots).enumerated() {
            guard let block = MarketMapLayout.blockFrame(index: index, size: district.size) else { continue }
            placements.append(PlacedSprite(
                sprite: SpriteCache.shared("market.block.\(block.width).\(district.standing.rawValue)") {
                    MarketSpriteLibrary.districtBlock(side: block.width, band: district.standing)
                },
                x: block.x, y: block.y,
                kind: .cityProp("district"),
                animation: .still, phase: 0,
                zIndex: -50_000 + index
            ))
            placements.append(contentsOf: markers(for: district, in: block, index: index))
        }
        return placements
    }

    /// The markers on one block, each at its own corner so they never
    /// hide one another: flags top-left, weather top-right, the studio's
    /// buildings bottom-left, the fortress bottom-right, the siege in the
    /// middle. Counts are capped by the room the block actually has.
    private static func markers(
        for district: MarketDistrictInfo, in block: MarketMapLayout.Rect, index: Int
    ) -> [PlacedSprite] {
        var placements: [PlacedSprite] = []
        let inset = 1
        let depth = index * 100

        // Weather, top-right.
        let weatherSprite = district.weather.map { weather in
            SpriteCache.shared("market.weather.\(weather.rawValue)") { MarketSpriteLibrary.weather(weather) }
        }
        if let weatherSprite {
            placements.append(PlacedSprite(
                sprite: weatherSprite,
                x: block.x + block.width - inset - weatherSprite.width,
                y: block.y + inset,
                kind: .cityProp("weather"),
                animation: .toggle(period: 3), phase: index,
                zIndex: depth + 40
            ))
        }

        // Rival flags, top-left, leaving the weather its corner.
        let flag = SpriteCache.shared("market.rivalFlag") { MarketSpriteLibrary.rivalFlag() }
        let flagRoom = (block.width - inset * 2 - (weatherSprite?.width ?? 0)) / flag.width
        let flags = min(district.rivalCount, max(0, flagRoom), markerCap)
        for offset in 0..<flags {
            placements.append(PlacedSprite(
                sprite: flag,
                x: block.x + inset + offset * flag.width,
                y: block.y + inset,
                kind: .cityProp("rivalFlag"),
                animation: .toggle(period: 3), phase: index + offset,
                zIndex: depth + 10 + offset
            ))
        }

        // The fortress, bottom-right.
        let fortress = SpriteCache.shared("market.fortress") { MarketSpriteLibrary.fortress() }
        if district.hasFortress {
            placements.append(PlacedSprite(
                sprite: fortress,
                x: block.x + block.width - inset - fortress.width,
                y: block.y + block.height - inset - fortress.height,
                kind: .cityProp("fortress"),
                animation: .glow, phase: index,
                zIndex: depth + 30
            ))
        }

        // The studio's buildings, bottom-left, leaving the fortress its lot.
        let building = SpriteCache.shared("market.playerBuilding") { MarketSpriteLibrary.playerBuilding() }
        let fortressRoom = district.hasFortress ? fortress.width + inset : 0
        let buildingRoom = (block.width - inset * 2 - fortressRoom) / building.width
        let buildings = min(district.playerProducts, max(0, buildingRoom), markerCap)
        for offset in 0..<buildings {
            placements.append(PlacedSprite(
                sprite: building,
                x: block.x + inset + offset * building.width,
                y: block.y + block.height - inset - building.height,
                kind: .cityProp("playerBuilding"),
                animation: .glow, phase: index + offset * 2,
                zIndex: depth + 20 + offset
            ))
        }

        // The siege, over the middle of the block, on top of everything.
        if district.underSiege {
            let siege = SpriteCache.shared("market.siege") { MarketSpriteLibrary.siegeMarker() }
            placements.append(PlacedSprite(
                sprite: siege,
                x: block.x + (block.width - siege.width) / 2,
                y: block.y + (block.height - siege.height) / 2,
                kind: .cityProp("siege"),
                animation: .toggle(period: 2), phase: index,
                zIndex: depth + 90
            ))
        }
        return placements
    }
}
