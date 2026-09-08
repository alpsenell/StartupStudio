import Foundation

// MARK: - Iteration 9 — L7: the things the founder owns

/// The decor a home can hold: the five shop possessions drawn as objects
/// rather than a list, plus the plant, the record player, the awards
/// pennant, a poster for each season twist and a trophy for each ending.
///
/// Raw values are the engine's decor ids (`TycoonEngine.HomeDecor`), so
/// the app maps one to the other by raw value and nothing has to know
/// both lists. Palette rule as everywhere else: `Palettes` ramps only.
extension SpriteLibrary {
    public enum HomeDecorName: String, CaseIterable, Sendable, Equatable {
        // Bought.
        case espressoMachine, gamingConsole, roadBike, designerWatch, sportsCar
        // Earned.
        case plant, recordPlayer, pennant
        case posterPlatformLaunch = "poster_platformLaunch"
        case posterFundingWinter = "poster_fundingWinter"
        case posterCrashSeason = "poster_crashSeason"
        case posterPoachingSeason = "poster_poachingSeason"
        case posterPressYear = "poster_pressYear"
        case trophyIPO = "trophy_ipo"
        case trophyAcquired = "trophy_acquired"
        case trophyIndependent = "trophy_independent"
        case trophySoldUp = "trophy_soldUp"
        case trophyOusted = "trophy_oustedByBoard"
        case trophyBankruptcy = "trophy_bankruptcy"
        // MARK: Iteration 10 — M5 (morning desk): the streak's three
        case deskSunrise, deskPlaque, deskCentury
        // MARK: end of Iteration 10 — M5
        // MARK: Iteration 11 — N3 (assets, vices and the doctor)
        // The four cars on the drive and the three animals in the room.
        // Raw values are `TycoonEngine.HomeDecor.assetDecorID(_:)`, which
        // is N3's catalog id with an `asset_` in front of it — so the
        // model car on the shelf (`sportsCar`) and the real one outside
        // (`asset_coupe`) can never be the same thing.
        case carHatchback = "asset_hatchback"
        case carEstate = "asset_estate"
        case carCoupe = "asset_coupe"
        case carSupercar = "asset_supercar"
        case petDog = "asset_dog"
        case petCat = "asset_cat"
        case petTortoise = "asset_tortoise"
        // MARK: end of Iteration 11 — N3
    }

    public static func homeDecor(_ name: HomeDecorName) -> PixelSprite {
        switch name {
        case .espressoMachine: espressoMachineSprite()
        case .gamingConsole: gamingConsoleSprite()
        case .roadBike: roadBikeSprite()
        case .designerWatch: designerWatchSprite()
        case .sportsCar: modelCarSprite()
        case .plant: homeProp(.plantHome)
        case .recordPlayer: recordPlayerSprite()
        case .pennant: pennantSprite()
        case .posterPlatformLaunch: posterSprite(.rising, ink: Palettes.teal[2], paper: Palettes.sand[0])
        case .posterFundingWinter: posterSprite(.flat, ink: Palettes.sky[2], paper: Palettes.stone[0])
        case .posterCrashSeason: posterSprite(.falling, ink: Palettes.ember[2], paper: Palettes.sand[1])
        case .posterPoachingSeason: posterSprite(.figures, ink: Palettes.plum[2], paper: Palettes.stone[1])
        case .posterPressYear: posterSprite(.star, ink: Palettes.gold[2], paper: Palettes.sand[0])
        case .trophyIPO: trophySprite(metal: Palettes.gold[2], shine: Palettes.gold[1])
        case .trophyAcquired: trophySprite(metal: Palettes.sky[2], shine: Palettes.sky[1])
        case .trophyIndependent: trophySprite(metal: Palettes.stone[2], shine: Palettes.stone[1])
        case .trophySoldUp: trophySprite(metal: Palettes.teal[3], shine: Palettes.teal[2])
        case .trophyOusted: trophySprite(metal: Palettes.plum[2], shine: Palettes.plum[1])
        case .trophyBankruptcy: trophySprite(metal: Palettes.clay[2], shine: Palettes.clay[1])
        // MARK: Iteration 10 — M5 (morning desk)
        case .deskSunrise: posterSprite(.rising, ink: Palettes.gold[2], paper: Palettes.sand[1])
        case .deskPlaque: trophySprite(metal: Palettes.gold[3], shine: Palettes.sand[0])
        case .deskCentury: posterSprite(.star, ink: Palettes.ember[2], paper: Palettes.sand[0])
        // MARK: end of Iteration 10 — M5
        // MARK: Iteration 11 — N3 (assets, vices and the doctor)
        case .carHatchback: assetCar(.hatchback)
        case .carEstate: assetCar(.estate)
        case .carCoupe: assetCar(.coupe)
        case .carSupercar: assetCar(.supercar)
        case .petDog: assetDog()
        // The house cat has been in the room since iteration 9; adopting
        // one is the founder finally admitting it lives here.
        case .petCat: cat(.sleeping)
        case .petTortoise: assetTortoise()
        // MARK: end of Iteration 11 — N3
        }
    }

