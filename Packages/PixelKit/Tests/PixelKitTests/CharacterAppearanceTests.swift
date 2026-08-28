import Foundation
import Testing
@testable import PixelKit

@Suite("CharacterAppearance derivation")
struct CharacterAppearanceTests {
    @Test func sameSeedIsDeterministic() {
        for seed: UInt64 in [0, 1, 42, 0xDEAD_BEEF, .max] {
            #expect(CharacterAppearance(seed: seed) == CharacterAppearance(seed: seed))
        }
    }

    @Test func spreadOfSeedsProducesVariety() {
        var distinct = Set<[Int]>()
        for seed in 0..<100 {
            let a = CharacterAppearance(seed: UInt64(seed))
            distinct.insert([a.skinTone, a.hairStyle, a.hairColor, a.shirtColor])
        }
        #expect(distinct.count >= 20)
    }

    @Test func allIndicesStayWithinTheirSpriteSets() {
        #expect(CharacterAppearance.skinToneCount >= 4)
        #expect(CharacterAppearance.hairStyleCount >= 5)
        #expect(CharacterAppearance.hairColorCount >= 4)
        #expect(CharacterAppearance.shirtColorCount >= 6)
        for seed in 0..<500 {
            let a = CharacterAppearance(seed: UInt64(seed) &* 0x9E37_79B9_7F4A_7C15 &+ 17)
            #expect((0..<CharacterAppearance.skinToneCount).contains(a.skinTone))
            #expect((0..<CharacterAppearance.hairStyleCount).contains(a.hairStyle))
            #expect((0..<CharacterAppearance.hairColorCount).contains(a.hairColor))
            #expect((0..<CharacterAppearance.shirtColorCount).contains(a.shirtColor))
        }
    }

    @Test func everyFieldVariesAcrossSeeds() {
        var skins = Set<Int>(), hairs = Set<Int>(), hairColors = Set<Int>(), shirts = Set<Int>()
        for seed in 0..<200 {
            let a = CharacterAppearance(seed: UInt64(seed))
            skins.insert(a.skinTone)
            hairs.insert(a.hairStyle)
            hairColors.insert(a.hairColor)
            shirts.insert(a.shirtColor)
        }
        #expect(skins.count == CharacterAppearance.skinToneCount)
        #expect(hairs.count == CharacterAppearance.hairStyleCount)
        #expect(hairColors.count == CharacterAppearance.hairColorCount)
        #expect(shirts.count == CharacterAppearance.shirtColorCount)
    }

    /// The v2 fields must never disturb the v1 stream. These are the exact
    /// skin / hair / hair-colour / shirt indices the pre-iteration-2
    /// derivation produced, recomputed independently from the SplitMix64
    /// definition — if a new appearance field is ever *inserted* rather than
    /// appended, every employee in every existing save changes face and this
    /// test catches it.
    @Test func oldSeedsKeepTheirOriginalLook() {
        let golden: [(seed: UInt64, skin: Int, hair: Int, hairColor: Int, shirt: Int)] = [
            (seed: 0, skin: 0, hair: 0, hairColor: 1, shirt: 4),
            (seed: 1, skin: 0, hair: 1, hairColor: 0, shirt: 3),
            (seed: 7, skin: 2, hair: 0, hairColor: 0, shirt: 3),
            (seed: 21, skin: 3, hair: 5, hairColor: 5, shirt: 1),
            (seed: 34, skin: 4, hair: 3, hairColor: 1, shirt: 7),
            (seed: 42, skin: 3, hair: 1, hairColor: 0, shirt: 4),
            (seed: 101, skin: 1, hair: 5, hairColor: 4, shirt: 7),
            (seed: 777, skin: 4, hair: 4, hairColor: 4, shirt: 3),
            (seed: 4242, skin: 0, hair: 4, hairColor: 1, shirt: 5),
            (seed: 0xDEAD_BEEF, skin: 2, hair: 2, hairColor: 5, shirt: 0),
            (seed: .max, skin: 1, hair: 3, hairColor: 1, shirt: 2),
        ]
        for entry in golden {
            let appearance = CharacterAppearance(seed: entry.seed)
            #expect(appearance.skinTone == entry.skin, "seed \(entry.seed) skin")
            #expect(appearance.hairStyle == entry.hair, "seed \(entry.seed) hair")
            #expect(appearance.hairColor == entry.hairColor, "seed \(entry.seed) hair colour")
            #expect(appearance.shirtColor == entry.shirt, "seed \(entry.seed) shirt")
        }
    }

    @Test func accessoriesVaryButStayInRange() {
        var withGlasses = 0, withBeards = 0
        var outfits = Set<Int>()
        for seed in 0..<400 {
            let appearance = CharacterAppearance(seed: UInt64(seed))
            if let style = appearance.glasses {
                #expect((0..<CharacterAppearance.glassesStyleCount).contains(style))
                withGlasses += 1
            }
            if appearance.hasBeard { withBeards += 1 }
            #expect((0..<CharacterAppearance.outfitCount).contains(appearance.outfit))
            outfits.insert(appearance.outfit)
        }
        // Roughly a third in glasses, roughly a quarter bearded: enough to
        // notice, not so many that everyone looks the same.
        #expect((60...220).contains(withGlasses), "\(withGlasses) of 400 wear glasses")
        #expect((50...180).contains(withBeards), "\(withBeards) of 400 have a beard")
        #expect(outfits.count == CharacterAppearance.outfitCount)
    }

    /// An appearance persisted before v2 has no accessory keys at all.
    @Test func decodesWhenTheV2KeysAreAbsent() throws {
        let legacy = Data(#"{"skinTone":2,"hairStyle":4,"hairColor":1,"shirtColor":5}"#.utf8)
        let decoded = try JSONDecoder().decode(CharacterAppearance.self, from: legacy)
        #expect(decoded.skinTone == 2)
        #expect(decoded.hairStyle == 4)
        #expect(decoded.hairColor == 1)
        #expect(decoded.shirtColor == 5)
        #expect(decoded.glasses == nil)
        #expect(decoded.hasBeard == false)
        #expect(decoded.outfit == 0)
    }

    @Test func codableRoundTrip() throws {
        let original = CharacterAppearance(seed: 987_654_321)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CharacterAppearance.self, from: data)
        #expect(decoded == original)
    }
}
