/// Home-scene additions to the sprite factory: extra person poses (the
/// office `seated` pose stays as-is), children, the baby, evening furniture
/// and decor, and the mood / zzz bubbles.
extension SpriteLibrary {
    // MARK: - Poses

    /// Every pose a person sprite can be drawn in.
    ///
    /// The first six are the home/office poses; the rest are the office-life
    /// poses the director needs. All of them keep the head in rows 1-6 of a
    /// 14-wide canvas (offset per frame where a pose bobs or slumps), which
    /// is what lets hair, glasses, beard, outfit and role accessories drop
    /// onto every one of them from a single set of overlays.
    public enum PersonPose: String, Sendable, Equatable, CaseIterable {
        case seated, standing, lying, seatedCouch, holdingBaby, exercising
        case walkLeft, walkRight, walkDown, cheer, slump, coffee, chat, carryBox, portrait
    }

    /// A person in a pose. `seated` is the office sprite (3 frames: typing
    /// A, typing B, blink); walking is a 4-frame cycle; the rest are two
    /// frames. `role` adds the accessory that tells the job apart — the
    /// founder always wears the indigo hoodie regardless of their outfit.
    public static func person(
        appearance: CharacterAppearance,
        pose: PersonPose,
        isFounder: Bool = false,
        role: RoleLook = .none
    ) -> PixelSprite {
        SpriteCache.sprite(for: SpriteCache.Key(
            appearance: appearance, pose: pose, isFounder: isFounder, role: role
        )) {
            buildPerson(appearance: appearance, pose: pose, isFounder: isFounder, role: role)
        }
    }

    private static func buildPerson(
        appearance: CharacterAppearance, pose: PersonPose, isFounder: Bool, role: RoleLook
    ) -> PixelSprite {
        // Either flag makes a founder: WS-C tags occupants with
        // `role: .founder`, older call sites pass `isFounder: true`.
        let look: RoleLook = isFounder ? .founder : role
        let isFounder = isFounder || role == .founder
        switch pose {
        case .seated:
            return composePerson(
                frames: [PersonArt.frameA, PersonArt.frameB, PersonArt.frameABlink],
                headOffsets: [0, 1, 0], appearance: appearance, isFounder: isFounder, role: look
            )
        case .standing:
            return composePerson(
                frames: [HomePersonArt.standingA, HomePersonArt.headBob(HomePersonArt.standingA)],
                headOffsets: [0, 1], appearance: appearance, isFounder: isFounder, role: look
            )
        case .seatedCouch:
            return composePerson(
                frames: [HomePersonArt.seatedCouchA, HomePersonArt.headBob(HomePersonArt.seatedCouchA)],
                headOffsets: [0, 1], appearance: appearance, isFounder: isFounder, role: look
            )
        case .lying:
            // Under the blanket the outfit and accessories are hidden, so
            // the founder flag is moot.
            return composePerson(
                frames: [HomePersonArt.lyingA, HomePersonArt.lyingB],
                headOffsets: [0, 0], appearance: appearance, isFounder: false, role: .none, sleeping: true
            )
        case .holdingBaby:
            return composePerson(
                frames: [HomePersonArt.holdingBabyA, HomePersonArt.holdingBabyB],
                headOffsets: [0, 1], appearance: appearance, isFounder: isFounder, role: look
            )
        case .exercising:
            return exercisingPerson(appearance: appearance, isFounder: isFounder)

        case .walkRight, .walkLeft:
            return composePerson(
                frames: HomePersonArt.walkRightFrames,
                headOffsets: HomePersonArt.walkHeadOffsets,
                appearance: appearance, isFounder: isFounder, role: look,
                mirrored: pose == .walkLeft
            )
        case .walkDown:
            // Toward the camera: the standing pose with alternating steps.
            return composePerson(
                frames: HomePersonArt.walkDownFrames,
                headOffsets: [0, 1], appearance: appearance, isFounder: isFounder, role: look
            )
        case .cheer:
            return composePerson(
                frames: [HomePersonArt.cheerDown, HomePersonArt.cheerUp],
                headOffsets: [0, -1], appearance: appearance, isFounder: isFounder, role: look
            )
        case .slump:
            return composePerson(
                frames: [HomePersonArt.slumpA, HomePersonArt.slumpB],
                headOffsets: [2, 3], torsoOffsets: [1, 1],
                appearance: appearance, isFounder: isFounder, role: look
            )
        case .coffee:
            return composePerson(
                frames: [HomePersonArt.standingA, HomePersonArt.headBob(HomePersonArt.standingA)],
                headOffsets: [0, 1], appearance: appearance, isFounder: isFounder, role: look,
                props: [HomePersonArt.mugLow, HomePersonArt.mugHigh]
            )
        case .chat:
            return composePerson(
                frames: [HomePersonArt.standingA, HomePersonArt.headBob(HomePersonArt.standingA)],
                headOffsets: [0, 1], appearance: appearance, isFounder: isFounder, role: look,
                props: [HomePersonArt.gestureUp, HomePersonArt.gestureDown]
            )
        case .carryBox:
            return composePerson(
                frames: [HomePersonArt.standingA, HomePersonArt.headBob(HomePersonArt.standingA)],
                headOffsets: [0, 1], appearance: appearance, isFounder: isFounder, role: look,
                props: [HomePersonArt.boxOverlay, HomePersonArt.boxOverlayLifted]
            )
        case .portrait:
            return portraitBust(appearance: appearance, isFounder: isFounder, role: look)
        }
    }

