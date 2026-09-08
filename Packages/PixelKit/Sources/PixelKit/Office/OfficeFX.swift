import Foundation

/// The one-off effects layered over the office: confetti, the upgrade wipe,
/// coin sparkles, weather on the windows, and the lighting wash for the
/// hour.
///
/// Everything here is a pure function of `(geometry, start time)` and comes
/// back as ordinary `PlacedSprite`s with motions, so effects animate at the
/// full 12 fps while the director still only rebuilds the list once a
/// second.
enum OfficeFX {
    /// How long each celebration owns the room.
    static func duration(of celebration: SceneCelebration) -> TimeInterval {
        switch celebration {
        case .shipped: 12
        case .hired: 10
        case .quit: 12
        case .officeUpgraded: 2
        case .researchComplete: 6
        case .contractDelivered: 3
        }
    }

    /// How long everyone stops what they are doing and cheers.
    static let cheerDuration: TimeInterval = 3

    // MARK: - Particles

    /// A fall of confetti across the whole room.
    ///
    /// Forty chips, staggered over the first second so it reads as a burst
    /// rather than a curtain, each accelerating downward (`.easeIn` *is*
    /// free-fall: p²) with a little sideways drift and a four-frame tumble.
    static func confetti(
        sceneWidth: Int, sceneHeight: Int, start: TimeInterval, at t: TimeInterval
    ) -> [PlacedSprite] {
        var rng = OfficeRandom(seed: 0x0C0F_FEE0 &+ UInt64(bitPattern: Int64(start.rounded())))
        var placements: [PlacedSprite] = []
        for index in 0..<40 {
            let launchX = Double(rng.int(2...(max(3, sceneWidth - 4))))
            let drift = Double(rng.int(-12...12))
            let delay = rng.unit() * 1.0
            let fall = 1.6 + rng.unit() * 1.0
            // A chip that has landed is gone — otherwise the floor keeps a
            // line of litter for the rest of the celebration.
            guard t < start + delay + fall else { continue }
            let sprite = SpriteCache.shared("fx.confetti.\(index % 5)") { OfficeFXSprites.confetti(variant: index) }
            let from = ScenePoint(x: launchX, y: Double(-4 - rng.int(0...10)))
            let to = ScenePoint(x: launchX + drift, y: Double(sceneHeight + 4 + rng.int(0...8)))
            placements.append(PlacedSprite(
                sprite: sprite,
                x: Int(from.x), y: Int(from.y),
                kind: .prop,
                animation: .sequence(frames: [0, 1, 2, 3], fps: 9, loop: true),
                phase: index % 4,
                start: start + delay,
                motion: Motion(from: from, to: to, start: start + delay, duration: fall, easing: .easeIn),
                zIndex: 90_000 + index,
                opacity: 1
            ))
        }
        return placements
    }

    /// The bright band that sweeps down the room on an office upgrade,
    /// leaving the new scene behind it.
    static func upgradeWipe(
        sceneWidth: Int, sceneHeight: Int, start: TimeInterval
    ) -> [PlacedSprite] {
        [PlacedSprite(
            sprite: SpriteCache.shared("fx.wipe.\(sceneWidth)") { OfficeFXSprites.wipeBand(width: sceneWidth) },
            x: 0, y: 0,
            kind: .prop,
            animation: .still,
            phase: 0,
            start: start,
            motion: Motion(
                from: ScenePoint(x: 0, y: -6),
                to: ScenePoint(x: 0, y: sceneHeight + 6),
                start: start, duration: 0.6, easing: .easeInOut
            ),
            zIndex: 99_000
        )]
    }

    /// A coin popping open over a desk when a contract lands.
    static func coinSparkle(at anchor: ScenePoint, start: TimeInterval) -> [PlacedSprite] {
        let sprite = SpriteCache.shared("fx.coin", make: OfficeFXSprites.coinSparkle)
        return [PlacedSprite(
            sprite: sprite,
            x: Int(anchor.x) - sprite.width / 2,
            y: Int(anchor.y) - 34,
            kind: .bubble,
            animation: .once(frames: [0, 1, 1, 1, 2, 2], fps: 4),
            phase: 0,
            start: start,
            motion: Motion(
                from: ScenePoint(x: anchor.x - Double(sprite.width / 2), y: anchor.y - 30),
                to: ScenePoint(x: anchor.x - Double(sprite.width / 2), y: anchor.y - 42),
                start: start, duration: 1.5, easing: .easeOut
            ),
            zIndex: 95_000
        )]
    }

    // MARK: - Ambience

