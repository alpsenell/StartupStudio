#if os(macOS)
import CoreGraphics
import Foundation
import Testing
@testable import PixelKit

/// Frame strips for judging character animation by eye, which is the only
/// way it can honestly be judged.
///
/// Each strip is consecutive 12 fps frames laid left to right with the
/// ground line drawn through them, so foot planting, the bounce and the
/// weight of a jump can be read off the page. Files land in
/// `PIXELKIT_PREVIEW_DIR`.
@Suite("Animation strip PNGs", .serialized)
struct WalkStripPNGTests {
    let png = PreviewPNGTests()

    func appearance(_ seed: UInt64) -> CharacterAppearance { CharacterAppearance(seed: seed) }

    /// Lays `count` consecutive frames of a placement out left to right,
    /// each drawn at its own position relative to the first, so a walker
    /// crosses the strip exactly as far as it walks.
    func strip(
        sprite: PixelSprite,
        animation: SpriteAnimation,
        motion: Motion?,
        start: TimeInterval,
        frames count: Int,
        gap: Int = 4
    ) -> CGImage {
        let scale = PreviewPNGTests.scale
        let cell = sprite.width + gap
        let width = cell * count + gap
        let height = sprite.height + 6
        let context = png.makeCanvas(
            width: width * scale, height: height * scale, background: .init(r: 30, g: 30, b: 38)
        )
        // The floor the feet are supposed to be standing on. Without it a
        // strip cannot answer the only questions worth asking of one — is
        // this foot planted, and did that jump leave the ground.
        let ground = PixelSprite(
            frames: [[String(repeating: "g", count: width)]],
            palette: ["g": .init(r: 96, g: 92, b: 120)]
        )
        png.blit(
            ground, frame: 0, x: 0, y: 2 + sprite.height,
            into: context, canvasHeight: height * scale
        )
        let placement = PlacedSprite(
            sprite: sprite, x: 0, y: 2, kind: .person,
            animation: animation, phase: 0, start: start, motion: motion
        )
        for index in 0..<count {
            let t = start + TimeInterval(index) / AnimationClock.fps
            // The vertical offset is the only thing carried over from the
            // motion: the strip supplies its own horizontal spacing.
            let y = motion.map { Int($0.position(at: t).y - $0.from.y) } ?? 0
            png.blit(
                sprite, frame: placement.frameIndex(at: t),
                x: gap + index * cell, y: 2 + y,
                into: context, canvasHeight: height * scale
            )
        }
        return context.makeImage()!
    }

    @Test func walkStripAtEverySpeed() throws {
        let who = appearance(22)
        let sprite = SpriteLibrary.person(appearance: who, pose: .walkRight)
        // A long corridor leg (full speed) and a short sidestep (the same
        // whole second, a third of the ground): the cadences must differ.
        for (name, distance) in [("fast", 72.0), ("slow", 26.0)] {
            let leg = Motion.walk(
                from: ScenePoint(x: 0, y: 0), to: ScenePoint(x: distance, y: 0),
                start: 0, speed: OfficeWaypoints.walkSpeed
            )
            let cadence = WalkCycle.cadence(for: leg, facing: .right)
            try png.writePNG(
                strip(
                    sprite: sprite,
                    animation: .sequence(frames: cadence.frames, fps: cadence.fps, loop: true),
                    motion: leg, start: 0, frames: 16
                ),
                named: "anim_walk_\(name).png"
            )
        }
    }

    @Test func cheerStripShowsTheWholeJump() throws {
        let sprite = SpriteLibrary.person(appearance: appearance(17), pose: .cheer)
        try png.writePNG(
            strip(
                sprite: sprite,
                animation: .sequence(frames: OfficeDirector.cheerChart, fps: 12, loop: true),
                motion: nil, start: 0, frames: 12
            ),
            named: "anim_cheer.png"
        )
    }

    @Test func typingStripShowsOnePersonsOwnLoop() throws {
        let sprite = SpriteLibrary.person(appearance: appearance(9), pose: .seated)
        let rhythm = ActorRhythm(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!)
        try png.writePNG(
            strip(
                sprite: sprite,
                animation: .sequence(frames: rhythm.typingChart, fps: 8, loop: true),
                motion: nil, start: 0, frames: 16
            ),
            named: "anim_typing.png"
        )
    }
}
#endif
