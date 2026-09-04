import CoreGraphics
import Foundation
import Testing
@testable import PixelKit

/// The office as something you can put a finger on: every person and every
/// prop the app gives a meaning to has a region, the regions are where the
/// director drew things this frame, and a figure standing on a prop is
/// the figure.
@Suite("Office hit regions")
struct OfficeHitRegionTests {
    let fixtures = OfficeDirectorTests()

    func scene(
        tier: OfficeTierStyle, count: Int, seated: Bool = false, friends: Bool = false
    ) -> OfficeSceneInput {
        var input = fixtures.input(
            tier: tier, count: count, amenities: [.gameRoom, .cafeteria, .gym], friends: friends
        )
        input.reduceMotion = seated
        return input
    }

    static let propKinds: Set<OfficeHitRegion.Kind> = [.coffeeMachine, .whiteboard, .door, .founderDesk]

    /// The middle of where two rectangles overlap, or `nil` when they don't.
    static func overlapCentre(
        _ a: (x: Int, y: Int, width: Int, height: Int),
        _ b: (x: Int, y: Int, width: Int, height: Int)
    ) -> (x: Int, y: Int)? {
        let left = max(a.x, b.x)
        let right = min(a.x + a.width, b.x + b.width)
        let top = max(a.y, b.y)
        let bottom = min(a.y + a.height, b.y + b.height)
        guard right > left, bottom > top else { return nil }
        return ((left + right) / 2, (top + bottom) / 2)
    }

    // MARK: Props

    @Test(arguments: OfficeTierStyle.allCases)
    func everyPropHasOneRegionInsideTheRoom(tier: OfficeTierStyle) {
        let size = SceneComposer.sceneSize(for: tier)
        let props = OfficeDirector.hitRegions(input: scene(tier: tier, count: 3), at: 0)
            .filter { !$0.kind.isPerson }
        #expect(Set(props.map(\.kind)) == Self.propKinds)
        #expect(props.count == Self.propKinds.count, "exactly one region per prop")
        for region in props {
            #expect(region.x >= 0 && region.x + region.width <= size.width, "\(region.kind) x")
            #expect(region.y >= 0 && region.y + region.height <= size.height, "\(region.kind) y")
            #expect(region.width >= 8 && region.height >= 2, "\(region.kind) is big enough to hit")
        }
    }

    @Test func aPointOnAPropAloneIsTheProp() {
        // Only the founder, seated: nobody stands on the coffee machine,
        // the whiteboard or the door.
        let input = scene(tier: .studio, count: 1, seated: true)
        let props = OfficeDirector.hitRegions(input: input, at: 0)
            .filter { !$0.kind.isPerson && $0.kind != .founderDesk }
        #expect(props.count == 3)
        for region in props {
            let hit = OfficeDirector.hitTest(
                input: input, at: 0,
                x: region.x + region.width / 2, y: region.y + region.height / 2
            )
            #expect(hit?.kind == region.kind)
        }
        #expect(OfficeDirector.hitTest(input: input, at: 0, x: -5, y: -5) == nil)
        #expect(OfficeDirector.hitTest(input: input, at: 0, x: 0, y: 0) == nil, "bare wall")
    }

