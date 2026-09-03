import Foundation

/// The moments the scene needs a wall-clock anchor for.
///
/// The director is a pure function of `(input, timing, t)`. Anything that
/// happens "when something changed" — a celebration firing, a status
/// flipping, a tap landing — needs to know *when* that change happened, and
/// only the view can observe it. It records the scene time here and hands
/// it back, which keeps the director testable and replayable.
///
/// All times are whole seconds, matching the director's plan boundaries.
public struct OfficeSceneTiming: Sendable, Equatable, Hashable {
    /// When the current `OfficeSceneInput.celebration` token appeared.
    public var celebrationStart: TimeInterval
    /// When each occupant's `status` last changed, for transient bubbles.
    public var statusChanges: [UUID: TimeInterval]
    /// The most recent tap on a person, if it is still on screen.
    public var tap: Tap?

    /// A tap the scene is still showing a name plate for.
    public struct Tap: Sendable, Equatable, Hashable {
        public var id: UUID
        public var at: TimeInterval

        public init(id: UUID, at: TimeInterval) {
            self.id = id
            self.at = at
        }
    }

    public init(
        celebrationStart: TimeInterval = 0,
        statusChanges: [UUID: TimeInterval] = [:],
        tap: Tap? = nil
    ) {
        self.celebrationStart = celebrationStart
        self.statusChanges = statusChanges
        self.tap = tap
    }

    /// Nothing has happened yet.
    public static let none = OfficeSceneTiming()
}

/// Decides what everyone in the office is doing at time `t` — desk work,
/// coffee runs, whiteboard huddles, amenity visits, celebrations — and
/// turns it into a back-to-front list of `PlacedSprite`s.
///
/// `compose(input:timing:at:)` is pure and deterministic: the same
/// arguments always give the same list, which is what the frame-sheet PNGs,
/// the behaviour tests and the perf budget all lean on. Because every plan
/// boundary lands on a whole second, the list only changes once a second —
/// so it is memoized per `(input, timing, second)` and the 12 fps renderer
/// gets its smoothness from the motions inside the placements rather than
/// from recomposing.
public enum OfficeDirector {
    // MARK: - Tunables

    /// How long a status bubble stays up after the status changes.
    static let statusBubbleDuration: TimeInterval = 3
    /// How often a person reminds you what they are working on.
    static let statusPulsePeriod: TimeInterval = 24
    /// How long a tapped name plate stays up.
    static let nameTagDuration: TimeInterval = 4

    // MARK: - Composition

    /// The office at scene time `t`.
    public static func compose(
        input: OfficeSceneInput,
        timing: OfficeSceneTiming = .none,
        at t: TimeInterval
    ) -> [PlacedSprite] {
        let bucket = AnimationClock.secondBucket(at: t)
        let key = SceneKey(input: input, timing: timing, second: bucket)
        if let cached = sceneCache.value(for: key) { return cached }
        let placements = build(input: input, timing: timing, at: TimeInterval(bucket))
        sceneCache.store(placements, for: key)
        return placements
    }

    /// Everyone's plan for the office day containing `t`.
    public static func plans(for input: OfficeSceneInput, at t: TimeInterval) -> [ActorPlan] {
        let day = dayIndex(at: t)
        let key = PlanKey(input: input, day: day)
        if let cached = planCache.value(for: key) { return cached }
        var plans = OfficeBehaviors.plans(for: input, dayIndex: day)
        if input.reduceMotion {
            plans = plans.map(seatedAllDay)
        }
        planCache.store(plans, for: key)
        return plans
    }

    /// The same person, at their desk for the whole day: the plan Reduce
    /// Motion asks for. The desk segment's pose and bubble are kept (a
    /// gloomy coder still looks gloomy); only the walking goes.
    private static func seatedAllDay(_ plan: ActorPlan) -> ActorPlan {
        let desk = plan.segments.first { $0.waypointID == "desk" } ?? plan.segments.first
        guard let desk else { return plan }
        return ActorPlan(
            id: plan.id,
            seatIndex: plan.seatIndex,
            deskAnchor: plan.deskAnchor,
            segments: [
                ActorSegment(
                    start: 0, end: OfficeBehaviors.dayLength, pose: desk.pose,
                    track: Track(parkedAt: plan.deskAnchor, from: 0),
                    bubble: desk.bubble, waypointID: "desk"
                ),
            ]
        )
    }

    /// The occupant whose sprite covers scene-space point (`x`, `y`) at
    /// time `t`, or `nil` when the tap missed everybody. The person drawn
    /// closest to the viewer wins.
    public static func hitTest(
        input: OfficeSceneInput,
        t: TimeInterval,
        x: Int,
        y: Int
    ) -> UUID? {
        var best: (id: UUID, zIndex: Int)?
        for actor in actorFrames(input: input, timing: .none, at: t) {
            guard x >= actor.x, x < actor.x + actor.width,
                  y >= actor.y, y < actor.y + actor.height else { continue }
            if best == nil || actor.zIndex > best!.zIndex {
                best = (actor.id, actor.zIndex)
            }
        }
        return best?.id
    }

