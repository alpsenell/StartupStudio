/// Home-scene additions to the sprite factory: extra person poses (the
/// office `seated` pose stays as-is), children, the baby, evening furniture
/// and decor, and the mood / zzz bubbles.
extension SpriteLibrary {
    // MARK: - Poses

    /// Every pose a person sprite can be drawn in.
    ///
    /// The first five are the authored home/office poses. The rest are the
    /// office-life poses WS-C's director needs: in the scaffold they are
    /// *placeholders* mapped onto existing art (walking → the activity
    /// walk cycle, cheer → the arms-up exercise frames, slump/coffee/chat/
    /// carryBox → standing, portrait → a bust cropped out of the seated
    /// frames). WS-D authors the real art behind the same case names, so
    /// nothing downstream has to change.
    public enum PersonPose: String, Sendable, Equatable, CaseIterable {
        case seated, standing, lying, seatedCouch, holdingBaby, exercising
        case walkLeft, walkRight, walkDown, cheer, slump, coffee, chat, carryBox, portrait
    }

    /// A person in a pose. `seated` is the existing office sprite
    /// (3 frames); the other poses are 2-frame (bob / breathe / rock /
    /// step). `role` is the accessory WS-D draws on top — ignored while
    /// the art doesn't exist, so every pose renders exactly as before.
    public static func person(
        appearance: CharacterAppearance,
        pose: PersonPose,
        isFounder: Bool = false,
        role: RoleLook = .none
    ) -> PixelSprite {
        switch pose {
        case .seated:
            return person(appearance: appearance, isFounder: isFounder)
        case .standing:
            return composePerson(
                frames: [HomePersonArt.standingA, HomePersonArt.headBob(HomePersonArt.standingA)],
                hairOffsets: [0, 1], appearance: appearance, isFounder: isFounder
            )
        case .seatedCouch:
            return composePerson(
                frames: [HomePersonArt.seatedCouchA, HomePersonArt.headBob(HomePersonArt.seatedCouchA)],
                hairOffsets: [0, 1], appearance: appearance, isFounder: isFounder
            )
        case .lying:
            // Under the blanket the hoodie is hidden, so the founder flag is moot.
            return composePerson(
                frames: [HomePersonArt.lyingA, HomePersonArt.lyingB],
                hairOffsets: [0, 0], appearance: appearance, isFounder: false, sleeping: true
            )
        case .holdingBaby:
            return composePerson(
                frames: [HomePersonArt.holdingBabyA, HomePersonArt.holdingBabyB],
                hairOffsets: [0, 1], appearance: appearance, isFounder: isFounder
            )
        case .exercising:
            return exercisingPerson(appearance: appearance, isFounder: isFounder)

        // MARK: Placeholders (WS-D authors the art)

        case .walkLeft, .walkRight, .walkDown:
            // One walk cycle for all three directions until WS-D draws the
            // side and front views.
            return ActivitySpriteLibrary.walkingPerson(
                appearance: appearance, isFounder: isFounder
            )
        case .cheer:
            // Arms down / arms up reads as a cheer well enough to block out
            // the celebration timing.
            return exercisingPerson(appearance: appearance, isFounder: isFounder)
        case .slump, .coffee, .chat, .carryBox:
            return composePerson(
                frames: [HomePersonArt.standingA, HomePersonArt.headBob(HomePersonArt.standingA)],
                hairOffsets: [0, 1], appearance: appearance, isFounder: isFounder
            )
        case .portrait:
            return portraitBust(appearance: appearance, isFounder: isFounder)
        }
    }

