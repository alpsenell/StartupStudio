import Foundation
import Testing
@testable import PixelKit

@Suite("SceneComposer")
struct SceneComposerTests {
    func occupant(
        seed: UInt64,
        status: WorkStatus = .coding,
        isFounder: Bool = false
    ) -> Occupant {
        Occupant(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", seed))!,
            appearance: CharacterAppearance(seed: seed),
            status: status,
            isFounder: isFounder
        )
    }

    func placements(of kind: PlacementKind, in scene: [PlacedSprite]) -> [PlacedSprite] {
        scene.filter { $0.kind == kind }
    }

    @Test func emptyOfficeStillHasRoomDesksAndMonitors() {
        for tier in OfficeTierStyle.allCases {
            let scene = SceneComposer.compose(tier: tier, occupants: [])
            let rooms = placements(of: .room, in: scene)
            #expect(rooms.count == 1)
            #expect(rooms[0].x == 0 && rooms[0].y == 0)
            // capacity regular desks + 1 dedicated founder desk
            #expect(placements(of: .desk, in: scene).count == tier.deskCapacity + 1)
            #expect(placements(of: .monitor, in: scene).count == tier.deskCapacity + 1)
            #expect(placements(of: .person, in: scene).isEmpty)
            #expect(placements(of: .bubble, in: scene).isEmpty)
        }
    }

    @Test func roomSpriteFillsTheScene() {
        for tier in OfficeTierStyle.allCases {
            let size = SceneComposer.sceneSize(for: tier)
            #expect(size.width > 0 && size.height > 0)
            let scene = SceneComposer.compose(tier: tier, occupants: [])
            let room = placements(of: .room, in: scene)[0]
            #expect(room.sprite.width == size.width)
            #expect(room.sprite.height == size.height)
        }
    }

    @Test func occupantsAreSeatedWithBubblesForNonIdle() {
        let occupants = [
            occupant(seed: 1, status: .coding, isFounder: true),
            occupant(seed: 2, status: .designing),
            occupant(seed: 3, status: .idle),
        ]
        let scene = SceneComposer.compose(tier: .garage, occupants: occupants)
        #expect(placements(of: .person, in: scene).count == 3)
        #expect(placements(of: .bubble, in: scene).count == 2, "idle gets no bubble")
    }

    @Test func founderSitsFrontLeftAndSeparated() {
        let occupants = [
            occupant(seed: 10, status: .coding),
            occupant(seed: 11, status: .marketing),
            occupant(seed: 12, status: .researching, isFounder: true),
        ]
        let scene = SceneComposer.compose(tier: .garage, occupants: occupants)
        let people = placements(of: .person, in: scene)
        #expect(people.count == 3)
        let front = people.max { $0.y < $1.y }!
        // The front-most person is the founder desk occupant: front row, left edge.
        #expect(front.x == people.map(\.x).min())
        #expect(people.filter { $0.y == front.y }.count == 1, "founder row holds only the founder")
    }

    @Test func idleOccupantsAnimateSlower() {
        let scene = SceneComposer.compose(
            tier: .garage,
            occupants: [occupant(seed: 5, status: .idle), occupant(seed: 6, status: .coding)]
        )
        let people = placements(of: .person, in: scene)
        let animations = Set(people.map(\.animation))
        #expect(animations.contains(.typing(slow: true)))
        #expect(animations.contains(.typing(slow: false)))
    }

    @Test func overflowOccupantsAreNotShown() {
        let crowd = (0..<20).map { occupant(seed: UInt64($0 + 100), isFounder: $0 == 0) }
        let scene = SceneComposer.compose(tier: .garage, occupants: crowd)
        #expect(placements(of: .person, in: scene).count == OfficeTierStyle.garage.deskCapacity + 1)
    }

    @Test func withoutAFounderTheFounderDeskStaysEmpty() {
        let crowd = (0..<10).map { occupant(seed: UInt64($0 + 200)) }
        let scene = SceneComposer.compose(tier: .garage, occupants: crowd)
        // Only the regular desks fill up.
        #expect(placements(of: .person, in: scene).count == OfficeTierStyle.garage.deskCapacity)
    }