    /// Which office day `t` falls in. A day is four real-time minutes.
    static func dayIndex(at t: TimeInterval) -> Int {
        Int((max(0, t) / OfficeBehaviors.dayLength).rounded(.down))
    }

    /// Time within the office day.
    static func dayTime(at t: TimeInterval) -> TimeInterval {
        max(0, t) - TimeInterval(dayIndex(at: t)) * OfficeBehaviors.dayLength
    }

    // MARK: - The frame

    /// Every person on screen right now, as a rectangle plus depth. Used
    /// for hit-testing and by the tests that check nobody walks through the
    /// furniture.
    struct ActorFrame {
        var id: UUID
        var x: Int
        var y: Int
        var width: Int
        var height: Int
        var zIndex: Int
        var pose: ActorPose
        var waypointID: String?
    }

    static func actorFrames(
        input: OfficeSceneInput, timing: OfficeSceneTiming, at t: TimeInterval
    ) -> [ActorFrame] {
        let dayT = dayTime(at: t)
        let celebration = activeCelebration(input: input, timing: timing, at: t)
        var frames: [ActorFrame] = []
        for plan in plans(for: input, at: t) {
            guard let occupant = occupant(plan.id, in: input) else { continue }
            let state = actorState(
                plan: plan, occupant: occupant, input: input,
                celebration: celebration, timing: timing, dayTime: dayT, t: t
            )
            guard state.pose != .desk || !state.hidden else { continue }
            guard !state.hidden else { continue }
            let sprite = personSprite(for: occupant, state: state)
            let origin = spriteOrigin(state: state, sprite: sprite, plan: plan, input: input)
            frames.append(ActorFrame(
                id: plan.id, x: origin.x, y: origin.y,
                width: sprite.width, height: sprite.height,
                zIndex: origin.y + sprite.height,
                pose: state.pose, waypointID: state.waypointID
            ))
        }
        return frames
    }