    /// A 10×10 head-and-shoulders bust cropped out of the seated frames
    /// (open eyes / blink), for UI portraits. The crop keeps the founder's
    /// hoodie collar, so the founder still reads as the founder.
    private static func portraitBust(
        appearance: CharacterAppearance, isFounder: Bool
    ) -> PixelSprite {
        let hair = PersonArt.hairOverlays[appearance.hairStyle % PersonArt.hairOverlays.count]
        let frames = [PersonArt.frameA, PersonArt.frameABlink].map { frame -> [String] in
            var grid = PixelGrid.overlay(base: frame, top: hair)
            if isFounder {
                grid = PixelGrid.overlay(base: grid, top: PersonArt.hoodieOverlay)
            }
            return grid.prefix(Self.portraitHeight).map { row in
                String(row.dropFirst(Self.portraitInsetX).prefix(Self.portraitWidth))
            }
        }
        return PixelSprite(frames: frames, palette: personPalette(appearance))
    }

    private static let portraitWidth = 10
    private static let portraitHeight = 10
    private static let portraitInsetX = 2

    /// Dumbbell workout: arms down / arms up. Internal — the composer uses it
    /// for `.exercising`.
    static func exercisingPerson(appearance: CharacterAppearance, isFounder: Bool) -> PixelSprite {
        composePerson(
            frames: [HomePersonArt.exerciseDown, HomePersonArt.exerciseUp],
            hairOffsets: [0, 0], appearance: appearance, isFounder: isFounder
        )
    }

    /// Shared assembly: hair overlay (per-frame vertical offset so it rides a
    /// head bob), optional founder hoodie, then the appearance palette.
    private static func composePerson(
        frames: [[String]], hairOffsets: [Int], appearance: CharacterAppearance, isFounder: Bool, sleeping: Bool = false
    ) -> PixelSprite {
        let hair = PersonArt.hairOverlays[appearance.hairStyle % PersonArt.hairOverlays.count]
        let composed = frames.enumerated().map { index, frame in
            var grid = PixelGrid.overlay(base: frame, top: hair, offsetY: hairOffsets[index])
            if isFounder {
                grid = PixelGrid.overlay(base: grid, top: PersonArt.hoodieOverlay)
            }
            return grid
        }
        return PixelSprite(frames: composed, palette: personPalette(appearance))
    }

    static func personPalette(_ appearance: CharacterAppearance) -> [Character: RGBA] {
        let skin = Palettes.skinTones[appearance.skinTone % Palettes.skinTones.count]
        let hairColor = Palettes.hairColors[appearance.hairColor % Palettes.hairColors.count]
        let shirt = Palettes.shirtColors[appearance.shirtColor % Palettes.shirtColors.count]
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
            "K": RGBA(r: 96, g: 94, b: 110),
            "R": RGBA(r: 214, g: 86, b: 110),
            "B": RGBA(r: 94, g: 96, b: 206),
        ]
        return PixelSprite(frames: [a, b], palette: palette)
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
            "W": RGBA(r: 246, g: 240, b: 226),
            "w": RGBA(r: 200, g: 192, b: 176),
            "R": RGBA(r: 196, g: 87, b: 78),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    // MARK: - Home props

