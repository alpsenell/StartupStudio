import Foundation

/// Instant life activities as PixelKit sees them. Raw values mirror the
/// engine's `InstantActivity` (plus `shopping`, which the app routes to
/// the shop sheet); the app maps with `init(rawValue:)` and a defensive
/// fallback.
public enum ActivitySceneStyle: String, Sendable, CaseIterable {
    case gymSession, walk, cinema, restaurant, shopping
}

/// Sprites specific to the activity mini-scenes.
enum ActivitySpriteLibrary {
    /// Walking in place, 14×22 on the shared person canvas: torso rows are
    /// `standingA`'s (head fixed at rows 1–6 so hair/hoodie overlays drop
    /// on), legs alternate — right foot lifted / left foot lifted. Motion
    /// is sold by the scrolling background, not by moving the sprite.
    static func walkingPerson(appearance: CharacterAppearance, isFounder: Bool) -> PixelSprite {
        var stepA = HomePersonArt.standingA
        stepA[18] = "   OPPOOPPO   "
        stepA[19] = "   OPPO OKKKO "
        stepA[20] = "  OKKKO       "
        stepA[21] = "  OOOO        "

        var stepB = HomePersonArt.headBob(HomePersonArt.standingA)
        stepB[18] = "   OPPOOPPO   "
        stepB[19] = " OKKKO OPPO   "
        stepB[20] = "       OKKKO  "
        stepB[21] = "        OOOO  "

        let hair = PersonArt.hairOverlays[appearance.hairStyle % PersonArt.hairOverlays.count]
        let frames = [(stepA, 0), (stepB, 1)].map { frame, hairOffset in
            var grid = PixelGrid.overlay(base: frame, top: hair, offsetY: hairOffset)
            if isFounder {
                grid = PixelGrid.overlay(base: grid, top: PersonArt.hoodieOverlay)
            }
            return grid
        }
        return PixelSprite(frames: frames, palette: SpriteLibrary.personPalette(appearance))
    }

    /// A park tree that shuffles two pixels between frames — placed beside
    /// the walker, it sells the walk as forward motion.
    static func passingTree() -> PixelSprite {
        let tree = [
            "   OOOO     ",
            "  OFFFFO    ",
            " OFFGFFFO   ",
            " OFGFFFGO   ",
            "  OFFFFO    ",
            "    OT      ",
            "    OT      ",
            "   OTTO     ",
        ]
        let shifted = tree.map { row -> String in
            let dropped = String(row.dropFirst(2))
            return dropped + "  "
        }
        return PixelSprite(frames: [tree, shifted], palette: [
            "O": Palettes.outline,
            "F": RGBA(r: 96, g: 148, b: 86),
            "G": RGBA(r: 122, g: 174, b: 104),
            "T": RGBA(r: 118, g: 86, b: 58),
        ])
    }

    /// The cinema screen, 44×20, glowing between two flickers.
    static func cinemaScreen() -> PixelSprite {
        func frame(seed: Int) -> [String] {
            (0..<20).map { y in
                String((0..<44).map { x -> Character in
                    if x == 0 || x == 43 || y == 0 || y == 19 { return "O" }
                    if x == 1 || x == 42 || y == 1 || y == 18 { return "F" }
                    return (x * 5 + y * 11 + seed) % 23 == 0 ? "L" : "S"
                })
            }
        }
        return PixelSprite(frames: [frame(seed: 0), frame(seed: 7)], palette: [
            "O": Palettes.outline,
            "F": RGBA(r: 58, g: 54, b: 72),
            "S": RGBA(r: 134, g: 150, b: 210),
            "L": RGBA(r: 224, g: 232, b: 255),
        ])
    }

