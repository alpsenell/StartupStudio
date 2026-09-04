import Foundation
import Testing
@testable import PixelKit

@Suite("Animation runtime")
struct AnimationTests {
    // MARK: Easing

    @Test func everyEasingStartsAtZeroAndEndsAtOne() {
        for easing in Easing.allCases {
            #expect(easing.apply(0) == 0, "\(easing) at 0")
            #expect(abs(easing.apply(1) - 1) < 1e-9, "\(easing) at 1")
        }
    }

    @Test func easingClampsOutOfRangeProgress() {
        for easing in Easing.allCases {
            #expect(easing.apply(-5) == easing.apply(0))
            #expect(easing.apply(5) == easing.apply(1))
        }
    }

    @Test func easingShapes() {
        #expect(Easing.linear.apply(0.25) == 0.25)
        #expect(Easing.easeIn.apply(0.5) < 0.5, "ease-in lags the middle")
        #expect(Easing.easeOut.apply(0.5) > 0.5, "ease-out leads the middle")
        #expect(abs(Easing.easeInOut.apply(0.5) - 0.5) < 1e-9, "ease-in-out is symmetric")
        #expect(Easing.easeOutBack.apply(0.75) > 1, "back overshoots before settling")
        #expect(Easing.step.apply(0.99) == 0)
    }

    @Test func easingIsMonotonicExceptForTheDeliberateOvershoot() {
        for easing in Easing.allCases where easing != .easeOutBack && easing != .bob {
            var previous = -1.0
            for i in 0...100 {
                let value = easing.apply(Double(i) / 100)
                #expect(value >= previous - 1e-12, "\(easing) went backwards at \(i)")
                previous = value
            }
        }
    }

    // MARK: Motion

    @Test func motionHoldsBeforeStartAndAfterEnd() {
        let motion = Motion(
            from: ScenePoint(x: 10, y: 20), to: ScenePoint(x: 50, y: 20),
            start: 2, duration: 4
        )
        #expect(motion.position(at: 0) == ScenePoint(x: 10, y: 20))
        #expect(motion.position(at: 2) == ScenePoint(x: 10, y: 20))
        #expect(motion.position(at: 4) == ScenePoint(x: 30, y: 20))
        #expect(motion.position(at: 6) == ScenePoint(x: 50, y: 20))
        #expect(motion.position(at: 900) == ScenePoint(x: 50, y: 20))
        #expect(motion.end == 6)
    }