    /// The plank a shelf slot draws under whatever is standing on it —
    /// 16×3, and only when the slot is filled, so an empty wall is empty.
    static func decorShelfSprite() -> PixelSprite {
        PixelSprite(frames: [[
            "OOOOOOOOOOOOOOOO",
            "OWWWWWWWWWWWWWWO",
            " O            O ",
        ]], palette: [
            "O": Palettes.outline,
            "W": Palettes.clay[1],
        ])
    }

    // MARK: Bought

    /// Chrome espresso machine, 10×12, two frames: the steam wisp lifts.
    private static func espressoMachineSprite() -> PixelSprite {
        func frame(_ steam: [String]) -> [String] {
            let body = [
                "          ",
                "          ",
                " OOOOOOOO ",
                " OMMMMMMO ",
                " OMKKKKMO ",
                " OMKssKMO ",
                " OMKKKKMO ",
                " OMMMMMMO ",
                " OMMOOMMO ",
                " OMWWWWMO ",
                " OMMMMMMO ",
                " OOOOOOOO ",
            ]
            return PixelGrid.overlay(base: body, top: steam, offsetX: 4, offsetY: 0)
        }
        return PixelSprite(
            frames: [frame([" g", "g "]), frame(["g ", " g"])],
            palette: [
                "O": Palettes.outline,
                "M": Palettes.stone[1],
                "K": Palettes.ink[3],
                "s": Palettes.ember[2],
                "W": Palettes.stone[3],
                "g": Palettes.translucent(Palettes.stone[0], 130),
            ]
        )
    }

    /// Console and one controller, 14×5. Two frames: the standby light
    /// breathes.
    private static func gamingConsoleSprite() -> PixelSprite {
        func frame(_ light: Character) -> [String] {
            [
                "OOOOOOOOO     ",
                "OKKKKKKKO OOO ",
                "OK\(light)KKKKKO OKKO",
                "OKKKKKKKO OOO ",
                "OOOOOOOOO     ",
            ]
        }
        return PixelSprite(frames: [frame("t"), frame("K")], palette: [
            "O": Palettes.outline,
            "K": Palettes.ink[3],
            "t": Palettes.teal[1],
        ])
    }