    /// A 10x10 head-and-shoulders bust cropped out of the seated frames
    /// (open eyes / blink), for UI portraits. The crop keeps the collar rows,
    /// so glasses, beard, hoodie and role accessory all survive into the
    /// portrait — a lawyer's tie and a QA's headset are visible in a list
    /// row, which is the whole point.
    private static func portraitBust(
        appearance: CharacterAppearance, isFounder: Bool, role: RoleLook
    ) -> PixelSprite {
        let full = composePerson(
            frames: [PersonArt.frameA, PersonArt.frameABlink],
            headOffsets: [0, 0], appearance: appearance, isFounder: isFounder, role: role
        )
        return crop(full, x: portraitInsetX, y: 1, width: portraitWidth, height: portraitHeight)
    }

    private static let portraitWidth = 10
    private static let portraitHeight = 10
    private static let portraitInsetX = 2

    /// A rectangular crop of every frame of a sprite, keeping the palette.
    private static func crop(_ sprite: PixelSprite, x: Int, y: Int, width: Int, height: Int) -> PixelSprite {
        let frames = sprite.frames.map { frame -> [String] in
            (y..<(y + height)).map { row -> String in
                guard row >= 0, row < frame.count else { return String(repeating: " ", count: width) }
                let chars = Array(frame[row])
                return String((x..<(x + width)).map { $0 >= 0 && $0 < chars.count ? chars[$0] : " " })
            }
        }
        return PixelSprite(frames: frames, palette: sprite.palette)
    }

    /// Dumbbell workout: arms down / arms up. Internal — the composer uses it
    /// for `.exercising`.
    static func exercisingPerson(appearance: CharacterAppearance, isFounder: Bool) -> PixelSprite {
        composePerson(
            frames: [HomePersonArt.exerciseDown, HomePersonArt.exerciseUp],
            headOffsets: [0, 0], appearance: appearance, isFounder: isFounder,
            role: isFounder ? .founder : .none
        )
    }

    /// Which role accessories hang off the head rather than the torso, and
    /// so travel with a head bob or a slump.
    private static func isHeadAccessory(_ role: RoleLook) -> Bool {
        switch role {
        case .qa, .designer, .marketer: true
        case .none, .founder, .lawyer, .hr, .ops: false
        }
    }

    /// Shared assembly. Layers, back to front: base pose, hair, beard,
    /// outfit, glasses, role accessory, held prop. Each layer takes the
    /// frame's own head or torso offset, so everything rides a bob together.
    private static func composePerson(
        frames: [[String]],
        headOffsets: [Int],
        torsoOffsets: [Int]? = nil,
        appearance: CharacterAppearance,
        isFounder: Bool,
        role: RoleLook = .none,
        sleeping: Bool = false,
        mirrored: Bool = false,
        props: [[String]] = []
    ) -> PixelSprite {
        let hair = PersonArt.hairOverlays[appearance.hairStyle % PersonArt.hairOverlays.count]
        let outfit = isFounder
            ? PersonArt.hoodieOverlay
            : PersonArt.outfitOverlays[appearance.outfit % PersonArt.outfitOverlays.count]
        let roleOverlay = PersonArt.roleOverlay(role)

        let composed = frames.enumerated().map { index, frame -> [String] in
            let head = headOffsets[min(index, headOffsets.count - 1)]
            let torso = torsoOffsets.map { $0[min(index, $0.count - 1)] } ?? 0
            var grid = PixelGrid.overlay(base: frame, top: hair, offsetY: head)
            if appearance.hasBeard, !sleeping {
                grid = PixelGrid.overlay(base: grid, top: PersonArt.beardOverlay, offsetY: head)
            }
            if !sleeping {
                grid = PixelGrid.overlay(base: grid, top: outfit, offsetY: torso)
                if let style = appearance.glasses {
                    grid = PixelGrid.overlay(
                        base: grid,
                        top: PersonArt.glassesOverlays[style % PersonArt.glassesOverlays.count],
                        offsetY: head
                    )
                }
                if let roleOverlay {
                    grid = PixelGrid.overlay(
                        base: grid, top: roleOverlay,
                        offsetY: isHeadAccessory(role) ? head : torso
                    )
                }
            }
            if index < props.count {
                grid = PixelGrid.overlay(base: grid, top: props[index], offsetY: torso)
            }
            return mirrored ? grid.map { String($0.reversed()) } : grid
        }
        return PixelSprite(frames: composed, palette: personPalette(appearance, isFounder: isFounder))
    }

    /// Every character an authored person grid can use, resolved for one
    /// appearance. Fixed tones come from the master palette; only skin, hair
    /// and shirt vary per person.
    static func personPalette(
        _ appearance: CharacterAppearance, isFounder: Bool = false
    ) -> [Character: RGBA] {
        let skin = Palettes.skinTones[appearance.skinTone % Palettes.skinTones.count]
        let hairColor = Palettes.hairColors[appearance.hairColor % Palettes.hairColors.count]
        // The founder's whole top is the hoodie, not a shirt with a collar
        // drawn on it — that is what makes them findable in a crowd of forty.
        let shirt = isFounder
            ? (base: Palettes.hoodie, shade: Palettes.hoodieShade)
            : Palettes.shirtColors[appearance.shirtColor % Palettes.shirtColors.count]
        return [
            "O": Palettes.outline,
            "E": Palettes.eye,
            "P": Palettes.pants,
            "C": Palettes.chair,
            "K": HomePalette.shoe,
            "D": Palettes.hoodie,
            "d": Palettes.hoodieShade,
            "M": HomePalette.metal,
            "W": HomePalette.babyBlanket, "w": HomePalette.babyBlanketShade,
            "B": HomePalette.blanket, "b": HomePalette.blanketShade,
            "N": Palettes.ink[3], "n": Palettes.lens,
            "Q": Palettes.stone[0],
            "V": Palettes.ink[1], "v": Palettes.ink[2],
            "R": Palettes.ember[2], "r": Palettes.ember[3],
            "G": Palettes.moss[2], "g": Palettes.moss[3],
            "X": Palettes.sand[1], "x": Palettes.sand[2],
            "Y": Palettes.gold[1],
            "I": Palettes.indigo[2],
            "S": skin.base, "s": skin.shade,
            "H": hairColor.base, "h": hairColor.shade,
            "T": shirt.base, "t": shirt.shade,
        ]
    }

