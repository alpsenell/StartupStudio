import Testing
@testable import PixelKit

@Suite("Home sprites")
struct HomeSpriteLibraryTests {
    /// Every skin × hair style, plus a spread of hair/shirt colors.
    var appearances: [CharacterAppearance] {
        var list: [CharacterAppearance] = []
        for skin in 0..<CharacterAppearance.skinToneCount {
            for hair in 0..<CharacterAppearance.hairStyleCount {
                var a = CharacterAppearance(seed: 1)
                a.skinTone = skin
                a.hairStyle = hair
                a.hairColor = (skin + hair) % CharacterAppearance.hairColorCount
                a.shirtColor = (skin * 3 + hair) % CharacterAppearance.shirtColorCount
                list.append(a)
            }
        }
        return list
    }

    @Test func posesAreDimensionStableAcrossAppearances() {
        for pose in SpriteLibrary.PersonPose.allCases {
            var dims = Set<[Int]>()
            var frameCounts = Set<Int>()
            for appearance in appearances {
                for isFounder in [false, true] {
                    let sprite = SpriteLibrary.person(appearance: appearance, pose: pose, isFounder: isFounder)
                    dims.insert([sprite.width, sprite.height])
                    frameCounts.insert(sprite.frameCount)
                }
            }
            #expect(dims.count == 1, "\(pose) shares one canvas across appearances")
            #expect(frameCounts.count == 1)
        }
    }

    @Test func poseDimensionsMatchArtDirection() {
        let a = CharacterAppearance(seed: 5)
        let seated = SpriteLibrary.person(appearance: a, pose: .seated)
        #expect(seated == SpriteLibrary.person(appearance: a), "seated pose is the existing office sprite")
        let standing = SpriteLibrary.person(appearance: a, pose: .standing)
        #expect(standing.width == 14 && standing.height == 22)
        #expect(standing.frameCount == 2)
        let lying = SpriteLibrary.person(appearance: a, pose: .lying)
        #expect(lying.width > lying.height, "lying is a wide sprite")
        #expect(lying.frameCount == 2, "breathing bob")
        let couch = SpriteLibrary.person(appearance: a, pose: .seatedCouch)
        #expect(couch.width == 14 && (18...22).contains(couch.height))
        #expect(couch.frameCount == 2)
        let baby = SpriteLibrary.person(appearance: a, pose: .holdingBaby)
        #expect(baby.width == 14 && baby.height == 22)
        #expect(baby.frameCount == 2, "rocking")
        #expect(baby != standing, "bundle is visible")
    }

    @Test func founderVariantIsDistinctButSameSize() {
        let a = CharacterAppearance(seed: 9)
        for pose in SpriteLibrary.PersonPose.allCases {
            let regular = SpriteLibrary.person(appearance: a, pose: pose)
            let founder = SpriteLibrary.person(appearance: a, pose: pose, isFounder: true)
            #expect(regular.width == founder.width && regular.height == founder.height)
            #expect(regular.frameCount == founder.frameCount)
            if pose != .lying {
                #expect(regular != founder, "\(pose): hoodie collar distinguishes the founder")
            }
        }
    }

    @Test func everyFrameOfEveryPoseIsDifferentFromTheNext() {
        let a = CharacterAppearance(seed: 12)
        for pose in SpriteLibrary.PersonPose.allCases {
            let sprite = SpriteLibrary.person(appearance: a, pose: pose)
            #expect(sprite.frames[0] != sprite.frames[1], "\(pose) animates")
        }
    }

    @Test func exercisingSpriteHasTwoDistinctFramesAndStableSize() {
        var dims = Set<[Int]>()
        for appearance in appearances {
            let sprite = SpriteLibrary.exercisingPerson(appearance: appearance, isFounder: true)
            dims.insert([sprite.width, sprite.height])
            #expect(sprite.frameCount == 2)
            #expect(sprite.frames[0] != sprite.frames[1])
        }
        #expect(dims.count == 1)
    }

    @Test func childIsSmallTwoFrameAndAppearanceStable() {
        var dims = Set<[Int]>()
        for appearance in appearances {
            let child = SpriteLibrary.child(appearance: appearance)
            dims.insert([child.width, child.height])
            #expect(child.frameCount == 2)
            #expect(child.frames[0] != child.frames[1], "bounce")
        }
        #expect(dims.count == 1)
        let child = SpriteLibrary.child(appearance: CharacterAppearance(seed: 1))
        #expect(child.width == 8)
        #expect((11...13).contains(child.height))
        // Distinct hair styles read on the child too.
        var a = CharacterAppearance(seed: 1), b = a
        a.hairStyle = 1
        b.hairStyle = 4
        #expect(SpriteLibrary.child(appearance: a) != SpriteLibrary.child(appearance: b))
    }

