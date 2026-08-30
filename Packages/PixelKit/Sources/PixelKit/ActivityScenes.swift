import Foundation

/// Life activities as PixelKit sees them, each with its own 96×64 vignette.
///
/// The first five raw values mirror the engine's `InstantActivity` (plus
/// `shopping`, which the app routes to the shop sheet); the rest mirror
/// `WeekendActivity`, so `ActivitySceneStyle(weekendActivity:)` maps a
/// planned weekend onto a scene without PixelKit importing the engine.
public enum ActivitySceneStyle: String, Sendable, CaseIterable {
    // Instant activities.
    case gymSession, walk, cinema, restaurant, shopping
    // Weekend plans.
    case dateNight, friends, hobby, familyTime, vacation, doctor, spa, networking

    /// The vignette for a weekend plan, by the engine's raw `WeekendActivity`
    /// value. `rest` has no vignette — resting is what the home scene is
    /// already showing — so it returns `nil`.
    public init?(weekendActivity rawValue: String) {
        switch rawValue {
        case "rest": return nil
        case "gym": self = .gymSession
        default:
            guard let style = ActivitySceneStyle(rawValue: rawValue) else { return nil }
            self = style
        }
    }

    /// A one-line description for the scene's accessibility label.
    public var sceneDescription: String {
        switch self {
        case .gymSession: "A workout at the gym"
        case .walk: "A walk in the park"
        case .cinema: "A film at the cinema"
        case .restaurant: "Dinner out"
        case .shopping: "Shopping"
        case .dateNight: "Date night at a restaurant"
        case .friends: "Drinks with friends"
        case .hobby: "Time in the workshop"
        case .familyTime: "An afternoon in the park with the family"
        case .vacation: "A holiday on the beach"
        case .doctor: "A visit to the doctor"
        case .spa: "An afternoon at the spa"
        case .networking: "A tech conference"
        }
    }
}