    /// A shop shelf stacked with colorful goods, 22×16, two frames (a
    /// price tag swings).
    static func shopShelf() -> PixelSprite {
        let a = [
            "OOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OW1W2WW3W1WW2W3WW1W2WO",
            "OW1W2WW3W1WW2W3WW1W2WO",
            "OOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OW3W1WW2W3WW1W2WW3W1WO",
            "OW3W1WW2W3WW1W2WW3W1WO",
            "OOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWO",
            "OW2W3WW1W2WW3W1WW2W3WO",
            "OW2W3WW1W2WW3W1WW2W3WO",
            "OOOOOOOOOOOOOOOOOOOOOO",
            "OTWWWWWWWWWWWWWWWWWWWO",
            "OtWWWWWWWWWWWWWWWWWWWO",
            "OOOOOOOOOOOOOOOOOOOOOO",
        ]
        var b = a
        b[13] = "OWWWWWWWWWWWWWWWWWWWWO"
        b[14] = "OTtWWWWWWWWWWWWWWWWWWO"
        return PixelSprite(frames: [a, b], palette: [
            "O": Palettes.outline,
            "W": RGBA(r: 226, g: 214, b: 192),
            "1": RGBA(r: 224, g: 120, b: 86),
            "2": RGBA(r: 62, g: 156, b: 138),
            "3": RGBA(r: 107, g: 127, b: 215),
            "T": RGBA(r: 255, g: 236, b: 120),
            "t": RGBA(r: 216, g: 196, b: 90),
        ])
    }

    /// A paper shopping bag, 8×8.
    static func shoppingBag() -> PixelSprite {
        let grid = [
            " O    O ",
            " O    O ",
            "OOOOOOOO",
            "OBBBBBBO",
            "OBbBBbBO",
            "OBBBBBBO",
            "OBBBBBBO",
            "OOOOOOOO",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "B": RGBA(r: 214, g: 164, b: 110),
            "b": RGBA(r: 186, g: 138, b: 88),
        ])
    }
}

/// Pure layout for the little activity vignettes shown while an instant
/// activity plays. One fixed 96×64 scene per style, drawn by the shared
/// `PixelSceneView`.
public enum ActivitySceneComposer {
    public static func sceneSize() -> (width: Int, height: Int) { (96, 64) }

    public static func compose(
        style: ActivitySceneStyle,
        appearance: CharacterAppearance,
        isFounder: Bool = true
    ) -> [PlacedSprite] {
        var placements = [PlacedSprite(
            sprite: background(for: style),
            x: 0, y: 0, kind: .room, animation: style == .walk ? .toggle(period: 1) : .still, phase: 0
        )]

        switch style {
        case .gymSession:
            placements.append(prop(SpriteLibrary.amenityProp(.treadmill), x: 8, y: 26, anim: .toggle(period: 1)))
            placements.append(prop(SpriteLibrary.amenityProp(.weightRack), x: 66, y: 30))
            placements.append(prop(SpriteLibrary.homeProp(.yogaMat), x: 66, y: 52))
            placements.append(PlacedSprite(
                sprite: SpriteLibrary.exercisingPerson(appearance: appearance, isFounder: isFounder),
                x: 41, y: 34, kind: .person, animation: .toggle(period: 2), phase: 0
            ))
        case .walk:
            placements.append(prop(ActivitySpriteLibrary.passingTree(), x: 10, y: 26, anim: .toggle(period: 1)))
            placements.append(prop(ActivitySpriteLibrary.passingTree(), x: 66, y: 22, anim: .toggle(period: 1), phase: 1))
            placements.append(PlacedSprite(
                sprite: ActivitySpriteLibrary.walkingPerson(appearance: appearance, isFounder: isFounder),
                x: 41, y: 34, kind: .person, animation: .toggle(period: 1), phase: 0
            ))
        case .cinema:
            placements.append(prop(ActivitySpriteLibrary.cinemaScreen(), x: 26, y: 6, anim: .glow))
            placements.append(PlacedSprite(
                sprite: SpriteLibrary.person(appearance: appearance, pose: .seatedCouch, isFounder: isFounder),
                x: 41, y: 40, kind: .person, animation: .toggle(period: 3), phase: 0
            ))
        case .restaurant:
            placements.append(PlacedSprite(
                sprite: SpriteLibrary.person(appearance: appearance, pose: .seatedCouch, isFounder: isFounder),
                x: 24, y: 30, kind: .person, animation: .toggle(period: 3), phase: 0
            ))
            placements.append(prop(SpriteLibrary.homeProp(.diningTable), x: 42, y: 42))
            placements.append(prop(SpriteLibrary.homeProp(.lamp), x: 76, y: 26))
        case .shopping:
            placements.append(prop(ActivitySpriteLibrary.shopShelf(), x: 8, y: 22, anim: .toggle(period: 3)))
            placements.append(PlacedSprite(
                sprite: SpriteLibrary.person(appearance: appearance, pose: .standing, isFounder: isFounder),
                x: 48, y: 32, kind: .person, animation: .toggle(period: 2), phase: 0
            ))
            placements.append(prop(ActivitySpriteLibrary.shoppingBag(), x: 64, y: 46))
        }
        return placements
    }