    /// The road bike, indoors because outdoors it would be gone, 18×12.
    private static func roadBikeSprite() -> PixelSprite {
        let grid = [
            "                  ",
            "      OO     OO   ",
            "     OSSO   OSSO  ",
            "      RR     RR   ",
            "      RR    RR    ",
            "     RRRRRRRR     ",
            "     R R   R R    ",
            "    R  R  R   R   ",
            " OOO   R R    OOO ",
            "O   O  RRR   O   O",
            "O   O        O   O",
            " OOO          OOO ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "R": Palettes.ember[2],
            "S": Palettes.stone[2],
        ])
    }

    /// The watch on its stand, winding itself, 8×11.
    private static func designerWatchSprite() -> PixelSprite {
        let grid = [
            "  OOO   ",
            " O   O  ",
            " O   O  ",
            "OOOOOOO ",
            "OGGGGGO ",
            "OGWWWGO ",
            "OGWkWGO ",
            "OGGGGGO ",
            "OOOOOOO ",
            " O   O  ",
            " OOOOO  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "G": Palettes.gold[2],
            "W": Palettes.stone[0],
            "k": Palettes.ink[3],
        ])
    }

    /// The car, in model form — the real one is downstairs, 14×6.
    private static func modelCarSprite() -> PixelSprite {
        let grid = [
            "              ",
            "    OOOOO     ",
            "  OORkkkROO   ",
            " ORRRRRRRRRO  ",
            " ORRRRRRRRRO  ",
            " OOKOOOOOKOO  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "R": Palettes.ember[2],
            "k": Palettes.sky[1],
            "K": Palettes.ink[3],
        ])
    }

    // MARK: Earned

    /// Record player with the lid up, 14×8. Two frames: the label turns.
    private static func recordPlayerSprite() -> PixelSprite {
        func frame(_ label: [String]) -> [String] {
            let body = [
                "              ",
                " OOOOOOOOOOOO ",
                " OWWWWWWWWWWO ",
                " OWOOOOOOOWWO ",
                " OWOKKKKKOWWO ",
                " OWOKKKKKOWWO ",
                " OWOOOOOOOWWO ",
                " OOOOOOOOOOOO ",
            ]
            return PixelGrid.overlay(base: body, top: label, offsetX: 5, offsetY: 4)
        }
        return PixelSprite(
            frames: [frame(["gK", "Kg"]), frame(["Kg", "gK"])],
            palette: [
                "O": Palettes.outline,
                "W": Palettes.clay[1],
                "K": Palettes.ink[4],
                "g": Palettes.gold[2],
            ]
        )
    }

    /// The awards pennant, 16×9 — you went up for it in a borrowed jacket.
    private static func pennantSprite() -> PixelSprite {
        let grid = [
            "OO              ",
            "OPPPPPPPOO      ",
            "OPPPPPPPPPPOO   ",
            "OPwwwwwPPPPPPOO ",
            "OPPPPPPPPPPPPPPO",
            "OPwwwwwPPPPPPOO ",
            "OPPPPPPPPPPOO   ",
            "OPPPPPPPOO      ",
            "OO              ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "P": Palettes.plum[2],
            "w": Palettes.gold[2],
        ])
    }

    /// What a season poster says without words.
    enum PosterGlyph {
        case rising, flat, falling, figures, star
    }

    /// A framed season poster, 14×18: a paper field, a printed band at the
    /// bottom, and one shape that is the season's whole argument.
    private static func posterSprite(_ glyph: PosterGlyph, ink: RGBA, paper: RGBA) -> PixelSprite {
        var grid = [
            "OOOOOOOOOOOOOO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OPPPPPPPPPPPPO",
            "OOOOOOOOOOOOOO",
            "OIIIIIIIIIIIIO",
            "OIPPIPPPIPPIIO",
            "OOOOOOOOOOOOOO",
        ]
        let art: [String]
        switch glyph {
        case .rising:
            art = [
                "        III ",
                "       IIII ",
                "         II ",
                "        I I ",
                "       I    ",
                "      I     ",
                "  I  I      ",
                "   II       ",
                "            ",
                "            ",
            ]
        case .flat:
            art = [
                "            ",
                "            ",
                "            ",
                "  IIIIIIII  ",
                "  I      I  ",
                "  IIIIIIII  ",
                "            ",
                "     II     ",
                "     II     ",
                "            ",
            ]
        case .falling:
            art = [
                "  II        ",
                "   II       ",
                "    II      ",
                "     II     ",
                "      II    ",
                "       II   ",
                "        III ",
                "        III ",
                "         II ",
                "            ",
            ]
        case .figures:
            art = [
                "  II    II  ",
                "  II    II  ",
                " IIII  IIII ",
                " I II  II I ",
                "   II  II   ",
                "   II  II   ",
                "   IIIIII   ",
                "     II     ",
                "            ",
                "            ",
            ]
        case .star:
            art = [
                "     II     ",
                "     II     ",
                "  IIIIIIII  ",
                "   IIIIII   ",
                "    IIII    ",
                "   IIIIII   ",
                "  III  III  ",
                "  II    II  ",
                "            ",
                "            ",
            ]
        }
        grid = PixelGrid.overlay(base: grid, top: art, offsetX: 1, offsetY: 3)
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "P": paper,
            "I": ink,
        ])
    }

    /// A cup on a plinth, 9×13. One shape, six metals: the ending decides
    /// which, including the two nobody frames on purpose.
    private static func trophySprite(metal: RGBA, shine: RGBA) -> PixelSprite {
        let grid = [
            "  OOOOO  ",
            " OGgGGGO ",
            "OOGgGGGOO",
            "O OGgGO O",
            "O OGgGO O",
            "OOGgGGGOO",
            " OGgGGGO ",
            "  OGgGO  ",
            "   OGO   ",
            "   OGO   ",
            "  OOOOO  ",
            " OGGGGGO ",
            " OOOOOOO ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "G": metal,
            "g": shine,
        ])
    }
}
