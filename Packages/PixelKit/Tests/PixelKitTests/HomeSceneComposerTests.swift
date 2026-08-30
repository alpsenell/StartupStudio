import Testing
@testable import PixelKit

@Suite("HomeSceneComposer")
struct HomeSceneComposerTests {
    // MARK: Helpers

    func founder(_ seed: UInt64 = 1) -> CharacterAppearance { CharacterAppearance(seed: seed) }

    func occupants(partner: Bool = false, children: Int = 0) -> HomeOccupants {
        HomeOccupants(
            founder: founder(),
            partner: partner ? CharacterAppearance(seed: 2) : nil,
            children: (0..<children).map { CharacterAppearance(seed: UInt64(10 + $0)) }
        )
    }

    func placements(of kind: PlacementKind, in scene: [PlacedSprite]) -> [PlacedSprite] {
        scene.filter { $0.kind == kind }
    }

    func prop(_ name: SpriteLibrary.HomePropName, in scene: [PlacedSprite]) -> PlacedSprite? {
        placements(of: .homeProp(name), in: scene).first
    }

    func overlaps(_ a: PlacedSprite, _ b: PlacedSprite) -> Bool {
        a.x < b.x + b.sprite.width && b.x < a.x + a.sprite.width
            && a.y < b.y + b.sprite.height && b.y < a.y + a.sprite.height
    }

    /// The founder (kind `.person`) — exactly one unless away.
    func founderPlacement(in scene: [PlacedSprite]) -> PlacedSprite? {
        placements(of: .person, in: scene).first
    }

    /// Every tier × activity pairing, for exhaustive layout checks.
    var allCombos: [(HomeTierStyle, HomeActivity)] {
        HomeTierStyle.allCases.flatMap { tier in HomeActivity.allCases.map { (tier, $0) } }
    }

    // MARK: Scene size

    @Test func sceneSizesGrowWithTier() {
        let sizes = HomeTierStyle.allCases.map { HomeSceneComposer.sceneSize(for: $0) }
        for size in sizes {
            #expect(size.width > 0 && size.height > 0)
        }
        let widths = sizes.map(\.width)
        #expect(widths == widths.sorted(), "wider homes as the tier rises")
        #expect(Set(widths).count == widths.count, "every tier has its own width")
        #expect(sizes[0].width < sizes[3].width)
    }

    @Test func sceneSizesStayCardFriendly() {
        for tier in HomeTierStyle.allCases {
            let size = HomeSceneComposer.sceneSize(for: tier)
            #expect(size.width <= 220, "\(tier) fits the office card widths")
            #expect(size.height <= 110)
            // Landscape, like the office scenes.
            #expect(size.width > size.height)
        }
    }

