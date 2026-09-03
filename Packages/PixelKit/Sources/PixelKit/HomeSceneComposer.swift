/// Pure home-scene layout: tier + household + activity + mood + ambience →
/// an ordered (back-to-front) list of placed sprites. `HomeSceneView` and
/// the PNG preview renderer both draw exactly this list.
///
/// The scene is written to be *read*, not just looked at. Three things
/// change it beyond the furniture:
///
/// - **the hour** — walls, windows and a lighting overlay move from morning
///   through dusk to night;
/// - **mood** — under 35 the room stops being looked after (laundry, a dead
///   plant, takeaway cartons); over 70 it is tidy and there are flowers;
/// - **who is home** — the partner cooks, reads or watches TV, kids play on
///   the rug or draw at the table, and the cat sleeps on the couch until
///   somebody sits on it.
///
/// Placement kinds: the founder is `.person`, the partner `.partner`, kids
/// `.child`, the crib baby `.baby`; furniture is `.homeProp(name)`; the
/// controller/book/laptop/cat are `.prop`; bubbles are `.bubble`.
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
        /// The stove the partner cooks at (nil where there is no kitchen).
        let kitchen: Point?
        /// The corner of the floor that shows how life is going.
        let moodCorner: Point

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
        /// Where the partner stands to cook: beside the range, feet on
        /// the wall line so they read as standing in the kitchen.
        var kitchenSlot: Point? { kitchen.map { Point(x: $0.x - 8, y: wallHeight - 22) } }
        /// The founder crashed out across the couch on a crunch week.
        var couchCrash: Point { Point(x: couch.x + 4, y: couch.y - 4) }
        /// The cat's favourite cushion, and the floor it patrols instead.
        var catCushion: Point { Point(x: couch.x + 18, y: couch.y - 3) }
        var catFloor: Point { Point(x: couch.x - 4, y: height - 11) }
    }

    static func layout(for tier: HomeTierStyle) -> Layout {
        switch tier {
        case .studioFlat:
            Layout(
                width: 108, height: 70, wallHeight: 34,
                bed: Point(x: 3, y: 30), lamp: Point(x: 30, y: 8), couch: Point(x: 44, y: 36),
                fridge: Point(x: 46, y: 8), tv: nil, table: nil, armchair: nil, crib: nil, plant: nil,
                fireplace: nil, bookshelf: nil,
                windows: [Point(x: 8, y: 6)], skylines: [], rug: nil,
                mat: Point(x: 6, y: 58), babySpot: Point(x: 84, y: 44),
                childSpots: [Point(x: 48, y: 52), Point(x: 60, y: 54), Point(x: 72, y: 52)],
                kitchen: Point(x: 76, y: 16), moodCorner: Point(x: 33, y: 59)
            )
        case .apartment:
            Layout(
                width: 140, height: 80, wallHeight: 38,
                bed: Point(x: 3, y: 34), lamp: Point(x: 34, y: 28), couch: Point(x: 46, y: 36),
                fridge: nil, tv: Point(x: 86, y: 6), table: Point(x: 104, y: 52), armchair: nil,
                crib: Point(x: 82, y: 56), plant: Point(x: 110, y: 26), fireplace: nil, bookshelf: nil,
                windows: [Point(x: 10, y: 6), Point(x: 110, y: 6)], skylines: [],
                rug: RoomBuilder.Rect(x: 40, y: 56, width: 40, height: 18),
                mat: Point(x: 6, y: 66), babySpot: Point(x: 66, y: 50),
                childSpots: [Point(x: 36, y: 62), Point(x: 46, y: 64), Point(x: 56, y: 62)],
                kitchen: Point(x: 62, y: 18), moodCorner: Point(x: 110, y: 68)
            )
        case .house:
            Layout(
                width: 184, height: 88, wallHeight: 42,
                bed: Point(x: 3, y: 38), lamp: Point(x: 34, y: 32), couch: Point(x: 102, y: 46),
                fridge: nil, tv: Point(x: 140, y: 6), table: Point(x: 46, y: 58), armchair: Point(x: 78, y: 50),
                crib: Point(x: 142, y: 56), plant: nil, fireplace: Point(x: 48, y: 22), bookshelf: Point(x: 78, y: 20),
                windows: [Point(x: 8, y: 6), Point(x: 116, y: 6)], skylines: [],
                rug: RoomBuilder.Rect(x: 96, y: 62, width: 46, height: 20),
                mat: Point(x: 6, y: 72), babySpot: Point(x: 162, y: 50),
                childSpots: [Point(x: 100, y: 66), Point(x: 111, y: 68), Point(x: 122, y: 66)],
                kitchen: Point(x: 148, y: 24), moodCorner: Point(x: 150, y: 74)
            )
        case .penthouse:
            Layout(
                width: 200, height: 90, wallHeight: 46,
                bed: Point(x: 3, y: 42), lamp: Point(x: 34, y: 36), couch: Point(x: 92, y: 50),
                fridge: nil, tv: Point(x: 106, y: 26), table: Point(x: 58, y: 62), armchair: nil,
                crib: Point(x: 156, y: 60), plant: Point(x: 48, y: 34), fireplace: nil, bookshelf: nil,
                windows: [], skylines: [Point(x: 8, y: 6)],
                rug: RoomBuilder.Rect(x: 88, y: 66, width: 42, height: 20),
                mat: Point(x: 6, y: 76), babySpot: Point(x: 176, y: 48),
                childSpots: [Point(x: 90, y: 70), Point(x: 101, y: 72), Point(x: 112, y: 70)],
                kitchen: Point(x: 158, y: 26), moodCorner: Point(x: 166, y: 76)
            )
        }
    }

    // MARK: Composition

    /// The evening scene the Life tab has always shown.
    public static func compose(
        tier: HomeTierStyle, occupants: HomeOccupants, activity: HomeActivity, mood: MoodLevel
    ) -> [PlacedSprite] {
        compose(tier: tier, occupants: occupants, activity: activity, mood: mood, ambience: .evening)
    }

    public static func compose(
        tier: HomeTierStyle,
        occupants: HomeOccupants,
        activity: HomeActivity,
        mood: MoodLevel,
        ambience: HomeAmbience
    ) -> [PlacedSprite] {
        compose(tier: tier, occupants: occupants, activity: activity, mood: mood, ambience: ambience, signals: .none)
    }

    public static func compose(
        tier: HomeTierStyle,
        occupants: HomeOccupants,
        activity: HomeActivity,
        mood: MoodLevel,
        ambience: HomeAmbience,
        signals: HomeSignals
    ) -> [PlacedSprite] {
        let l = layout(for: tier)
        let time = ambience.timeOfDay
        var scene: [PlacedSprite] = []

        func place(_ name: SpriteLibrary.HomePropName, _ p: Point, animation: SpriteAnimation = .still, phase: Int = 0) {
            scene.append(PlacedSprite(
                sprite: SpriteLibrary.homeProp(name), x: p.x, y: p.y, kind: .homeProp(name), animation: animation, phase: phase
            ))
        }

        // Keyed through SpriteCache for the same reason WS-C keys the
        // office room: this is a grid of a few thousand strings rebuilt on
        // every frame of the Life tab, and it is a pure function of these
        // five parameters.
        scene.append(PlacedSprite(
            sprite: SpriteCache.shared(
                "home.\(tier.rawValue).\(l.width)x\(l.height).\(l.wallHeight)."
                    + (l.rug.map { "\($0.x),\($0.y),\($0.width),\($0.height)" } ?? "norug")
                    + ".\(time)"
            ) {
                RoomBuilder.homeRoom(
                    tier: tier, width: l.width, height: l.height, wallHeight: l.wallHeight,
                    rug: l.rug, time: time
                )
            },
            x: 0, y: 0, kind: .room, animation: .still, phase: 0
        ))

        // Wall decor. Windows keep the `.windowNight` placement kind — the
        // slot on the wall is the same one; only the view through it moves
        // with the hour and the weather.
        let windowSprite = SpriteLibrary.window(style: .home, time: time, weather: ambience.weather)
        for (index, w) in l.windows.enumerated() {
            scene.append(PlacedSprite(
                sprite: windowSprite, x: w.x, y: w.y,
                kind: .homeProp(.windowNight), animation: .still, phase: index
            ))
        }
        let skylineSprite = SpriteLibrary.skyline(time: time, weather: ambience.weather)
        for point in l.skylines {
            scene.append(PlacedSprite(
                sprite: skylineSprite, x: point.x, y: point.y,
                kind: .homeProp(.skylineWindow), animation: .still, phase: 0
            ))
        }
        if let f = l.fireplace { place(.fireplace, f, animation: .toggle(period: 1)) }
        if let b = l.bookshelf { place(.bookshelf, b) }
        // The lamp is only on when the room needs it.
        place(.lamp, l.lamp, animation: time.needsArtificialLight ? .toggle(period: 4) : .still,
              phase: time.needsArtificialLight ? 0 : 1)

        // Floor furniture, back to front.
        place(.bed, l.bed)
        if let f = l.fridge {
            place(.fridge, f)
            // A child's drawing goes up on the fridge when family life is good.
            if !occupants.children.isEmpty, mood == .great {
                scene.append(PlacedSprite(
                    sprite: SpriteLibrary.kidDrawing(), x: f.x + 1, y: f.y + 4,
                    kind: .prop, animation: .still, phase: 0
                ))
            }
        }
        let partnerCooking = occupants.partner != nil && activity == .dinner && l.kitchen != nil
        if let kitchen = l.kitchen {
            place(.stove, kitchen, animation: partnerCooking ? .toggle(period: 2) : .still,
                  phase: partnerCooking ? 0 : 1)
        }
        if let p = l.plant {
            place(mood == .low ? .deadPlant : .plantHome, p)
        }
        if let t = l.tv {
            place(.tv, t, animation: .glow, phase: activity == .gaming ? 1 : 0)
        }
        place(.couch, l.couch)
        if let a = l.armchair { place(.armchair, a) }

        // The corner that shows how the founder is actually doing.
        switch mood {
        case .low:
            place(.laundryPile, l.moodCorner)
            place(.takeoutBoxes, Point(x: l.moodCorner.x + 2, y: l.moodCorner.y - 8))
        case .great:
            place(.flowerVase, Point(x: l.moodCorner.x + 4, y: l.moodCorner.y - 3))
        case .okay:
            break
        }
        if activity == .crunching || (signals.healthLow && mood != .low) {
            // Crunch weeks leave their own evidence, whatever the mood —
            // and so does a body that is not being looked after.
            place(.takeoutBoxes, Point(x: l.couch.x + 36, y: l.height - 11))
        }
        if signals.billsDue {
            // Unpaid bills, on the table when there is one and on the
            // couch arm when there is not.
            let spot = l.table.map { Point(x: $0.x + 4, y: $0.y - 6) }
                ?? Point(x: l.couch.x + 30, y: l.couch.y - 4)
            scene.append(PlacedSprite(
                sprite: OfficeFXSprites.stickyNote(), x: spot.x, y: spot.y,
                kind: .prop, animation: .toggle(period: 5), phase: 1
            ))
        }

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
        if activity == .away || activity == .awayPartnerAlone {
            place(.suitcase, l.suitcase)
        }

        // People: partner first (behind the founder in bed), then founder, then kids.
        let founderAtTable = activity == .dinner && l.table != nil
        var partnerPlacement: PlacedSprite?
        if let partner = occupants.partner {
            partnerPlacement = placePartner(
                partner, activity: activity, layout: l, cooking: partnerCooking, into: &scene
            )
        }

        var founderPlacement: PlacedSprite?
        var extras: [PlacedSprite] = []
        if activity != .away, activity != .awayPartnerAlone {
            let founder = occupants.founder
            func person(_ pose: SpriteLibrary.PersonPose) -> PixelSprite {
                SpriteLibrary.person(appearance: founder, pose: pose, isFounder: true)
            }
            let p: PlacedSprite
            switch activity {
            case .sleeping:
                let slot = l.bedSlot
                p = PlacedSprite(sprite: person(.lying), x: slot.x, y: slot.y, kind: .person, animation: .toggle(period: 4), phase: 0)
            case .crunching:
                // Face down across the couch, laptop still open on the arm.
                let slot = l.couchCrash
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
            case .crunching:
                extras.append(PlacedSprite(
                    sprite: SpriteLibrary.laptop(), x: p.x + 13, y: p.y + 4, kind: .prop, animation: .glow, phase: 0
                ))
            default:
                break
            }
        }

        // Kids: on the rug, or drawing at the table when there is one.
        for (i, child) in children.enumerated() {
            let drawingAtTable = i == 0 && l.table != nil && activity == .dinner
            let spot = drawingAtTable
                ? Point(x: l.table!.x + 22, y: l.table!.y - 13)
                : l.childSpots[i]
            scene.append(PlacedSprite(
                sprite: SpriteLibrary.child(appearance: child), x: spot.x, y: spot.y, kind: .child,
                animation: .toggle(period: drawingAtTable ? 4 : 2), phase: i
            ))
        }

        // The cat: on its cushion when the couch is free, patrolling when it
        // is not, and never in the founder's lap.
        if occupants.hasCat {
            let couchTaken = founderPlacement.map { $0.x < l.couch.x + 34 && $0.x + $0.sprite.width > l.couch.x } ?? false
            let onCushion = !couchTaken && activity != .crunching
            let spot = onCushion ? l.catCushion : l.catFloor
            scene.append(PlacedSprite(
                sprite: SpriteLibrary.cat(onCushion ? .sleeping : .walking),
                x: spot.x, y: spot.y, kind: .prop,
                animation: .toggle(period: onCushion ? 5 : 2), phase: 1
            ))
        }

        // The table is drawn over diners' laps, like an office desk.
        if let t = l.table { place(.diningTable, t) }
        scene += extras

        // Bubbles.
        if let founder = founderPlacement {
            if activity == .sleeping || activity == .crunching {
                scene.append(bubble(SpriteLibrary.zzzBubble(), over: founder, phase: 0))
                if activity == .sleeping, let partner = partnerPlacement {
                    // Shifted right so the two zzz columns don't tangle.
                    scene.append(bubble(SpriteLibrary.zzzBubble(), over: partner, phase: 1, dx: 10))
                }
            } else if mood != .okay {
                scene.append(bubble(SpriteLibrary.moodBubble(mood), over: founder, phase: 0))
            }
            if let partner = partnerPlacement {
                if signals.relationshipsLow {
                    // The number the meters show, on the person it is about:
                    // no heart at dinner, a low bubble on the couch.
                    scene.append(bubble(SpriteLibrary.moodBubble(.low), over: partner, phase: 1))
                } else if activity == .dinner {
                    scene.append(bubble(SpriteLibrary.moodBubble(.great), over: partner, phase: 0))
                }
            }
        } else if let partner = partnerPlacement, activity == .awayPartnerAlone {
            // Nobody to eat with.
            scene.append(bubble(SpriteLibrary.moodBubble(.low), over: partner, phase: 0))
        }

        // The hour, laid over everything.
        if time != .day {
            scene.append(PlacedSprite(
                sprite: SpriteLibrary.lightingOverlay(width: l.width, height: l.height, time: time),
                x: 0, y: 0, kind: .prop, animation: .still, phase: 0
            ))
        }
        return scene
    }

    /// Where the partner is and what they are doing. They cook at the stove
    /// during dinner prep, sit opposite at the table, sleep beside the
    /// founder, eat alone when the founder is away, and otherwise take the
    /// far end of the couch.
    private static func placePartner(
        _ partner: CharacterAppearance,
        activity: HomeActivity,
        layout l: Layout,
        cooking: Bool,
        into scene: inout [PlacedSprite]
    ) -> PlacedSprite {
        let placement: PlacedSprite
        switch activity {
        case .sleeping, .crunching:
            // On a crunch week the founder is face down on the couch, so the
            // partner went to bed on their own. That is the whole picture.
            let slot = activity == .crunching ? l.bedSlot : l.bedSlotBehind
            placement = PlacedSprite(
                sprite: SpriteLibrary.person(appearance: partner, pose: .lying),
                x: slot.x, y: slot.y, kind: .partner, animation: .toggle(period: 4), phase: 2
            )
        case .dinner where cooking:
            let slot = l.kitchenSlot!
            placement = PlacedSprite(
                sprite: SpriteLibrary.person(appearance: partner, pose: .standing),
                x: slot.x, y: slot.y + 6, kind: .partner, animation: .toggle(period: 3), phase: 3
            )
        case .dinner where l.table != nil:
            let seat = l.tableSeat(1)!
            placement = PlacedSprite(
                sprite: SpriteLibrary.person(appearance: partner, pose: .seated),
                x: seat.x, y: seat.y, kind: .partner, animation: .typing(slow: true), phase: 3
            )
        case .awayPartnerAlone where l.table != nil:
            let seat = l.tableSeat(0)!
            placement = PlacedSprite(
                sprite: SpriteLibrary.person(appearance: partner, pose: .seated),
                x: seat.x, y: seat.y, kind: .partner, animation: .typing(slow: true), phase: 3
            )
        default:
            // The armchair is the founder's reading spot, so the partner
            // always takes the far end of the couch.
            let slot = l.couchSlot(1)
            placement = PlacedSprite(
                sprite: SpriteLibrary.person(appearance: partner, pose: .seatedCouch),
                x: slot.x, y: slot.y, kind: .partner, animation: .toggle(period: 4), phase: 2
            )
        }
        scene.append(placement)
        return placement
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
