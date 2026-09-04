import Foundation
import Testing
@testable import PixelKit

/// The rival studio scene: the building grows with strength, lights up
/// with reputation, becomes a fortress for the incumbent and hangs a
/// price tag when it is for sale — and every colour is a master colour.
@Suite("Rival studio scene")
struct RivalStudioTests {
    @Test func theStudioGrowsWithStrengthAndTheFortressTowersOverIt() {
        var heights: [Int] = []
        for band in StrengthBand.allCases {
            let scene = RivalStudioComposer.compose(RivalStudioInput(band: band, reputation: 0.5, founderSeed: 9))
            let studio = scene.first { $0.kind == .cityProp("studio") }!
            heights.append(studio.sprite.height)
            #expect(studio.y + studio.sprite.height == RivalStudioComposer.groundY + 1, "\(band) stands on the pavement")
        }
        #expect(heights == heights.sorted())
        #expect(heights.first! < heights.last!)
        let fortress = RivalStudioComposer.compose(
            RivalStudioInput(band: .minnow, reputation: 0.5, isFortress: true)
        ).first { $0.kind == .cityProp("fortress") }!
        #expect(fortress.sprite.height >= heights.last!)
    }

    @Test func reputationLightsTheWindows() {
        func litWindows(_ reputation: Double) -> Int {
            let sprite = RivalSpriteLibrary.studio(band: .large, litFraction: reputation, seed: 3, time: .night)
            let gold = Palettes.gold[1]
            return sprite.frames[0].reduce(0) { total, row in
                total + row.filter { sprite.palette[$0] == gold }.count
            }
        }
        #expect(litWindows(0) < litWindows(0.5))
        #expect(litWindows(0.5) < litWindows(1))
    }

    @Test func everyBandHasWindowsAndADoor() {
        for band in StrengthBand.allCases {
            let sprite = RivalSpriteLibrary.studio(band: band, litFraction: 1, seed: 1, time: .night)
            let gold = Palettes.gold[1]
            let lit = sprite.frames[0].reduce(0) { total, row in
                total + row.filter { sprite.palette[$0] == gold }.count
            }
            // The door's glass is six pixels; anything past that is a window.
            #expect(lit > 6, "\(band) has no windows")
            let door = Palettes.sand[4]
            #expect(sprite.frames[0].contains { row in row.contains { sprite.palette[$0] == door } }, "\(band) has no door")
        }
    }

    @Test func thePriceTagHangsOnlyWhenTheStudioIsForSale() {
        let input = RivalStudioInput(band: .mid, reputation: 0.5, forSale: true)
        let forSale = RivalStudioComposer.compose(input)
        #expect(forSale.contains { $0.kind == .cityProp("forSale") })
        var notForSale = input
        notForSale.forSale = false
        #expect(!RivalStudioComposer.compose(notForSale).contains { $0.kind == .cityProp("forSale") })
    }

    @Test func everyPlacementStaysInsideTheScene() {
        let size = RivalStudioComposer.sceneSize
        for time in TimeOfDay.allCases {
            for band in StrengthBand.allCases {
                for fortress in [false, true] {
                    let scene = RivalStudioComposer.compose(RivalStudioInput(
                        band: band, reputation: 0.5, isFortress: fortress, forSale: true, timeOfDay: time
                    ))
                    for placement in scene {
                        #expect(placement.x >= 0 && placement.y >= 0, "\(placement.kind) origin")
                        #expect(placement.x + placement.sprite.width <= size.width, "\(placement.kind) right edge")
                        #expect(placement.y + placement.sprite.height <= size.height, "\(placement.kind) bottom edge")
                    }
                }
            }
        }
    }

    @Test func theSceneIsDeterministic() {
        for time in TimeOfDay.allCases {
            let input = RivalStudioInput(band: .mid, reputation: 0.6, forSale: true, founderSeed: 44, timeOfDay: time)
            #expect(RivalStudioComposer.compose(input) == RivalStudioComposer.compose(input))
        }
    }

    // MARK: Palette

    static func allSprites() -> [(name: String, sprite: PixelSprite)] {
        var out: [(String, PixelSprite)] = [("forSale", RivalSpriteLibrary.forSaleSign())]
        for time in TimeOfDay.allCases {
            out.append(("backdrop(\(time))", RivalSpriteLibrary.backdrop(time: time)))
            for band in StrengthBand.allCases {
                for reputation in [0.0, 0.5, 1.0] {
                    out.append((
                        "studio(\(band), \(reputation), \(time))",
                        RivalSpriteLibrary.studio(band: band, litFraction: reputation, seed: 5, time: time)
                    ))
                }
            }
            out.append(("fortress(\(time))", RivalSpriteLibrary.fortress(litFraction: 0.7, seed: 5, time: time)))
            for placement in RivalStudioComposer.compose(
                RivalStudioInput(band: .large, reputation: 0.8, isFortress: true, forSale: true, founderSeed: 12, timeOfDay: time)
            ) {
                out.append(("scene \(time) \(placement.kind)", placement.sprite))
            }
        }
        return out
    }

    @Test func everyStudioSpriteColorIsInTheMasterPalette() {
        var offenders: [String] = []
        for (name, sprite) in Self.allSprites() {
            for (character, color) in sprite.palette where !Palettes.isMaster(color) {
                offenders.append("\(name): '\(character)' = rgb(\(color.r), \(color.g), \(color.b))")
            }
        }
        #expect(offenders.isEmpty, "off-palette colors: \(Set(offenders).sorted().joined(separator: "; "))")
    }
}