    @Test func roomSpriteFillsTheScene() {
        for tier in HomeTierStyle.allCases {
            let size = HomeSceneComposer.sceneSize(for: tier)
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .relaxing, mood: .okay)
            let rooms = placements(of: .room, in: scene)
            #expect(rooms.count == 1)
            #expect(scene.first?.kind == .room, "room is drawn first")
            #expect(rooms[0].x == 0 && rooms[0].y == 0)
            #expect(rooms[0].sprite.width == size.width)
            #expect(rooms[0].sprite.height == size.height)
        }
    }

    // MARK: Furniture per tier

    @Test func everyTierHasABedACouchAndALamp() {
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .relaxing, mood: .okay)
            #expect(prop(.bed, in: scene) != nil, "\(tier) bed")
            #expect(prop(.couch, in: scene) != nil, "\(tier) couch")
            #expect(prop(.lamp, in: scene) != nil, "\(tier) lamp")
        }
    }

    @Test func tierSpecificFurniture() {
        func scene(_ tier: HomeTierStyle) -> [PlacedSprite] {
            HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .relaxing, mood: .okay)
        }
        let studio = scene(.studioFlat)
        #expect(prop(.fridge, in: studio) != nil)
        #expect(prop(.windowNight, in: studio) != nil)
        #expect(prop(.diningTable, in: studio) == nil, "studio is too small for a table")
        #expect(prop(.armchair, in: studio) == nil)

        let apartment = scene(.apartment)
        #expect(prop(.tv, in: apartment) != nil)
        #expect(prop(.diningTable, in: apartment) != nil)
        #expect(prop(.plantHome, in: apartment) != nil)
        #expect(placements(of: .homeProp(.windowNight), in: apartment).count == 2)

        let house = scene(.house)
        #expect(prop(.fireplace, in: house) != nil)
        #expect(prop(.bookshelf, in: house) != nil)
        #expect(prop(.armchair, in: house) != nil)
        #expect(prop(.diningTable, in: house) != nil)
        #expect(prop(.tv, in: house) != nil)

        let penthouse = scene(.penthouse)
        let skyline = try! #require(prop(.skylineWindow, in: penthouse))
        #expect(skyline.sprite.width * 10 >= HomeSceneComposer.sceneSize(for: .penthouse).width * 8, "skyline spans the back wall")
        #expect(prop(.plantHome, in: penthouse) != nil)
        #expect(prop(.couch, in: penthouse) != nil)
    }

    // MARK: Founder placement by activity

    @Test func founderIsPlacedExactlyOnceUnlessAway() {
        for (tier, activity) in allCombos {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: activity, mood: .okay)
            let founders = placements(of: .person, in: scene)
            if !activity.isFounderHome {
                #expect(founders.isEmpty, "\(tier) \(activity): no founder")
            } else {
                #expect(founders.count == 1, "\(tier) \(activity): one founder")
            }
        }
    }

    @Test func sleepingFounderLiesInTheBed() {
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .sleeping, mood: .okay)
            let founder = try! #require(founderPlacement(in: scene))
            let bed = try! #require(prop(.bed, in: scene))
            #expect(overlaps(founder, bed), "\(tier): founder on the bed")
            #expect(founder.sprite == SpriteLibrary.person(appearance: self.founder(), pose: .lying, isFounder: true))
            #expect(founder.animation != .still, "breathing bob")
            #expect(placements(of: .bubble, in: scene).contains { $0.sprite == SpriteLibrary.zzzBubble() }, "zzz bubble")
        }
    }

    @Test func relaxingAndGamingFounderSitsOnTheCouch() {
        for tier in HomeTierStyle.allCases {
            for activity in [HomeActivity.relaxing, .gaming] {
                let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: activity, mood: .okay)
                let founder = try! #require(founderPlacement(in: scene))
                let couch = try! #require(prop(.couch, in: scene))
                #expect(overlaps(founder, couch), "\(tier) \(activity): founder on the couch")
                #expect(founder.sprite == SpriteLibrary.person(appearance: self.founder(), pose: .seatedCouch, isFounder: true))
                #expect(founder.x >= couch.x && founder.x + founder.sprite.width <= couch.x + couch.sprite.width)
            }
        }
    }

    @Test func gamingAddsAControllerOverTheFoundersHands() {
        let relaxing = HomeSceneComposer.compose(tier: .apartment, occupants: occupants(), activity: .relaxing, mood: .okay)
        let gaming = HomeSceneComposer.compose(tier: .apartment, occupants: occupants(), activity: .gaming, mood: .okay)
        let founder = try! #require(founderPlacement(in: gaming))
        let extras = gaming.filter { $0.kind == .prop }
        #expect(extras.contains { overlaps($0, founder) }, "controller sits on the founder")
        #expect(gaming.filter { $0.kind == .prop }.count > relaxing.filter { $0.kind == .prop }.count)
        #expect(founder.animation == .toggle(period: 2), "controller wiggle is the fast 2-frame")
    }

    @Test func dinnerSeatsTheFounderAtTheTableWhereThereIsOne() {
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .dinner, mood: .okay)
            let founder = try! #require(founderPlacement(in: scene))
            if let table = prop(.diningTable, in: scene) {
                #expect(overlaps(founder, table), "\(tier): founder at the table")
                #expect(founder.sprite == SpriteLibrary.person(appearance: self.founder(), pose: .seated, isFounder: true))
                // The table is drawn over the founder's lap, like office desks.
                let founderIndex = scene.firstIndex(of: founder)!
                let tableIndex = scene.firstIndex(of: table)!
                #expect(tableIndex > founderIndex)
            } else {
                let couch = try! #require(prop(.couch, in: scene))
                #expect(overlaps(founder, couch), "\(tier): no table → dinner on the couch")
            }
        }
    }

    @Test func exercisingFounderStandsOnTheYogaMat() {
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .exercising, mood: .okay)
            let founder = try! #require(founderPlacement(in: scene))
            let mat = try! #require(prop(.yogaMat, in: scene))
            #expect(prop(.dumbbells, in: scene) != nil)
            #expect(overlaps(founder, mat), "\(tier): founder on the mat")
            #expect(founder.sprite.frameCount == 2, "up/down exercise frames")
            #expect(founder.animation != .still)
            // The mat is only shown while exercising.
            let relaxing = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .relaxing, mood: .okay)
            #expect(prop(.yogaMat, in: relaxing) == nil)
        }
    }

    @Test func readingFounderUsesTheArmchairWhenThereIsOne() {
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .reading, mood: .okay)
            let founder = try! #require(founderPlacement(in: scene))
            let seat = prop(.armchair, in: scene) ?? prop(.couch, in: scene)!
            #expect(overlaps(founder, seat), "\(tier): reading in the armchair or on the couch")
            #expect(founder.sprite == SpriteLibrary.person(appearance: self.founder(), pose: .seatedCouch, isFounder: true))
            #expect(scene.contains { $0.kind == .prop && overlaps($0, founder) }, "book in hand")
        }
    }

    @Test func withBabyFounderHoldsTheBabyByTheCrib() {
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(
                tier: tier, occupants: occupants(children: 1), activity: .withBaby, mood: .okay
            )
            let founder = try! #require(founderPlacement(in: scene))
            #expect(founder.sprite == SpriteLibrary.person(appearance: self.founder(), pose: .holdingBaby, isFounder: true))
            #expect(placements(of: .baby, in: scene).isEmpty, "the baby is in the founder's arms, not the crib")
            if tier == .studioFlat {
                #expect(prop(.crib, in: scene) == nil, "studio has no room for a crib")
            } else {
                let crib = try! #require(prop(.crib, in: scene))
                let gap = max(crib.x - (founder.x + founder.sprite.width), founder.x - (crib.x + crib.sprite.width))
                #expect(gap <= 6 && gap >= 0, "\(tier): founder stands right beside the crib (gap \(gap))")
            }
        }
    }

    @Test func cribAndBabyRules() {
        // No children → no crib (unless holding the baby).
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .relaxing, mood: .okay)
            #expect(prop(.crib, in: scene) == nil, "\(tier): no kids, no crib")
            #expect(placements(of: .baby, in: scene).isEmpty)
        }
        // Children at apartment+ → crib with a baby bundle inside.
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(children: 2), activity: .relaxing, mood: .okay)
            if tier == .studioFlat {
                #expect(prop(.crib, in: scene) == nil)
                #expect(placements(of: .baby, in: scene).isEmpty)
            } else {
                let crib = try! #require(prop(.crib, in: scene))
                let babies = placements(of: .baby, in: scene)
                #expect(babies.count == 1)
                #expect(overlaps(babies[0], crib), "baby inside the crib")
                #expect(scene.firstIndex(of: babies[0])! > scene.firstIndex(of: crib)!, "baby drawn over the mattress")
                #expect(babies[0].animation != .still, "baby rocks")
            }
        }
    }

    // MARK: Partner & children

    @Test func partnerIsPlacedWhenPresentAndAbsentOtherwise() {
        for (tier, activity) in allCombos {
            let alone = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: activity, mood: .okay)
            #expect(placements(of: .partner, in: alone).isEmpty, "\(tier) \(activity): no partner")
            let together = HomeSceneComposer.compose(tier: tier, occupants: occupants(partner: true), activity: activity, mood: .okay)
            #expect(placements(of: .partner, in: together).count == 1, "\(tier) \(activity): partner placed")
        }
    }

    @Test func partnerPlacementFollowsTheActivity() {
        for tier in HomeTierStyle.allCases {
            let sleeping = HomeSceneComposer.compose(tier: tier, occupants: occupants(partner: true), activity: .sleeping, mood: .okay)
            let bed = prop(.bed, in: sleeping)!
            let partner = placements(of: .partner, in: sleeping)[0]
            #expect(overlaps(partner, bed), "\(tier): two in the bed")
            #expect(partner.sprite == SpriteLibrary.person(appearance: CharacterAppearance(seed: 2), pose: .lying))
            // Partner lies behind the founder: drawn first.
            let founder = founderPlacement(in: sleeping)!
            #expect(sleeping.firstIndex(of: partner)! < sleeping.firstIndex(of: founder)!)

            let dinner = HomeSceneComposer.compose(tier: tier, occupants: occupants(partner: true), activity: .dinner, mood: .okay)
            let dinnerPartner = placements(of: .partner, in: dinner)[0]
            // Somebody has to cook: with a kitchen the partner is at the
            // stove, otherwise they are opposite the founder at the table.
            if let stove = prop(.stove, in: dinner) {
                #expect(overlaps(dinnerPartner, stove), "\(tier): partner cooking at the stove")
            } else if let table = prop(.diningTable, in: dinner) {
                #expect(overlaps(dinnerPartner, table), "\(tier): partner at the table too")
                let founderAtTable = founderPlacement(in: dinner)!
                #expect(dinnerPartner.x != founderAtTable.x, "opposite seats")
            } else {
                #expect(overlaps(dinnerPartner, prop(.couch, in: dinner)!))
            }
            // Dinner with a partner gets a heart bubble somewhere in the scene.
            let hearts = placements(of: .bubble, in: dinner).filter { $0.sprite == SpriteLibrary.moodBubble(.great) }
            #expect(!hearts.isEmpty, "\(tier): date night heart")

            let relaxing = HomeSceneComposer.compose(tier: tier, occupants: occupants(partner: true), activity: .relaxing, mood: .okay)
            let couchPartner = placements(of: .partner, in: relaxing)[0]
            #expect(overlaps(couchPartner, prop(.couch, in: relaxing)!), "\(tier): partner on the couch beside")
        }
    }

    @Test func childrenAreRenderedAsSmallBouncingSprites() {
        for tier in HomeTierStyle.allCases {
            for count in 0...3 {
                let scene = HomeSceneComposer.compose(
                    tier: tier, occupants: occupants(partner: true, children: count), activity: .relaxing, mood: .okay
                )
                let kids = placements(of: .child, in: scene)
                #expect(kids.count == count, "\(tier): \(count) children")
                for kid in kids {
                    #expect(kid.sprite.frameCount == 2)
                    #expect(kid.animation != .still, "kids bounce")
                    #expect(kid.sprite.width <= 10 && kid.sprite.height <= 14, "kids are small")
                }
                #expect(Set(kids.map(\.phase)).count == kids.count, "kids bounce out of sync")
            }
        }
    }

    @Test func childrenAreCappedAtThree() {
        let many = HomeOccupants(founder: founder(), children: (0..<6).map { CharacterAppearance(seed: UInt64($0)) })
        let scene = HomeSceneComposer.compose(tier: .house, occupants: many, activity: .relaxing, mood: .okay)
        #expect(placements(of: .child, in: scene).count == 3)
    }

    @Test func awayShowsASuitcaseAndKeepsTheFamily() {
        for tier in HomeTierStyle.allCases {
            let scene = HomeSceneComposer.compose(
                tier: tier, occupants: occupants(partner: true, children: 2), activity: .away, mood: .great
            )
            #expect(placements(of: .person, in: scene).isEmpty, "\(tier): founder is away")
            #expect(prop(.suitcase, in: scene) != nil, "\(tier): suitcase by the door")
            #expect(placements(of: .partner, in: scene).count == 1)
            #expect(placements(of: .child, in: scene).count == 2)
            #expect(placements(of: .bubble, in: scene).isEmpty, "no founder → no mood bubble")

            let home = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: .relaxing, mood: .okay)
            #expect(prop(.suitcase, in: home) == nil, "suitcase only while away")
        }
    }

    // MARK: Mood bubble

    @Test func moodBubbleFloatsAboveTheFoundersHead() {
        for (tier, activity) in allCombos where activity.isFounderHome && activity != .sleeping && activity != .crunching {
            for mood in MoodLevel.allCases {
                let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(), activity: activity, mood: mood)
                let founder = founderPlacement(in: scene)!
                let bubbles = placements(of: .bubble, in: scene).filter { $0.sprite == SpriteLibrary.moodBubble(mood) }
                if mood == .okay {
                    #expect(bubbles.isEmpty, "\(tier) \(activity): okay mood shows no bubble")
                } else {
                    #expect(bubbles.count == 1, "\(tier) \(activity) \(mood): one mood bubble")
                    let bubble = bubbles[0]
                    #expect(bubble.y + bubble.sprite.height <= founder.y + 2, "above the head")
                    #expect(bubble.x >= founder.x - 2 && bubble.x < founder.x + founder.sprite.width, "over the founder")
                    #expect(scene.firstIndex(of: bubble)! > scene.firstIndex(of: founder)!, "bubbles draw last")
                }
            }
        }
    }

    // MARK: Global invariants

    @Test func everyPlacementStaysInsideTheScene() {
        for (tier, activity) in allCombos {
            for mood in MoodLevel.allCases {
                let size = HomeSceneComposer.sceneSize(for: tier)
                let scene = HomeSceneComposer.compose(
                    tier: tier, occupants: occupants(partner: true, children: 3), activity: activity, mood: mood
                )
                for p in scene {
                    #expect(p.x >= 0 && p.y >= 0, "\(tier) \(activity) \(p.kind) origin (\(p.x), \(p.y))")
                    #expect(p.x + p.sprite.width <= size.width, "\(tier) \(activity) \(p.kind) right edge")
                    #expect(p.y + p.sprite.height <= size.height, "\(tier) \(activity) \(p.kind) bottom edge")
                }
            }
        }
    }

    @Test func peopleNeverOverlapEachOther() {
        for (tier, activity) in allCombos {
            let scene = HomeSceneComposer.compose(
                tier: tier, occupants: occupants(partner: true, children: 3), activity: activity, mood: .great
            )
            let people = scene.filter { [.person, .partner, .child].contains($0.kind) }
            for i in people.indices {
                for j in people.indices where j > i {
                    // Two in the bed deliberately stack (partner behind the founder).
                    let bothInBed = activity == .sleeping && people[i].kind != .child && people[j].kind != .child
                    if !bothInBed {
                        #expect(!overlaps(people[i], people[j]), "\(tier) \(activity): \(people[i].kind) overlaps \(people[j].kind)")
                    }
                }
            }
        }
    }

    /// Nobody stands inside the tall furniture. People may of course occupy
    /// the thing they are *using* (bed, couch, armchair, table, crib, mat,
    /// range) and may stand among floor-level clutter — a kid beside the
    /// laundry pile is the point — but a person drawn through the fridge,
    /// the TV, the bookshelf, the fireplace, the lamp, a plant or a window
    /// is a layout bug.
    @Test func peopleNeverStandInsideTallFurniture() {
        let tall: Set<SpriteLibrary.HomePropName> = [
            .fridge, .tv, .bookshelf, .fireplace, .lamp, .plantHome, .deadPlant,
            .flowerVase, .skylineWindow, .windowNight,
        ]
        for (tier, activity) in allCombos {
            for mood in MoodLevel.allCases {
                let scene = HomeSceneComposer.compose(
                    tier: tier, occupants: occupants(partner: true, children: 3), activity: activity, mood: mood
                )
                let people = scene.filter { [.person, .partner, .child].contains($0.kind) }
                for placement in scene {
                    guard case .homeProp(let name) = placement.kind, tall.contains(name) else { continue }
                    for person in people {
                        #expect(
                            !overlaps(person, placement),
                            "\(tier) \(activity) \(mood): \(person.kind) is drawn inside the \(name)"
                        )
                    }
                }
            }
        }
    }

    /// Floor clutter is drawn before the people who walk among it, so a
    /// person always occludes the mess rather than the other way round.
    @Test func floorClutterIsDrawnBehindPeople() {
        let clutter: Set<SpriteLibrary.HomePropName> = [.laundryPile, .takeoutBoxes, .dumbbells, .yogaMat, .catBed]
        for (tier, activity) in allCombos {
            let scene = HomeSceneComposer.compose(
                tier: tier, occupants: occupants(partner: true, children: 3), activity: activity, mood: .low
            )
            guard let firstPerson = scene.firstIndex(where: { [.person, .partner, .child].contains($0.kind) }) else {
                continue
            }
            for (index, placement) in scene.enumerated() {
                guard case .homeProp(let name) = placement.kind, clutter.contains(name) else { continue }
                #expect(index < firstPerson, "\(tier) \(activity): \(name) draws over people")
            }
        }
    }

    @Test func peopleStandOnTheFloorNotTheWall() {
        for (tier, activity) in allCombos where activity.isFounderHome {
            let scene = HomeSceneComposer.compose(
                tier: tier, occupants: occupants(partner: true, children: 3), activity: activity, mood: .okay
            )
            let wall = HomeSceneComposer.wallHeight(for: tier)
            for p in scene where [.person, .partner, .child].contains(p.kind) {
                #expect(p.y + p.sprite.height > wall, "\(tier) \(activity): \(p.kind) feet below the wall line")
            }
        }
    }

    @Test func peopleAreDrawnAfterFurnitureTheySitOn() {
        for (tier, activity) in allCombos where activity.isFounderHome {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(partner: true), activity: activity, mood: .okay)
            let founderIndex = scene.firstIndex { $0.kind == .person }!
            let seats: [SpriteLibrary.HomePropName] = [.bed, .couch, .armchair]
            for seat in seats {
                if let seatIndex = scene.firstIndex(where: { $0.kind == .homeProp(seat) }) {
                    #expect(seatIndex < founderIndex, "\(tier) \(activity): \(seat) behind the founder")
                }
            }
        }
    }

    @Test func compositionIsDeterministic() {
        for (tier, activity) in allCombos {
            let a = HomeSceneComposer.compose(tier: tier, occupants: occupants(partner: true, children: 2), activity: activity, mood: .low)
            let b = HomeSceneComposer.compose(tier: tier, occupants: occupants(partner: true, children: 2), activity: activity, mood: .low)
            #expect(a == b)
        }
    }

    @Test func frameIndexNeverExceedsFrameCount() {
        for (tier, activity) in allCombos {
            let scene = HomeSceneComposer.compose(tier: tier, occupants: occupants(partner: true, children: 3), activity: activity, mood: .great)
            for p in scene {
                for tick in 0..<24 {
                    let f = p.frameIndex(atTick: tick)
                    #expect(f >= 0 && f < p.sprite.frameCount)
                }
            }
        }
    }

    @Test func toggleAnimationAlternatesEveryPeriod() {
        let sprite = SpriteLibrary.child(appearance: CharacterAppearance(seed: 3))
        let fast = PlacedSprite(sprite: sprite, x: 0, y: 0, kind: .child, animation: .toggle(period: 2), phase: 0)
        #expect((0..<8).map { fast.frameIndex(atTick: $0) } == [0, 0, 1, 1, 0, 0, 1, 1])
        let slow = PlacedSprite(sprite: sprite, x: 0, y: 0, kind: .child, animation: .toggle(period: 4), phase: 1)
        #expect((0..<8).map { slow.frameIndex(atTick: $0) } == [1, 1, 1, 1, 0, 0, 0, 0])
        let still = PlacedSprite(sprite: SpriteLibrary.homeProp(.bed), x: 0, y: 0, kind: .homeProp(.bed), animation: .toggle(period: 1), phase: 0)
        #expect((0..<6).allSatisfy { still.frameIndex(atTick: $0) == 0 }, "single-frame sprites clamp")
    }
}
