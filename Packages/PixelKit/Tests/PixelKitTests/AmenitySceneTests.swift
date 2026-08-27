import Foundation
import Testing
@testable import PixelKit

@Suite("SceneComposer amenities")
struct AmenitySceneTests {
    func occupant(seed: UInt64, status: WorkStatus = .coding, isFounder: Bool = false) -> Occupant {
        Occupant(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", seed))!,
            appearance: CharacterAppearance(seed: seed),
            status: status,
            isFounder: isFounder
        )
    }

    /// A full house of non-idle workers for a tier (founder + every desk filled).
    func fullCrowd(for tier: OfficeTierStyle, statuses: [WorkStatus] = [.coding, .designing, .marketing, .researching, .testing, .legal, .peopleOps, .operations]) -> [Occupant] {
        (0...tier.deskCapacity).map {
            occupant(seed: UInt64($0 + 500), status: statuses[$0 % statuses.count], isFounder: $0 == 0)
        }
    }

    /// Every subset of `AmenityStyle.allCases` (16 sets).
    static let powerSet: [Set<AmenityStyle>] = {
        let all = AmenityStyle.allCases
        return (0..<(1 << all.count)).map { mask in
            Set(all.enumerated().compactMap { mask & (1 << $0.offset) != 0 ? $0.element : nil })
        }
    }()

    func amenityProps(in scene: [PlacedSprite]) -> [PlacedSprite] {
        scene.filter {
            if case .amenityProp = $0.kind { return true }
            return false
        }
    }

    func amenityPropNames(in scene: [PlacedSprite]) -> [SpriteLibrary.AmenityPropName] {
        scene.compactMap {
            if case .amenityProp(let name) = $0.kind { return name }
            return nil
        }
    }

    func overlaps(_ a: PlacedSprite, _ b: PlacedSprite) -> Bool {
        a.x < b.x + b.sprite.width && b.x < a.x + a.sprite.width
            && a.y < b.y + b.sprite.height && b.y < a.y + a.sprite.height
    }

    // MARK: Legacy compatibility

    @Test func legacyComposeEqualsEmptyAmenities() {
        for tier in OfficeTierStyle.allCases {
            let crowd = fullCrowd(for: tier)
            let legacy = SceneComposer.compose(tier: tier, occupants: crowd)
            let explicit = SceneComposer.compose(tier: tier, occupants: crowd, amenities: [])
            #expect(legacy == explicit, "\(tier)")
            #expect(amenityProps(in: legacy).isEmpty)
        }
    }

    @Test func sceneSizeGrowsMonotonicallyWithTier() {
        let sizes = OfficeTierStyle.allCases.map(SceneComposer.sceneSize(for:))
        for (smaller, larger) in zip(sizes, sizes.dropFirst()) {
            #expect(larger.width >= smaller.width)
            #expect(larger.height >= smaller.height)
            #expect(larger.width * larger.height > smaller.width * smaller.height)
        }
    }

    // MARK: Zone capacity and priority

    @Test func garageNeverShowsAmenities() {
        for set in Self.powerSet {
            let scene = SceneComposer.compose(tier: .garage, occupants: fullCrowd(for: .garage), amenities: set)
            #expect(amenityProps(in: scene).isEmpty, "\(set)")
        }
    }

    @Test func loftOnlyFitsTheGameRoom() {
        let all = Set(AmenityStyle.allCases)
        let withGameRoom = SceneComposer.compose(tier: .loft, occupants: [], amenities: all)
        #expect(Set(amenityPropNames(in: withGameRoom)) == [.arcadeCabinet, .foosballTable])

        let withoutGameRoom = SceneComposer.compose(tier: .loft, occupants: [], amenities: [.cafeteria, .shuttle, .gym])
        #expect(amenityProps(in: withoutGameRoom).isEmpty)
    }