    @Test func babyBundleRocks() {
        let baby = SpriteLibrary.baby()
        #expect(baby.frameCount == 2)
        #expect(baby.frames[0] != baby.frames[1])
        #expect(baby.width <= 12 && baby.height <= 8)
        #expect(baby == SpriteLibrary.baby(), "deterministic")
    }

    @Test func everyHomePropBuildsAndIsStable() {
        for name in SpriteLibrary.HomePropName.allCases {
            let sprite = SpriteLibrary.homeProp(name)
            #expect(sprite.width > 0 && sprite.height > 0, "\(name) has pixels")
            #expect(sprite == SpriteLibrary.homeProp(name), "\(name) deterministic")
            let bytes = rgbaBytes(of: sprite.cgImage(frame: 0))
            #expect(bytes.contains { $0 != 0 }, "\(name) draws something")
        }
        #expect(SpriteLibrary.HomePropName.allCases.count == 22, "16 original props plus the six mood/kitchen props")
    }

    @Test func animatedPropsHaveTwoFrames() {
        for name in [SpriteLibrary.HomePropName.tv, .fireplace, .lamp] {
            #expect(SpriteLibrary.homeProp(name).frameCount == 2, "\(name) glows/flickers")
        }
        for name in [SpriteLibrary.HomePropName.bed, .couch, .suitcase, .bookshelf] {
            #expect(SpriteLibrary.homeProp(name).frameCount == 1, "\(name) is still")
        }
    }

    @Test func moodBubblesShareOneCanvasAndOkayIsTransparent() {
        var dims = Set<[Int]>()
        for mood in MoodLevel.allCases {
            let bubble = SpriteLibrary.moodBubble(mood)
            dims.insert([bubble.width, bubble.height])
        }
        #expect(dims.count == 1)
        let okay = rgbaBytes(of: SpriteLibrary.moodBubble(.okay).cgImage(frame: 0))
        #expect(okay.allSatisfy { $0 == 0 }, "okay mood draws nothing")
        for mood in [MoodLevel.great, .low] {
            let bytes = rgbaBytes(of: SpriteLibrary.moodBubble(mood).cgImage(frame: 0))
            #expect(bytes.contains { $0 != 0 }, "\(mood) draws a bubble")
        }
        #expect(SpriteLibrary.moodBubble(.great) != SpriteLibrary.moodBubble(.low))
        // Same footprint as the office status bubbles so layouts line up.
        let office = SpriteLibrary.statusBubble(.coding)
        #expect(SpriteLibrary.moodBubble(.great).width == office.width)
        #expect(SpriteLibrary.moodBubble(.great).height == office.height)
    }

    @Test func zzzBubbleDrifts() {
        let zzz = SpriteLibrary.zzzBubble()
        #expect(zzz.frameCount == 2)
        #expect(zzz.frames[0] != zzz.frames[1])
        #expect(zzz.width == SpriteLibrary.moodBubble(.great).width)
        #expect(zzz.height == SpriteLibrary.moodBubble(.great).height)
    }

    @Test func homeRoomsFillTheirCanvasWithAFrame() {
        for tier in HomeTierStyle.allCases {
            let room = RoomBuilder.homeRoom(tier: tier, width: 60, height: 40, wallHeight: 20)
            #expect(room.width == 60 && room.height == 40)
            // The room is stamped by `PixelCanvas`, which assigns its own
            // palette characters, so the frame is checked by color.
            let frame = room.frames[0]
            func color(_ x: Int, _ y: Int) -> PixelSprite.RGBA? {
                let row = Array(frame[y])
                return room.palette[row[x]]
            }
            #expect((0..<60).allSatisfy { color($0, 0) == Palettes.outline })
            #expect((0..<60).allSatisfy { color($0, 39) == Palettes.outline })
            #expect((0..<40).allSatisfy { color(0, $0) == Palettes.outline && color(59, $0) == Palettes.outline })
            // Wall and floor are visibly different surfaces.
            #expect(color(5, 5) != color(5, 30))
        }
    }

    @Test func homeTypesAreFrozen() {
        #expect(HomeTierStyle.allCases == [.studioFlat, .apartment, .house, .penthouse])
        #expect(HomeActivity.allCases == [
            .relaxing, .sleeping, .gaming, .dinner, .exercising, .reading, .withBaby, .away,
            .crunching, .awayPartnerAlone,
        ], "v2 activities are appended, never inserted")
        #expect(HomeActivity.allCases.filter { !$0.isFounderHome } == [.away, .awayPartnerAlone])
        #expect(MoodLevel.allCases == [.great, .okay, .low])
        let occupants = HomeOccupants(founder: CharacterAppearance(seed: 1))
        #expect(occupants.partner == nil && occupants.children.isEmpty)
        #expect(HomeTierStyle.studioFlat.rawValue == "studioFlat")
    }
}
