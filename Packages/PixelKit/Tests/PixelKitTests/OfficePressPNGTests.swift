#if os(macOS)
import CoreGraphics
import Foundation
import Testing
@testable import PixelKit

/// The press highlight: one PNG per pressed kind in two tiers so the
/// outline and the lift can be reviewed by eye, plus the rules the
/// pictures rely on — one outline per pressed sprite, an outline that hugs
/// its silhouette in a master colour, and a bob that Reduce Motion drops.
@Suite("Press PNGs", .serialized)
struct OfficePressPNGTests {
    let png = PreviewPNGTests()
    let sheet = OfficeFrameSheetPNGTests()

    private func input(
        tier: OfficeTierStyle, headcount: Int, pressed: OfficeHitRegion.Kind?
    ) -> OfficeSceneInput {
        var input = OfficeSceneInput(
            tier: tier,
            occupants: sheet.occupants(headcount, seed: 740, moods: [.okay, .great, .low]),
            amenities: [.gameRoom, .cafeteria]
        )
        input.pressed = pressed
        return input
    }

    @Test(arguments: [OfficeTierStyle.garage, .studio])
    func eachPressedKindHasAPicture(tier: OfficeTierStyle) throws {
        let headcount = tier == .garage ? 4 : 12
        let people = input(tier: tier, headcount: headcount, pressed: nil).occupants
        let kinds: [(name: String, kind: OfficeHitRegion.Kind)] = [
            ("person", .person(people[1].id)),
            ("founder", .person(people[0].id)),
            ("coffee", .coffeeMachine),
            ("whiteboard", .whiteboard),
            ("door", .door),
            ("desk", .founderDesk),
        ]
        for (name, kind) in kinds {
            // Three seconds in, with the press anchored at zero: the bob
            // has settled and the figure sits a pixel up inside its outline.
            try png.writePNG(
                sheet.renderFrame(
                    input: input(tier: tier, headcount: headcount, pressed: kind),
                    timing: OfficeSceneTiming(pressStart: 0), t: 3
                ),
                named: "press_\(tier.rawValue)_\(name).png"
            )
        }
    }

    @Test func aPressAddsExactlyOneOutlinePerPressedSprite() {
        let plain = input(tier: .studio, headcount: 8, pressed: nil)
        let base = OfficeDirector.compose(input: plain, timing: .none, at: 3)
        #expect(!base.contains { $0.kind == .highlight }, "nothing pressed, nothing outlined")

        let person = OfficeDirector.compose(
            input: input(tier: .studio, headcount: 8, pressed: .person(plain.occupants[2].id)),
            timing: .none, at: 3
        )
        #expect(person.filter { $0.kind == .highlight }.count == 1)
        #expect(person.count == base.count + 1)

        let desk = OfficeDirector.compose(
            input: input(tier: .studio, headcount: 8, pressed: .founderDesk), timing: .none, at: 3
        )
        #expect(desk.filter { $0.kind == .highlight }.count == 2, "the desk and its monitor")

        for kind in [OfficeHitRegion.Kind.coffeeMachine, .whiteboard, .door] {
            for tier in OfficeTierStyle.allCases {
                let scene = OfficeDirector.compose(
                    input: input(tier: tier, headcount: 4, pressed: kind), timing: .none, at: 3
                )
                #expect(scene.filter { $0.kind == .highlight }.count == 1, "\(tier) \(kind)")
            }
        }
    }