/// Sprites specific to the activity mini-scenes.
enum ActivitySpriteLibrary {
    /// Walking toward the camera on the shared person canvas. Motion is sold
    /// by the scrolling background, not by moving the sprite.
    static func walkingPerson(appearance: CharacterAppearance, isFounder: Bool) -> PixelSprite {
        SpriteLibrary.person(appearance: appearance, pose: .walkDown, isFounder: isFounder)
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
            String(row.dropFirst(2)) + "  "
        }
        return PixelSprite(frames: [tree, shifted], palette: [
            "O": Palettes.outline,
            "F": Palettes.moss[3],
            "G": Palettes.moss[2],
            "T": Palettes.sand[3],
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
            "F": Palettes.ink[2],
            "S": Palettes.sky[2],
            "L": Palettes.sky[0],
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
            "W": Palettes.sand[1],
            "1": Palettes.ember[2],
            "2": Palettes.teal[2],
            "3": Palettes.sky[2],
            "T": Palettes.gold[1],
            "t": Palettes.gold[2],
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
            "B": Palettes.sand[1],
            "b": Palettes.sand[2],
        ])
    }

    // MARK: v2 vignette props

    /// A candle in a holder, 5×9, with a flame that flickers.
    static func candle() -> PixelSprite {
        func frame(_ flame: String) -> [String] {
            [
                "  " + flame + "  ",
                "  Y  ",
                " OWO ",
                " OWO ",
                " OWO ",
                " OWO ",
                "OOMOO",
                "OMMMO",
                "OOOOO",
            ]
        }
        return PixelSprite(frames: [frame("R"), frame("Y")], palette: [
            "O": Palettes.outline,
            "W": Palettes.stone[0],
            "Y": Palettes.gold[0],
            "R": Palettes.ember[1],
            "M": Palettes.gold[3],
        ])
    }

    /// A stemmed glass, 5×8. Two frames: the wine level catches the light.
    static func wineGlass() -> PixelSprite {
        func frame(_ fill: Character) -> [String] {
            [
                "OWWWO",
                "O\(fill)\(fill)\(fill)O",
                "O\(fill)\(fill)\(fill)O",
                "OO\(fill)OO",
                " OWO ",
                " OWO ",
                "OWWWO",
                "OOOOO",
            ]
        }
        return PixelSprite(frames: [frame("R"), frame("r")], palette: [
            "O": Palettes.outline,
            "W": Palettes.stone[1],
            "R": Palettes.ember[3],
            "r": Palettes.ember[4],
        ])
    }

    /// A bar counter with a bottle shelf behind it, 46×26.
    static func barCounter() -> PixelSprite {
        var canvas = PixelCanvas(width: 46, height: 26)
        // Bottle shelf.
        canvas.fill(x: 0, y: 0, width: 46, height: 12, Palettes.sand[4])
        for shelf in 0..<2 {
            let y = shelf * 6
            canvas.hLine(x: 0, y: y + 5, length: 46, Palettes.sand[3])
            for slot in 0..<11 {
                let x = 2 + slot * 4
                let tone = [Palettes.moss[2], Palettes.ember[2], Palettes.gold[2], Palettes.teal[2]][(slot + shelf) % 4]
                canvas.fill(x: x, y: y + 1, width: 2, height: 4, tone)
                canvas.set(x: x, y: y, Palettes.outline)
                canvas.set(x: x + 1, y: y, Palettes.outline)
            }
        }
        // Counter.
        canvas.fill(x: 0, y: 14, width: 46, height: 3, Palettes.sand[2])
        canvas.hLine(x: 0, y: 17, length: 46, Palettes.outline)
        canvas.fill(x: 0, y: 18, width: 46, height: 7, Palettes.sand[3])
        canvas.hLine(x: 0, y: 25, length: 46, Palettes.outline)
        canvas.hLine(x: 0, y: 13, length: 46, Palettes.outline)
        return canvas.sprite()
    }

    /// A workbench with a vice and a scattering of parts, 40×16.
    static func workbench() -> PixelSprite {
        var canvas = PixelCanvas(width: 40, height: 16)
        canvas.fill(x: 0, y: 4, width: 40, height: 4, Palettes.sand[2])
        canvas.hLine(x: 0, y: 3, length: 40, Palettes.outline)
        canvas.hLine(x: 0, y: 8, length: 40, Palettes.outline)
        canvas.fill(x: 2, y: 9, width: 3, height: 7, Palettes.sand[3])
        canvas.fill(x: 35, y: 9, width: 3, height: 7, Palettes.sand[3])
        // Vice, a circuit board and a coil of solder on the bench top.
        canvas.fill(x: 4, y: 0, width: 6, height: 3, Palettes.stone[3])
        canvas.fill(x: 16, y: 1, width: 9, height: 2, Palettes.moss[3])
        canvas.set(x: 18, y: 1, Palettes.gold[2])
        canvas.set(x: 22, y: 1, Palettes.gold[2])
        canvas.fill(x: 30, y: 1, width: 4, height: 2, Palettes.stone[2])
        return canvas.sprite()
    }

    /// A park bench, 24×10.
    static func parkBench() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWWWO",
            "OOOOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWWWO",
            "OOOOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWWWWWWWWWO",
            "OOOOOOOOOOOOOOOOOOOOOOOO",
            "  OMO              OMO  ",
            "  OMO              OMO  ",
            "  OMO              OMO  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.sand[2],
            "M": Palettes.stone[3],
        ])
    }

    /// A beach umbrella, 22×22, whose canopy shifts a pixel in the breeze.
    static func beachUmbrella() -> PixelSprite {
        func paint(into canvas: inout PixelCanvas, lean: Int) {
            for slice in 0..<5 {
                let x = 1 + slice * 4 + lean
                let tone = slice.isMultiple(of: 2) ? Palettes.ember[2] : Palettes.stone[0]
                let drop = abs(2 - slice)
                canvas.fill(x: x, y: 2 + drop, width: 4, height: 4 - drop, tone)
            }
            canvas.hLine(x: 1 + lean, y: 6, length: 20, Palettes.outline)
            canvas.vLine(x: 10, y: 7, length: 15, Palettes.sand[3])
            canvas.set(x: 10, y: 21, Palettes.sand[4])
        }
        var a = PixelCanvas(width: 22, height: 22)
        paint(into: &a, lean: 0)
        var b = PixelCanvas(like: a)
        paint(into: &b, lean: 1)
        return a.sprite(followedBy: [b])
    }

    /// A palm tree, 18×26.
    static func palmTree() -> PixelSprite {
        var canvas = PixelCanvas(width: 18, height: 26)
        canvas.vLine(x: 8, y: 6, length: 20, Palettes.sand[3])
        canvas.vLine(x: 9, y: 6, length: 20, Palettes.sand[4])
        for (dx, dy) in [(-7, 2), (-4, 0), (3, 0), (6, 2)] {
            for step in 0..<6 {
                let x = 9 + dx + (dx < 0 ? step : -step)
                canvas.set(x: x, y: 4 + dy + step / 3, Palettes.moss[2])
                canvas.set(x: x, y: 5 + dy + step / 3, Palettes.moss[3])
            }
        }
        canvas.fill(x: 7, y: 2, width: 4, height: 3, Palettes.moss[3])
        return canvas.sprite()
    }

    /// A clinic examination couch, 30×14.
    static func examCouch() -> PixelSprite {
        var canvas = PixelCanvas(width: 30, height: 14)
        canvas.fill(x: 0, y: 2, width: 30, height: 5, Palettes.teal[1])
        canvas.hLine(x: 0, y: 1, length: 30, Palettes.outline)
        canvas.hLine(x: 0, y: 7, length: 30, Palettes.outline)
        canvas.fill(x: 1, y: 0, width: 8, height: 1, Palettes.stone[0])
        canvas.fill(x: 0, y: 8, width: 30, height: 3, Palettes.stone[2])
        canvas.hLine(x: 0, y: 11, length: 30, Palettes.outline)
        canvas.vLine(x: 2, y: 12, length: 2, Palettes.stone[3])
        canvas.vLine(x: 27, y: 12, length: 2, Palettes.stone[3])
        return canvas.sprite()
    }

    /// A folding spa screen with candles and a rolled towel, 20×20.
    static func spaScreen() -> PixelSprite {
        var canvas = PixelCanvas(width: 20, height: 20)
        for panel in 0..<3 {
            let x = panel * 7
            canvas.fill(x: x, y: 0, width: 6, height: 18, panel == 1 ? Palettes.moss[1] : Palettes.moss[2])
            canvas.vLine(x: x + 6, y: 0, length: 18, Palettes.outline)
            canvas.fill(x: x + 2, y: 4, width: 2, height: 8, Palettes.moss[0])
        }
        canvas.hLine(x: 0, y: 18, length: 20, Palettes.outline)
        canvas.hLine(x: 0, y: 19, length: 20, Palettes.sand[3])
        return canvas.sprite()
    }

    /// A conference banner on a stand, 28×24.
    static func conferenceBanner() -> PixelSprite {
        var canvas = PixelCanvas(width: 28, height: 24)
        canvas.fill(x: 0, y: 0, width: 28, height: 21, Palettes.indigo[3])
        canvas.fill(x: 3, y: 3, width: 22, height: 4, Palettes.stone[0])
        canvas.fill(x: 3, y: 9, width: 14, height: 2, Palettes.indigo[0])
        canvas.fill(x: 3, y: 13, width: 18, height: 2, Palettes.indigo[0])
        canvas.fill(x: 3, y: 17, width: 10, height: 2, Palettes.gold[2])
        canvas.hLine(x: 0, y: 21, length: 28, Palettes.outline)
        canvas.hLine(x: 6, y: 22, length: 16, Palettes.stone[3])
        canvas.hLine(x: 4, y: 23, length: 20, Palettes.outline)
        return canvas.sprite()
    }

    /// A lanyard badge floating over the crowd, 12×12, gently swinging.
    static func conferenceBadge() -> PixelSprite {
        func paint(into canvas: inout PixelCanvas, shift: Int) {
            canvas.vLine(x: 5 + shift, y: 0, length: 3, Palettes.ember[3])
            canvas.fill(x: 1 + shift, y: 3, width: 9, height: 8, Palettes.stone[0])
            canvas.fill(x: 2 + shift, y: 5, width: 7, height: 1, Palettes.indigo[2])
            canvas.fill(x: 2 + shift, y: 7, width: 5, height: 1, Palettes.ink[2])
            canvas.fill(x: 2 + shift, y: 9, width: 6, height: 1, Palettes.ink[1])
        }
        var a = PixelCanvas(width: 12, height: 12)
        paint(into: &a, shift: 0)
        var b = PixelCanvas(like: a)
        paint(into: &b, shift: 1)
        return a.sprite(followedBy: [b])
    }
}