    @Test func theFounderSitsAtTheirDeskAndBothAreTappable() {
        let input = scene(tier: .loft, count: 4, seated: true)
        let founder = input.occupants[0]
        let desk = try! #require(
            OfficeDirector.hitRegions(input: input, at: 0).first { $0.kind == .founderDesk }
        )
        // The bottom-left corner of the desk is clear of the chair.
        let edge = OfficeDirector.hitTest(input: input, at: 0, x: desk.x + 1, y: desk.y + desk.height - 1)
        #expect(edge?.kind == .founderDesk)
        // The founder, in the middle of it, is the founder: figures over props.
        let middle = OfficeDirector.hitTest(input: input, at: 0, x: desk.x + desk.width / 2, y: desk.y + 2)
        #expect(middle?.kind == .person(founder.id))
    }

    @Test(arguments: [OfficeTierStyle.loft, .studio, .campus])
    func theDoormatIsWhereTheHiresWalkIn(tier: OfficeTierStyle) {
        let input = scene(tier: tier, count: 3)
        let door = try! #require(OfficeWaypoints.all(for: tier, amenities: []).first { $0.kind == .door })
        let region = try! #require(OfficeDirector.hitRegions(input: input, at: 0).first { $0.kind == .door })
        #expect(region.contains(x: Int(door.anchor.x), y: Int(door.anchor.y) - 1))
        let mat = OfficeFXSprites.doorMat()
        #expect(OfficeDirector.compose(input: input, at: 0).contains { $0.sprite == mat }, "and it is drawn")
    }

    @Test func theGarageHasARealDoor() {
        let input = scene(tier: .garage, count: 3)
        let door = try! #require(OfficeDirector.hitRegions(input: input, at: 0).first { $0.kind == .door })
        let sprite = SpriteLibrary.prop(.garageDoor)
        #expect((door.width, door.height) == (sprite.width, sprite.height))
        let mat = OfficeFXSprites.doorMat()
        #expect(!OfficeDirector.compose(input: input, at: 0).contains { $0.sprite == mat }, "no mat under a roller door")
    }

    // MARK: People

    @Test(arguments: OfficeTierStyle.allCases)
    func everyoneInTheRoomHasARegionTheSizeOfTheirSprite(tier: OfficeTierStyle) {
        let count = min(tier.deskCapacity + 1, 8)
        let input = scene(tier: tier, count: count)
        let actors = OfficeDirector.actorFrames(input: input, timing: .none, at: 5)
        let people = OfficeDirector.hitRegions(input: input, at: 5).filter(\.kind.isPerson)
        #expect(people.count == count)
        for actor in actors {
            let region = try! #require(people.first { $0.kind == .person(actor.id) })
            #expect((region.x, region.y, region.width, region.height) == (actor.x, actor.y, actor.width, actor.height))
        }
    }

    @Test func aPersonStandingAtTheCoffeeMachineIsThePerson() {
        // The loft's kitchenette is the one a coffee-getter stands right in
        // front of, sprite over counter.
        let input = scene(tier: .loft, count: 6)
        var found = false
        for t in stride(from: 0.0, to: 240.0, by: 1.0) {
            let actors = OfficeDirector.actorFrames(input: input, timing: .none, at: t)
            guard let drinker = actors.first(where: { $0.waypointID == "coffee" && $0.pose != .walk }) else { continue }
            let coffee = try! #require(
                OfficeDirector.hitRegions(input: input, at: t).first { $0.kind == .coffeeMachine }
            )
            guard let (x, y) = Self.overlapCentre(
                (drinker.x, drinker.y, drinker.width, drinker.height),
                (coffee.x, coffee.y, coffee.width, coffee.height)
            ) else { continue }
            found = true
            let hit = OfficeDirector.hitTest(input: input, at: t, x: x, y: y)
            #expect(hit?.kind == .person(drinker.id), "figures over props at t=\(t)")
            break
        }
        #expect(found, "somebody stood at the kitchenette during the office day")
    }

    @Test func theNearestFigureWinsWhenTwoOverlap() {
        let input = scene(tier: .studio, count: 12, friends: true)
        var checked = false
        for t in stride(from: 0.0, to: 240.0, by: 1.0) {
            let actors = OfficeDirector.actorFrames(input: input, timing: .none, at: t)
            for a in actors {
                for b in actors where b.id != a.id {
                    guard a.zIndex != b.zIndex, let (x, y) = Self.overlapCentre(
                        (a.x, a.y, a.width, a.height), (b.x, b.y, b.width, b.height)
                    ) else { continue }
                    let front = a.zIndex > b.zIndex ? a : b
                    #expect(OfficeDirector.hitTest(input: input, at: t, x: x, y: y)?.kind == .person(front.id))
                    checked = true
                }
            }
            if checked { break }
        }
        #expect(checked, "two people overlapped somewhere in the day")
    }

    @Test func regionsMoveWithTheFrameAndPropsDoNot() {
        let input = scene(tier: .studio, count: 10)
        let start = OfficeDirector.hitRegions(input: input, at: 0).filter(\.kind.isPerson)
        var moved = false
        for t in stride(from: 1.0, to: 240.0, by: 1.0) {
            let later = OfficeDirector.hitRegions(input: input, at: t).filter(\.kind.isPerson)
            if zip(start, later).contains(where: { $0.kind == $1.kind && ($0.x, $0.y) != ($1.x, $1.y) }) {
                moved = true
                break
            }
        }
        #expect(moved, "people's regions follow them round the room")
        func props(at t: TimeInterval) -> [OfficeHitRegion] {
            OfficeDirector.hitRegions(input: input, at: t).filter { !$0.kind.isPerson }
        }
        #expect(props(at: 0) == props(at: 100))
    }

    @Test func aPressNeverMovesAnybody() {
        var input = scene(tier: .studio, count: 10)
        let before = OfficeDirector.hitRegions(input: input, at: 7)
        input.pressed = .person(input.occupants[3].id)
        #expect(OfficeDirector.hitRegions(input: input, at: 7) == before)
        input.pressed = .coffeeMachine
        #expect(OfficeDirector.hitRegions(input: input, at: 7) == before)
    }

    // MARK: Through the view

    @Test func viewPointsMapBackThroughScaleAndLetterbox() {
        let input = scene(tier: .loft, count: 3, seated: true)
        let scene = SceneComposer.sceneSize(for: .loft)
        // Three times the scene's width and a bit, taller than it needs to
        // be: scale 3, a one-point margin left, letterboxed 20 up and down.
        let size = CGSize(width: CGFloat(scene.width * 3) + 2, height: CGFloat(scene.height * 3) + 40)
        let geometry = PixelSceneGeometry(sceneSize: (scene.width, scene.height), viewSize: size)
        #expect(geometry.scale == 3)
        #expect(geometry.origin == CGPoint(x: 1, y: 20))
        #expect(geometry.scenePoint(CGPoint(x: 1, y: 20)) == (0, 0))
        #expect(geometry.scenePoint(CGPoint(x: 3.9, y: 22.9)) == (0, 0))
        #expect(geometry.scenePoint(CGPoint(x: 4, y: 23)) == (1, 1))

        for region in OfficeDirector.hitRegions(input: input, at: 0)
        where !region.kind.isPerson && region.kind != .founderDesk {
            let rect = geometry.viewRect(x: region.x, y: region.y, width: region.width, height: region.height)
            let hit = OfficeDirector.hitTest(
                input: input, at: 0, point: CGPoint(x: rect.midX, y: rect.midY), in: size
            )
            #expect(hit?.kind == region.kind, "\(region.kind) through the view")
        }
        // The letterbox above the room is nothing.
        #expect(OfficeDirector.hitTest(input: input, at: 0, point: CGPoint(x: 30, y: 5), in: size) == nil)
    }

    @Test func aFixedScaleMapsExactly() {
        let geometry = PixelSceneGeometry(sceneSize: (100, 60), viewSize: CGSize(width: 400, height: 240), mode: .fixed(4))
        #expect(geometry.scale == 4)
        #expect(geometry.origin == .zero)
        #expect(geometry.viewRect(x: 10, y: 5, width: 3, height: 2) == CGRect(x: 40, y: 20, width: 12, height: 8))
    }

    // MARK: VoiceOver

    @Test func peopleAreNamedForVoiceOver() {
        let look = CharacterAppearance(seed: 3)
        let dev = Occupant(
            id: UUID(), appearance: look, status: .coding, mood: .great,
            name: "Priya", roleDescription: "backend dev"
        )
        #expect(dev.accessibilityLabel == "Priya, backend dev, happy")
        let tester = Occupant(id: UUID(), appearance: look, status: .testing, mood: .low, role: .qa, name: "Dev")
        #expect(tester.accessibilityLabel == "Dev, QA, unhappy")
        var founder = Occupant(id: UUID(), appearance: look, status: .coding, isFounder: true, name: "Mira")
        founder.isAway = true
        #expect(founder.accessibilityLabel == "Mira, coding, okay, away today")
        let stranger = Occupant(id: UUID(), appearance: look, status: .idle)
        #expect(stranger.accessibilityLabel == "Someone, idle, okay")
    }
}