    @Test func everyPlacementStaysInsideTheScene() {
        let crowd = (0..<50).map {
            occupant(
                seed: UInt64($0 + 300),
                status: WorkStatus.allCases[$0 % WorkStatus.allCases.count],
                isFounder: $0 == 0
            )
        }
        for tier in OfficeTierStyle.allCases {
            let size = SceneComposer.sceneSize(for: tier)
            for p in SceneComposer.compose(tier: tier, occupants: crowd) {
                #expect(p.x >= 0 && p.y >= 0, "\(tier) \(p.kind) origin")
                #expect(p.x + p.sprite.width <= size.width, "\(tier) \(p.kind) right edge")
                #expect(p.y + p.sprite.height <= size.height, "\(tier) \(p.kind) bottom edge")
            }
        }
    }

    @Test func roomIsDrawnFirstAndPeopleBeforeTheirDesks() {
        let scene = SceneComposer.compose(
            tier: .garage,
            occupants: [occupant(seed: 40, isFounder: true), occupant(seed: 41)]
        )
        #expect(scene.first?.kind == .room)
        // For every person there must be a desk drawn later that overlaps them (the lap cover).
        let people = scene.enumerated().filter { $0.element.kind == .person }
        for (index, person) in people {
            let laterDesks = scene.dropFirst(index + 1).filter { $0.kind == .desk }
            #expect(
                laterDesks.contains { desk in
                    desk.x < person.x + person.sprite.width && person.x < desk.x + desk.sprite.width
                        && desk.y < person.y + person.sprite.height && person.y < desk.y + desk.sprite.height
                },
                "someone should be seated behind a desk drawn over their lap"
            )
        }
    }

    @Test func compositionIsDeterministic() {
        let occupants = [
            occupant(seed: 51, status: .researching, isFounder: true),
            occupant(seed: 52, status: .idle),
            occupant(seed: 53, status: .marketing),
        ]
        let a = SceneComposer.compose(tier: .loft, occupants: occupants)
        let b = SceneComposer.compose(tier: .loft, occupants: occupants)
        #expect(a == b)
    }

    @Test func frameIndexPatterns() {
        let sprite = SpriteLibrary.person(appearance: CharacterAppearance(seed: 1))
        let typing = PlacedSprite(sprite: sprite, x: 0, y: 0, kind: .person, animation: .typing(slow: false), phase: 0)
        // A, B, A, B, A, B, blink
        let cycle = (0..<7).map { typing.frameIndex(atTick: $0) }
        #expect(cycle == [0, 1, 0, 1, 0, 1, 2])
        #expect(typing.frameIndex(atTick: 7) == 0, "cycle repeats")

        let slow = PlacedSprite(sprite: sprite, x: 0, y: 0, kind: .person, animation: .typing(slow: true), phase: 0)
        #expect(slow.frameIndex(atTick: 0) == slow.frameIndex(atTick: 1), "slow typing holds frames twice as long")

        let monitor = PlacedSprite(sprite: SpriteLibrary.monitor(), x: 0, y: 0, kind: .monitor, animation: .glow, phase: 0)
        let glowFrames = Set((0..<8).map { monitor.frameIndex(atTick: $0) })
        #expect(glowFrames == [0, 1])

        let still = PlacedSprite(sprite: SpriteLibrary.desk(), x: 0, y: 0, kind: .desk, animation: .still, phase: 0)
        #expect((0..<10).allSatisfy { still.frameIndex(atTick: $0) == 0 })
    }

    @Test func frameIndexNeverExceedsFrameCount() {
        for tier in OfficeTierStyle.allCases {
            let crowd = (0..<8).map { occupant(seed: UInt64($0), isFounder: $0 == 0) }
            for p in SceneComposer.compose(tier: tier, occupants: crowd) {
                for tick in 0..<20 {
                    let f = p.frameIndex(atTick: tick)
                    #expect(f >= 0 && f < p.sprite.frameCount)
                }
            }
        }
    }
}
