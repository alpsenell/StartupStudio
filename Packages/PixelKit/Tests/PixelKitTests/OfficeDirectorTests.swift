import Foundation
import Testing
@testable import PixelKit

@Suite("Office director")
struct OfficeDirectorTests {
    // MARK: Fixtures

    func id(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }

    func occupants(
        _ count: Int,
        seed: UInt64 = 200,
        statuses: [WorkStatus] = [.coding, .designing, .testing, .marketing, .researching],
        moods: [MoodLevel] = [.okay],
        friends: Bool = false
    ) -> [Occupant] {
        (0..<count).map { index in
            Occupant(
                id: id(index),
                appearance: CharacterAppearance(seed: UInt64(index) &+ seed),
                status: statuses[index % statuses.count],
                isFounder: index == 0,
                mood: moods[index % moods.count],
                friendIDs: friends && index % 2 == 0 && count > 1 ? [id((index + 1) % count)] : [],
                name: "P\(index)"
            )
        }
    }

    func input(
        tier: OfficeTierStyle,
        count: Int,
        amenities: Set<AmenityStyle> = [.gameRoom, .cafeteria, .gym],
        ambience: OfficeAmbience = .plain,
        friends: Bool = false
    ) -> OfficeSceneInput {
        OfficeSceneInput(
            tier: tier,
            occupants: occupants(count, friends: friends),
            amenities: amenities,
            ambience: ambience
        )
    }

    /// 600 s of scene time, sampled at 12 fps.
    var sampleTimes: [TimeInterval] {
        stride(from: 0.0, to: 600.0, by: 1.0 / 12.0).map { $0 }
    }

    // MARK: Waypoints

    @Test(arguments: OfficeTierStyle.allCases)
    func everyTierHasSomewhereToGo(tier: OfficeTierStyle) {
        let waypoints = OfficeWaypoints.all(for: tier, amenities: [.gameRoom, .cafeteria, .gym, .shuttle])
        let kinds = Set(waypoints.map(\.kind))
        #expect(kinds.contains(.door))
        #expect(kinds.contains(.coffee), "every tier can make a coffee")
        #expect(waypoints.filter { $0.kind == .whiteboard }.count == 3, "room for a three-person huddle")
        #expect(kinds.contains(.loiter))
        #expect(Set(waypoints.map(\.id)).count == waypoints.count, "waypoint ids are unique")
    }

    @Test(arguments: OfficeTierStyle.allCases)
    func waypointsAreInsideTheRoom(tier: OfficeTierStyle) {
        let size = SceneComposer.sceneSize(for: tier)
        for waypoint in OfficeWaypoints.all(for: tier, amenities: [.gameRoom, .cafeteria, .gym]) {
            #expect(waypoint.anchor.x >= 0 && waypoint.anchor.x <= Double(size.width), "\(waypoint.id) x")
            #expect(waypoint.anchor.y >= 0 && waypoint.anchor.y <= Double(size.height), "\(waypoint.id) y")
        }
    }

    @Test func waypointsAreDeterministic() {
        let a = OfficeWaypoints.all(for: .studio, amenities: [.cafeteria, .gym])
        let b = OfficeWaypoints.all(for: .studio, amenities: [.gym, .cafeteria])
        #expect(a == b, "a Set of amenities always yields the same ordered list")
    }

    // MARK: Plans

    @Test(arguments: OfficeTierStyle.allCases)
    func everyoneVisitsAtLeastTwoPlacesAndComesBack(tier: OfficeTierStyle) {
        let headcount = min(tier.deskCapacity + 1, 12)
        let scene = input(tier: tier, count: headcount)
        // 600 s of scene time is two and a half office days.
        var visitsByActor: [UUID: Set<String>] = [:]
        for day in 0...2 {
            for plan in OfficeBehaviors.plans(for: scene, dayIndex: day) {
                visitsByActor[plan.id, default: []].formUnion(plan.visitedWaypointIDs)

                // Segments tile the day with no gaps and no overlaps.
                #expect(plan.segments.first?.start == 0)
                #expect(plan.segments.last?.end == OfficeBehaviors.dayLength)
                for pair in zip(plan.segments, plan.segments.dropFirst()) {
                    #expect(pair.0.end == pair.1.start, "gap in \(plan.id)'s day")
                }
                // And they always end the day back in their chair.
                #expect(plan.segments.last?.waypointID == "desk")
            }
        }
        #expect(visitsByActor.count == headcount, "everybody gets a plan")
        for (actor, visits) in visitsByActor {
            #expect(visits.count >= 2, "\(actor) only went to \(visits)")
        }
    }

