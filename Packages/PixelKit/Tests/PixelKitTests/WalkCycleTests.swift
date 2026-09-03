import Foundation
import Testing
@testable import PixelKit

/// The craft-level guarantees: feet that stay on the ground, a walk that
/// plays the cycle it was drawn with, turns that read as turns, and a room
/// that is not a metronome.
@Suite("Walk cycle and actor rhythm")
struct WalkCycleTests {
    func id(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }

    // MARK: Cadence

    @Test func cadenceKeepsOneCyclePerStrideWhateverTheSpeed() {
        // The whole point: however fast a leg travels, one full cycle of the
        // art has to cover exactly the ground the art claims. Anything else
        // is a sprite skating.
        // Only across the range the clamps leave alone: a crawl is
        // deliberately given quicker feet than its ground speed earns, so
        // that it still reads as movement rather than as a stuck sprite.
        for speed in stride(from: 10.0, through: 24.0, by: 2.0) {
            let rate = WalkCycle.fps(
                speed: speed, frames: WalkCycle.sideFrames.count,
                cycleLength: WalkCycle.sideCycleLength
            )
            let secondsPerCycle = Double(WalkCycle.sideFrames.count) / rate
            let groundPerCycle = speed * secondsPerCycle
            #expect(
                abs(groundPerCycle - WalkCycle.sideCycleLength) < 0.001,
                "at \(speed) px/s a cycle covered \(groundPerCycle) px"
            )
        }
    }

    @Test func cadenceIsClampedAtBothEnds() {
        #expect(WalkCycle.fps(speed: 0.01, frames: 4, cycleLength: 18) == WalkCycle.minimumFPS)
        #expect(WalkCycle.fps(speed: 900, frames: 4, cycleLength: 18) == WalkCycle.maximumFPS)
        #expect(WalkCycle.fps(speed: 0, frames: 4, cycleLength: 18) == WalkCycle.minimumFPS)
    }

    @Test func groundSpeedReadsTheLegNotTheRequestedSpeed() {
        // `Motion.walk` rounds up to a whole second, so a 13 px hop asked
        // for at 24 px/s actually travels at 13 px/s. Cadence must follow
        // the truth, not the request.
        let leg = Motion.walk(
            from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 13, y: 0), start: 0, speed: 24
        )
        #expect(leg.duration == 1)
        #expect(abs(WalkCycle.groundSpeed(of: leg) - 13) < 0.001)

        let long = Motion.walk(
            from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 72, y: 0), start: 0, speed: 24
        )
        #expect(abs(WalkCycle.groundSpeed(of: long) - 24) < 0.001)
        #expect(
            WalkCycle.cadence(for: long, facing: .right).fps
                > WalkCycle.cadence(for: leg, facing: .right).fps,
            "the faster leg takes quicker steps"
        )
    }

    @Test func profileAndCameraWalksUseTheirOwnCycles() {
        let leg = Motion(from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 24, y: 0), start: 0, duration: 1)
        #expect(WalkCycle.cadence(for: leg, facing: .right).frames == WalkCycle.sideFrames)
        #expect(WalkCycle.cadence(for: leg, facing: .left).frames == WalkCycle.sideFrames)
        #expect(WalkCycle.cadence(for: leg, facing: .forward).frames == WalkCycle.towardFrames)
    }

    @Test func aLongerStrideMeansFewerSteps() {
        let leg = Motion(from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 24, y: 0), start: 0, duration: 1)
        let short = WalkCycle.cadence(for: leg, facing: .right, strideScale: 0.9).fps
        let long = WalkCycle.cadence(for: leg, facing: .right, strideScale: 1.1).fps
        #expect(short > long, "a shorter stride is more steps over the same ground")
    }

    // MARK: Per-actor rhythm

    @Test func rhythmIsDeterministicAndVariedAcrossPeople() {
        #expect(ActorRhythm(id: id(3)) == ActorRhythm(id: id(3)), "a gait belongs to a person")
        let strides = Set((0..<24).map { ActorRhythm(id: id($0)).strideScale })
        #expect(strides.count >= 20, "only \(strides.count) distinct gaits in 24 people")
        for stride in strides {
            #expect(stride >= 0.88 && stride <= 1.12, "\(stride) is not a human stride")
        }
    }

    @Test func everyTypingChartBlinksAndHoldsABeat() {
        for index in 0..<40 {
            let chart = ActorRhythm(id: id(index)).typingChart
            #expect(chart.count == ActorRhythm.typingChartLength)
            #expect(chart.allSatisfy { (0...2).contains($0) }, "charts index the three seated frames")
            #expect(chart.contains(2), "person \(index) never blinks")
            #expect(chart.contains(1), "person \(index) never touches the keys")
            // A held beat: three steps in a row with the hands off the keys.
            let held = (0..<(chart.count - 2)).contains { chart[$0] == 0 && chart[$0 + 1] == 0 }
            #expect(held, "person \(index) never pauses")
        }
    }

    @Test func chartsDifferBetweenNeighbours() {
        let charts = Set((0..<20).map { ActorRhythm(id: id($0)).typingChart })
        #expect(charts.count >= 8, "a wall of desks needs more than \(charts.count) typing patterns")
    }

    // MARK: Turning

    @Test func aShortSidestepBorrowsTheJourneysHeading() {
        // Out of the desk row four pixels to the right, down to the
        // corridor, then a long walk left. The sidestep must not flip the
        // sprite for a second on the way.
        let track = Track.route(
            from: ScenePoint(x: 100, y: 40), to: ScenePoint(x: 20, y: 40),
            corridorY: 100, lanes: [104, 24], departingAt: 0, speed: 24
        )
        #expect(track.dominantHeading == .left)
        for t in stride(from: 0.05, to: track.end, by: 0.05) {
            let leg = track.leg(at: t)
            let short = leg.from.distance(to: leg.to) < Track.turnThreshold
            let horizontal = abs(leg.to.x - leg.from.x) > abs(leg.to.y - leg.from.y)
            if short, horizontal {
                #expect(track.heading(at: t) == .left, "twitched at t=\(t)")
            }
        }
    }

    @Test func longLegsFaceTheWayTheyGoAndVerticalLegsFaceTheViewer() {
        let track = Track.route(
            from: ScenePoint(x: 20, y: 40), to: ScenePoint(x: 200, y: 40),
            corridorY: 100, departingAt: 0, speed: 24
        )
        // Leg 0 is straight down to the corridor, leg 1 is the long walk right.
        #expect(track.heading(at: track.legs[0].start + 0.5) == .forward)
        #expect(track.heading(at: track.legs[1].start + 0.5) == .right)
        #expect(track.heading(at: track.end + 5) == .forward, "arrived people face the room")
    }

    @Test func aParkedTrackHasNoHeading() {
        let track = Track(parkedAt: ScenePoint(x: 4, y: 4))
        #expect(track.dominantHeading == nil)
        #expect(track.heading(at: 3) == .forward)
    }

    // MARK: Tempo

    @Test func tempoReadsCrunchMoraleAndAnOrdinaryDay() {
        // Crunch is a fact the scene input carries (the team's pace), not
        // something read off the room's own clock.
        func scene(time: TimeOfDay, mood: MoodLevel, building: Bool, crunch: Bool = false) -> OfficeSceneInput {
            let statuses: [WorkStatus] = building ? [.coding, .designing, .testing] : [.idle, .marketing]
            let people = (0..<6).map { index in
                Occupant(
                    id: id(index), appearance: CharacterAppearance(seed: UInt64(index)),
                    status: statuses[index % statuses.count], isFounder: index == 0
                )
            }
            var input = OfficeSceneInput(
                tier: .loft, occupants: people,
                ambience: OfficeAmbience(timeOfDay: time, teamMood: mood)
            )
            input.pressure = OfficePressure(crunch: crunch)
            return input
        }
        #expect(OfficeTempo.reading(for: scene(time: .night, mood: .okay, building: true, crunch: true)) == .crunch)
        #expect(
            OfficeTempo.reading(for: scene(time: .night, mood: .great, building: true, crunch: true)) == .crunch,
            "a good mood on crunch still looks like crunch"
        )
        #expect(
            OfficeTempo.reading(for: scene(time: .night, mood: .okay, building: true)) != .crunch,
            "a late hour on its own is no longer crunch"
        )
        #expect(OfficeTempo.reading(for: scene(time: .night, mood: .okay, building: false)) == .steady)
        #expect(OfficeTempo.reading(for: scene(time: .day, mood: .great, building: true)) == .buoyant)
        #expect(OfficeTempo.reading(for: scene(time: .day, mood: .low, building: true)) == .flagging)
        #expect(OfficeTempo.reading(for: scene(time: .day, mood: .okay, building: true)) == .steady)
        #expect(OfficeTempo.reading(for: .init(tier: .loft, occupants: [])) == .steady)
    }

    @Test func crunchHurriesAndFlaggingDrags() {
        #expect(OfficeTempo.crunch.walkScale > OfficeTempo.steady.walkScale)
        #expect(OfficeTempo.flagging.walkScale < OfficeTempo.steady.walkScale)
        #expect(OfficeTempo.crunch.typingStepsPerSecond > OfficeTempo.flagging.typingStepsPerSecond)
        #expect(OfficeTempo.buoyant.breathBias < OfficeTempo.flagging.breathBias, "a good week breathes quicker")
    }
}