/// Pure layout for the little activity vignettes shown while an activity
/// plays. One fixed 96×64 scene per style, drawn by the shared
/// `PixelSceneView`. Every scene has at least two moving elements, because
/// a still vignette reads as a loading screen.
public enum ActivitySceneComposer {
    public static func sceneSize() -> (width: Int, height: Int) { (96, 64) }

    public static func compose(
        style: ActivitySceneStyle,
        appearance: CharacterAppearance,
        isFounder: Bool = true
    ) -> [PlacedSprite] {
        compose(style: style, appearance: appearance, isFounder: isFounder, companion: nil)
    }

    /// The vignette, optionally with a second person in it (a partner on
    /// date night, a child in the park).
    public static func compose(
        style: ActivitySceneStyle,
        appearance: CharacterAppearance,
        isFounder: Bool = true,
        companion: CharacterAppearance?
    ) -> [PlacedSprite] {
        var placements = [PlacedSprite(
            sprite: background(for: style),
            x: 0, y: 0, kind: .room, animation: style == .walk ? .toggle(period: 1) : .still, phase: 0
        )]

        func prop(
            _ sprite: PixelSprite, x: Int, y: Int,
            anim: SpriteAnimation = .still, phase: Int = 0
        ) -> PlacedSprite {
            PlacedSprite(sprite: sprite, x: x, y: y, kind: .prop, animation: anim, phase: phase)
        }

        func person(
            _ who: CharacterAppearance, _ pose: SpriteLibrary.PersonPose,
            x: Int, y: Int, founder: Bool, anim: SpriteAnimation, phase: Int = 0
        ) -> PlacedSprite {
            PlacedSprite(
                sprite: SpriteLibrary.person(appearance: who, pose: pose, isFounder: founder),
                x: x, y: y, kind: .person, animation: anim, phase: phase
            )
        }

        let other = companion ?? CharacterAppearance(seed: 0x5EED &+ UInt64(style.rawValue.count))

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
            placements.append(person(appearance, .walkDown, x: 41, y: 34, founder: isFounder, anim: .toggle(period: 1)))

        case .cinema:
            placements.append(prop(ActivitySpriteLibrary.cinemaScreen(), x: 26, y: 6, anim: .glow))
            placements.append(person(appearance, .seatedCouch, x: 41, y: 40, founder: isFounder, anim: .toggle(period: 3)))

        case .restaurant:
            placements.append(person(appearance, .seatedCouch, x: 24, y: 30, founder: isFounder, anim: .toggle(period: 3)))
            placements.append(prop(SpriteLibrary.homeProp(.diningTable), x: 42, y: 42))
            placements.append(prop(SpriteLibrary.homeProp(.lamp), x: 76, y: 26, anim: .toggle(period: 4)))
            placements.append(prop(ActivitySpriteLibrary.candle(), x: 56, y: 33, anim: .toggle(period: 1)))

        case .shopping:
            placements.append(prop(ActivitySpriteLibrary.shopShelf(), x: 8, y: 22, anim: .toggle(period: 3)))
            placements.append(person(appearance, .standing, x: 48, y: 32, founder: isFounder, anim: .toggle(period: 2)))
            placements.append(prop(ActivitySpriteLibrary.shoppingBag(), x: 64, y: 46))

        case .dateNight:
            // Two across a candlelit table, glasses catching the light.
            placements.append(prop(SpriteLibrary.homeProp(.lamp), x: 2, y: 16, anim: .toggle(period: 4)))
            placements.append(person(appearance, .seated, x: 24, y: 26, founder: isFounder, anim: .typing(slow: true)))
            placements.append(person(other, .seated, x: 56, y: 26, founder: false, anim: .typing(slow: true), phase: 3))
            placements.append(prop(SpriteLibrary.homeProp(.diningTable), x: 33, y: 37))
            placements.append(prop(ActivitySpriteLibrary.candle(), x: 46, y: 28, anim: .toggle(period: 1)))
            placements.append(prop(ActivitySpriteLibrary.wineGlass(), x: 38, y: 32, anim: .glow))
            placements.append(prop(ActivitySpriteLibrary.wineGlass(), x: 54, y: 32, anim: .glow, phase: 1))

        case .friends:
            placements.append(prop(ActivitySpriteLibrary.barCounter(), x: 4, y: 12))
            placements.append(person(appearance, .chat, x: 16, y: 34, founder: isFounder, anim: .toggle(period: 2)))
            placements.append(person(other, .coffee, x: 38, y: 34, founder: false, anim: .toggle(period: 3), phase: 1))
            placements.append(person(
                CharacterAppearance(seed: 991), .chat, x: 60, y: 34, founder: false,
                anim: .toggle(period: 2), phase: 2
            ))

        case .hobby:
            placements.append(prop(SpriteLibrary.prop(.pegboard), x: 8, y: 6))
            placements.append(person(appearance, .standing, x: 44, y: 24, founder: isFounder, anim: .toggle(period: 3)))
            placements.append(prop(ActivitySpriteLibrary.workbench(), x: 28, y: 40))
            placements.append(prop(SpriteLibrary.prop(.toolbox), x: 74, y: 49, anim: .still))
            placements.append(prop(SpriteLibrary.prop(.bulb), x: 20, y: 6, anim: .still))
            placements.append(prop(ActivitySpriteLibrary.candle(), x: 32, y: 35, anim: .toggle(period: 1)))

        case .familyTime:
            placements.append(prop(ActivitySpriteLibrary.passingTree(), x: 4, y: 18, anim: .toggle(period: 3)))
            placements.append(prop(ActivitySpriteLibrary.passingTree(), x: 78, y: 16, anim: .toggle(period: 3), phase: 1))
            placements.append(prop(ActivitySpriteLibrary.parkBench(), x: 58, y: 44))
            placements.append(person(appearance, .standing, x: 26, y: 34, founder: isFounder, anim: .toggle(period: 4)))
            placements.append(PlacedSprite(
                sprite: SpriteLibrary.child(appearance: other), x: 44, y: 43,
                kind: .child, animation: .toggle(period: 1), phase: 0
            ))
            placements.append(PlacedSprite(
                sprite: SpriteLibrary.child(appearance: CharacterAppearance(seed: 77)), x: 54, y: 41,
                kind: .child, animation: .toggle(period: 1), phase: 1
            ))

        case .vacation:
            placements.append(prop(ActivitySpriteLibrary.palmTree(), x: 4, y: 12, anim: .still))
            placements.append(prop(ActivitySpriteLibrary.beachUmbrella(), x: 58, y: 20, anim: .toggle(period: 4)))
            placements.append(person(appearance, .lying, x: 30, y: 46, founder: isFounder, anim: .toggle(period: 4)))
            placements.append(prop(SpriteLibrary.homeProp(.suitcase), x: 80, y: 46))
            placements.append(prop(ActivitySpriteLibrary.wineGlass(), x: 70, y: 44, anim: .glow))

        case .doctor:
            placements.append(prop(ActivitySpriteLibrary.examCouch(), x: 10, y: 40))
            placements.append(person(appearance, .seatedCouch, x: 18, y: 26, founder: isFounder, anim: .toggle(period: 4)))
            placements.append(person(
                other, .standing, x: 62, y: 30, founder: false,
                anim: .toggle(period: 3), phase: 2
            ))
            placements.append(prop(SpriteLibrary.prop(.framedReviews), x: 60, y: 6))
            placements.append(prop(SpriteLibrary.homeProp(.plantHome), x: 84, y: 40))

        case .spa:
            placements.append(prop(ActivitySpriteLibrary.spaScreen(), x: 6, y: 14))
            placements.append(prop(SpriteLibrary.homeProp(.plantHome), x: 82, y: 34))
            placements.append(person(appearance, .lying, x: 34, y: 40, founder: isFounder, anim: .toggle(period: 5)))
            placements.append(prop(ActivitySpriteLibrary.candle(), x: 30, y: 33, anim: .toggle(period: 1)))
            placements.append(prop(ActivitySpriteLibrary.candle(), x: 64, y: 33, anim: .toggle(period: 1), phase: 1))
            placements.append(PlacedSprite(
                sprite: SpriteLibrary.zzzBubble(), x: 60, y: 28, kind: .bubble,
                animation: .toggle(period: 3), phase: 0
            ))

        case .networking:
            placements.append(prop(ActivitySpriteLibrary.conferenceBanner(), x: 4, y: 10))
            placements.append(person(appearance, .chat, x: 38, y: 30, founder: isFounder, anim: .toggle(period: 2)))
            placements.append(person(other, .chat, x: 56, y: 30, founder: false, anim: .toggle(period: 2), phase: 1))
            placements.append(person(
                CharacterAppearance(seed: 1234), .coffee, x: 74, y: 30, founder: false,
                anim: .toggle(period: 3), phase: 2
            ))
            placements.append(prop(ActivitySpriteLibrary.conferenceBadge(), x: 40, y: 14, anim: .toggle(period: 2)))
        }
        return placements
    }

    // MARK: Backgrounds

    /// Per-style backdrop, generated the `RoomBuilder` way. The walk backdrop
    /// has two frames with the path dashes shifted so the ground appears to
    /// slide under the walker.
    private static func background(for style: ActivitySceneStyle) -> PixelSprite {
        let (width, height) = sceneSize()

        /// (upper, floor, floorAlt, horizon) tones for the style.
        let scheme: (upper: RGBA, upperAlt: RGBA, floor: RGBA, floorAlt: RGBA, horizon: Int) = {
            switch style {
            case .walk, .familyTime:
                (Palettes.sky[1], Palettes.sky[0], Palettes.moss[2], Palettes.moss[3], 20)
            case .cinema:
                (Palettes.ink[3], Palettes.ink[2], Palettes.ink[2], Palettes.ink[3], 34)
            case .gymSession:
                (Palettes.stone[1], Palettes.stone[0], Palettes.stone[3], Palettes.stone[4], 22)
            case .restaurant, .dateNight:
                (Palettes.ember[4], Palettes.ember[3], Palettes.sand[2], Palettes.sand[3], 24)
            case .shopping:
                (Palettes.stone[0], Palettes.stone[1], Palettes.sand[1], Palettes.sand[2], 20)
            case .friends:
                (Palettes.plum[4], Palettes.plum[3], Palettes.sand[3], Palettes.sand[4], 40)
            case .hobby:
                (Palettes.clay[3], Palettes.clay[2], Palettes.clay[1], Palettes.clay[2], 24)
            case .vacation:
                (Palettes.sky[1], Palettes.sky[0], Palettes.sand[1], Palettes.sand[0], 30)
            case .doctor:
                (Palettes.teal[0], Palettes.teal[1], Palettes.stone[1], Palettes.stone[2], 24)
            case .spa:
                (Palettes.moss[3], Palettes.moss[4], Palettes.sand[2], Palettes.sand[3], 26)
            case .networking:
                (Palettes.indigo[4], Palettes.indigo[3], Palettes.stone[3], Palettes.stone[4], 30)
            }
        }()

        func paint(shift: Int, like template: PixelCanvas?) -> PixelCanvas {
            var canvas = template.map { PixelCanvas(like: $0) } ?? PixelCanvas(width: width, height: height)
            // Upper half: sky, or a wall with a faint texture.
            canvas.fill(x: 0, y: 0, width: width, height: scheme.horizon, scheme.upper)
            for y in 0..<scheme.horizon {
                for x in 0..<width where (x * 7 + y * 13) % 61 == 0 {
                    canvas.set(x: x, y: y, scheme.upperAlt)
                }
            }
            // Lower half: ground.
            canvas.fill(
                x: 0, y: scheme.horizon, width: width, height: height - scheme.horizon, scheme.floor
            )
            for y in scheme.horizon..<height {
                for x in 0..<width where (x * 5 + y * 11) % 43 == 0 {
                    canvas.set(x: x, y: y, scheme.floorAlt)
                }
            }
            canvas.hLine(x: 0, y: scheme.horizon, length: width, Palettes.blended(
                scheme.floor, toward: Palettes.ink[4], amount: 0.35
            ))

            // Style-specific features.
            switch style {
            case .walk:
                canvas.fill(x: 0, y: 52, width: width, height: 6, Palettes.clay[1])
                for x in 0..<width where ((x + shift) / 4) % 2 == 0 {
                    canvas.set(x: x, y: 54, Palettes.clay[0])
                    canvas.set(x: x, y: 55, Palettes.clay[0])
                }
            case .familyTime:
                // A sun and a couple of clouds.
                canvas.fill(x: 76, y: 4, width: 6, height: 6, Palettes.gold[0])
                canvas.fill(x: 12, y: 6, width: 12, height: 3, Palettes.stone[0])
                canvas.fill(x: 40, y: 10, width: 16, height: 3, Palettes.stone[0])
            case .vacation:
                // Sea between sky and sand, with two lines of surf.
                canvas.fill(x: 0, y: 20, width: width, height: 10, Palettes.teal[2])
                for x in 0..<width where ((x + shift * 2) / 5) % 3 == 0 {
                    canvas.set(x: x, y: 24, Palettes.teal[1])
                    canvas.set(x: x, y: 28, Palettes.teal[0])
                }
                canvas.fill(x: 68, y: 4, width: 7, height: 7, Palettes.gold[0])
            case .cinema:
                // Rows of seat-backs in silhouette.
                for row in 0..<3 {
                    let y = 44 + row * 7
                    for seat in 0..<8 {
                        canvas.fill(x: 2 + seat * 12, y: y, width: 9, height: 5, Palettes.ink[3])
                    }
                }
            case .friends:
                // Pendant lamps over the bar.
                for x in stride(from: 12, to: width, by: 24) {
                    canvas.vLine(x: x, y: 0, length: 4, Palettes.ink[4])
                    canvas.fill(x: x - 2, y: 4, width: 5, height: 3, Palettes.gold[2])
                    canvas.set(x: x, y: 7, Palettes.gold[0])
                }
            case .doctor:
                // A tiled dado rail.
                canvas.hLine(x: 0, y: 18, length: width, Palettes.teal[2])
                canvas.hLine(x: 0, y: 19, length: width, Palettes.teal[3])
            case .networking:
                // Distant heads: a crowd, out of focus.
                for index in 0..<12 {
                    let x = 2 + index * 8
                    canvas.fill(x: x, y: 22, width: 5, height: 5, Palettes.indigo[3])
                    canvas.fill(x: x, y: 27, width: 5, height: 4, Palettes.indigo[4])
                }
            case .spa:
                canvas.hLine(x: 0, y: 20, length: width, Palettes.moss[2])
            case .gymSession, .restaurant, .dateNight, .shopping, .hobby:
                break
            }

            // Frame.
            for x in 0..<width {
                canvas.set(x: x, y: 0, Palettes.outline)
                canvas.set(x: x, y: height - 1, Palettes.outline)
            }
            for y in 0..<height {
                canvas.set(x: 0, y: y, Palettes.outline)
                canvas.set(x: width - 1, y: y, Palettes.outline)
            }
            return canvas
        }

        let a = paint(shift: 0, like: nil)
        guard style == .walk || style == .vacation else { return a.sprite() }
        return a.sprite(followedBy: [paint(shift: 2, like: a)])
    }
}