    public enum HomePropName: String, CaseIterable, Sendable {
        case bed, couch, tv, diningTable, yogaMat, dumbbells, bookshelf, armchair, crib, fridge, lamp, windowNight,
             suitcase, plantHome, fireplace, skylineWindow
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
        }
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
            "B": RGBA(r: 56, g: 54, b: 68),
            "G": RGBA(r: 88, g: 132, b: 196),
            "g": RGBA(r: 150, g: 196, b: 240),
            "Q": RGBA(r: 240, g: 230, b: 160),
            "L": RGBA(r: 150, g: 190, b: 250, a: 90),
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
            "P": RGBA(r: 240, g: 240, b: 244),
            "g": RGBA(r: 214, g: 126, b: 70),
            "C": RGBA(r: 236, g: 226, b: 200),
            "Y": RGBA(r: 255, g: 214, b: 96),
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
            "V": RGBA(r: 116, g: 96, b: 196),
            "v": RGBA(r: 96, g: 78, b: 168),
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
            "R": RGBA(r: 196, g: 87, b: 78),
            "G": RGBA(r: 62, g: 156, b: 138),
            "B": RGBA(r: 94, g: 96, b: 206),
            "Y": RGBA(r: 217, g: 164, b: 65),
            "P": RGBA(r: 217, g: 140, b: 166),
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
            "N": RGBA(r: 60, g: 56, b: 76),
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
            "F": RGBA(r: 214, g: 218, b: 226),
            "f": RGBA(r: 176, g: 180, b: 194),
            "R": RGBA(r: 214, g: 86, b: 110),
            "G": RGBA(r: 96, g: 168, b: 96),
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
            "G": RGBA(r: 255, g: 200, b: 110, a: 70),
            "g": RGBA(r: 255, g: 200, b: 110, a: 95),
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
            "B": RGBA(r: 168, g: 92, b: 66),
            "Y": RGBA(r: 217, g: 164, b: 65),
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
            "L": RGBA(r: 96, g: 168, b: 96),
            "l": RGBA(r: 72, g: 138, b: 76),
            "W": RGBA(r: 226, g: 222, b: 212),
            "w": RGBA(r: 190, g: 184, b: 172),
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
            "B": RGBA(r: 150, g: 84, b: 66), "b": RGBA(r: 126, g: 68, b: 54),
            "K": RGBA(r: 38, g: 30, b: 36),
            "Y": RGBA(r: 255, g: 214, b: 96),
            "R": RGBA(r: 230, g: 120, b: 56),
            "L": RGBA(r: 92, g: 62, b: 44),
            "H": RGBA(r: 120, g: 116, b: 126),
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
            "Y": RGBA(r: 255, g: 214, b: 120),
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
            "W": RGBA(r: 250, g: 250, b: 252),
            "R": RGBA(r: 224, g: 80, b: 104),
            "G": RGBA(r: 134, g: 138, b: 156), "g": RGBA(r: 104, g: 108, b: 128),
            "B": RGBA(r: 96, g: 150, b: 230),
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
            "Z": RGBA(r: 236, g: 240, b: 252),
            "z": RGBA(r: 190, g: 200, b: 236),
        ]
        return PixelSprite(frames: [a, b], palette: palette)
    }
}

/// Fixed evening tones for home furniture: warm wood, cream linen, indigo
/// couch, a mustard armchair, and the night-sky set for windows.
enum HomePalette {
    static let wood = RGBA(r: 172, g: 124, b: 82)
    static let woodShade = RGBA(r: 138, g: 96, b: 62)
    static let linen = RGBA(r: 238, g: 232, b: 220)
    static let linenShade = RGBA(r: 206, g: 198, b: 184)
    static let sheet = RGBA(r: 214, g: 206, b: 196)
    static let sheetShade = RGBA(r: 186, g: 178, b: 168)
    static let blanket = RGBA(r: 98, g: 108, b: 186)
    static let blanketShade = RGBA(r: 80, g: 88, b: 158)
    static let babyBlanket = RGBA(r: 246, g: 226, b: 214)
    static let babyBlanketShade = RGBA(r: 214, g: 186, b: 176)
    static let babySkin = RGBA(r: 240, g: 196, b: 151)
    static let babySkinShade = RGBA(r: 216, g: 168, b: 124)
    static let couch = RGBA(r: 82, g: 94, b: 170)
    static let couchShade = RGBA(r: 66, g: 76, b: 142)
    static let armchair = RGBA(r: 196, g: 140, b: 58)
    static let armchairShade = RGBA(r: 166, g: 116, b: 46)
    static let shoe = RGBA(r: 64, g: 54, b: 50)
    static let metal = RGBA(r: 150, g: 154, b: 168)
    static let metalShade = RGBA(r: 112, g: 116, b: 130)
    static let lampShade = RGBA(r: 252, g: 214, b: 140)
    static let lampShadeShade = RGBA(r: 230, g: 184, b: 110)
    static let nightSky = RGBA(r: 26, g: 32, b: 66)
    static let nightCity = RGBA(r: 16, g: 20, b: 42)
    static let moon = RGBA(r: 250, g: 238, b: 180)
    static let star = RGBA(r: 232, g: 236, b: 252)
}