    /// Rain or snow, drawn over the band of wall the windows sit in so it
    /// reads as weather seen *through* them rather than indoor precipitation.
    static func weather(
        _ weather: Weather, sceneWidth: Int, wallHeight: Int
    ) -> [PlacedSprite] {
        guard weather != .clear else { return [] }
        let height = max(4, wallHeight - 2)
        let sprite = SpriteCache.shared("fx.\(weather.rawValue).\(sceneWidth)x\(height)") {
            weather == .rain
                ? OfficeFXSprites.rainPane(width: sceneWidth, height: height)
                : OfficeFXSprites.snowPane(width: sceneWidth, height: height)
        }
        return [PlacedSprite(
            sprite: sprite,
            x: 0, y: 1,
            kind: .prop,
            animation: .sequence(
                frames: Array(0..<sprite.frameCount),
                fps: weather == .rain ? 12 : 4,
                loop: true
            ),
            phase: 0,
            zIndex: -50_000, // behind everything except the room itself
            opacity: weather == .rain ? 0.85 : 1
        )]
    }

    /// The wash of colour for the hour.
    ///
    /// Prefers WS-D's authored overlay; falls back to the runtime's own
    /// generated tint while that is still the transparent placeholder.
    static func lighting(
        sceneWidth: Int, sceneHeight: Int, wallHeight: Int, time: TimeOfDay
    ) -> [PlacedSprite] {
        let authored = SpriteCache.shared("overlay.\(sceneWidth)x\(sceneHeight).\(time.rawValue)") {
            SpriteLibrary.lightingOverlay(width: sceneWidth, height: sceneHeight, time: time)
        }
        let sprite: PixelSprite
        if authored.palette.isEmpty {
            guard let generated = OfficeFXSprites.lightingTint(
                width: sceneWidth, height: sceneHeight, time: time, wallHeight: wallHeight
            ) else { return [] }
            sprite = SpriteCache.shared("tint.\(sceneWidth)x\(sceneHeight).\(wallHeight).\(time.rawValue)") { generated }
        } else {
            sprite = authored
        }
        return [PlacedSprite(
            sprite: sprite, x: 0, y: 0, kind: .prop,
            animation: .still, phase: 0, zIndex: 80_000
        )]
    }

    // MARK: - Iteration 10 — M6 (the bug hunt)

    /// How long one lap of a bug's patrol takes, and how the lap is cut up.
    ///
    /// Whole seconds, deliberately: the director hands the view one list of
    /// placements a second, so a leg that changed halfway through a second
    /// would draw a stale motion until the next bucket. Legs that begin on
    /// second boundaries never can.
    static let bugLegSeconds: [TimeInterval] = [2, 1, 2, 1]
    static var bugLapSeconds: TimeInterval { bugLegSeconds.reduce(0, +) }

    /// The four corners of the floor strip a bug patrols, in front of the
    /// desk it belongs to: along the front, one step down, back along the
    /// front, one step up.
    ///
    /// The strip is *in front of* the desk rather than on the desktop, and
    /// that is the whole reason the hunt is playable: the desktop is under
    /// a monitor and behind whoever is sitting at it, and a bug you cannot
    /// see is a bug you cannot squash. It still reads as their desk — it is
    /// two pixels from the drawers.
    static func bugLoop(seat: Int, tier: OfficeTierStyle) -> [ScenePoint] {
        let cell = SceneComposer.cellOrigin(tier: tier, index: seat)
        let left = Double(cell.x + 9)
        let right = Double(cell.x + 22)
        let near = Double(cell.y + 18)
        let far = Double(cell.y + 20)
        return [
            ScenePoint(x: left, y: near),
            ScenePoint(x: right, y: near),
            ScenePoint(x: right, y: far),
            ScenePoint(x: left, y: far),
        ]
    }

    /// Where a bug is at scene time `t`, and which way it is facing: the
    /// leg of the lap it is on, as an absolute `Motion` so the 12 fps
    /// renderer interpolates it without the director recomposing.
    ///
    /// Pure in `(bug, tier, t)` — the same bug is in the same place every
    /// time the scene is evaluated, which is what lets the hit region and
    /// the drawing agree to the pixel.
    static func bugFrame(
        _ bug: OfficeBug, tier: OfficeTierStyle, at t: TimeInterval
    ) -> (motion: Motion, flipX: Bool, legIndex: Int) {
        let loop = bugLoop(seat: bug.seat, tier: tier)
        let lap = bugLapSeconds
        // Each bug starts a different distance round the lap, so two of
        // them on one desk never march in step.
        let offset = TimeInterval((bug.id &* 2) % Int(lap))
        let phase = (max(0, t) + offset).truncatingRemainder(dividingBy: lap)
        var cursor: TimeInterval = 0
        var index = 0
        for (leg, seconds) in bugLegSeconds.enumerated() {
            if phase < cursor + seconds {
                index = leg
                break
            }
            cursor += seconds
        }
        let legStart = max(0, t) - phase + cursor
        let from = loop[index]
        let to = loop[(index + 1) % loop.count]
        return (
            Motion(from: from, to: to, start: legStart, duration: bugLegSeconds[index]),
            // Legs 2 and 3 run right to left; the sprite is drawn facing
            // right, so those two are mirrored.
            index >= 2,
            index
        )
    }

