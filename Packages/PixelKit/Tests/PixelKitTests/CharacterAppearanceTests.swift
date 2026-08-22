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

    @Test func codableRoundTrip() throws {
        let original = CharacterAppearance(seed: 987_654_321)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CharacterAppearance.self, from: data)
        #expect(decoded == original)
    }
}
