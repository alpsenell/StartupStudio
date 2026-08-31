import Foundation
import Testing
@testable import PixelKit

/// What the office actually puts on screen, frame by frame: the whole walk
/// cycle, feet that match the floor, a launch that has a jump in it, and a
/// room whose pace says what kind of week the team is having.
@Suite("Office animation")
struct OfficeAnimationTests {
    func id(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }

    func people(_ count: Int, mood: MoodLevel = .okay, status: WorkStatus = .coding) -> [Occupant] {
        (0..<count).map { index in
            Occupant(
                id: id(index),
                appearance: CharacterAppearance(seed: UInt64(index) &+ 200),
                status: index % 4 == 0 ? .designing : status,
                isFounder: index == 0,
                mood: mood,
                name: "P\(index)"
            )
        }
    }

    func scene(
        _ count: Int = 12,
        tier: OfficeTierStyle = .studio,
        ambience: OfficeAmbience = .plain,
        mood: MoodLevel = .okay
    ) -> OfficeSceneInput {
        OfficeSceneInput(
            tier: tier, occupants: people(count, mood: mood),
            amenities: [.gameRoom, .cafeteria, .gym], ambience: ambience
        )
    }

    /// Every person placement that is mid-walk, over a slice of the day.
    ///
    /// Deliberately a slice of a mid-sized room rather than a whole campus
    /// day. `SpriteCache` is process-global and `OfficePerfTests` asserts
    /// that a warmed cache re-rasterizes *nothing*; a suite that composes
    /// ten thousand campus frames beside it evicts the very entries that
    /// test is measuring and fails it about half the time. Forty-five
    /// seconds of a studio floor is more walking than any assertion here
    /// needs, and it keeps this suite from breaking someone else's.
    func walkers(
        in input: OfficeSceneInput,
        step: TimeInterval = 1.0 / 12,
        window: TimeInterval = 45
    ) -> [(PlacedSprite, TimeInterval)] {
        var found: [(PlacedSprite, TimeInterval)] = []
        for t in stride(from: 0.0, to: window, by: step) {
            for placement in OfficeDirector.compose(input: input, at: t)
            where placement.kind == .person && placement.motion != nil {
                found.append((placement, t))
            }
        }
        return found
    }

    func rate(of animation: SpriteAnimation) -> Double? {
        if case .sequence(_, let fps, _) = animation { return fps }
        return nil
    }

    // MARK: The walk

    @Test func theWalkPlaysAllFourAuthoredPoses() {
        // The director used to ask for frames [0, 1] of a four-frame cycle,
        // so the contact-back and bobbed-passing poses were drawn but never
        // shown: the same hand led every stride.
        var drawn = Set<Int>()
        for (placement, t) in walkers(in: scene(12))
        where placement.sprite.frameCount == WalkCycle.sideFrames.count {
            drawn.insert(placement.frameIndex(at: t))
        }
        #expect(drawn == Set(WalkCycle.sideFrames), "only saw frames \(drawn.sorted())")
    }