    private static func build(
        input: OfficeSceneInput, timing: OfficeSceneTiming, at t: TimeInterval
    ) -> [PlacedSprite] {
        let tier = input.tier
        let l = SceneComposer.layout(for: tier)
        let size = SceneComposer.sceneSize(for: tier)
        let rows = SceneComposer.deskRows(for: tier, cols: l.cols)
        let founderY = l.rowsStartY + rows * SceneComposer.Layout.cellHeight + SceneComposer.Layout.founderGap
        let ambience = input.ambience
        let celebration = activeCelebration(input: input, timing: timing, at: t)
        let dayT = dayTime(at: t)
        let actors = plans(for: input, at: t)
        let tempo = OfficeTempo.reading(for: input)
        let seatedIDs = Dictionary(uniqueKeysWithValues: actors.map { ($0.seatIndex, $0.id) })

        var scene: [PlacedSprite] = []

        // 1. The room itself, at the hour. The amenity zones go on top of
        //    it, so it is told where they land and leaves its own floor
        //    dressing out from under them; the shown set is part of the
        //    cache key for exactly that reason.
        let shownAmenities = SceneComposer.shownAmenities(for: tier, amenities: input.amenities)
        let zoneRects = SceneComposer.zoneFrames(
            for: tier, shown: shownAmenities, size: size,
            founderY: SceneComposer.founderRowY(for: tier)
        ).map { (x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        scene.append(PlacedSprite(
            sprite: SpriteCache.shared(
                "room.\(tier.rawValue).\(size.width)x\(size.height).\(l.wallHeight)"
                    + ".\(ambience.timeOfDay.rawValue).\(shownAmenities.map(\.rawValue).joined(separator: "-"))"
            ) {
                RoomBuilder.officeRoom(
                    tier: tier, width: size.width, height: size.height,
                    wallHeight: l.wallHeight, time: ambience.timeOfDay, amenityRects: zoneRects
                )
            },
            x: 0, y: 0, kind: .room, animation: .still, phase: 0
        ))

        // 2. Weather behind the props, so it sits in the windows.
        scene += OfficeFX.weather(ambience.weather, sceneWidth: size.width, wallHeight: l.wallHeight)

        // 3. Fixed props, then the runtime's own kitchenette where the tier
        //    has no coffee machine of its own.
        scene += SceneComposer.props(for: tier, size: size, layout: l, ambience: ambience)
        if let origin = OfficeWaypoints.coffee(for: tier).kitchenette {
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("fx.kitchenette", make: OfficeFXSprites.kitchenette),
                x: origin.x, y: origin.y,
                kind: .prop, animation: .toggle(period: 6), phase: 0
            ))
        }

        // 4. The flip-chart, only while somebody is actually huddled at it.
        if actors.contains(where: { ($0.segment(at: dayT).waypointID ?? "").hasPrefix("whiteboard") })
            || isShipCelebration(celebration) {
            let easel = OfficeWaypoints.easelOrigin(for: tier)
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("fx.easel", make: OfficeFXSprites.easel),
                x: easel.x, y: easel.y,
                kind: .prop, animation: .toggle(period: 8), phase: 0
            ))
        }

        // 5. Desks and monitors. A monitor with nobody in front of it is
        //    dark — a room of forty lit screens over empty chairs was the
        //    single most lifeless thing about the old scene.
        for index in 0...tier.deskCapacity {
            let cell = SceneComposer.cellOrigin(tier: tier, index: index)
            let occupied = seatedIDs[index] != nil
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("desk", make: SpriteLibrary.desk),
                x: cell.x + 3, y: cell.y + 13,
                kind: .desk, animation: .still, phase: 0
            ))
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("monitor", make: SpriteLibrary.monitor),
                x: cell.x + 10, y: cell.y + 7,
                kind: .monitor,
                animation: occupied ? .glow : .still,
                phase: occupied ? index % 2 : 0,
                // The monitor stands on the desk, in front of whoever is
                // sitting behind it: nudge it past the desk's own baseline.
                zIndex: cell.y + SceneComposer.Layout.cellHeight - 6
            ))
        }

        // 6. A note on the desk of anyone who is out today.
        for (index, occupant) in OfficeBehaviors.seating(for: input) where seatedIDs[index] == nil {
            guard occupant.isAway || input.ambience.isWeekend else { continue }
            guard occupant.isAway else { continue }
            let cell = SceneComposer.cellOrigin(tier: tier, index: index)
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("fx.note", make: OfficeFXSprites.stickyNote),
                x: cell.x + 20, y: cell.y + 6,
                kind: .prop, animation: .toggle(period: 5), phase: index % 3
            ))
        }

        // 6b. What the company is under, one prop per signal. The founder's
        //     desk carries the money (a pizza box for crunch, an envelope
        //     pile for a short runway); the coffee machine carries debt;
        //     a coder's desk carries the bugs; a leaver's desk carries the
        //     flat box; the door carries the offer.
        let pressure = input.pressure
        let founderCell = SceneComposer.cellOrigin(tier: tier, index: tier.deskCapacity)
        if pressure.crunch {
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("fx.pizza", make: OfficeFXSprites.pizzaBox),
                x: founderCell.x + 24, y: founderCell.y + 9,
                kind: .prop, animation: .still, phase: 0,
                zIndex: founderCell.y + SceneComposer.Layout.cellHeight - 5
            ))
        }
        if pressure.runwayIsShort {
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("fx.envelopes", make: OfficeFXSprites.envelopePile),
                x: founderCell.x + 1, y: founderCell.y + 8,
                kind: .prop, animation: .still, phase: 0,
                zIndex: founderCell.y + SceneComposer.Layout.cellHeight - 5
            ))
        }
        if pressure.inDebt {
            // "Out of order": the note goes on the coffee machine, or the
            // founder's monitor where the tier has no counter of its own.
            let spot = OfficeWaypoints.coffee(for: tier).kitchenette.map { (x: $0.x + 2, y: $0.y - 2) }
                ?? (x: founderCell.x + 12, y: founderCell.y + 2)
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("fx.note", make: OfficeFXSprites.stickyNote),
                x: spot.x, y: spot.y,
                kind: .prop, animation: .toggle(period: 5), phase: 1,
                zIndex: spot.y + 20
            ))
        }
        if pressure.bugLoad > 0 {
            // More coders get a bug over the desk the worse the build is:
            // one in three at load 1, two in three at 2, everyone at 3.
            for (index, occupant) in OfficeBehaviors.seating(for: input)
            where occupant.status == .coding && index % 3 < pressure.bugLoad {
                let cell = SceneComposer.cellOrigin(tier: tier, index: index)
                scene.append(PlacedSprite(
                    sprite: SpriteCache.shared("bubble.testing") { SpriteLibrary.statusBubble(.testing) },
                    x: cell.x + 16, y: cell.y - 9,
                    kind: .prop, animation: .toggle(period: 3), phase: index % 2,
                    zIndex: cell.y + SceneComposer.Layout.cellHeight + 40
                ))
            }
        }
        if !pressure.departing.isEmpty {
            for (index, occupant) in OfficeBehaviors.seating(for: input)
            where pressure.departing.contains(occupant.id) {
                let cell = SceneComposer.cellOrigin(tier: tier, index: index)
                scene.append(PlacedSprite(
                    sprite: SpriteCache.shared("fx.flatbox", make: OfficeFXSprites.flatBox),
                    x: cell.x + 4, y: cell.y + 23,
                    kind: .prop, animation: .still, phase: 0,
                    zIndex: cell.y + SceneComposer.Layout.cellHeight - 8
                ))
            }
        }
        if pressure.pendingOffer {
            // A courier at the door, envelope out, until the offer is
            // answered. Same door the hires walk in through.
            let corridor = OfficeWaypoints.corridorY(for: tier)
            let door: (x: Int, y: Int) = tier == .garage
                ? (size.width - 20, l.wallHeight + 14)
                : (10, Int(corridor))
            let courierSprite = SpriteCache.shared("fx.courier") {
                SpriteLibrary.person(appearance: CharacterAppearance(seed: 0xC0_FFEE), isFounder: false)
            }
            let feetY = door.y + 4
            scene.append(PlacedSprite(
                sprite: courierSprite,
                x: door.x - courierSprite.width / 2, y: feetY - courierSprite.height,
                kind: .prop, animation: .toggle(period: 4), phase: 0,
                zIndex: feetY
            ))
            scene.append(PlacedSprite(
                sprite: SpriteCache.shared("fx.envelope", make: OfficeFXSprites.envelope),
                x: door.x + courierSprite.width / 2 - 3, y: feetY - courierSprite.height + 8,
                kind: .prop, animation: .toggle(period: 2), phase: 0,
                zIndex: feetY + 1
            ))
        }

        // 7. Amenity furniture (people are placed by the director, not here).
        scene += SceneComposer.amenityZones(
            for: tier,
            shown: shownAmenities,
            size: size, founderY: founderY, onBreak: nil
        )

        // 8. The people, and what is over their heads.
        for plan in actors {
            guard let occupant = occupant(plan.id, in: input) else { continue }
            let state = actorState(
                plan: plan, occupant: occupant, input: input,
                celebration: celebration, timing: timing, dayTime: dayT, t: t
            )
            guard !state.hidden else { continue }
            let sprite = personSprite(for: occupant, state: state)
            let origin = spriteOrigin(state: state, sprite: sprite, plan: plan, input: input)
            let baseline = origin.y + sprite.height
            let rhythm = ActorRhythm(id: plan.id)

            scene.append(PlacedSprite(
                sprite: sprite,
                x: origin.x, y: origin.y,
                kind: .person,
                animation: animation(for: state, occupant: occupant, rhythm: rhythm, tempo: tempo),
                // A walk always starts its cycle on a contact pose, so every
                // corner of an L-route lands on a planted foot: that plant
                // *is* the turnaround. A cheer starts on its crouch for the
                // same reason — and because a room that jumps in unison is
                // the whole point of a launch. Everything else desyncs from
                // its neighbours on the walker's own seeded phase.
                phase: state.pose == .walk || state.pose == .cheer ? 0 : rhythm.idlePhase,
                start: state.animationStart,
                motion: state.motion.map { offset($0, dx: -Double(sprite.width) / 2, dy: -Double(sprite.height)) },
                zIndex: baseline,
                opacity: state.opacity,
                flipX: state.facing.flipsX
            ))

            // A leaver carries their desk out with them.
            if state.pose == .carryBox {
                let box = SpriteCache.shared("fx.box", make: OfficeFXSprites.cardboardBox)
                scene.append(PlacedSprite(
                    sprite: box,
                    x: origin.x + (sprite.width - box.width) / 2,
                    y: origin.y + 9,
                    kind: .prop,
                    animation: boxBob(state: state, rhythm: rhythm, tempo: tempo), phase: 0,
                    start: state.animationStart,
                    motion: state.motion.map {
                        offset($0, dx: -Double(box.width) / 2, dy: -Double(sprite.height) + 9)
                    },
                    zIndex: baseline + 1,
                    opacity: state.opacity
                ))
            }

            if let bubble = state.bubble {
                scene.append(bubblePlacement(
                    bubble, over: origin, sprite: sprite, motion: state.motion,
                    baseline: baseline, start: state.bubbleStart, opacity: state.opacity,
                    sceneWidth: size.width
                ))
            }
        }

        // 9. Celebration effects on top of everybody.
        if let celebration {
            scene += effects(
                for: celebration, input: input, size: size,
                founderY: founderY, actors: actors, at: t
            )
        }

        // 10. The hour's colour wash, over the lot.
        scene += OfficeFX.lighting(
            sceneWidth: size.width, sceneHeight: size.height,
            wallHeight: l.wallHeight, time: ambience.timeOfDay
        )

        // Painter's algorithm, stable so equal depths keep authored order.
        return scene.enumerated()
            .sorted { ($0.element.zIndex, $0.offset) < ($1.element.zIndex, $1.offset) }
            .map(\.element)
    }

    // MARK: - Actor state

    /// Everything the director needs to draw one person this second.
    struct DrawState {
        var position: ScenePoint
        var pose: ActorPose
        var facing: Facing
        var bubble: ActorBubble?
        var bubbleStart: TimeInterval
        var motion: Motion?
        var animationStart: TimeInterval
        var opacity: Double
        var hidden: Bool
        var waypointID: String?
        /// True when the person is in their chair, drawn at the seat origin.
        var seated: Bool
    }

    private static func actorState(
        plan: ActorPlan,
        occupant: Occupant,
        input: OfficeSceneInput,
        celebration: ActiveCelebration?,
        timing: OfficeSceneTiming,
        dayTime dayT: TimeInterval,
        t: TimeInterval
    ) -> DrawState {
        // A celebration can take a person off their plan entirely.
        if let celebration, let override = celebrationState(
            celebration, for: plan, occupant: occupant, input: input, t: t
        ) {
            return override
        }

        let segment = plan.segment(at: dayT)
        let state = plan.state(at: dayT)
        let seated = state.waypointID == "desk"
            && (segment.pose == .desk || segment.pose == .slump || segment.pose == .seatedSlump)
        let leg = segment.track.leg(at: dayT)

        var pose = state.pose
        // The room's cheer is anchored to the celebration rather than to
        // whatever each person's plan was doing, so a launch crouches and
        // jumps as one — the unison is the point of a launch.
        var animationStart = leg.start
        if let celebration, celebration.kind.isCheerable, t - celebration.start < OfficeFX.cheerDuration {
            pose = .cheer
            animationStart = celebration.start
        }

        return DrawState(
            position: state.position,
            pose: pose,
            facing: state.facing,
            bubble: bubble(for: occupant, state: state, timing: timing, plan: plan, t: t, celebration: celebration),
            bubbleStart: TimeInterval(AnimationClock.secondBucket(at: t)),
            motion: segment.track.isMoving(at: dayT) ? leg : nil,
            animationStart: animationStart,
            opacity: 1,
            hidden: false,
            waypointID: state.waypointID,
            seated: seated
        )
    }

    /// Where the sprite's top-left corner goes: at the seat for desk work,
    /// centred on the feet anchor for everything else.
    private static func spriteOrigin(
        state: DrawState, sprite: PixelSprite, plan: ActorPlan, input: OfficeSceneInput
    ) -> (x: Int, y: Int) {
        if state.seated {
            return SceneComposer.seatOrigin(tier: input.tier, index: plan.seatIndex)
        }
        let point = state.position.rounded
        return (point.x - sprite.width / 2, point.y - sprite.height)
    }

    private static func personSprite(for occupant: Occupant, state: DrawState) -> PixelSprite {
        let pose: SpriteLibrary.PersonPose
        switch state.pose {
        case .desk:
            pose = .seated
        case .walk:
            switch state.facing {
            case .left: pose = .walkLeft
            case .right: pose = .walkRight
            case .forward: pose = .walkDown
            }
        default:
            pose = state.pose.personPose
        }
        return SpriteCache.person(
            appearance: occupant.appearance, pose: pose,
            isFounder: occupant.isFounder, role: occupant.role
        )
    }

    /// The celebration jump, as a timing chart rather than a frame rate.
    ///
    /// Fourteen steps at twelve frames a second — a shade over a second a
    /// cycle — across the four authored cheer frames: planted (0), leaving
    /// the floor (1), crouched (2), apex (3).
    ///
    /// Spacing is where the weight lives. Two steps of crouch to anticipate,
    /// one to push off, one on the way up, three held at the apex (the eye
    /// rests at the top of a jump, not at the bottom — this is the slow-in
    /// that makes it feel like a jump rather than a bounce), one on the way
    /// down, a landing, a single-step recoil into the crouch, then four to
    /// stand back up. Played at an even rate the same four frames read as a
    /// sprite being jiggled.
    static let cheerChart = [2, 2, 0, 1, 3, 3, 3, 1, 0, 2, 0, 0, 0, 0]

    private static func animation(
        for state: DrawState, occupant: Occupant, rhythm: ActorRhythm, tempo: OfficeTempo
    ) -> SpriteAnimation {
        switch state.pose {
        case .desk:
            // Idle hands are slower hands, whatever the room around them is
            // doing. The chart itself carries this person's own blink and
            // their own held beat, so a wall of desks is no longer one
            // keyboard being played by twenty-five identical hands.
            let rate = occupant.status == .idle
                ? tempo.typingStepsPerSecond * 0.55
                : tempo.typingStepsPerSecond
            return .sequence(frames: rhythm.typingChart, fps: rate, loop: true)
        case .walk:
            guard let leg = state.motion else { return .toggle(period: 4) }
            let cadence = WalkCycle.cadence(
                for: leg, facing: state.facing,
                strideScale: rhythm.strideScale, tempoScale: tempo.walkScale
            )
            return .sequence(frames: cadence.frames, fps: cadence.fps, loop: true)
        case .cheer:
            return .sequence(frames: cheerChart, fps: 12, loop: true)
        case .chat, .coffee:
            return .toggle(period: rhythm.idlePeriod(base: 3 + tempo.breathBias))
        case .slump, .seatedSlump:
            // A defeated breath is a long one, and it does not speed up
            // because the rest of the floor is sprinting.
            return .toggle(period: rhythm.idlePeriod(base: 6))
        case .stand, .carryBox:
            return .toggle(period: rhythm.idlePeriod(base: 5 + tempo.breathBias))
        }
    }

    /// The bob of a box being carried out of the building.
    ///
    /// One lift per step, taken from the leg the carrier is actually walking
    /// rather than from a fixed rate, so the load moves with the gait; a box
    /// standing still does not bounce.
    private static func boxBob(
        state: DrawState, rhythm: ActorRhythm, tempo: OfficeTempo
    ) -> SpriteAnimation {
        guard let leg = state.motion else { return .still }
        let step = WalkCycle.sideCycleLength / 2 * max(0.5, rhythm.strideScale)
        let rate = WalkCycle.fps(
            speed: WalkCycle.groundSpeed(of: leg), frames: 2, cycleLength: step
        )
        // Clamped like the walk itself: past the renderer's own 12 fps a
        // faster bob only aliases.
        return .sequence(
            frames: [0, 1],
            fps: min(WalkCycle.maximumFPS, rate * tempo.walkScale),
            loop: true
        )
    }

    private static func offset(_ motion: Motion, dx: Double, dy: Double) -> Motion {
        Motion(
            from: ScenePoint(x: motion.from.x + dx, y: motion.from.y + dy),
            to: ScenePoint(x: motion.to.x + dx, y: motion.to.y + dy),
            start: motion.start, duration: motion.duration, easing: motion.easing
        )
    }

    // MARK: - Bubbles

    /// What floats over a head this second.
    ///
    /// Priority: a tap the player just made, then the celebration, then the
    /// mood cloud, then the segment's own bubble, then the transient work
    /// status. Status bubbles are no longer permanent — they appear for
    /// three seconds when the status changes and again on a slow pulse, so
    /// a campus is not a wall of twenty-five identical icons.
    private static func bubble(
        for occupant: Occupant,
        state: ActorState,
        timing: OfficeSceneTiming,
        plan: ActorPlan,
        t: TimeInterval,
        celebration: ActiveCelebration?
    ) -> ActorBubble? {
        if let tap = timing.tap, tap.id == occupant.id, t - tap.at < nameTagDuration {
            return .nameTag(name: occupant.name ?? "Team", line: occupant.speech)
        }
        if let celebration, case .researchComplete = celebration.kind,
           occupant.status == .researching, t - celebration.start < OfficeFX.duration(of: celebration.kind) {
            return .idea
        }
        if let bubble = state.bubble { return bubble }
        if occupant.mood == .low { return .gloom }
        guard occupant.status != .idle else { return nil }

        if let changed = timing.statusChanges[occupant.id], t - changed < statusBubbleDuration, t >= changed {
            return .status(occupant.status)
        }
        // A slow, desynchronized reminder of what everyone is working on.
        let phase = TimeInterval(abs(plan.seatIndex * 7) % Int(statusPulsePeriod))
        let cycle = (t + phase).truncatingRemainder(dividingBy: statusPulsePeriod)
        return cycle < statusBubbleDuration ? .status(occupant.status) : nil
    }

    private static func bubblePlacement(
        _ bubble: ActorBubble,
        over origin: (x: Int, y: Int),
        sprite: PixelSprite,
        motion: Motion?,
        baseline: Int,
        start: TimeInterval,
        opacity: Double,
        sceneWidth: Int
    ) -> PlacedSprite {
        let art: PixelSprite
        let animation: SpriteAnimation
        switch bubble {
        case .status(let status):
            art = SpriteCache.shared("bubble.\(status.rawValue)") { SpriteLibrary.statusBubble(status) }
            animation = .still
        case .chatter:
            art = SpriteCache.shared("fx.chatter", make: OfficeFXSprites.chatterBubble)
            animation = .sequence(frames: [0, 1, 2], fps: 2, loop: true)
        case .gloom:
            art = SpriteCache.shared("fx.gloom", make: OfficeFXSprites.gloomCloud)
            animation = .sequence(frames: [0, 1], fps: 3, loop: true)
        case .idea:
            art = SpriteCache.shared("fx.idea", make: OfficeFXSprites.ideaBubble)
            animation = .sequence(frames: [0, 1], fps: 3, loop: true)
        case .mug:
            art = SpriteCache.shared("fx.mug", make: OfficeFXSprites.mugBubble)
            animation = .toggle(period: 3)
        case .nameTag(let name, let line):
            // Two passes: measure the card, work out how far it has to be
            // shoved back inside the room, then rebuild it with the tail
            // moved to match so it still points at the right head.
            let probe = OfficeFXSprites.nameTag(name: name, line: line)
            let wanted = origin.x + sprite.width / 2 - probe.width / 2
            let clamped = min(max(0, wanted), max(0, sceneWidth - probe.width))
            let head = Double(origin.x + sprite.width / 2 - clamped - 2)
            art = OfficeFXSprites.nameTag(
                name: name, line: line,
                tailX: min(max(0.02, head / Double(probe.width)), 0.9)
            )
            animation = .still
        }
        var dx = Double(sprite.width) / 2 - Double(art.width) / 2
        if case .nameTag = bubble {} else { dx += 4 }
        let dy = -Double(art.height) + 2
        // Nothing floats off the side of the room.
        let x = min(max(0, origin.x + Int(dx)), max(0, sceneWidth - art.width))
        let shift = Double(x - origin.x)
        return PlacedSprite(
            sprite: art,
            x: x, y: origin.y + Int(dy),
            kind: .bubble,
            animation: animation,
            phase: 0,
            start: start,
            motion: motion.map { offset($0, dx: shift - Double(sprite.width) / 2, dy: dy - Double(sprite.height)) },
            zIndex: baseline + 1_000,
            opacity: opacity
        )
    }

    // MARK: - Celebrations

    /// A celebration that is currently on screen.
    struct ActiveCelebration {
        var kind: SceneCelebration
        var start: TimeInterval
    }

    /// Whether the flip-chart should be on the floor for this celebration —
    /// a ship sends the founder to it whatever the score.
    private static func isShipCelebration(_ celebration: ActiveCelebration?) -> Bool {
        guard case .shipped = celebration?.kind else { return false }
        return true
    }

    static func activeCelebration(
        input: OfficeSceneInput, timing: OfficeSceneTiming, at t: TimeInterval
    ) -> ActiveCelebration? {
        guard let celebration = input.celebration else { return nil }
        let start = timing.celebrationStart
        guard t >= start, t - start < OfficeFX.duration(of: celebration.kind) else { return nil }
        return ActiveCelebration(kind: celebration.kind, start: start)
    }

    /// The per-person override a celebration imposes, if any.
    private static func celebrationState(
        _ celebration: ActiveCelebration,
        for plan: ActorPlan,
        occupant: Occupant,
        input: OfficeSceneInput,
        t: TimeInterval
    ) -> DrawState? {
        let elapsed = t - celebration.start
        let tier = input.tier
        let corridor = OfficeWaypoints.corridorY(for: tier)
        let lanes = OfficeWaypoints.lanes(for: tier)
        let door = OfficeWaypoints.all(for: tier, amenities: input.amenities)
            .first { $0.kind == .door }?.anchor ?? ScenePoint(x: 10, y: corridor)
        let desk = OfficeWaypoints.deskAnchor(tier: tier, index: plan.seatIndex)

        switch celebration.kind {
        case .hired(let id) where id == occupant.id:
            // In through the door and straight to the new desk.
            let walk = Track.route(
                from: door, to: desk, corridorY: corridor, lanes: lanes,
                departingAt: celebration.start, speed: OfficeWaypoints.walkSpeed
            )
            guard t < walk.end else { return nil }
            let leg = walk.leg(at: t)
            let moving = walk.isMoving(at: t)
            return DrawState(
                position: walk.position(at: t),
                pose: moving ? .walk : .stand,
                facing: moving ? (leg.to.x < leg.from.x ? .left : .right) : .forward,
                bubble: nil, bubbleStart: t,
                motion: moving ? leg : nil,
                animationStart: leg.start,
                opacity: 1, hidden: false, waypointID: "door", seated: false
            )

        case .quit(let id) where id == occupant.id:
            // Stand, pick up the box, walk out, fade through the doorway.
            let standUntil = celebration.start + 2
            if t < standUntil {
                return DrawState(
                    position: desk, pose: .carryBox, facing: .forward,
                    bubble: nil, bubbleStart: celebration.start,
                    motion: nil, animationStart: celebration.start,
                    opacity: 1, hidden: false, waypointID: "desk", seated: false
                )
            }
            let walk = Track.route(
                from: desk, to: door, corridorY: corridor, lanes: lanes,
                departingAt: standUntil, speed: OfficeWaypoints.walkSpeed
            )
            let leg = walk.leg(at: t)
            let moving = walk.isMoving(at: t)
            // Linger a beat at the door, then fade through it.
            let fade = max(0, min(1, (walk.end + 2.5 - t) / 1.5))
            return DrawState(
                position: walk.position(at: t),
                pose: .carryBox,
                facing: moving ? (leg.to.x < leg.from.x ? .left : .right) : .forward,
                bubble: nil, bubbleStart: celebration.start,
                motion: moving ? leg : nil,
                animationStart: leg.start,
                opacity: fade, hidden: fade <= 0, waypointID: "door", seated: false
            )

        case .shipped where occupant.isFounder:
            // After the cheer the founder crosses to the flip-chart and
            // stands in front of it, the way founders do.
            guard elapsed >= OfficeFX.cheerDuration else { return nil }
            let easel = OfficeWaypoints.easelOrigin(for: tier)
            let target = ScenePoint(x: Double(easel.x + 8), y: corridor)
            let walk = Track.route(
                from: desk, to: target, corridorY: corridor, lanes: lanes,
                departingAt: celebration.start + OfficeFX.cheerDuration,
                speed: OfficeWaypoints.walkSpeed
            )
            let leg = walk.leg(at: t)
            let moving = walk.isMoving(at: t)
            return DrawState(
                position: walk.position(at: t),
                pose: moving ? .walk : .chat,
                facing: moving ? (leg.to.x < leg.from.x ? .left : .right) : .forward,
                bubble: moving ? nil : .chatter, bubbleStart: walk.end,
                motion: moving ? leg : nil,
                animationStart: leg.start,
                opacity: 1, hidden: false, waypointID: "whiteboard.0", seated: false
            )

        default:
            return nil
        }
    }

    private static func effects(
        for celebration: ActiveCelebration,
        input: OfficeSceneInput,
        size: SceneComposer.SceneSize,
        founderY: Int,
        actors: [ActorPlan],
        at t: TimeInterval
    ) -> [PlacedSprite] {
        switch celebration.kind {
        case .shipped:
            return OfficeFX.confetti(
                sceneWidth: size.width, sceneHeight: size.height,
                start: celebration.start, at: t
            )
        case .officeUpgraded:
            return OfficeFX.upgradeWipe(
                sceneWidth: size.width, sceneHeight: size.height, start: celebration.start
            )
        case .contractDelivered:
            let anchor = OfficeWaypoints.deskAnchor(tier: input.tier, index: input.tier.deskCapacity)
            return OfficeFX.coinSparkle(at: anchor, start: celebration.start)
        case .hired, .quit, .researchComplete:
            return []
        }
    }

    // MARK: - Lookup

    private static func occupant(_ id: UUID, in input: OfficeSceneInput) -> Occupant? {
        input.occupants.first { $0.id == id }
    }

    // MARK: - Memoization

    private struct SceneKey: Hashable {
        var input: OfficeSceneInput
        var timing: OfficeSceneTiming
        var second: Int
    }

    private struct PlanKey: Hashable {
        var input: OfficeSceneInput
        var day: Int
    }

    /// A tiny most-recent-wins cache. The office only ever asks about the
    /// second it is drawing and the one before it, so eight entries is
    /// generous; a miss is a recompose, never a wrong answer.
    private final class Memo<Key: Hashable, Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [(key: Key, value: Value)] = []
        private let limit: Int

        init(limit: Int) { self.limit = limit }

        func value(for key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            return entries.first { $0.key == key }?.value
        }

        func store(_ value: Value, for key: Key) {
            lock.lock()
            defer { lock.unlock() }
            entries.removeAll { $0.key == key }
            entries.insert((key, value), at: 0)
            if entries.count > limit { entries.removeLast(entries.count - limit) }
        }

        func removeAll() {
            lock.lock()
            entries.removeAll()
            lock.unlock()
        }
    }

    private static let sceneCache = Memo<SceneKey, [PlacedSprite]>(limit: 8)
    private static let planCache = Memo<PlanKey, [ActorPlan]>(limit: 4)

    /// Drops the memoized scenes and plans. Tests use it to measure a cold
    /// pipeline; the app never needs to.
    public static func resetCaches() {
        sceneCache.removeAll()
        planCache.removeAll()
    }
}

private extension SceneCelebration {
    /// Whether the whole room stops and cheers for this.
    var isCheerable: Bool {
        switch self {
        case .shipped, .contractDelivered: true
        case .hired, .quit, .officeUpgraded, .researchComplete: false
        }
    }
}