    // MARK: - Child & baby

    /// A small child, 8×13, two frames (ground / one pixel up = bounce).
    public static func child(appearance: CharacterAppearance) -> PixelSprite {
        let hair = HomePersonArt.childHairOverlays[appearance.hairStyle % HomePersonArt.childHairOverlays.count]
        let grounded = PixelGrid.overlay(base: HomePersonArt.childBody, top: hair, offsetY: 1)
        let airborne = Array(grounded.dropFirst()) + [String(repeating: " ", count: grounded[0].count)]
        return PixelSprite(frames: [grounded, airborne], palette: personPalette(appearance))
    }

    /// The swaddled baby that lives in the crib, 10×6, two rocking frames.
    public static func baby() -> PixelSprite {
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": HomePalette.babyBlanket, "w": HomePalette.babyBlanketShade,
            "S": HomePalette.babySkin, "s": HomePalette.babySkinShade,
        ]
        return PixelSprite(frames: [HomePersonArt.babyA, HomePersonArt.babyB], palette: palette)
    }

    // MARK: - Hand-held extras (internal)

    /// Game controller, 9×4, two tilt frames.
    static func controller() -> PixelSprite {
        let a = [
            "OOOOOOOO ",
            "OKRKKBKO ",
            "OKKKKKKO ",
            " OO  OO  ",
        ]
        let b = [
            " OOOOOOOO",
            " OKRKKBKO",
            " OKKKKKKO",
            "  OO  OO ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "K": Palettes.ink[1],
            "R": Palettes.ember[2],
            "B": Palettes.indigo[2],
        ]
        return PixelSprite(frames: [a, b], palette: palette)
    }

    /// An open laptop, 12x8, screen glowing (two frames) - the object the
    /// founder falls asleep next to on a crunch week.
    static func laptop() -> PixelSprite {
        func frame(_ screen: Character) -> [String] {
            let band = String(repeating: screen, count: 8)
            return [
                " OOOOOOOOOO ",
                " O" + band + "O ",
                " O" + band + "O ",
                " O" + band + "O ",
                " OOOOOOOOOO ",
                "OMMMMMMMMMMO",
                "OmmmmmmmmmmO",
                "OOOOOOOOOOOO",
            ]
        }
        return PixelSprite(frames: [frame("G"), frame("g")], palette: [
            "O": Palettes.outline,
            "G": Palettes.sky[3],
            "g": Palettes.sky[2],
            "M": Palettes.stone[2],
            "m": Palettes.stone[3],
        ])
    }

    /// An open paperback, 8×5.
    static func book() -> PixelSprite {
        let grid = [
            "OOOOOOOO",
            "OWwWWwWO",
            "OWWWOWWO",
            "OWwWOwWO",
            "ORRRRRRO",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": Palettes.stone[0],
            "w": Palettes.clay[1],
            "R": Palettes.ember[3],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    // MARK: - Home props

    public enum HomePropName: String, CaseIterable, Sendable {
        case bed, couch, tv, diningTable, yogaMat, dumbbells, bookshelf, armchair, crib, fridge, lamp, windowNight,
             suitcase, plantHome, fireplace, skylineWindow
        // v2: the props that let the room tell you how life is going.
        case stove, laundryPile, deadPlant, flowerVase, takeoutBoxes, catBed
    }

    public static func homeProp(_ name: HomePropName) -> PixelSprite {
        switch name {
        case .bed: bedSprite()
        case .couch: couchSprite()
        case .tv: tvSprite()
        case .diningTable: diningTableSprite()
        case .yogaMat: yogaMatSprite()
        case .dumbbells: dumbbellsSprite()
        case .bookshelf: bookshelfSprite()
        case .armchair: armchairSprite()
        case .crib: cribSprite()
        case .fridge: fridgeSprite()
        case .lamp: lampSprite()
        case .windowNight: windowNightSprite()
        case .suitcase: suitcaseSprite()
        case .plantHome: plantHomeSprite()
        case .fireplace: fireplaceSprite()
        case .skylineWindow: skylineWindowSprite()
        case .stove: stoveSprite()
        case .laundryPile: laundryPileSprite()
        case .deadPlant: deadPlantSprite()
        case .flowerVase: flowerVaseSprite()
        case .takeoutBoxes: takeoutBoxesSprite()
        case .catBed: catBedSprite()
        }
    }

    // MARK: v2 props

    /// Kitchen range with an oven window and a pan on the hob, 16×18. Two
    /// frames: the steam curls off the pan.
    private static func stoveSprite() -> PixelSprite {
        func frame(_ steam: [String]) -> [String] {
            var grid = [
                "                ",
                "                ",
                "                ",
                "OOOOOOOOOOOOOOOO",
                "OMMMMMMMMMMMMMMO",
                "OMKKMMMMMMKKKKMO",
                "OOOOOOOOOOOOOOOO",
                "OMMMMMMMMMMMMMMO",
                "OMOOOOOOOOOOOOMO",
                "OMOKKKKKKKKKKOMO",
                "OMOKYYKKKKKKKOMO",
                "OMOKYYYKKKKKKOMO",
                "OMOKKKKKKKKKKOMO",
                "OMOOOOOOOOOOOOMO",
                "OMMMMMMMMMMMMMMO",
                "OMMMMMMMMMMMMMMO",
                "OOOOOOOOOOOOOOOO",
                " OO          OO ",
            ]
            grid = PixelGrid.overlay(base: grid, top: [
                "OOOOOOO",
                "OSSSSSO",
                "OOOOOOO",
            ], offsetX: 1, offsetY: 3)
            return PixelGrid.overlay(base: grid, top: steam, offsetX: 2, offsetY: 0)
        }
        let a = frame([" g g ", "  g  ", " g g "])
        let b = frame(["  g  ", " g g ", "  g  "])
        return PixelSprite(frames: [a, b], palette: [
            "O": Palettes.outline,
            "M": Palettes.stone[2],
            "K": Palettes.ink[3],
            "Y": Palettes.ember[2],
            "S": Palettes.stone[3],
            "g": Palettes.translucent(Palettes.stone[0], 130),
        ])
    }

    /// A heap of unwashed laundry, 18×9 — the room's honest opinion of how
    /// the week went.
    private static func laundryPileSprite() -> PixelSprite {
        let grid = [
            "      OOOO        ",
            "    OOAAAAOO      ",
            "  OOAAAABBBAOO    ",
            " OAAABBBBBAAAAO   ",
            "OABBBAAAACCCAAAO  ",
            "OAAAACCCAAAABBBAO ",
            "OCCAAAABBBAAACCAO ",
            " OOCCCAAAACCAAOO  ",
            "   OOOOOOOOOOO    ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "A": Palettes.stone[1],
            "B": Palettes.teal[2],
            "C": Palettes.ember[2],
        ])
    }

    /// A plant nobody watered, 8×12: brown leaves on the floor.
    private static func deadPlantSprite() -> PixelSprite {
        let grid = [
            "        ",
            "   L    ",
            "  Ll    ",
            "   lL   ",
            "    l   ",
            "   ll   ",
            "   OO   ",
            " OOOOOO ",
            " OWWWWO ",
            " OWwwWO ",
            "  OWWO  ",
            " lOOOOl ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "L": Palettes.sand[3],
            "l": Palettes.sand[4],
            "W": Palettes.stone[1],
            "w": Palettes.stone[2],
        ])
    }

    /// Cut flowers in a vase, 8×12 — the tidy, cared-for version of the
    /// same corner.
    private static func flowerVaseSprite() -> PixelSprite {
        let grid = [
            "  R  P  ",
            " RRR PP ",
            "  RGGP  ",
            "   GG   ",
            "  GGGG  ",
            "   GG   ",
            "   GG   ",
            "  OOOO  ",
            "  OWWO  ",
            "  OWwO  ",
            "  OWWO  ",
            "  OOOO  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "R": Palettes.ember[2],
            "P": Palettes.plum[1],
            "G": Palettes.moss[2],
            "W": Palettes.sky[1],
            "w": Palettes.sky[2],
        ])
    }

    /// Stacked takeaway cartons, 14×8: dinner on a crunch week.
    private static func takeoutBoxesSprite() -> PixelSprite {
        let grid = [
            "   OOOOOO     ",
            "   OWWRWO     ",
            "   OWWWWO     ",
            "OOOOOOOOOOOO  ",
            "OWWRWWWWWWWO  ",
            "OWWWWWWWWWWO  ",
            "OWWWWWWWWWWO  ",
            "OOOOOOOOOOOO  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.stone[0],
            "R": Palettes.ember[2],
        ])
    }

    /// A round cat bed, 14×7.
    private static func catBedSprite() -> PixelSprite {
        let grid = [
            "   OOOOOOOO   ",
            " OOBBBBBBBBOO ",
            "OBBbbbbbbbbBBO",
            "OBbbbbbbbbbbBO",
            "OBBbbbbbbbbBBO",
            " OOBBBBBBBBOO ",
            "   OOOOOOOO   ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "B": Palettes.plum[2],
            "b": Palettes.plum[3],
        ])
    }

    // MARK: - The cat

    /// What the household cat is up to.
    public enum CatPose: String, Sendable, CaseIterable {
        /// Curled up asleep; the tail twitches.
        case sleeping
        /// Padding across the floor, two frames.
        case walking
    }

    /// The household cat, 14×8. Arrives with the house and never leaves.
    public static func cat(_ pose: CatPose = .sleeping) -> PixelSprite {
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "F": Palettes.sand[3],
            "f": Palettes.sand[4],
            "E": Palettes.moss[1],
            "N": Palettes.plum[1],
        ]
        switch pose {
        case .sleeping:
            let a = [
                "              ",
                "    OOOOOO    ",
                "  OOFFFFFFOO  ",
                " OFFFFFFFFFFO ",
                "OFFffffffffFFO",
                "OFFFFFFFFFFFFO",
                " OOFFFFFFFFOO ",
                "   OOOOOOOO   ",
            ]
            var b = a
            b[6] = " OOFFFFFFFFOOf"
            b[7] = "   OOOOOOOO Of"
            return PixelSprite(frames: [a, b], palette: palette)
        case .walking:
            let a = [
                " OO        OO ",
                "OEOOOOOOOOOOfO",
                "OFFFFFFFFFFFfO",
                "OFFffffffffFFO",
                "OFFFFFFFFFFFFO",
                "OOOOOOOOOOOOOO",
                " OO      OO   ",
                " OO      OO   ",
            ]
            var b = a
            b[6] = "  OO    OO    "
            b[7] = "  OO    OO    "
            return PixelSprite(frames: [a, b], palette: palette)
        }
    }

    /// A child's crayon drawing, taped up, 10×10. Goes on the fridge after a
    /// family day.
    public static func kidDrawing() -> PixelSprite {
        let grid = [
            "T        T",
            "OWWWWWWWWO",
            "OWWYYYWWWO",
            "OWYYYYYWWO",
            "OWWYYYWWWO",
            "OWWWGWWWWO",
            "OWGGGGGWWO",
            "OWWWGWWWWO",
            "OWWGWGWWWO",
            "OOOOOOOOOO",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "W": Palettes.stone[0],
            "Y": Palettes.gold[2],
            "G": Palettes.moss[2],
            "T": Palettes.translucent(Palettes.stone[0], 150),
        ])
    }

    /// Side-view bed, 30×14: headboard left, pillow, mattress, wooden frame.
    /// A `.lying` person goes at (x + 2, y − 1) so the head rests on the
    /// pillow and the blanket covers the mattress.
    private static func bedSprite() -> PixelSprite {
        let grid = [
            " OOO                          ",
            "OHHHO                         ",
            "OHhHO                         ",
            "OHHHO  OOOOOOOOOO             ",
            "OHHHO OWWWWWWWWWWO            ",
            "OHHHOOWWwwwwwwwwWOOOOOOOOOOOOO",
            "OHHHOMMMMMMMMMMMMMMMMMMMMMMMMO",
            "OHHHOMmMMMMMMMMMMMMMMMMMMMMmMO",
            "OHHHOMMMMMMMMMMMMMMMMMMMMMMMMO",
            "OHHHOMMMMMMMMMMMMMMMMMMMMMMMMO",
            "OHHHOOOOOOOOOOOOOOOOOOOOOOOOOO",
            "OHhHOFFFFFFFFFFFFFFFFFFFFFFFFO",
            "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOO",
            " OO                        OO ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "H": HomePalette.wood, "h": HomePalette.woodShade,
            "F": HomePalette.woodShade,
            "W": HomePalette.linen, "w": HomePalette.linenShade,
            "M": HomePalette.sheet, "m": HomePalette.sheetShade,
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Two-seater couch, 34×14. Seat slots for `.seatedCouch` people are at
    /// x + 3 and x + 17, y − 6.
    private static func couchSprite() -> PixelSprite {
        let back = "   O" + String(repeating: "U", count: 26) + "O   "
        let grid = [
            "   " + String(repeating: "O", count: 28) + "   ",
            back,
            "   Ou" + String(repeating: "U", count: 24) + "uO   ",
            back,
            back,
            "OOOO" + String(repeating: "U", count: 26) + "OOOO",
            "OUUO" + String(repeating: "u", count: 13) + "O" + String(repeating: "u", count: 12) + "OUUO",
            "OUUO" + String(repeating: "U", count: 13) + "O" + String(repeating: "U", count: 12) + "OUUO",
            "OUUO" + String(repeating: "U", count: 13) + "O" + String(repeating: "U", count: 12) + "OUUO",
            "OUUO" + String(repeating: "U", count: 13) + "O" + String(repeating: "U", count: 12) + "OUUO",
            "OUuO" + String(repeating: "u", count: 13) + "O" + String(repeating: "u", count: 12) + "OuUO",
            String(repeating: "O", count: 34),
            "O" + String(repeating: "F", count: 32) + "O",
            " OO" + String(repeating: " ", count: 28) + "OO ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "U": HomePalette.couch, "u": HomePalette.couchShade,
            "F": HomePalette.woodShade,
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Flat-screen TV on a low cabinet, 22×16, with a two-frame screen glow
    /// (the 1px halo only shows on the bright frame).
    private static func tvSprite() -> PixelSprite {
        func screen(_ s: Character, halo: Character) -> [String] {
            let h = String(halo)
            return [
                h + String(repeating: halo, count: 20) + h,
                h + String(repeating: "O", count: 20) + h,
                h + "OB" + String(repeating: s, count: 16) + "BO" + h,
                h + "OB" + String(repeating: s, count: 16) + "BO" + h,
                h + "OB" + String(repeating: s, count: 7) + "Q" + String(repeating: s, count: 8) + "BO" + h,
                h + "OB" + String(repeating: s, count: 16) + "BO" + h,
                h + "OB" + String(repeating: s, count: 16) + "BO" + h,
                h + "OB" + String(repeating: s, count: 16) + "BO" + h,
                h + String(repeating: "O", count: 20) + h,
                h + String(repeating: halo, count: 20) + h,
                "         OOOO         ",
                "  OOOOOOOOOOOOOOOOOO  ",
                "  OFFFFFFFFFFFFFFFFO  ",
                "  OFFFOFFFFFFFFFFFFO  ",
                "  OOOOOOOOOOOOOOOOOO  ",
                "   OO            OO   ",
            ]
        }
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "B": Palettes.hairColors[0].base,
            "G": Palettes.sky[3],
            "g": Palettes.sky[1],
            "Q": Palettes.gold[1],
            "L": Palettes.translucent(Palettes.sky[1], 90),
            "F": HomePalette.woodShade,
        ]
        return PixelSprite(frames: [screen("G", halo: " "), screen("g", halo: "L")], palette: palette)
    }

    /// Dining table with two place settings and a candle, 30×12. Seated
    /// people go at (x + 2, y − 11) and (x + 16, y − 11); the table top then
    /// covers their laps like an office desk.
    private static func diningTableSprite() -> PixelSprite {
        let grid = [
            "              Y               ",
            "              C               ",
            "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOO",
            "OWWWWPPPPWWWWWCWWWWWWPPPPWWWWO",
            "OWWWWPggPWWWWWCWWWWWWPggPWWWWO",
            "OWWWWPPPPWWWWWWWWWWWWPPPPWWWWO",
            "OwwwwwwwwwwwwwwwwwwwwwwwwwwwwO",
            "OOOOOOOOOOOOOOOOOOOOOOOOOOOOOO",
            "  OwO                    OwO  ",
            "  OwO                    OwO  ",
            "  OwO                    OwO  ",
            "  OOO                    OOO  ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": HomePalette.wood, "w": HomePalette.woodShade,
            "P": Palettes.stone[0],
            "g": Palettes.ember[2],
            "C": Palettes.sand[0],
            "Y": Palettes.gold[2],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Rolled-out yoga mat, 24×5.
    private static func yogaMatSprite() -> PixelSprite {
        let grid = [
            " OOOOOOOOOOOOOOOOOOOOOO ",
            "OVVVVVVVVVVVVVVVVVVVVVVO",
            "OVvvvvvvvvvvvvvvvvvvvvVO",
            "OVVVVVVVVVVVVVVVVVVVVVVO",
            " OOOOOOOOOOOOOOOOOOOOOO ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "V": Palettes.indigo[2],
            "v": Palettes.indigo[3],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// A dumbbell on the floor, 12×4.
    private static func dumbbellsSprite() -> PixelSprite {
        let grid = [
            "OOO      OOO",
            "OMMOOOOOOMMO",
            "OmmOMMMMOmmO",
            "OOO      OOO",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "M": HomePalette.metal,
            "m": HomePalette.metalShade,
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Bookshelf, 16×22: three shelves of colored spines.
    private static func bookshelfSprite() -> PixelSprite {
        let plank = "O" + String(repeating: "W", count: 14) + "O"
        let shelves = ["RRGGBBYYRRPPGG", "BBYYRRGGPPBBYY", "GGPPBBRRYYGGRR"]
        var grid = [String(repeating: "O", count: 16), plank]
        for spines in shelves {
            for row in 0..<5 {
                // Books stand a little shorter on the top row so the shelf reads.
                let visible = row == 0 ? " " + spines.dropFirst() : Substring(spines)
                grid.append("O" + visible + "O")
            }
            grid.append(plank)
        }
        grid.append(String(repeating: "O", count: 16))
        grid.append("  OO        OO  ")
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": HomePalette.wood,
            "R": Palettes.ember[3],
            "G": Palettes.teal[2],
            "B": Palettes.indigo[2],
            "Y": Palettes.gold[2],
            "P": Palettes.plum[1],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Reading armchair, 20×16. Seat slot for a `.seatedCouch` person at
    /// (x + 3, y − 4).
    private static func armchairSprite() -> PixelSprite {
        let back = "   O" + String(repeating: "A", count: 12) + "O   "
        let grid = [
            "   " + String(repeating: "O", count: 14) + "   ",
            back,
            "   Oa" + String(repeating: "A", count: 10) + "aO   ",
            back,
            back,
            back,
            back,
            "OOOO" + String(repeating: "A", count: 12) + "OOOO",
            "OAAO" + String(repeating: "a", count: 12) + "OAAO",
            "OAAO" + String(repeating: "A", count: 12) + "OAAO",
            "OAAO" + String(repeating: "A", count: 12) + "OAAO",
            "OAAO" + String(repeating: "A", count: 12) + "OAAO",
            "OAaO" + String(repeating: "a", count: 12) + "OaAO",
            String(repeating: "O", count: 20),
            "O" + String(repeating: "F", count: 18) + "O",
            " OO" + String(repeating: " ", count: 14) + "OO ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "A": HomePalette.armchair, "a": HomePalette.armchairShade,
            "F": HomePalette.woodShade,
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Crib, 18×14: tall back rail, mattress, low front rail. The baby
    /// bundle sits at (x + 4, y + 4).
    private static func cribSprite() -> PixelSprite {
        let bars = "O" + String(repeating: "WN", count: 8) + "O"
        let grid = [
            String(repeating: "O", count: 18),
            "O" + String(repeating: "W", count: 16) + "O",
            bars, bars, bars, bars,
            "O" + String(repeating: "M", count: 16) + "O",
            "O" + String(repeating: "m", count: 16) + "O",
            "O" + String(repeating: "W", count: 16) + "O",
            bars, bars,
            "O" + String(repeating: "W", count: 16) + "O",
            String(repeating: "O", count: 18),
            " OO            OO ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": HomePalette.linen,
            "N": Palettes.ink[2],
            "M": HomePalette.sheet, "m": HomePalette.sheetShade,
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Fridge, 12×22, with a couple of magnets.
    private static func fridgeSprite() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOO",
            "OFFFFFFFFFFO",
            "OFFFFFFFFOFO",
            "OFFFFFFFFOFO",
            "OFFFFFFFFFFO",
            "OffffffffffO",
            "OOOOOOOOOOOO",
            "OFFFFFFFFFFO",
            "OFFFFFFFFOFO",
            "OFRRFFFFFOFO",
            "OFRRFFFFFOFO",
            "OFFFFFFFFOFO",
            "OFFFFGGFFFFO",
            "OFFFFGGFFFFO",
            "OFFFFFFFFFFO",
            "OFFFFFFFFFFO",
            "OFFFFFFFFFFO",
            "OFFFFFFFFFFO",
            "OFFFFFFFFFFO",
            "OffffffffffO",
            "OOOOOOOOOOOO",
            " OO      OO ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "F": Palettes.stone[1],
            "f": Palettes.stone[2],
            "R": Palettes.ember[2],
            "G": Palettes.moss[2],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Floor lamp, 12×20, with a soft amber halo that breathes (two frames).
    private static func lampSprite() -> PixelSprite {
        func frame(_ g: Character) -> [String] {
            let h = String(g)
            return [
                "  " + h + "OOOOOO" + h + "  ",
                " " + h + "OLLLLLLO" + h + " ",
                " " + h + "OLLLLLLO" + h + " ",
                h + h + "OLllllLO" + h + h,
                h + h + "OOOOOOOO" + h + h,
                h + h + h + "  OO  " + h + h + h,
                " " + h + h + "  OO  " + h + h + " ",
                "  " + h + "  OO  " + h + "  ",
                "     OO     ",
                "     OO     ",
                "     OO     ",
                "     OO     ",
                "     OO     ",
                "     OO     ",
                "     OO     ",
                "     OO     ",
                "     OO     ",
                "    OOOO    ",
                "   OOOOOO   ",
                "   OOOOOO   ",
            ]
        }
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "L": HomePalette.lampShade, "l": HomePalette.lampShadeShade,
            "G": Palettes.translucent(Palettes.gold[1], 70),
            "g": Palettes.translucent(Palettes.gold[1], 95),
        ]
        return PixelSprite(frames: [frame("G"), frame("g")], palette: palette)
    }

    /// Night window, 12×14: navy sky, a moon, stars, city silhouette.
    private static func windowNightSprite() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOO",
            "ONNNNONNNNNO",
            "ONNMMONNSNNO",
            "ONMMMONNNNNO",
            "ONMMMONNNNNO",
            "ONNMMONSNNNO",
            "OOOOOOOOOOOO",
            "ONNNNONNNNNO",
            "ONSNNONNNNNO",
            "ONNNNONNNSNO",
            "ONnNNOnNNnNO",
            "OnnnnOnnnnnO",
            "OOOOOOOOOOOO",
            "OOOOOOOOOOOO",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "N": HomePalette.nightSky,
            "n": HomePalette.nightCity,
            "M": HomePalette.moon,
            "S": HomePalette.star,
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Travel suitcase, 12×10, with a sticker.
    private static func suitcaseSprite() -> PixelSprite {
        let grid = [
            "    OOOO    ",
            "    O  O    ",
            "OOOOOOOOOOOO",
            "OBBBBBBBBBBO",
            "OBBYYBBBBBBO",
            "OBBYYBBBBBBO",
            "OOOOOOOOOOOO",
            "OBBBBBBBBBBO",
            "OOOOOOOOOOOO",
            " OO      OO ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "B": Palettes.ember[3],
            "Y": Palettes.gold[2],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Tall leafy plant in a pale pot, 8×12.
    private static func plantHomeSprite() -> PixelSprite {
        let grid = [
            "   LL   ",
            "  LLLL  ",
            " LLlLlL ",
            "LLlLLLlL",
            " LLLLLL ",
            "  LlLL  ",
            "   OO   ",
            " OOOOOO ",
            " OWWWWO ",
            " OWwwWO ",
            "  OWWO  ",
            "  OOOO  ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "L": Palettes.moss[2],
            "l": Palettes.moss[3],
            "W": Palettes.clay[0],
            "w": Palettes.clay[1],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Brick fireplace with a mantel, 24×20, two flicker frames.
    private static func fireplaceSprite() -> PixelSprite {
        func frame(flames: [String]) -> [String] {
            var grid = [
                String(repeating: "O", count: 24),
                "O" + String(repeating: "W", count: 22) + "O",
                String(repeating: "O", count: 24),
            ]
            // Rows 3–16: brick pillars either side of the dark firebox.
            for y in 0..<14 {
                let brick = y.isMultiple(of: 2) ? "BbBB" : "BBbB"
                let inner: String
                let flameRow = y - (14 - flames.count)
                if flameRow >= 0 {
                    inner = flames[flameRow]
                } else {
                    inner = String(repeating: "K", count: 14)
                }
                grid.append("O" + brick + inner + brick + "O")
            }
            grid.append("O" + String(repeating: "L", count: 22) + "O") // logs / grate
            grid.append(String(repeating: "O", count: 24))
            grid.append("O" + String(repeating: "H", count: 22) + "O") // hearth stone
            return grid
        }
        let a = frame(flames: [
            "KKKKKKYKKKKKKK",
            "KKKKKYYYKKYKKK",
            "KKKYKYYYKYYKKK",
            "KKYYYRYYYYYYKK",
            "KRYYRRRYYRRYRK",
            "RRRRRRRRRRRRRR",
        ])
        let b = frame(flames: [
            "KKKKKKKKKYKKKK",
            "KKKYKKKYYYKKKK",
            "KKYYKKYYYYYKYK",
            "KKYYYYYRYYYYYK",
            "KRYRRYRRRYRRRK",
            "RRRRRRRRRRRRRR",
        ])
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": HomePalette.wood,
            "B": Palettes.skinTones[3].shade, "b": Palettes.skinTones[4].base,
            "K": Palettes.hairColors[0].shade,
            "Y": Palettes.gold[2],
            "R": Palettes.ember[2],
            "L": Palettes.hairColors[1].base,
            "H": Palettes.stone[3],
        ]
        return PixelSprite(frames: [a, b], palette: palette)
    }

    /// Panoramic skyline window, 172×18: four panes behind slim mullions,
    /// a navy sky with one moon and scattered stars over a row of towers
    /// with lit windows. Built procedurally from fixed tower/star tables so
    /// it stays deterministic.
    private static func skylineWindowSprite() -> PixelSprite {
        let width = 172, height = 18
        let ground = 15 // street line row; towers rise from the row above
        // Tower widths/heights cycle through fixed tables across the pane.
        let widths = [3, 4, 2, 5, 3, 4, 6, 2, 3, 5, 4, 3]
        let tops = [9, 6, 8, 4, 10, 7, 5, 8, 11, 6, 9, 5]
        var towers: [(x: Int, w: Int, top: Int)] = []
        var cursor = 2
        var i = 0
        while cursor < width - 2 {
            let w = min(widths[i % widths.count], width - 2 - cursor)
            towers.append((cursor, w, tops[i % tops.count]))
            cursor += w + 1
            i += 1
        }
        let stars: [(Int, Int)] = (0..<14).map { ((($0 * 37) % 168) + 2, 2 + ($0 * 5) % 6) }
        let moon = (x: 150, y: 3)
        let mullions = [43, 86, 129]

        var rows: [String] = []
        for y in 0..<height {
            var chars: [Character] = []
            for x in 0..<width {
                if x == 0 || y == 0 || x == width - 1 || y >= height - 2 || mullions.contains(x) {
                    chars.append("O")
                    continue
                }
                if y == ground {
                    chars.append("n")
                    continue
                }
                if let tower = towers.first(where: { x >= $0.x && x < $0.x + $0.w && y >= $0.top }) {
                    let lit = (x - tower.x).isMultiple(of: 2) && (y - tower.top) % 2 == 1 && (x * 7 + y * 3) % 5 != 0
                    chars.append(lit ? "Y" : "n")
                    continue
                }
                let mx = x - moon.x, my = y - moon.y
                if (0...3).contains(mx) && (0...3).contains(my) && !(mx == 3 && (1...2).contains(my)) && !(mx == 0 && (my == 0 || my == 3)) {
                    chars.append("M")
                    continue
                }
                chars.append(stars.contains { $0 == (x, y) } ? "S" : "N")
            }
            rows.append(String(chars))
        }
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "N": HomePalette.nightSky,
            "n": HomePalette.nightCity,
            "M": HomePalette.moon,
            "S": HomePalette.star,
            "Y": Palettes.gold[1],
        ]
        return PixelSprite(frames: [rows], palette: palette)
    }

    // MARK: - Bubbles

    /// Mood bubble on the office bubble canvas (10×9): heart for `.great`,
    /// storm cloud for `.low`, fully transparent for `.okay`.
    public static func moodBubble(_ mood: MoodLevel) -> PixelSprite {
        let width = 10, height = 9
        let grid: [String]
        switch mood {
        case .okay:
            return PixelSprite(frames: [Array(repeating: String(repeating: " ", count: width), count: height)], palette: [:])
        case .great:
            grid = [
                " OOOOOOOO ",
                "OWWWWWWWWO",
                "OWWRRWRRWO",
                "OWWRRRRRWO",
                "OWWWRRRWWO",
                "OWWWWRWWWO",
                " OOWWOOOO ",
                "  OWO     ",
                "   O      ",
            ]
        case .low:
            grid = [
                " OOOOOOOO ",
                "OWWWGGGWWO",
                "OWGGGGGGWO",
                "OWGgggggWO",
                "OWWBWBWBWO",
                "OWWWWWWWWO",
                " OOWWOOOO ",
                "  OWO     ",
                "   O      ",
            ]
        }
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": Palettes.stone[0],
            "R": Palettes.ember[2],
            "G": Palettes.stone[3], "g": Palettes.ink[0],
            "B": Palettes.sky[2],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Drifting "z Z" on the bubble canvas (10×9), two frames.
    public static func zzzBubble() -> PixelSprite {
        let a = [
            "          ",
            "     ZZZZ ",
            "       Z  ",
            "      Z   ",
            "     ZZZZ ",
            "          ",
            "  zzz     ",
            "   z      ",
            "  zzz     ",
        ]
        let b = [
            "      ZZZZ",
            "        Z ",
            "       Z  ",
            "      ZZZZ",
            "          ",
            "   zzz    ",
            "    z     ",
            "   zzz    ",
            "          ",
        ]
        let palette: [Character: RGBA] = [
            "Z": Palettes.stone[0],
            "z": Palettes.indigo[0],
        ]
        return PixelSprite(frames: [a, b], palette: palette)
    }
}

/// The home scenes' named tones. Every one is a master-palette color, so
/// the founder's evening and the founder's office are lit by the same box
/// of crayons.
enum HomePalette {
    static let wood = Palettes.sand[2]
    static let woodShade = Palettes.sand[3]
    static let linen = Palettes.stone[0]
    static let linenShade = Palettes.stone[1]
    static let sheet = Palettes.stone[1]
    static let sheetShade = Palettes.stone[2]
    static let blanket = Palettes.indigo[2]
    static let blanketShade = Palettes.indigo[3]
    static let babyBlanket = Palettes.plum[0]
    static let babyBlanketShade = Palettes.plum[1]
    static let babySkin = Palettes.skinTones[1].base
    static let babySkinShade = Palettes.skinTones[1].shade
    static let couch = Palettes.indigo[2]
    static let couchShade = Palettes.indigo[3]
    static let armchair = Palettes.gold[3]
    static let armchairShade = Palettes.gold[4]
    static let shoe = Palettes.ink[3]
    static let metal = Palettes.stone[2]
    static let metalShade = Palettes.stone[3]
    static let lampShade = Palettes.gold[1]
    static let lampShadeShade = Palettes.gold[2]
    static let nightSky = Palettes.indigo[4]
    static let nightCity = Palettes.ink[4]
    static let moon = Palettes.stone[0]
    static let star = Palettes.gold[0]
}