    private static func prop(
        _ sprite: PixelSprite, x: Int, y: Int,
        anim: SpriteAnimation = .still, phase: Int = 0
    ) -> PlacedSprite {
        PlacedSprite(sprite: sprite, x: x, y: y, kind: .prop, animation: anim, phase: phase)
    }

    /// Per-style backdrop, generated the `RoomBuilder` way. The walk
    /// backdrop has two frames with the path dashes shifted so the ground
    /// appears to slide under the walker.
    private static func background(for style: ActivitySceneStyle) -> PixelSprite {
        let (width, height) = sceneSize()

        func frame(shift: Int) -> [String] {
            (0..<height).map { y in
                String((0..<width).map { x -> Character in
                    if x == 0 || x == width - 1 || y == 0 || y == height - 1 { return "O" }
                    switch style {
                    case .walk:
                        if y < 20 { return "K" }                    // sky
                        if y >= 52, y < 58 {                        // path
                            return (y == 54 || y == 55) && ((x + shift) / 4) % 2 == 0 ? "d" : "A"
                        }
                        return (x * 7 + y * 13) % 31 == 0 ? "g" : "G"
                    case .cinema:
                        return y < 34 ? "N" : ((x / 2 + y / 2) % 2 == 0 ? "n" : "N")
                    case .gymSession:
                        if y < 22 { return "V" }
                        return (x / 2 + y / 2).isMultiple(of: 2) ? "F" : "f"
                    case .restaurant:
                        if y < 24 { return "R" }
                        return y % 3 == 2 ? "e" : "E"
                    case .shopping:
                        if y < 20 { return "V" }
                        return (x / 3 + y / 3).isMultiple(of: 2) ? "E" : "e"
                    }
                })
            }
        }

        let frames = style == .walk ? [frame(shift: 0), frame(shift: 2)] : [frame(shift: 0)]
        return PixelSprite(frames: frames, palette: [
            "O": Palettes.outline,
            "K": RGBA(r: 170, g: 204, b: 228),  // sky
            "G": RGBA(r: 132, g: 168, b: 112),  // grass
            "g": RGBA(r: 114, g: 148, b: 96),
            "A": RGBA(r: 176, g: 164, b: 146),  // path
            "d": RGBA(r: 210, g: 200, b: 182),
            "N": RGBA(r: 40, g: 38, b: 54),     // cinema dark
            "n": RGBA(r: 50, g: 48, b: 66),
            "V": RGBA(r: 196, g: 192, b: 204),  // interior wall
            "F": RGBA(r: 120, g: 116, b: 134),  // gym floor
            "f": RGBA(r: 108, g: 104, b: 122),
            "R": RGBA(r: 172, g: 120, b: 104),  // restaurant wall
            "E": RGBA(r: 190, g: 158, b: 122),  // wood floor
            "e": RGBA(r: 172, g: 140, b: 106),
        ])
    }
}
