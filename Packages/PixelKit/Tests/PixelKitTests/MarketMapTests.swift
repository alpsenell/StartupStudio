import Foundation
import Testing
@testable import PixelKit

/// The market map's geometry, the rules that keep its markers honest, and
/// the palette gate over every sprite it draws.
@Suite("Market map")
struct MarketMapTests {
    /// A mid-game market: standing across the bands, live products in a
    /// few topics, rivals in most, the incumbent's fortress in two, a
    /// fight in one, and a forecast wherever the studio holds the category.
    static func midGame() -> MarketMapInput {
        let names = [
            "fitness", "finance", "social", "travel", "food_delivery", "education",
            "music", "gaming", "productivity", "health", "dating", "logistics",
        ]
        let bands: [StandingBand] = [
            .household, .none, .known, .newcomer, .none, .established,
            .known, .none, .newcomer, .none, .none, .none,
        ]
        let sizes = [0.95, 0.4, 0.7, 0.2, 0.5, 0.85, 0.6, 1.0, 0.3, 0.55, 0.0, 0.45]
        return MarketMapInput(districts: names.enumerated().map { index, id in
            MarketDistrictInfo(
                id: id,
                name: id.capitalized,
                size: sizes[index],
                standing: bands[index],
                playerProducts: [2, 0, 1, 1, 0, 3, 1, 0, 1, 0, 0, 0][index],
                rivalCount: [2, 1, 3, 0, 1, 1, 2, 4, 0, 1, 0, 1][index],
                hasFortress: index == 0 || index == 6,
                underSiege: index == 0,
                weather: [.sunny, nil, nil, nil, nil, .rain, nil, nil, nil, nil, nil, nil][index]
            )
        })
    }

    /// Day zero: nothing anywhere.
    static func fresh() -> MarketMapInput {
        MarketMapInput(districts: (0..<12).map {
            MarketDistrictInfo(id: "t\($0)", name: "Topic \($0)", size: 0.4, standing: .none)
        })
    }

    // MARK: Layout

    @Test func twelveCellsTileTheSceneWithoutOverlapping() throws {
        let size = MarketMapLayout.sceneSize
        var cells: [MarketMapLayout.Rect] = []
        for index in 0..<MarketMapLayout.slots {
            let cell = try #require(MarketMapLayout.cellFrame(index: index))
            #expect(cell.x >= 0 && cell.y >= 0)
            #expect(cell.x + cell.width <= size.width)
            #expect(cell.y + cell.height <= size.height)
            for other in cells {
                let overlaps = cell.x < other.x + other.width && other.x < cell.x + cell.width
                    && cell.y < other.y + other.height && other.y < cell.y + cell.height
                #expect(!overlaps, "cell \(index) overlaps another")
            }
            cells.append(cell)
        }
        #expect(MarketMapLayout.cellFrame(index: 12) == nil)
    }

    @Test func everyPointInsideTheFrameHitsExactlyOneDistrict() {
        let size = MarketMapLayout.sceneSize
        for y in 1..<(size.height - 1) {
            for x in 1..<(size.width - 1) {
                #expect(MarketMapLayout.hitTest(x: x, y: y) != nil, "(\(x), \(y)) hits nothing")
            }
        }
        for index in 0..<MarketMapLayout.slots {
            let cell = MarketMapLayout.cellFrame(index: index)!
            #expect(MarketMapLayout.hitTest(x: cell.x, y: cell.y) == index)
            #expect(MarketMapLayout.hitTest(x: cell.x + cell.width - 1, y: cell.y + cell.height - 1) == index)
        }
        #expect(MarketMapLayout.hitTest(x: 0, y: 0) == nil)
        #expect(MarketMapLayout.hitTest(x: size.width, y: 5) == nil)
        // A catalog with fewer topics leaves the spare cells dead.
        #expect(MarketMapLayout.hitTest(x: size.width - 3, y: size.height - 3, count: 11) == nil)
    }

    @Test func theBlockGrowsWithTheMarketAndStaysInItsCell() {
        #expect(MarketMapLayout.blockSide(size: 0) == MarketMapLayout.minBlock)
        #expect(MarketMapLayout.blockSide(size: 1) == MarketMapLayout.blockArea)
        #expect(MarketMapLayout.blockSide(size: 0.5) > MarketMapLayout.minBlock)
        #expect(MarketMapLayout.blockSide(size: 0.5) < MarketMapLayout.blockArea)
        #expect(MarketMapLayout.blockSide(size: -3) == MarketMapLayout.minBlock)
        #expect(MarketMapLayout.blockSide(size: 9) == MarketMapLayout.blockArea)
        for index in 0..<MarketMapLayout.slots {
            for size in [0.0, 0.3, 0.75, 1.0] {
                let area = MarketMapLayout.blockAreaFrame(index: index)!
                let block = MarketMapLayout.blockFrame(index: index, size: size)!
                #expect(block.x >= area.x && block.y >= area.y)
                #expect(block.x + block.width <= area.x + area.width)
                #expect(block.y + block.height <= area.y + area.height)
            }
        }
    }

    @Test func theFitMatchesTheSceneViewsArithmetic() {
        let scene = MarketMapLayout.sceneSize
        let fit = MarketMapLayout.fit(in: CGSize(width: 361, height: 327))
        #expect(fit.scale == 361 / scene.width)
        #expect(fit.origin.x == ((361 - CGFloat(scene.width * fit.scale)) / 2).rounded(.down))
        let tiny = MarketMapLayout.fit(in: CGSize(width: 40, height: 40))
        #expect(tiny.scale == 1)
    }

