/// Pure home-scene layout: tier + household + activity + mood → an ordered
/// (back-to-front) list of placed sprites. `HomeSceneView` and the PNG
/// preview renderer both draw exactly this list.
///
/// Placement kinds: the founder is `.person`, the partner `.partner`, kids
/// `.child`, the crib baby `.baby`; furniture is `.homeProp(name)`; the
/// controller/book are `.prop`; mood, heart and zzz bubbles are `.bubble`.
public enum HomeSceneComposer {
    public static func sceneSize(for tier: HomeTierStyle) -> (width: Int, height: Int) {
        let l = layout(for: tier)
        return (l.width, l.height)
    }

    /// Where the floor starts (internal; tests check people stand on it).
    static func wallHeight(for tier: HomeTierStyle) -> Int {
        layout(for: tier).wallHeight
    }

    // MARK: Layout

    struct Point: Equatable { let x: Int; let y: Int }

    /// Every fixed position in a tier's room. Furniture coordinates are the
    /// sprite's top-left; person slots are derived from them.
    struct Layout {
        let width: Int
        let height: Int
        let wallHeight: Int
        let bed: Point
        let lamp: Point
        let couch: Point
        let fridge: Point?
        let tv: Point?
        let table: Point?
        let armchair: Point?
        let crib: Point?
        let plant: Point?
        let fireplace: Point?
        let bookshelf: Point?
        let windows: [Point]
        let skylines: [Point]
        /// Rug woven into the floor pattern (in front of the couch).
        let rug: RoomBuilder.Rect?
        let mat: Point
        /// Where the founder stands while holding the baby.
        let babySpot: Point
        let childSpots: [Point]

        var suitcase: Point {
            let door = RoomBuilder.doorFrame(width: width, wallHeight: wallHeight)
            return Point(x: door.x - 1, y: wallHeight + 2)
        }

        // Person slots, derived from the furniture art (see sprite doc comments).
        func couchSlot(_ index: Int) -> Point { Point(x: couch.x + 3 + index * 14, y: couch.y - 6) }
        var bedSlot: Point { Point(x: bed.x + 2, y: bed.y - 1) }
        /// Behind the founder: up and a touch left so both heads read.
        var bedSlotBehind: Point { Point(x: bed.x + 1, y: bed.y - 4) }
        func tableSeat(_ index: Int) -> Point? { table.map { Point(x: $0.x + 2 + index * 14, y: $0.y - 11) } }
        var armchairSlot: Point? { armchair.map { Point(x: $0.x + 3, y: $0.y - 4) } }
        var matSlot: Point { Point(x: mat.x + 5, y: mat.y + 5 - 22) }
        var dumbbells: Point { Point(x: mat.x, y: mat.y - 6) }
        var babyInCrib: Point? { crib.map { Point(x: $0.x + 4, y: $0.y + 4) } }
    }

    static func layout(for tier: HomeTierStyle) -> Layout {
        switch tier {
        case .studioFlat:
            Layout(
                width: 108, height: 70, wallHeight: 34,
                bed: Point(x: 3, y: 30), lamp: Point(x: 34, y: 24), couch: Point(x: 46, y: 32),
                fridge: Point(x: 80, y: 20), tv: nil, table: nil, armchair: nil, crib: nil, plant: nil,
                fireplace: nil, bookshelf: nil,
                windows: [Point(x: 8, y: 6)], skylines: [], rug: nil,
                mat: Point(x: 6, y: 58), babySpot: Point(x: 84, y: 44),
                childSpots: [Point(x: 48, y: 52), Point(x: 60, y: 54), Point(x: 72, y: 52)]
            )
        case .apartment:
            Layout(
                width: 140, height: 80, wallHeight: 38,
                bed: Point(x: 3, y: 34), lamp: Point(x: 34, y: 28), couch: Point(x: 46, y: 36),
                fridge: nil, tv: Point(x: 90, y: 26), table: Point(x: 104, y: 52), armchair: nil,
                crib: Point(x: 82, y: 56), plant: Point(x: 81, y: 28), fireplace: nil, bookshelf: nil,
                windows: [Point(x: 10, y: 6), Point(x: 96, y: 6)], skylines: [],
                rug: RoomBuilder.Rect(x: 40, y: 56, width: 40, height: 18),
                mat: Point(x: 6, y: 66), babySpot: Point(x: 66, y: 50),
                childSpots: [Point(x: 36, y: 62), Point(x: 46, y: 64), Point(x: 56, y: 62)]
            )
        case .house:
            Layout(
                width: 184, height: 88, wallHeight: 42,
                bed: Point(x: 3, y: 38), lamp: Point(x: 34, y: 32), couch: Point(x: 102, y: 46),
                fridge: nil, tv: Point(x: 140, y: 30), table: Point(x: 46, y: 58), armchair: Point(x: 78, y: 50),
                crib: Point(x: 142, y: 56), plant: nil, fireplace: Point(x: 48, y: 22), bookshelf: Point(x: 78, y: 20),
                windows: [Point(x: 8, y: 6), Point(x: 116, y: 6)], skylines: [],
                rug: RoomBuilder.Rect(x: 96, y: 62, width: 46, height: 20),
                mat: Point(x: 6, y: 72), babySpot: Point(x: 162, y: 50),
                childSpots: [Point(x: 100, y: 66), Point(x: 111, y: 68), Point(x: 122, y: 66)]
            )
        case .penthouse:
            Layout(
                width: 200, height: 90, wallHeight: 46,
                bed: Point(x: 3, y: 42), lamp: Point(x: 34, y: 36), couch: Point(x: 92, y: 50),
                fridge: nil, tv: Point(x: 130, y: 34), table: Point(x: 58, y: 62), armchair: nil,
                crib: Point(x: 156, y: 60), plant: Point(x: 48, y: 34), fireplace: nil, bookshelf: nil,
                windows: [], skylines: [Point(x: 8, y: 6)],
                rug: RoomBuilder.Rect(x: 88, y: 66, width: 42, height: 20),
                mat: Point(x: 6, y: 76), babySpot: Point(x: 176, y: 54),
                childSpots: [Point(x: 90, y: 70), Point(x: 101, y: 72), Point(x: 112, y: 70)]
            )
        }
    }

