import Testing
@testable import PixelKit

@Suite("SpriteLibrary")
struct SpriteLibraryTests {
    @Test func everySkinAndHairComboBuildsIdenticallySizedPeople() {
        var dims = Set<[Int]>()
        for skin in 0..<CharacterAppearance.skinToneCount {
            for hair in 0..<CharacterAppearance.hairStyleCount {
                var appearance = CharacterAppearance(seed: 1)
                appearance.skinTone = skin
                appearance.hairStyle = hair
                appearance.hairColor = hair % CharacterAppearance.hairColorCount
                appearance.shirtColor = (skin + hair) % CharacterAppearance.shirtColorCount
                let sprite = SpriteLibrary.person(appearance: appearance)
                dims.insert([sprite.width, sprite.height])
                #expect(sprite.frameCount == 3, "typing A, typing B, blink")
            }
        }
        #expect(dims.count == 1, "all people share one canvas size")
    }

    @Test func personDimensionsMatchArtDirection() {
        let sprite = SpriteLibrary.person(appearance: CharacterAppearance(seed: 7))
        #expect((12...14).contains(sprite.width))
        #expect((16...18).contains(sprite.height))
    }

    @Test func founderVariantKeepsDimensions() {
        let appearance = CharacterAppearance(seed: 3)
        let regular = SpriteLibrary.person(appearance: appearance)
        let founder = SpriteLibrary.person(appearance: appearance, isFounder: true)
        #expect(founder.width == regular.width)
        #expect(founder.height == regular.height)
        #expect(founder.frameCount == regular.frameCount)
        #expect(founder != regular, "founder must be visually distinguishable")
    }

    @Test func everyShirtAndHairColorBuilds() {
        for shirt in 0..<CharacterAppearance.shirtColorCount {
            for hairColor in 0..<CharacterAppearance.hairColorCount {
                var appearance = CharacterAppearance(seed: 11)
                appearance.shirtColor = shirt
                appearance.hairColor = hairColor
                _ = SpriteLibrary.person(appearance: appearance)
            }
        }
    }

    @Test func deskIsStableAndSized() {
        let desk = SpriteLibrary.desk()
        #expect((20...24).contains(desk.width))
        #expect(desk.height > 0)
        #expect(desk == SpriteLibrary.desk(), "desk dimensions/content stable across calls")
    }

    @Test func monitorHasTwoGlowFrames() {
        let monitor = SpriteLibrary.monitor()
        #expect(monitor.frameCount == 2)
        #expect(monitor == SpriteLibrary.monitor())
        #expect(monitor.width > 0 && monitor.height > 0)
    }

    @Test func everyStatusBuildsABubbleOfSharedSize() {
        var dims = Set<[Int]>()
        for status in WorkStatus.allCases {
            let bubble = SpriteLibrary.statusBubble(status)
            dims.insert([bubble.width, bubble.height])
        }
        #expect(dims.count == 1, "bubbles share one canvas so layout is uniform")
    }

    @Test func idleBubbleIsFullyTransparent() {
        let bubble = SpriteLibrary.statusBubble(.idle)
        let bytes = rgbaBytes(of: bubble.cgImage(frame: 0))
        #expect(bytes.allSatisfy { $0 == 0 })
    }

    @Test func nonIdleBubblesHaveVisiblePixels() {
        for status in WorkStatus.allCases where status != .idle {
            let bubble = SpriteLibrary.statusBubble(status)
            let bytes = rgbaBytes(of: bubble.cgImage(frame: 0))
            #expect(bytes.contains { $0 != 0 }, "\(status) bubble should draw something")
        }
    }

    @Test func everyPropBuilds() {
        for prop in SpriteLibrary.PropName.allCases {
            let sprite = SpriteLibrary.prop(prop)
            #expect(sprite.width > 0 && sprite.height > 0, "\(prop) should have pixels")
        }
    }
}
