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
}