    /// The bugs on the floor at scene time `t` — the live ones crawling,
    /// the squashed ones as a splat where they stopped.
    static func bugs(
        _ bugs: [OfficeBug], tier: OfficeTierStyle, at t: TimeInterval
    ) -> [PlacedSprite] {
        guard !bugs.isEmpty else { return [] }
        var placements: [PlacedSprite] = []
        for bug in bugs {
            let frame = bugFrame(bug, tier: tier, at: t)
            let anchor = frame.motion.position(at: t).rounded
            if bug.isSquashed {
                let splat = SpriteCache.shared("fx.bugsplat", make: OfficeFXSprites.bugSplat)
                placements.append(PlacedSprite(
                    sprite: splat,
                    x: anchor.x - 1, y: anchor.y + 1,
                    kind: .prop,
                    animation: .toggle(period: 2),
                    phase: 0,
                    zIndex: anchor.y + splat.height + 2_000
                ))
                continue
            }
            let sprite = SpriteCache.shared("fx.bug", make: OfficeFXSprites.bug)
            placements.append(PlacedSprite(
                sprite: sprite,
                x: anchor.x, y: anchor.y,
                kind: .prop,
                // The two walking frames on the long legs, the two standing
                // frames on the short ones: a bug that has turned a corner
                // stops and thinks about it.
                animation: frame.legIndex % 2 == 0
                    ? .sequence(frames: [0, 1], fps: 8, loop: true)
                    : .sequence(frames: [2, 3], fps: 3, loop: true),
                phase: bug.id % 2,
                start: frame.motion.start,
                motion: frame.motion,
                // Well clear of the furniture. A bug half behind a stack
                // of boxes is a bug the player will not find, and unlike
                // every other thing in this room it is gone in a few
                // seconds — so it is drawn over the room and under the
                // hour's colour wash.
                zIndex: anchor.y + sprite.height + 2_000,
                flipX: frame.flipX
            ))
        }
        return placements
    }

    /// A composed scene with the bugs merged into it at their own depth,
    /// rather than dropped on top of the lighting wash.
    ///
    /// `OfficeDirector.compose` returns its placements sorted back to
    /// front; this keeps that order and slots each bug in where its depth
    /// says it belongs, so a bug is drawn over the desk it is in front of
    /// and still under the evening light.
    static func merging(
        bugs: [OfficeBug], into scene: [PlacedSprite], tier: OfficeTierStyle, at t: TimeInterval
    ) -> [PlacedSprite] {
        let extra = Self.bugs(bugs, tier: tier, at: t)
        guard !extra.isEmpty else { return scene }
        var merged = scene
        for placement in extra {
            let index = merged.firstIndex { $0.zIndex > placement.zIndex } ?? merged.count
            merged.insert(placement, at: index)
        }
        return merged
    }
}

// MARK: - Iteration 10 — M6

/// One bug in the room, as the app knows it.
///
/// PixelKit knows where a bug is and what it looks like; the app knows
/// which build it belongs to and what a thumb on it means. The id is the
/// identity on both sides of that line — it is what a tap comes back as —
/// and it also seeds the bug's place in its lap, so two bugs on one desk
/// never march in step.
///
/// A squashed bug stays in the list for as long as the app leaves it there
/// (about half a second) and is drawn as the splat. Keeping the splat's
/// lifetime on the app's side is what lets PixelKit stay a pure function of
/// `(input, t)`: there is no "when was it squashed" for the scene to
/// remember.
public struct OfficeBug: Sendable, Equatable, Hashable, Identifiable {
    /// Stable for the life of this bug, and unique within the list.
    public var id: Int
    /// The desk cell it patrols, in `SceneComposer`'s indexing — the
    /// founder's own desk is `tier.deskCapacity`.
    public var seat: Int
    /// Drawn as a splat rather than a beetle, and no longer tappable.
    public var isSquashed: Bool

    public init(id: Int, seat: Int, isSquashed: Bool = false) {
        self.id = id
        self.seat = seat
        self.isSquashed = isSquashed
    }
}