    // MARK: Composition

    @Test func compositionIsDeterministicAndStartsWithThePlate() {
        let scene = MarketMapComposer.compose(Self.midGame())
        #expect(scene == MarketMapComposer.compose(Self.midGame()))
        #expect(scene.first?.kind == .room)
        #expect(scene.first?.sprite.width == MarketMapLayout.sceneSize.width)
        #expect(scene.first?.sprite.height == MarketMapLayout.sceneSize.height)
    }

    @Test func everyMarkerStaysInsideItsDistrictsBlock() {
        let input = Self.midGame()
        let scene = MarketMapComposer.compose(input)
        var blockIndex = -1
        for placement in scene.dropFirst() {
            if placement.kind == .cityProp("district") {
                blockIndex += 1
                continue
            }
            let block = MarketMapLayout.blockFrame(index: blockIndex, size: input.districts[blockIndex].size)!
            #expect(placement.x >= block.x, "\(placement.kind) left of block \(blockIndex)")
            #expect(placement.y >= block.y, "\(placement.kind) above block \(blockIndex)")
            #expect(placement.x + placement.sprite.width <= block.x + block.width, "\(placement.kind) past block \(blockIndex)")
            #expect(placement.y + placement.sprite.height <= block.y + block.height, "\(placement.kind) below block \(blockIndex)")
        }
        #expect(blockIndex == 11)
    }

    @Test func theMarkersFollowTheInput() {
        let scene = MarketMapComposer.compose(Self.midGame())
        func count(_ name: String) -> Int { scene.filter { $0.kind == .cityProp(name) }.count }
        #expect(count("district") == 12)
        #expect(count("fortress") == 2)
        #expect(count("siege") == 1)
        #expect(count("weather") == 2)
        // Gaming asked for four flags; the cap is three.
        #expect(count("rivalFlag") == 2 + 1 + 3 + 1 + 1 + 2 + 3 + 1 + 1)
        // Education asked for three buildings on a large block: all drawn.
        // Fitness has the fortress and two buildings; the block is big
        // enough for both.
        #expect(count("playerBuilding") == 2 + 1 + 1 + 3 + 1 + 1)

        let empty = MarketMapComposer.compose(Self.fresh())
        #expect(empty.count == 13, "a fresh market is the plate and twelve bare blocks")
    }

    @Test func aSmallDistrictStillShowsTheFortressAndOneOfYourBuildings() {
        let input = MarketMapInput(districts: [
            MarketDistrictInfo(id: "a", name: "A", size: 0, standing: .known, playerProducts: 3, rivalCount: 3, hasFortress: true, underSiege: true, weather: .storm),
        ])
        let scene = MarketMapComposer.compose(input)
        #expect(scene.contains { $0.kind == .cityProp("fortress") })
        #expect(scene.filter { $0.kind == .cityProp("playerBuilding") }.count == 1)
        #expect(scene.filter { $0.kind == .cityProp("rivalFlag") }.count == 2)
        #expect(scene.contains { $0.kind == .cityProp("siege") })
        #expect(scene.contains { $0.kind == .cityProp("weather") })
    }

    @Test func aThirteenthDistrictHasNoSlot() {
        let input = MarketMapInput(districts: (0..<13).map {
            MarketDistrictInfo(id: "t\($0)", name: "T", size: 1, standing: .none, playerProducts: 1)
        })
        let scene = MarketMapComposer.compose(input)
        #expect(scene.filter { $0.kind == .cityProp("district") }.count == 12)
    }

    // MARK: Palette

    /// Every sprite the map can produce, for the master-palette gate.
    static func allSprites() -> [(name: String, sprite: PixelSprite)] {
        var out: [(String, PixelSprite)] = [("plate", MarketSpriteLibrary.plate())]
        for band in StandingBand.allCases {
            for side in [MarketMapLayout.minBlock, 23, MarketMapLayout.blockArea] {
                out.append(("block(\(band), \(side))", MarketSpriteLibrary.districtBlock(side: side, band: band)))
            }
        }
        out.append(("playerBuilding", MarketSpriteLibrary.playerBuilding()))
        out.append(("rivalFlag", MarketSpriteLibrary.rivalFlag()))
        out.append(("fortress", MarketSpriteLibrary.fortress()))
        out.append(("siege", MarketSpriteLibrary.siegeMarker()))
        for weather in MarketWeather.allCases {
            out.append(("weather(\(weather))", MarketSpriteLibrary.weather(weather)))
        }
        for placement in MarketMapComposer.compose(midGame()) {
            out.append(("map \(placement.kind)", placement.sprite))
        }
        return out
    }

    @Test func everyMapSpriteColorIsInTheMasterPalette() {
        var offenders: [String] = []
        for (name, sprite) in Self.allSprites() {
            for (character, color) in sprite.palette where !Palettes.isMaster(color) {
                offenders.append("\(name): '\(character)' = rgb(\(color.r), \(color.g), \(color.b))")
            }
        }
        #expect(offenders.isEmpty, "off-palette colors: \(Set(offenders).sorted().joined(separator: "; "))")
    }

    @Test func theStandingBandsReadInOrder() {
        // Nobody's is grey; every rung the studio climbs is a different
        // colour, and the two greens are a real step apart.
        let grounds = StandingBand.allCases.map(\.ground)
        #expect(Set(grounds).count == grounds.count)
        #expect(Palettes.luminance(StandingBand.known.ground) > Palettes.luminance(StandingBand.established.ground))
    }
}
