import CoreGraphics
import Foundation
import Testing
@testable import PixelKit

/// The office has to stay smooth on a campus of forty people while the
/// simulation is running at 4× and the HQ card rebuilds constantly. These
/// are the budgets that keep it there.
@Suite("Office performance", .serialized)
struct OfficePerfTests {
    /// A full campus: forty desks plus the founder, four amenities, the lot.
    func campus() -> OfficeSceneInput {
        func id(_ index: Int) -> UUID {
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
        }
        let moods: [MoodLevel] = [.okay, .great, .low]
        var people: [Occupant] = []
        for index in 0..<41 {
            let friends: [UUID] = index % 4 == 0 ? [id(index + 1)] : []
            people.append(Occupant(
                id: id(index),
                appearance: CharacterAppearance(seed: UInt64(index) &+ 900),
                status: WorkStatus.allCases[index % WorkStatus.allCases.count],
                isFounder: index == 0,
                mood: moods[index % moods.count],
                friendIDs: friends,
                name: "P\(index)"
            ))
        }
        return OfficeSceneInput(
            tier: .campus,
            occupants: people,
            amenities: [.gameRoom, .cafeteria, .gym, .shuttle]
        )
    }

    func canvas(for input: OfficeSceneInput) -> CGContext {
        let size = SceneComposer.sceneSize(for: input.tier)
        return CGContext(
            data: nil, width: size.width, height: size.height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    /// Composes and draws one frame the way `PixelSceneView` does.
    func drawFrame(_ input: OfficeSceneInput, into context: CGContext, at t: TimeInterval) {
        let height = context.height
        for placement in OfficeDirector.compose(input: input, at: t) {
            let point = placement.position(at: t)
            context.draw(
                placement.sprite.cgImage(frame: placement.frameIndex(at: t)),
                in: CGRect(
                    x: point.x,
                    y: height - point.y - placement.sprite.height,
                    width: placement.sprite.width,
                    height: placement.sprite.height
                )
            )
        }
    }

    @Test func fortyPeopleAtTwelveFpsStayWithinBudget() {
        let input = campus()
        let context = canvas(for: input)
        OfficeDirector.resetCaches()
        SpriteCache.removeAll()

        // Warm-up frame: first-ever rasterization of every sprite.
        drawFrame(input, into: context, at: 0)

        // Ten seconds of animation — 120 frames at 12 fps.
        let started = Date()
        for frame in 1...120 {
            drawFrame(input, into: context, at: AnimationClock.time(ofFrame: frame))
        }
        let elapsed = Date().timeIntervalSince(started)
        #expect(elapsed < 0.6, "120 campus frames took \(String(format: "%.3f", elapsed)) s")
    }

    @Test func repeatedFramesRasterizeNothing() {
        let input = campus()
        let context = canvas(for: input)
        OfficeDirector.resetCaches()
        SpriteCache.removeAll()

        // Warm up a whole second of the scene so every sprite and frame
        // index in it has been seen once.
        for frame in 0..<12 {
            drawFrame(input, into: context, at: AnimationClock.time(ofFrame: frame))
        }

        let rasterized = SpriteRenderStats.rasterizations {
            for _ in 0..<10 {
                for frame in 0..<12 {
                    drawFrame(input, into: context, at: AnimationClock.time(ofFrame: frame))
                }
            }
        }
        #expect(rasterized == 0, "\(rasterized) frames re-rasterized after warm-up")
    }

    @Test func theSameSecondIsComposedOnlyOnce() {
        let input = campus()
        OfficeDirector.resetCaches()
        let first = OfficeDirector.compose(input: input, at: 4)

        // Every sample inside the same second must be the identical list —
        // that is what makes the memo exact rather than a rounding error.
        for fraction in stride(from: 0.0, to: 1.0, by: 1.0 / 12.0) {
            #expect(OfficeDirector.compose(input: input, at: 4 + fraction) == first)
        }
    }

    @Test func peopleAreSharedNotRebuilt() {
        SpriteCache.removeAll()
        let appearance = CharacterAppearance(seed: 12)
        let a = SpriteCache.person(appearance: appearance, pose: .seated)
        let cold = SpriteRenderStats.rasterizations { _ = a.cgImage(frame: 0) }
        #expect(cold == 1, "the first draw rasterizes")

        let warm = SpriteRenderStats.rasterizations {
            for _ in 0..<50 {
                let again = SpriteCache.person(appearance: appearance, pose: .seated)
                _ = again.cgImage(frame: 0)
            }
        }
        #expect(warm == 0, "the cache hands back the same instance, frame cache and all")
    }

    @Test func aCampusSceneIsNotWastefullyLarge() {
        // The renderer culls off-screen sprites, but the list itself should
        // stay proportional to what is in the room: a room, its props, one
        // desk and monitor per seat, one sprite per person, and a handful of
        // bubbles.
        let input = campus()
        let placements = OfficeDirector.compose(input: input, at: 7)
        let seats = OfficeTierStyle.campus.deskCapacity + 1
        #expect(placements.filter { $0.kind == .desk }.count == seats)
        #expect(placements.filter { $0.kind == .person }.count == 41)
        #expect(placements.count < seats * 4, "\(placements.count) placements for \(seats) desks")
    }
}