    @Test func zonesRenderTheirPropSets() {
        let expectations: [AmenityStyle: [SpriteLibrary.AmenityPropName]] = [
            .gameRoom: [.arcadeCabinet, .foosballTable],
            .cafeteria: [.cafeteriaCounter, .cafeteriaTable, .cafeteriaTable, .vendingMachine],
            .shuttle: [.shuttleVan],
            .gym: [.treadmill, .weightRack],
        ]
        for (amenity, props) in expectations {
            let scene = SceneComposer.compose(tier: .campus, occupants: [], amenities: [amenity])
            #expect(amenityPropNames(in: scene).sorted { $0.rawValue < $1.rawValue } == props.sorted { $0.rawValue < $1.rawValue }, "\(amenity)")
        }
    }

    @Test func studioDropsTheLastAmenityByCaseOrder() {
        let scene = SceneComposer.compose(tier: .studio, occupants: [], amenities: Set(AmenityStyle.allCases))
        let names = Set(amenityPropNames(in: scene))
        #expect(names.contains(.arcadeCabinet))
        #expect(names.contains(.cafeteriaCounter))
        #expect(names.contains(.shuttleVan))
        #expect(!names.contains(.treadmill), "gym is 4th in case order; studio has 3 zones")
        #expect(!names.contains(.weightRack))

        // With the game room absent the gym gets the third slot.
        let noGameRoom = SceneComposer.compose(tier: .studio, occupants: [], amenities: [.cafeteria, .shuttle, .gym])
        #expect(Set(amenityPropNames(in: noGameRoom)).contains(.treadmill))
    }

    @Test func campusShowsAllFour() {
        let scene = SceneComposer.compose(tier: .campus, occupants: fullCrowd(for: .campus), amenities: Set(AmenityStyle.allCases))
        #expect(Set(amenityPropNames(in: scene)) == Set(SpriteLibrary.AmenityPropName.allCases))
    }

    @Test func shuttleVanIsParkedOutsideOnTheBackWall() {
        for tier in [OfficeTierStyle.studio, .campus] {
            let scene = SceneComposer.compose(tier: tier, occupants: fullCrowd(for: tier), amenities: [.shuttle])
            let vans = amenityProps(in: scene)
            #expect(vans.count == 1)
            guard let van = vans.first else { continue }
            let desks = scene.filter { $0.kind == .desk }
            let topDesk = desks.map(\.y).min()!
            #expect(van.y + van.sprite.height <= topDesk, "\(tier): van window sits on the wall above the back row")
        }
    }

    // MARK: Geometry for every tier x every subset

    @Test func everyZoneStaysInBoundsAndClearOfDesksPeopleAndProps() {
        for tier in OfficeTierStyle.allCases {
            let size = SceneComposer.sceneSize(for: tier)
            let crowd = fullCrowd(for: tier)
            for set in Self.powerSet {
                let scene = SceneComposer.compose(tier: tier, occupants: crowd, amenities: set)
                let amenities = amenityProps(in: scene)
                let furniture = scene.filter {
                    switch $0.kind {
                    case .desk, .monitor, .person, .bubble, .prop: true
                    default: false
                    }
                }
                for a in amenities {
                    #expect(a.x >= 1 && a.y >= 1, "\(tier) \(set) \(a.kind) inside the frame")
                    #expect(a.x + a.sprite.width <= size.width - 1, "\(tier) \(set) \(a.kind) right edge")
                    #expect(a.y + a.sprite.height <= size.height - 1, "\(tier) \(set) \(a.kind) bottom edge")
                    for f in furniture {
                        #expect(!overlaps(a, f), "\(tier) \(set): \(a.kind) overlaps \(f.kind) at (\(f.x),\(f.y))")
                    }
                }
                for (i, a) in amenities.enumerated() {
                    for b in amenities.dropFirst(i + 1) {
                        #expect(!overlaps(a, b), "\(tier) \(set): \(a.kind) overlaps \(b.kind)")
                    }
                }
            }
        }
    }

    @Test func amenitiesNeverChangeTheSceneSizeOrHeadcount() {
        for tier in OfficeTierStyle.allCases {
            let crowd = fullCrowd(for: tier)
            let base = SceneComposer.compose(tier: tier, occupants: crowd)
            for set in Self.powerSet {
                let scene = SceneComposer.compose(tier: tier, occupants: crowd, amenities: set)
                #expect(scene.first?.kind == .room)
                #expect(scene.first?.sprite.width == SceneComposer.sceneSize(for: tier).width)
                #expect(scene.filter { $0.kind == .person }.count == base.filter { $0.kind == .person }.count)
                #expect(scene.filter { $0.kind == .desk }.count == base.filter { $0.kind == .desk }.count)
            }
        }
    }