    @Test func zeroDurationMotionSnaps() {
        let motion = Motion(from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 9, y: 9), start: 3, duration: 0)
        #expect(motion.position(at: 2.9) == ScenePoint(x: 0, y: 0))
        #expect(motion.position(at: 3) == ScenePoint(x: 9, y: 9))
        #expect(motion.isMoving(at: 3) == false)
    }

    @Test func motionIsMovingOnlyInsideItsWindow() {
        let motion = Motion(from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 24, y: 0), start: 1, duration: 1)
        #expect(motion.isMoving(at: 1) == false)
        #expect(motion.isMoving(at: 1.5))
        #expect(motion.isMoving(at: 2) == false)
    }

    @Test func walkDurationIsWholeSecondsAtTheGivenSpeed() {
        // 72 px at 24 px/s is exactly 3 s; 70 px rounds up to 3 s as well, so
        // every plan boundary lands on a whole second.
        let exact = Motion.walk(
            from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 72, y: 0), start: 0, speed: 24
        )
        #expect(exact.duration == 3)
        let ragged = Motion.walk(
            from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 70, y: 0), start: 0, speed: 24
        )
        #expect(ragged.duration == 3)
        let tiny = Motion.walk(
            from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 2, y: 0), start: 0, speed: 24
        )
        #expect(tiny.duration == 1, "even a shuffle takes a whole second")
    }

    @Test func scenePointRoundsToWholePixels() {
        #expect(ScenePoint(x: 10.4, y: 20.6).rounded == (10, 21))
        #expect(ScenePoint(x: 3, y: 4).distance(to: ScenePoint(x: 0, y: 0)) == 5)
    }

    // MARK: Track

    @Test func routeIsLShapedThroughTheCorridor() {
        let track = Track.route(
            from: ScenePoint(x: 20, y: 40), to: ScenePoint(x: 140, y: 30),
            corridorY: 100, departingAt: 0, speed: 24
        )
        // down to the corridor, along it, then up to the destination
        #expect(track.legs.count == 3)
        #expect(track.legs[0].to == ScenePoint(x: 20, y: 100))
        #expect(track.legs[1].to == ScenePoint(x: 140, y: 100))
        #expect(track.destination == ScenePoint(x: 140, y: 30))
        #expect(track.legs[0].end == track.legs[1].start, "legs are contiguous")
        #expect(track.legs[1].end == track.legs[2].start)
        #expect(track.duration == track.legs.reduce(0) { $0 + $1.duration })
    }

    @Test func routeCollapsesWhenBothEndsAreOnTheCorridor() {
        let track = Track.route(
            from: ScenePoint(x: 10, y: 100), to: ScenePoint(x: 90, y: 100),
            corridorY: 100, departingAt: 5, speed: 24
        )
        #expect(track.legs.count == 1)
        #expect(track.start == 5)
    }

    @Test func trackPositionFollowsTheActiveLeg() {
        let track = Track.route(
            from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 48, y: 0),
            corridorY: 24, departingAt: 0, speed: 24
        )
        #expect(track.position(at: 0) == ScenePoint(x: 0, y: 0))
        #expect(track.position(at: track.end) == track.destination)
        #expect(track.isMoving(at: track.end) == false)
        #expect(track.isMoving(at: track.duration / 2))
    }

    @Test func parkedTrackNeverMoves() {
        let track = Track(parkedAt: ScenePoint(x: 7, y: 8))
        #expect(track.position(at: 0) == ScenePoint(x: 7, y: 8))
        #expect(track.position(at: 1_000) == ScenePoint(x: 7, y: 8))
        #expect(track.isMoving(at: 500) == false)
    }

    // MARK: Clock

    @Test func clockMapsSecondsOntoBothRates() {
        #expect(AnimationClock.fps == 12)
        #expect(AnimationClock.tick(at: 0) == 0)
        #expect(AnimationClock.tick(at: 1) == 4)
        #expect(AnimationClock.tick(at: 1.75) == 7)
        #expect(AnimationClock.frame(at: 1) == 12)
        #expect(AnimationClock.time(ofFrame: 12) == 1)
        #expect(AnimationClock.secondBucket(at: 3.99) == 3)
        #expect(AnimationClock.tick(at: -5) == 0)
    }

    // MARK: Animation modes

    private func placed(_ animation: SpriteAnimation, frames: Int = 4, start: TimeInterval = 0, phase: Int = 0) -> PlacedSprite {
        let row = String(repeating: "X", count: 2)
        let sprite = PixelSprite(
            frames: Array(repeating: [row, row], count: frames),
            palette: ["X": .init(r: 1, g: 2, b: 3)]
        )
        return PlacedSprite(
            sprite: sprite, x: 0, y: 0, kind: .prop,
            animation: animation, phase: phase, start: start
        )
    }

    @Test func sequenceLoopsAtItsOwnFrameRate() {
        let p = placed(.sequence(frames: [0, 1, 2], fps: 12, loop: true))
        #expect(p.frameIndex(at: 0) == 0)
        #expect(p.frameIndex(at: 1 / 12.0) == 1)
        #expect(p.frameIndex(at: 2 / 12.0) == 2)
        #expect(p.frameIndex(at: 3 / 12.0) == 0, "loops")
        #expect(p.frameIndex(at: 4 / 12.0) == 1)
    }

    @Test func nonLoopingSequenceHoldsTheLastFrame() {
        let p = placed(.sequence(frames: [0, 1, 2], fps: 6, loop: false))
        #expect(p.frameIndex(at: 0) == 0)
        #expect(p.frameIndex(at: 0.5) == 2)
        #expect(p.frameIndex(at: 60) == 2)
    }

    @Test func onceIsAnchoredToStartAndReportsCompletion() {
        let p = placed(.once(frames: [1, 2, 3], fps: 3), start: 10)
        #expect(p.frameIndex(at: 0) == 1, "before the start it shows frame one")
        #expect(p.frameIndex(at: 10) == 1)
        #expect(p.frameIndex(at: 10.4) == 2)
        #expect(p.frameIndex(at: 10.7) == 3)
        #expect(p.hasFinished(at: 10.5) == false)
        #expect(p.hasFinished(at: 11.5))
    }

    @Test func sequencePhaseDesyncsNeighbours() {
        let a = placed(.sequence(frames: [0, 1], fps: 12, loop: true), phase: 0)
        let b = placed(.sequence(frames: [0, 1], fps: 12, loop: true), phase: 1)
        #expect(a.frameIndex(at: 0) != b.frameIndex(at: 0))
    }

    @Test func frameIndexNeverLeavesTheSprite() {
        let p = placed(.sequence(frames: [0, 5, 9], fps: 12, loop: true), frames: 2)
        for frame in 0..<48 {
            let index = p.frameIndex(at: AnimationClock.time(ofFrame: frame))
            #expect((0..<p.sprite.frameCount).contains(index))
        }
    }

    @Test func legacyModesAgreeBetweenTicksAndSeconds() {
        let modes: [SpriteAnimation] = [
            .still, .typing(slow: false), .typing(slow: true), .glow, .toggle(period: 3),
        ]
        for mode in modes {
            let p = placed(mode, frames: 3, phase: 2)
            for tick in 0..<40 {
                let seconds = TimeInterval(tick) / AnimationClock.legacyTicksPerSecond
                #expect(
                    p.frameIndex(at: seconds) == p.frameIndex(atTick: tick),
                    "\(mode) disagreed at tick \(tick)"
                )
            }
        }
    }

    @Test func sequenceIsReachableFromTheLegacyTickEntryPoint() {
        let p = placed(.sequence(frames: [0, 1, 2], fps: 4, loop: true))
        #expect(p.frameIndex(atTick: 1) == 1)
        #expect(p.frameIndex(atTick: 3) == 0)
    }

    // MARK: Placement geometry

    @Test func placementWithoutMotionStaysPut() {
        let p = placed(.still)
        #expect(p.position(at: 0) == (0, 0))
        #expect(p.position(at: 99) == (0, 0))
    }

    @Test func placementWithMotionFollowsIt() {
        var p = placed(.still)
        p.motion = Motion(from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: 10, y: 0), start: 0, duration: 2)
        #expect(p.position(at: 1) == (5, 0))
        #expect(p.position(at: 2) == (10, 0))
    }

    @Test func defaultZIndexSortsByBaselineWithRoomsBehindAndBubblesInFront() {
        let sprite = SpriteLibrary.desk()
        let back = PlacedSprite(sprite: sprite, x: 0, y: 10, kind: .desk, animation: .still, phase: 0)
        let front = PlacedSprite(sprite: sprite, x: 0, y: 40, kind: .desk, animation: .still, phase: 0)
        let room = PlacedSprite(sprite: sprite, x: 0, y: 0, kind: .room, animation: .still, phase: 0)
        let bubble = PlacedSprite(sprite: sprite, x: 0, y: 10, kind: .bubble, animation: .still, phase: 0)
        #expect(back.zIndex < front.zIndex)
        #expect(room.zIndex < back.zIndex)
        #expect(bubble.zIndex > front.zIndex)
        #expect(back.zIndex == 10 + sprite.height)
    }

    @Test func explicitZIndexWins() {
        let p = PlacedSprite(
            sprite: SpriteLibrary.desk(), x: 0, y: 10, kind: .desk,
            animation: .still, phase: 0, zIndex: 42
        )
        #expect(p.zIndex == 42)
    }

    // MARK: The old composers are untouched

    @Test func existingOfficeCompositionIsUnchangedAtTimeZero() {
        let occupants = (0..<12).map { i in
            Occupant(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!,
                appearance: CharacterAppearance(seed: UInt64(i) &+ 5),
                status: WorkStatus.allCases[i % WorkStatus.allCases.count],
                isFounder: i == 0
            )
        }
        for tier in OfficeTierStyle.allCases {
            let scene = SceneComposer.compose(tier: tier, occupants: occupants, amenities: [.gameRoom, .cafeteria])
            for placement in scene {
                #expect(placement.motion == nil, "the static composer never animates position")
                #expect(placement.opacity == 1)
                #expect(placement.flipX == false)
                #expect(placement.start == 0)
                #expect(placement.position(at: 0) == (placement.x, placement.y))
                #expect(placement.frameIndex(at: 0) == placement.frameIndex(atTick: 0))
            }
        }
    }

    @Test func homeAndCitySceneAnimationStillReadsFromTheTickClock() {
        // The home composer is WS-D's; this guards that the shared runtime
        // change did not move its frames.
        let scene = HomeSceneComposer.compose(
            tier: .studioFlat,
            occupants: HomeOccupants(founder: CharacterAppearance(seed: 3)),
            activity: .relaxing,
            mood: .okay
        )
        for placement in scene {
            for tick in 0..<12 {
                let seconds = TimeInterval(tick) / AnimationClock.legacyTicksPerSecond
                #expect(placement.frameIndex(at: seconds) == placement.frameIndex(atTick: tick))
            }
        }
    }
}