    @Test func plansAreDeterministic() {
        let scene = input(tier: .studio, count: 12, friends: true)
        #expect(
            OfficeBehaviors.plans(for: scene, dayIndex: 4)
                == OfficeBehaviors.plans(for: scene, dayIndex: 4)
        )
        #expect(
            OfficeBehaviors.plans(for: scene, dayIndex: 4)
                != OfficeBehaviors.plans(for: scene, dayIndex: 5),
            "a new day is a new routine"
        )
    }

    @Test func everySegmentBoundaryIsAWholeSecond() {
        // This is what makes per-second memoization exact rather than
        // approximate: the placement list can only change on a bucket edge.
        let scene = input(tier: .campus, count: 30, friends: true)
        for plan in OfficeBehaviors.plans(for: scene, dayIndex: 1) {
            for segment in plan.segments {
                #expect(segment.start == segment.start.rounded(), "\(segment.start)")
                #expect(segment.end == segment.end.rounded(), "\(segment.end)")
                for leg in segment.track.legs {
                    #expect(leg.start == leg.start.rounded())
                    #expect(leg.duration == leg.duration.rounded())
                }
            }
        }
    }

    @Test func nobodyQueueJumps() {
        // No waypoint is ever occupied by two people at once.
        let scene = input(tier: .studio, count: 15, friends: true)
        for day in 0...2 {
            var occupancy: [String: [(TimeInterval, TimeInterval, UUID)]] = [:]
            for plan in OfficeBehaviors.plans(for: scene, dayIndex: day) {
                for segment in plan.segments {
                    guard let waypoint = segment.waypointID, waypoint != "desk",
                          !segment.track.isMoving(at: segment.start + 0.5) else { continue }
                    occupancy[waypoint, default: []].append((segment.start, segment.end, plan.id))
                }
            }
            for (waypoint, spans) in occupancy {
                for (a, b) in spans.enumerated().flatMap({ i, x in
                    spans.dropFirst(i + 1).map { (x, $0) }
                }) where a.2 != b.2 {
                    #expect(a.0 >= b.1 || b.0 >= a.1, "\(waypoint) double-booked on day")
                }
            }
        }
    }

    // MARK: Movement

    @Test(arguments: OfficeTierStyle.allCases)
    func nobodyWalksThroughTheFurniture(tier: OfficeTierStyle) {
        // People are 14×22 and the aisles between desk rows are 7 px, so a
        // walker *overlapping* a desk is not only unavoidable, it is the
        // point — `zIndex` decides who is in front. What must never happen
        // is a walker's feet landing inside a piece of furniture.
        let scene = input(tier: tier, count: min(tier.deskCapacity + 1, 12))
        let rects = OfficeWaypoints.furnitureRects(for: tier, amenities: scene.amenities)
        for t in stride(from: 0.0, to: 240.0, by: 0.5) {
            for actor in OfficeDirector.actorFrames(input: scene, timing: .none, at: t) {
                guard actor.pose == .walk else { continue }
                let feetY = actor.y + actor.height - 1
                let feetLeft = actor.x + 4
                let feetRight = actor.x + actor.width - 4
                for rect in rects {
                    let hit = feetRight > rect.x && feetLeft < rect.x + rect.width
                        && feetY >= rect.y && feetY < rect.y + rect.height
                    #expect(!hit, "\(tier) walker's feet inside furniture at t=\(t)")
                }
            }
        }
    }

    @Test(arguments: OfficeTierStyle.allCases)
    func everybodyStaysInTheRoom(tier: OfficeTierStyle) {
        let scene = input(tier: tier, count: min(tier.deskCapacity + 1, 14))
        let size = SceneComposer.sceneSize(for: tier)
        for t in stride(from: 0.0, to: 240.0, by: 1.0) {
            for actor in OfficeDirector.actorFrames(input: scene, timing: .none, at: t) {
                #expect(actor.x >= -2, "\(tier) x=\(actor.x) at t=\(t)")
                #expect(actor.x + actor.width <= size.width + 2, "\(tier) right edge at t=\(t)")
                #expect(actor.y >= -2, "\(tier) y=\(actor.y) at t=\(t)")
                #expect(actor.y + actor.height <= size.height + 2, "\(tier) bottom at t=\(t)")
            }
        }
    }

    @Test func peopleActuallyMoveOverTheDay() {
        let scene = input(tier: .studio, count: 12, friends: true)
        var positions: [UUID: Set<Int>] = [:]
        for t in stride(from: 0.0, to: 240.0, by: 1.0) {
            for actor in OfficeDirector.actorFrames(input: scene, timing: .none, at: t) {
                positions[actor.id, default: []].insert(actor.x * 1000 + actor.y)
            }
        }
        for (actor, seen) in positions {
            #expect(seen.count >= 4, "\(actor) barely moved (\(seen.count) positions)")
        }
    }

    @Test func walkersFaceTheWayTheyAreGoing() {
        let scene = input(tier: .campus, count: 20)
        var sawLeft = false
        var sawRight = false
        for t in stride(from: 0.0, to: 240.0, by: 0.5) {
            for placement in OfficeDirector.compose(input: scene, at: t)
            where placement.kind == .person && placement.motion != nil {
                if placement.flipX { sawLeft = true } else { sawRight = true }
            }
        }
        #expect(sawLeft && sawRight, "the walk cycle is mirrored for both directions")
    }

    // MARK: Composition

    @Test func compositionIsDeterministicAndSortedByDepth() {
        let scene = input(tier: .studio, count: 12, friends: true)
        OfficeDirector.resetCaches()
        let a = OfficeDirector.compose(input: scene, at: 37)
        OfficeDirector.resetCaches()
        let b = OfficeDirector.compose(input: scene, at: 37)
        #expect(a == b)
        #expect(a.first?.kind == .room, "the room is always the backdrop")
        #expect(a.map(\.zIndex) == a.map(\.zIndex).sorted(), "back to front")
    }

    @Test func placementListOnlyChangesOnceASecond() {
        let scene = input(tier: .studio, count: 12, friends: true)
        for second in stride(from: 0, to: 60, by: 1) {
            let base = OfficeDirector.compose(input: scene, at: TimeInterval(second))
            for fraction in [0.08, 0.25, 0.5, 0.99] {
                let mid = OfficeDirector.compose(input: scene, at: TimeInterval(second) + fraction)
                #expect(mid == base, "the list moved mid-second at \(second)+\(fraction)")
            }
        }
    }

    @Test func motionMakesPeopleMoveBetweenFrames() {
        let scene = input(tier: .campus, count: 24)
        var moved = false
        for t in stride(from: 0.0, to: 120.0, by: 1.0 / 12.0) {
            for placement in OfficeDirector.compose(input: scene, at: t)
            where placement.kind == .person && placement.motion != nil {
                let now = placement.position(at: t)
                let next = placement.position(at: t + 1 / 12.0)
                if now != next { moved = true }
            }
            if moved { break }
        }
        #expect(moved, "sprites move between frames, not only between seconds")
    }

    @Test func emptyDeskMonitorsAreDark() {
        let scene = input(tier: .campus, count: 6, amenities: [])
        let monitors = OfficeDirector.compose(input: scene, at: 0).filter { $0.kind == .monitor }
        #expect(monitors.count == OfficeTierStyle.campus.deskCapacity + 1)
        let lit = monitors.filter { $0.animation == .glow }.count
        #expect(lit == 6, "one lit screen per person, not forty over empty chairs")
    }

    @Test func awayPeopleLeaveANoteAndAnEmptyChair() {
        var people = occupants(6)
        people[3].isAway = true
        let scene = OfficeSceneInput(tier: .loft, occupants: people)
        let placements = OfficeDirector.compose(input: scene, at: 5)
        #expect(placements.filter { $0.kind == .person }.count == 5)
        #expect(OfficeBehaviors.present(for: scene, dayIndex: 0).count == 5)
        // The note sits where the missing person's monitor is.
        let note = OfficeFXSprites.stickyNote()
        #expect(placements.contains { $0.sprite == note }, "a note marks the empty desk")
    }

    @Test func weekendsAreQuiet() {
        let weekday = input(tier: .studio, count: 15, ambience: .plain)
        let weekend = input(
            tier: .studio, count: 15,
            ambience: OfficeAmbience(isWeekend: true)
        )
        let inOnSaturday = OfficeBehaviors.present(for: weekend, dayIndex: 3).count
        #expect(OfficeBehaviors.present(for: weekday, dayIndex: 3).count == 15)
        #expect(inOnSaturday >= 2 && inOnSaturday <= 3, "founder plus a workhorse or two")
        let founder = weekend.occupants[0]
        #expect(OfficeBehaviors.present(for: weekend, dayIndex: 3).contains(founder.id))
    }

    // MARK: Bubbles

    @Test func statusBubblesAreTransient() {
        let scene = input(tier: .loft, count: 4, amenities: [])
        let subject = scene.occupants[1]
        let timing = OfficeSceneTiming(statusChanges: [subject.id: 10])
        func bubbleCount(at t: TimeInterval) -> Int {
            OfficeDirector.compose(input: scene, timing: timing, at: t)
                .filter { $0.kind == .bubble }.count
        }
        // Somebody is always mid-pulse, but the room is never wallpapered
        // with bubbles the way the old permanent ones made it.
        for t in stride(from: 0.0, to: 120.0, by: 1.0) {
            #expect(bubbleCount(at: t) <= scene.occupants.count)
        }
        let quiet = (0..<120).map { bubbleCount(at: TimeInterval($0)) }
        #expect(quiet.contains { $0 < scene.occupants.count }, "bubbles do come down")
    }

    @Test func tappingSomeoneShowsTheirNamePlate() {
        let scene = input(tier: .loft, count: 5, amenities: [])
        let subject = scene.occupants[2]
        let timing = OfficeSceneTiming(tap: .init(id: subject.id, at: 20))
        let tag = OfficeFXSprites.nameTag(name: "P2", line: nil)
        let shown = OfficeDirector.compose(input: scene, timing: timing, at: 21)
        #expect(shown.contains { $0.sprite.width == tag.width && $0.kind == .bubble })
        let later = OfficeDirector.compose(input: scene, timing: timing, at: 26)
        #expect(!later.contains { $0.sprite.width == tag.width && $0.kind == .bubble },
                "the plate comes down after four seconds")
    }

    @Test func tappingAPersonFindsThem() {
        let scene = input(tier: .loft, count: 5, amenities: [])
        let t: TimeInterval = 3
        let actors = OfficeDirector.actorFrames(input: scene, timing: .none, at: t)
        let target = try! #require(actors.first)
        let hit = OfficeDirector.hitTest(
            input: scene, t: t,
            x: target.x + target.width / 2, y: target.y + target.height / 2
        )
        #expect(hit == target.id)
        #expect(OfficeDirector.hitTest(input: scene, t: t, x: -20, y: -20) == nil)
    }

    // MARK: Celebrations

    @Test func shippingMakesTheRoomCheerThenSendsTheFounderToTheBoard() {
        let people = occupants(9)
        let scene = OfficeSceneInput(
            tier: .studio, occupants: people,
            celebration: .init(kind: .shipped(score: 71), token: 3)
        )
        let timing = OfficeSceneTiming(celebrationStart: 0)
        let cheerPoses = OfficeDirector.actorFrames(input: scene, timing: timing, at: 1)
        #expect(cheerPoses.allSatisfy { $0.pose == .cheer }, "everyone stops and cheers")

        let confetti = OfficeDirector.compose(input: scene, timing: timing, at: 1)
            .filter { $0.sprite.width == 2 }
        #expect(!confetti.isEmpty, "confetti falls")
        let settled = OfficeDirector.compose(input: scene, timing: timing, at: 6)
            .filter { $0.sprite.width == 2 }
        #expect(settled.isEmpty, "and does not litter the floor afterwards")

        // Once the cheer is over the founder walks to the flip-chart.
        let founder = try! #require(
            OfficeDirector.actorFrames(input: scene, timing: timing, at: 8)
                .first { $0.id == people[0].id }
        )
        #expect(founder.waypointID == "whiteboard.0")
    }

    @Test func hiringWalksSomeoneInThroughTheDoor() {
        let people = occupants(6)
        let scene = OfficeSceneInput(
            tier: .loft, occupants: people,
            celebration: .init(kind: .hired(people[5].id), token: 1)
        )
        let timing = OfficeSceneTiming(celebrationStart: 0)
        let door = try! #require(
            OfficeWaypoints.all(for: .loft, amenities: []).first { $0.kind == .door }
        )
        let arriving = try! #require(
            OfficeDirector.actorFrames(input: scene, timing: timing, at: 0)
                .first { $0.id == people[5].id }
        )
        #expect(abs(Double(arriving.x + arriving.width / 2) - door.anchor.x) <= 2, "starts at the door")

        // …and closes on their own desk with every step.
        func distanceToDesk(at t: TimeInterval) -> Double {
            let frame = OfficeDirector.actorFrames(input: scene, timing: timing, at: t)
                .first { $0.id == people[5].id }!
            let desk = OfficeWaypoints.deskAnchor(tier: .loft, index: 4)
            return ScenePoint(x: frame.x + frame.width / 2, y: frame.y + frame.height)
                .distance(to: desk)
        }
        #expect(distanceToDesk(at: 3) < distanceToDesk(at: 0))
        let seated = try! #require(
            OfficeDirector.actorFrames(input: scene, timing: timing, at: 8)
                .first { $0.id == people[5].id }
        )
        let seat = SceneComposer.seatOrigin(tier: .loft, index: 4)
        #expect((seated.x, seated.y) == seat, "and settles into their own chair")
    }

    @Test func quittingCarriesABoxOutAndFades() {
        let people = occupants(6)
        let leaver = people[4]
        let scene = OfficeSceneInput(
            tier: .loft, occupants: people,
            celebration: .init(kind: .quit(leaver.id), token: 1)
        )
        let timing = OfficeSceneTiming(celebrationStart: 0)
        let box = OfficeFXSprites.cardboardBox()
        #expect(
            OfficeDirector.compose(input: scene, timing: timing, at: 1).contains { $0.sprite == box },
            "the box comes out"
        )
        let fading = stride(from: 2.0, to: 12.0, by: 0.5).flatMap { t in
            OfficeDirector.compose(input: scene, timing: timing, at: t)
                .filter { $0.kind == .person && $0.opacity < 1 }
        }
        #expect(!fading.isEmpty, "and they fade out through the door")
        let gone = OfficeDirector.compose(input: scene, timing: timing, at: 11)
            .filter { $0.kind == .person }
        #expect(!gone.contains { $0.opacity > 0 && $0.sprite == SpriteCache.person(
            appearance: leaver.appearance, pose: .carryBox, isFounder: false
        ) }, "and are gone by the end of it")
    }

    @Test func upgradingSweepsALightBandDownTheRoom() {
        let scene = OfficeSceneInput(
            tier: .campus, occupants: occupants(10),
            celebration: .init(kind: .officeUpgraded, token: 1)
        )
        let timing = OfficeSceneTiming(celebrationStart: 0)
        let size = SceneComposer.sceneSize(for: .campus)
        let band = try! #require(
            OfficeDirector.compose(input: scene, timing: timing, at: 0)
                .first { $0.sprite.width == size.width && $0.kind == .prop }
        )
        #expect(band.position(at: 0).y < 0)
        #expect(band.position(at: 0.6).y > size.height)
        #expect(
            OfficeDirector.compose(input: scene, timing: timing, at: 4)
                .allSatisfy { !($0.sprite.width == size.width && $0.kind == .prop) },
            "the wipe is gone once the celebration ends"
        )
    }

    @Test func researchLightsBulbsOverTheResearchers() {
        var people = occupants(8, statuses: [.coding])
        people[2].status = .researching
        people[5].status = .researching
        let scene = OfficeSceneInput(
            tier: .studio, occupants: people,
            celebration: .init(kind: .researchComplete, token: 1)
        )
        let bulb = OfficeFXSprites.ideaBubble()
        let bulbs = OfficeDirector.compose(input: scene, timing: OfficeSceneTiming(celebrationStart: 0), at: 1)
            .filter { $0.sprite == bulb }
        #expect(bulbs.count == 2)
    }

    @Test func deliveringAContractSparklesOverTheFounderDesk() {
        let scene = OfficeSceneInput(
            tier: .studio, occupants: occupants(6),
            celebration: .init(kind: .contractDelivered, token: 1)
        )
        let coin = OfficeFXSprites.coinSparkle()
        #expect(
            OfficeDirector.compose(input: scene, timing: OfficeSceneTiming(celebrationStart: 0), at: 0.5)
                .contains { $0.sprite == coin }
        )
    }

    @Test func celebrationsExpire() {
        let scene = OfficeSceneInput(
            tier: .studio, occupants: occupants(6),
            celebration: .init(kind: .contractDelivered, token: 1)
        )
        let timing = OfficeSceneTiming(celebrationStart: 0)
        #expect(OfficeDirector.activeCelebration(input: scene, timing: timing, at: 1) != nil)
        #expect(OfficeDirector.activeCelebration(input: scene, timing: timing, at: 30) == nil)
    }

    // MARK: Ambience

    @Test func theRoomGoesRoundTheClockOnItsOwn() {
        var seen: Set<TimeOfDay> = []
        for t in stride(from: 0.0, to: OfficeAmbience.clockPeriod, by: 5.0) {
            seen.insert(OfficeAmbience.timeOfDay(at: t))
        }
        #expect(seen == Set(TimeOfDay.allCases), "a full day passes in four minutes")
        #expect(OfficeAmbience.timeOfDay(at: 0, startingAt: .night) == .night, "the caller picks the hour it opens on")
        #expect(
            OfficeAmbience.timeOfDay(at: 0) == OfficeAmbience.timeOfDay(at: OfficeAmbience.clockPeriod),
            "and it loops"
        )
    }

    @Test func nightAndWeatherAddLayersWithoutMovingAnybody() {
        let plain = input(tier: .studio, count: 10, amenities: [])
        let stormy = OfficeSceneInput(
            tier: .studio, occupants: plain.occupants,
            ambience: OfficeAmbience(timeOfDay: .night, weather: .rain)
        )
        let day = OfficeDirector.compose(input: plain, at: 5).filter { $0.kind == .person }
        let night = OfficeDirector.compose(input: stormy, at: 5).filter { $0.kind == .person }
        #expect(day.map { ($0.x, $0.y) }.elementsEqual(night.map { ($0.x, $0.y) }, by: ==),
                "ambience is cosmetic — it never moves a person")
        #expect(
            OfficeDirector.compose(input: stormy, at: 5).count
                > OfficeDirector.compose(input: plain, at: 5).count,
            "night adds a lighting wash and rain adds a pane"
        )
    }

    @Test func middayAddsNoTint() {
        let noon = input(tier: .loft, count: 4, amenities: [], ambience: OfficeAmbience(timeOfDay: .day))
        let dusk = input(tier: .loft, count: 4, amenities: [], ambience: OfficeAmbience(timeOfDay: .dusk))
        #expect(
            OfficeDirector.compose(input: dusk, at: 1).count
                == OfficeDirector.compose(input: noon, at: 1).count + 1
        )
    }
}