    // MARK: Composition

    public static func compose(
        tier: HomeTierStyle, occupants: HomeOccupants, activity: HomeActivity, mood: MoodLevel
    ) -> [PlacedSprite] {
        let l = layout(for: tier)
        var scene: [PlacedSprite] = []

        func place(_ name: SpriteLibrary.HomePropName, _ p: Point, animation: SpriteAnimation = .still, phase: Int = 0) {
            scene.append(PlacedSprite(
                sprite: SpriteLibrary.homeProp(name), x: p.x, y: p.y, kind: .homeProp(name), animation: animation, phase: phase
            ))
        }

        scene.append(PlacedSprite(
            sprite: RoomBuilder.homeRoom(tier: tier, width: l.width, height: l.height, wallHeight: l.wallHeight, rug: l.rug),
            x: 0, y: 0, kind: .room, animation: .still, phase: 0
        ))

        // Wall decor.
        for (i, w) in l.windows.enumerated() { place(.windowNight, w, phase: i) }
        for s in l.skylines { place(.skylineWindow, s) }
        if let f = l.fireplace { place(.fireplace, f, animation: .toggle(period: 1)) }
        if let b = l.bookshelf { place(.bookshelf, b) }
        place(.lamp, l.lamp, animation: .toggle(period: 4))

        // Floor furniture, back to front.
        place(.bed, l.bed)
        if let f = l.fridge { place(.fridge, f) }
        if let p = l.plant { place(.plantHome, p) }
        if let t = l.tv { place(.tv, t, animation: .glow, phase: activity == .gaming ? 1 : 0) }
        place(.couch, l.couch)
        if let a = l.armchair { place(.armchair, a) }

        let children = Array(occupants.children.prefix(l.childSpots.count))
        let showCrib = tier.hasRoomForCrib && (!children.isEmpty || activity == .withBaby)
        if showCrib, let c = l.crib {
            place(.crib, c)
            if !children.isEmpty, activity != .withBaby, let b = l.babyInCrib {
                scene.append(PlacedSprite(
                    sprite: SpriteLibrary.baby(), x: b.x, y: b.y, kind: .baby, animation: .toggle(period: 4), phase: 1
                ))
            }
        }
        if activity == .exercising {
            place(.yogaMat, l.mat)
            place(.dumbbells, l.dumbbells)
        }
        if activity == .away {
            place(.suitcase, l.suitcase)
        }

        // People: partner first (behind the founder in bed), then founder, then kids.
        let founderAtTable = activity == .dinner && l.table != nil
        var partnerPlacement: PlacedSprite?
        if let partner = occupants.partner {
            let p: PlacedSprite
            switch activity {
            case .sleeping:
                let slot = l.bedSlotBehind
                p = PlacedSprite(
                    sprite: SpriteLibrary.person(appearance: partner, pose: .lying),
                    x: slot.x, y: slot.y, kind: .partner, animation: .toggle(period: 4), phase: 2
                )
            case .dinner where founderAtTable:
                let seat = l.tableSeat(1)!
                p = PlacedSprite(
                    sprite: SpriteLibrary.person(appearance: partner, pose: .seated),
                    x: seat.x, y: seat.y, kind: .partner, animation: .typing(slow: true), phase: 3
                )
            default:
                let slot = l.couchSlot(1)
                p = PlacedSprite(
                    sprite: SpriteLibrary.person(appearance: partner, pose: .seatedCouch),
                    x: slot.x, y: slot.y, kind: .partner, animation: .toggle(period: 4), phase: 2
                )
            }
            scene.append(p)
            partnerPlacement = p
        }

        var founderPlacement: PlacedSprite?
        var extras: [PlacedSprite] = []
        if activity != .away {
            let founder = occupants.founder
            func person(_ pose: SpriteLibrary.PersonPose) -> PixelSprite {
                SpriteLibrary.person(appearance: founder, pose: pose, isFounder: true)
            }
            let p: PlacedSprite
            switch activity {
            case .sleeping:
                let slot = l.bedSlot
                p = PlacedSprite(sprite: person(.lying), x: slot.x, y: slot.y, kind: .person, animation: .toggle(period: 4), phase: 0)
            case .dinner where founderAtTable:
                let seat = l.tableSeat(0)!
                p = PlacedSprite(sprite: person(.seated), x: seat.x, y: seat.y, kind: .person, animation: .typing(slow: true), phase: 0)
            case .exercising:
                let slot = l.matSlot
                p = PlacedSprite(
                    sprite: SpriteLibrary.exercisingPerson(appearance: founder, isFounder: true),
                    x: slot.x, y: slot.y, kind: .person, animation: .toggle(period: 3), phase: 0
                )
            case .withBaby:
                p = PlacedSprite(sprite: person(.holdingBaby), x: l.babySpot.x, y: l.babySpot.y, kind: .person, animation: .toggle(period: 4), phase: 0)
            case .reading where l.armchairSlot != nil:
                let slot = l.armchairSlot!
                p = PlacedSprite(sprite: person(.seatedCouch), x: slot.x, y: slot.y, kind: .person, animation: .toggle(period: 4), phase: 0)
            case .gaming:
                let slot = l.couchSlot(0)
                p = PlacedSprite(sprite: person(.seatedCouch), x: slot.x, y: slot.y, kind: .person, animation: .toggle(period: 2), phase: 0)
            default: // relaxing, reading without an armchair, dinner without a table
                let slot = l.couchSlot(0)
                p = PlacedSprite(sprite: person(.seatedCouch), x: slot.x, y: slot.y, kind: .person, animation: .toggle(period: 4), phase: 0)
            }
            scene.append(p)
            founderPlacement = p

            // Hand-held extras sit on the couch-pose hands (row 12).
            switch activity {
            case .gaming:
                extras.append(PlacedSprite(
                    sprite: SpriteLibrary.controller(), x: p.x + 2, y: p.y + 11, kind: .prop, animation: .toggle(period: 2), phase: 0
                ))
            case .reading:
                extras.append(PlacedSprite(
                    sprite: SpriteLibrary.book(), x: p.x + 3, y: p.y + 10, kind: .prop, animation: .still, phase: 0
                ))
            default:
                break
            }
        }

        for (i, child) in children.enumerated() {
            let spot = l.childSpots[i]
            scene.append(PlacedSprite(
                sprite: SpriteLibrary.child(appearance: child), x: spot.x, y: spot.y, kind: .child, animation: .toggle(period: 2), phase: i
            ))
        }

        // The table is drawn over diners' laps, like an office desk.
        if let t = l.table { place(.diningTable, t) }
        scene += extras

        // Bubbles last.
        if let founder = founderPlacement {
            if activity == .sleeping {
                scene.append(bubble(SpriteLibrary.zzzBubble(), over: founder, phase: 0))
                if let partner = partnerPlacement {
                    // Shifted right so the two zzz columns don't tangle.
                    scene.append(bubble(SpriteLibrary.zzzBubble(), over: partner, phase: 1, dx: 10))
                }
            } else if mood != .okay {
                scene.append(bubble(SpriteLibrary.moodBubble(mood), over: founder, phase: 0))
            }
            if activity == .dinner, let partner = partnerPlacement {
                scene.append(bubble(SpriteLibrary.moodBubble(.great), over: partner, phase: 0))
            }
        }

        return scene
    }

    /// A bubble whose tail touches the top of the head (rows 1–6, columns
    /// 3–10 of every adult pose).
    private static func bubble(_ sprite: PixelSprite, over person: PlacedSprite, phase: Int, dx: Int = 0) -> PlacedSprite {
        PlacedSprite(
            sprite: sprite, x: person.x + 4 + dx, y: person.y - 8, kind: .bubble,
            animation: sprite.frameCount > 1 ? .toggle(period: 4) : .still, phase: phase
        )
    }
}