    @Test func compositionWithAmenitiesIsDeterministic() {
        let crowd = fullCrowd(for: .studio, statuses: [.coding, .idle, .legal, .testing])
        let a = SceneComposer.compose(tier: .studio, occupants: crowd, amenities: [.gym, .cafeteria, .gameRoom])
        let b = SceneComposer.compose(tier: .studio, occupants: crowd, amenities: [.gameRoom, .cafeteria, .gym])
        #expect(a == b)
    }

    @Test func amenityPropsAnimateWithinTheirFrameCounts() {
        let scene = SceneComposer.compose(tier: .campus, occupants: [], amenities: Set(AmenityStyle.allCases))
        var animated = 0
        for p in amenityProps(in: scene) {
            if p.animation != .still { animated += 1 }
            for tick in 0..<20 {
                let f = p.frameIndex(atTick: tick)
                #expect(f >= 0 && f < p.sprite.frameCount)
            }
        }
        #expect(animated >= 3, "treadmill belt, arcade screen and vending light animate")
    }

    // MARK: Role bubbles in the scene

    @Test func roleStatusesGetBubblesAtTheirDesks() {
        let crowd = [
            occupant(seed: 1, status: .testing, isFounder: true),
            occupant(seed: 2, status: .legal),
            occupant(seed: 3, status: .peopleOps),
            occupant(seed: 4, status: .operations),
        ]
        let scene = SceneComposer.compose(tier: .loft, occupants: crowd, amenities: [.gameRoom])
        #expect(scene.filter { $0.kind == .bubble }.count == 4)
    }

    // MARK: Idle polish

    @Test func oneIdleWorkerTakesABreakAtTheCafeteria() {
        let crowd = [
            occupant(seed: 1, status: .coding, isFounder: true),
            occupant(seed: 2, status: .coding),
            occupant(seed: 3, status: .idle),
            occupant(seed: 4, status: .idle),
        ]
        let scene = SceneComposer.compose(tier: .studio, occupants: crowd, amenities: [.cafeteria])
        let people = scene.filter { $0.kind == .person }
        #expect(people.count == 4, "nobody disappears")
        let tables = scene.filter { $0.kind == .amenityProp(.cafeteriaTable) }
        let seated = people.filter { person in tables.contains { overlaps(person, $0) } }
        #expect(seated.count == 1, "exactly one idle worker sits at a table")
        // The seated person is drawn before the table that covers their lap.
        if let person = seated.first, let personIndex = scene.firstIndex(of: person) {
            let coveringTable = scene.enumerated().first { $0.element.kind == .amenityProp(.cafeteriaTable) && overlaps($0.element, person) }
            #expect(coveringTable.map { $0.offset > personIndex } == true)
        }
        // Without idle workers nobody leaves their desk.
        let busy = SceneComposer.compose(tier: .studio, occupants: fullCrowd(for: .studio), amenities: [.cafeteria])
        let busyPeople = busy.filter { $0.kind == .person }
        #expect(!busyPeople.contains { person in busy.contains { $0.kind == .amenityProp(.cafeteriaTable) && overlaps(person, $0) } })
    }

    @Test func idleFounderNeverLeavesTheFounderDesk() {
        let crowd = [occupant(seed: 1, status: .idle, isFounder: true), occupant(seed: 2, status: .coding)]
        let with = SceneComposer.compose(tier: .studio, occupants: crowd, amenities: [.cafeteria])
        let without = SceneComposer.compose(tier: .studio, occupants: crowd)
        let founderWith = with.filter { $0.kind == .person }.max { $0.y < $1.y }
        let founderWithout = without.filter { $0.kind == .person }.max { $0.y < $1.y }
        #expect(founderWith?.x == founderWithout?.x && founderWith?.y == founderWithout?.y)
    }
}