    @Test func theOutlineHugsTheSpriteInAMasterColour() {
        for sprite in [OfficeFXSprites.kitchenette(), SpriteLibrary.person(appearance: CharacterAppearance(seed: 9), pose: .walkLeft)] {
            let outline = OfficeFXSprites.outline(of: sprite)
            #expect(outline.width == sprite.width + 2 && outline.height == sprite.height + 2)
            #expect(outline.frameCount == sprite.frameCount)
            for frame in 0..<sprite.frameCount {
                let source = sprite.frames[frame].map(Array.init)
                let traced = outline.frames[frame].map(Array.init)
                func opaque(_ x: Int, _ y: Int) -> Bool {
                    x >= 0 && y >= 0 && x < sprite.width && y < sprite.height && source[y][x] != " "
                }
                var lit = 0
                for y in 0..<outline.height {
                    for x in 0..<outline.width where traced[y][x] != " " {
                        lit += 1
                        let sx = x - 1
                        let sy = y - 1
                        #expect(!opaque(sx, sy), "the outline never paints over the sprite")
                        #expect(
                            opaque(sx - 1, sy) || opaque(sx + 1, sy) || opaque(sx, sy - 1) || opaque(sx, sy + 1),
                            "every outline pixel touches the sprite"
                        )
                    }
                }
                #expect(lit > 0)
            }
        }
        #expect(Palettes.isMaster(OfficeFXSprites.highlight), "the highlight is a master colour")
    }

    @Test func thePressedSpriteBobsUnlessMotionIsReduced() {
        var scene = input(tier: .loft, headcount: 5, pressed: .whiteboard)
        let timing = OfficeSceneTiming(pressStart: 10)
        let board = SceneComposer.propSprite(.whiteboard)
        let placements = OfficeDirector.compose(input: scene, timing: timing, at: 10)
        let pressed = try! #require(placements.first { $0.sprite == board })
        let outline = try! #require(placements.first { $0.kind == .highlight })
        let rest = pressed.y
        #expect(pressed.position(at: 9.9).y == rest, "still before the finger lands")
        #expect(pressed.position(at: 10.12).y == rest - 2, "hops two pixels up")
        #expect(pressed.position(at: 11).y == rest - 1, "and settles one pixel up")
        #expect(outline.position(at: 11).y == rest - 2, "the outline follows, a pixel above")
        #expect(outline.position(at: 11).x == pressed.position(at: 11).x - 1, "and a pixel left")
        #expect(outline.zIndex == pressed.zIndex + 1, "just in front of what it outlines")

        scene.reduceMotion = true
        let still = OfficeDirector.compose(input: scene, timing: timing, at: 10)
        let board2 = try! #require(still.first { $0.sprite == board })
        #expect(still.contains { $0.kind == .highlight }, "the outline stays")
        #expect(board2.motion == nil, "nothing lifts")
        #expect(board2.position(at: 11).y == rest)
    }

    @Test func aWalkerKeepsWalkingWhenPressed() {
        // Somebody mid-walk gets the outline and keeps their route: the
        // outline shares the walk, one pixel up and left.
        let plain = input(tier: .studio, headcount: 12, pressed: nil)
        for t in stride(from: 0.0, to: 240.0, by: 1.0) {
            let walking = OfficeDirector.compose(input: plain, timing: .none, at: t)
                .filter { $0.kind == .person && $0.motion != nil }
            guard let walker = walking.first else { continue }
            let people = OfficeDirector.actorFrames(input: plain, timing: .none, at: t)
            guard let id = people.first(where: { $0.x == walker.x && $0.y == walker.y })?.id else { continue }
            var scene = plain
            scene.pressed = .person(id)
            let pressed = OfficeDirector.compose(input: scene, timing: OfficeSceneTiming(pressStart: t), at: t)
            let figure = try! #require(pressed.first { $0.kind == .person && $0.motion == walker.motion })
            let outline = try! #require(pressed.first { $0.kind == .highlight })
            let later = t + 0.5
            #expect(figure.position(at: later) == walker.position(at: later), "the walk is untouched")
            #expect(outline.position(at: later).x == figure.position(at: later).x - 1)
            #expect(outline.position(at: later).y == figure.position(at: later).y - 1)
            #expect(outline.flipX == figure.flipX && outline.animation == figure.animation)
            return
        }
        Issue.record("nobody walked in the first office day")
    }
}
#endif