    @Test func feetKeepUpWithTheFloorTheyWalkOn() {
        for (placement, _) in walkers(in: scene(12)) {
            guard let motion = placement.motion,
                  let fps = rate(of: placement.animation),
                  placement.sprite.frameCount == WalkCycle.sideFrames.count else { continue }
            let speed = WalkCycle.groundSpeed(of: motion)
            // Below and above the clamps the relationship is deliberately
            // broken (a crawl still has to look alive), so only judge the
            // range the clamps leave alone.
            let unclamped = Double(WalkCycle.sideFrames.count) * speed / WalkCycle.sideCycleLength
            guard unclamped > WalkCycle.minimumFPS, unclamped < WalkCycle.maximumFPS else { continue }
            let groundPerCycle = speed * Double(WalkCycle.sideFrames.count) / fps
            #expect(
                groundPerCycle > WalkCycle.sideCycleLength * 0.85
                    && groundPerCycle < WalkCycle.sideCycleLength * 1.15,
                "a stride covered \(groundPerCycle) px of floor, not ~\(WalkCycle.sideCycleLength)"
            )
        }
    }

    @Test func everyLegStartsOnAPlantedFoot() {
        // A cycle that restarts on the contact pose at each leg boundary is
        // what makes the corner of an L-route read as a turn rather than as
        // a slide round the bend.
        var checked = 0
        for (placement, _) in walkers(in: scene(12), step: 0.25) {
            guard let motion = placement.motion, rate(of: placement.animation) != nil else { continue }
            #expect(placement.frameIndex(at: motion.start) == 0, "leg began mid-stride")
            checked += 1
        }
        #expect(checked > 50, "only \(checked) walking frames to judge")
    }

    @Test func twoWalkersAreNeverInLockstep() {
        var rates = Set<Double>()
        for (placement, _) in walkers(in: scene(16), step: 0.5) {
            if let fps = rate(of: placement.animation) { rates.insert((fps * 100).rounded()) }
        }
        #expect(rates.count >= 6, "the whole room walks at \(rates.count) cadence(s)")
    }

    // MARK: Desks

    @Test func aWallOfDesksIsNotOneKeyboard() {
        let placements = OfficeDirector.compose(input: scene(24, tier: .campus), at: 3)
        var charts = Set<[Int]>()
        for placement in placements where placement.kind == .person {
            if case .sequence(let frames, _, _) = placement.animation, frames.count > 4 {
                charts.insert(frames)
            }
        }
        #expect(charts.count >= 8, "only \(charts.count) typing patterns on a campus floor")
    }

    @Test func crunchTypesFasterThanAFlaggingRoom() {
        func typingRate(_ input: OfficeSceneInput) -> Double {
            let placements = OfficeDirector.compose(input: input, at: 2)
            for placement in placements where placement.kind == .person {
                if case .sequence(let frames, let fps, _) = placement.animation,
                   frames.count == ActorRhythm.typingChartLength {
                    return fps
                }
            }
            return 0
        }
        let crunch = scene(12, ambience: OfficeAmbience(timeOfDay: .night, teamMood: .okay))
        let flagging = scene(12, ambience: OfficeAmbience(timeOfDay: .day, teamMood: .low), mood: .okay)
        let ordinary = scene(12)
        #expect(OfficeTempo.reading(for: crunch) == .crunch)
        #expect(typingRate(crunch) > typingRate(ordinary))
        #expect(typingRate(flagging) < typingRate(ordinary))
        #expect(typingRate(ordinary) > 0)
    }

    @Test func idleHandsAreSlowerHands() {
        var busy = people(6)
        busy[3].status = .idle
        let input = OfficeSceneInput(tier: .loft, occupants: busy)
        var rates: [Double] = []
        for placement in OfficeDirector.compose(input: input, at: 2) where placement.kind == .person {
            if case .sequence(let frames, let fps, _) = placement.animation,
               frames.count == ActorRhythm.typingChartLength {
                rates.append(fps)
            }
        }
        #expect(Set(rates).count == 2, "the idle desk should tick at its own rate")
        #expect(rates.min()! < rates.max()!)
    }

    // MARK: The cheer

    @Test func theCheerChartHasAnticipationHangTimeAndALanding() {
        let chart = OfficeDirector.cheerChart
        #expect(chart.first == 2, "a jump starts by going down")
        #expect(chart.last == 0, "and finishes standing")
        #expect(Set(chart) == [0, 1, 2, 3], "all four cheer frames are used")
        // Frame 1 is only ever passed through, once on the way up and once
        // on the way down: it is the in-between, not a pose to hold.
        #expect(chart.filter { $0 == 1 }.count == 2, "the rise and the fall")
        // The apex is the longest hold in the chart. That slow-in at the
        // top is where the eye rests, and it is what separates a jump from
        // a jiggle.
        func longestRun(of frame: Int) -> Int {
            var best = 0
            var run = 0
            for value in chart {
                run = value == frame ? run + 1 : 0
                best = max(best, run)
            }
            return best
        }
        #expect(longestRun(of: 3) > longestRun(of: 2), "hang time beats the crouch")
        #expect(longestRun(of: 3) >= 3)
        // Crouch, push, rise, hang, fall, land — in that order, exactly once.
        let beats = chart.reduce(into: [Int]()) { runs, value in
            if runs.last != value { runs.append(value) }
        }
        #expect(beats == [2, 0, 1, 3, 1, 0, 2, 0], "the arc is out of order: \(beats)")
    }

    @Test func shippingPlaysTheWholeJumpInUnison() {
        let input = OfficeSceneInput(
            tier: .loft, occupants: people(8),
            celebration: .init(kind: .shipped(score: 78), token: 1)
        )
        let timing = OfficeSceneTiming(celebrationStart: 0)
        var drawnByPerson: [Int: Set<Int>] = [:]
        var perFrame: [TimeInterval: Set<Int>] = [:]
        for step in 0..<OfficeDirector.cheerChart.count {
            let t = AnimationClock.time(ofFrame: step)
            var index = 0
            for placement in OfficeDirector.compose(input: input, timing: timing, at: t)
            where placement.kind == .person {
                drawnByPerson[index, default: []].insert(placement.frameIndex(at: t))
                perFrame[t, default: []].insert(placement.frameIndex(at: t))
                index += 1
            }
        }
        #expect(
            drawnByPerson.values.allSatisfy { $0 == [0, 1, 2, 3] },
            "everybody crouches, jumps, hangs and lands"
        )
        #expect(
            perFrame.values.allSatisfy { $0.count == 1 },
            "a launch is cheered in unison, not as a Mexican wave"
        )
    }

    // MARK: Carried things

    @Test func theCarriedBoxBobsOnlyWhileTheLeaverIsWalking() {
        let staff = people(6)
        let input = OfficeSceneInput(
            tier: .loft, occupants: staff,
            celebration: .init(kind: .quit(staff[4].id), token: 1)
        )
        let timing = OfficeSceneTiming(celebrationStart: 0)
        let box = OfficeFXSprites.cardboardBox()
        #expect(box.frameCount == 2, "a carried box has a lift in it")

        func boxAnimation(at t: TimeInterval) -> SpriteAnimation? {
            OfficeDirector.compose(input: input, timing: timing, at: t)
                .first { $0.sprite == box }?.animation
        }
        // The first two seconds are spent standing up with the box.
        #expect(boxAnimation(at: 1) == .still, "a box standing still does not bounce")
        let walking = (3...6).compactMap { boxAnimation(at: TimeInterval($0)) }
        #expect(walking.contains { rate(of: $0) != nil }, "and rides the stride once they set off")
    }

    // MARK: Still deterministic

    @Test func everyRateIsAPureFunctionOfTimeAndState() {
        let input = scene(12)
        for t in stride(from: 0.0, to: 60.0, by: 5.0) {
            OfficeDirector.resetCaches()
            let a = OfficeDirector.compose(input: input, at: t)
            OfficeDirector.resetCaches()
            let b = OfficeDirector.compose(input: input, at: t)
            #expect(a.map(\.animation) == b.map(\.animation), "animation drifted at t=\(t)")
            #expect(a.map(\.phase) == b.map(\.phase))
            #expect(a.map(\.start) == b.map(\.start))
        }
    }
}
