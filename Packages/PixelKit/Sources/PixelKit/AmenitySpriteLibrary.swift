/// Amenity props: the furniture that makes up the office's game room,
/// cafeteria, gym and shuttle zones. Drawn at desk scale (a person is 14×18,
/// a desk 24×7) so they sit naturally next to the desk grid.
extension SpriteLibrary {
    public enum AmenityPropName: String, CaseIterable, Sendable {
        case cafeteriaCounter, cafeteriaTable, shuttleVan, treadmill, weightRack, arcadeCabinet, foosballTable,
             vendingMachine
    }

    public static func amenityProp(_ name: AmenityPropName) -> PixelSprite {
        switch name {
        case .cafeteriaCounter: cafeteriaCounterSprite()
        case .cafeteriaTable: cafeteriaTableSprite()
        case .shuttleVan: shuttleVanSprite()
        case .treadmill: treadmillSprite()
        case .weightRack: weightRackSprite()
        case .arcadeCabinet: arcadeCabinetSprite()
        case .foosballTable: foosballTableSprite()
        case .vendingMachine: vendingMachineSprite()
        }
    }

    // MARK: - Cafeteria

    /// Serving counter, 20×12: coffee urn, a stack of plates and a fruit bowl
    /// on a pale top over a wooden front with drawer lines.
    private static func cafeteriaCounterSprite() -> PixelSprite {
        let grid = [
            "  OO     OOO        ",
            " OKKO   OWWWO   AaA ",
            " OKRO   OWWWO  OBBBO",
            "OOOOOOOOOOOOOOOOOOOO",
            "OSSSSSSSSSSSSSSSSSSO",
            "OOOOOOOOOOOOOOOOOOOO",
            "OPPPPPPPPPPPPPPPPPPO",
            "OPpppppPPpppppPPpppO",
            "OPPPPPPPPPPPPPPPPPPO",
            "OPpppppPPpppppPPpppO",
            "OPPPPPPPPPPPPPPPPPPO",
            "OOOOOOOOOOOOOOOOOOOO",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "K": Palettes.ink[2],
            "R": Palettes.ember[2],
            "W": Palettes.stone[0],
            "A": Palettes.ember[3],
            "a": Palettes.moss[2],
            "B": Palettes.stone[3],
            "S": Palettes.clay[0],
            "P": Palettes.skinTones[3].base,
            "p": Palettes.sand[3],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Round pedestal table with two red stools, 12×11. A person placed at
    /// (x - 1, y - 12) sits behind it with the top covering their lap.
    private static func cafeteriaTableSprite() -> PixelSprite {
        let grid = [
            "  OOOOOOOO  ",
            " OWWWWWWWWO ",
            " OwwwwwwwwO ",
            "  OOOOOOOO  ",
            "     PP     ",
            "OOOO PP OOOO",
            "ORRO PP ORRO",
            "OOOO PP OOOO",
            " O   PP   O ",
            " O  OPPO  O ",
            "    OOOO    ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "W": Palettes.stone[0],
            "w": Palettes.clay[0],
            "P": Palettes.ink[0],
            "R": Palettes.ember[3],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    /// Vending machine, 10×18, two frames: the header light and the lit
    /// glass front pulse between the frames.
    private static func vendingMachineSprite() -> PixelSprite {
        let lit = [
            " OOOOOOOO ",
            " OLLLLLLO ",
            " OOOOOOOO ",
            " OKRYRKBO ",
            " OKKKKKcO ",
            " OKGRGKBO ",
            " OKKKKKYO ",
            " OKYGYKBO ",
            " OKKKKKBO ",
            " OOOOOOBO ",
            " OBBBBBBO ",
            " OBOOOOBO ",
            " OBOKKOBO ",
            " OBOOOOBO ",
            " OBBBBBBO ",
            " OOOOOOOO ",
            " OO    OO ",
            " OO    OO ",
        ]
        // Dimmer header, glowing interior behind the glass (rows 3-8).
        let dim = lit.enumerated().map { y, row -> String in
            var out = row
            if y == 1 { out = out.replacingOccurrences(of: "L", with: "l") }
            if (3...8).contains(y) { out = out.replacingOccurrences(of: "K", with: "k") }
            return out
        }
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "B": Palettes.sky[3],
            "L": Palettes.gold[0],
            "l": Palettes.sand[1],
            "K": Palettes.ink[3],
            "k": Palettes.ink[2],
            "R": Palettes.ember[3],
            "Y": Palettes.gold[2],
            "G": Palettes.moss[2],
            "c": Palettes.ink[4],
        ]
        return PixelSprite(frames: [lit, dim], palette: palette)
    }

    // MARK: - Shuttle

    /// The company shuttle, seen parked at the curb through a wide back-wall
    /// window, 28×14: white van with an indigo stripe, three windows and two
    /// wheels, sky above, asphalt below.
    private static func shuttleVanSprite() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOOOOOOOOOOOOOOOOOO",
            "OSSSSSSSSSSSSSSSSSSSSSSSSSSO",
            "OSSSSSSSSSSSSSSSSSSSSSSSSSSO",
            "OSSSOOOOOOOOOOOOOOOOOOOSSSSO",
            "OSSSOWWWWWWWWWWWWWWWWWOSSSSO",
            "OSSSOWOBBOWOBBOWOBBOWWOSSSSO",
            "OSSSOWOBBOWOBBOWOBBOWWOSSSSO",
            "OSSSOIIIIIIIIIIIIIIIIIOSSSSO",
            "OSSSOWWWWWWWWWWWWWWWWWOSSSSO",
            "OGGGOOOKKOOOOOOOOOKKOOOGGGGO",
            "OGGGGGGKKGGGGGGGGGGKKGGGGGGO",
            "OggggggggggggggggggggggggggO",
            "OggggggggggggggggggggggggggO",
            "OOOOOOOOOOOOOOOOOOOOOOOOOOOO",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "S": Palettes.sky[1],
            "W": Palettes.stone[0],
            "I": Palettes.indigo[2],
            "B": Palettes.sky[2],
            "K": Palettes.hairColors[0].shade,
            "G": Palettes.stone[2],
            "g": Palettes.clay[2],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    // MARK: - Gym

    /// Treadmill in side view, 14×16, two frames: the belt stripes shift
    /// one pixel so the belt appears to run.
    private static func treadmillSprite() -> PixelSprite {
        let running = [
            " OOOOO        ",
            " OSSSO        ",
            " OSsSO        ",
            " OOOOO        ",
            "   OO         ",
            "   OOOOOOOO   ",
            "   OO         ",
            "   OO         ",
            "   OO         ",
            "   OO         ",
            "  OOO         ",
            "OOOOOOOOOOOOOO",
            "OBbBbBbBbBbBbO",
            "OOOOOOOOOOOOOO",
            "OKKKKKKKKKKKKO",
            "OOOOOOOOOOOOOO",
        ]
        var shifted = running
        shifted[12] = "ObBbBbBbBbBbBO"
        shifted[2] = " OsSsO        "
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "S": Palettes.teal[1],
            "s": Palettes.teal[2],
            "B": Palettes.ink[2],
            "b": Palettes.ink[0],
            "K": Palettes.stone[3],
        ]
        return PixelSprite(frames: [running, shifted], palette: palette)
    }

    /// Two-shelf dumbbell rack, 20×12, red/blue/green weights.
    private static func weightRackSprite() -> PixelSprite {
        let grid = [
            " O                O ",
            " O R  R B  B G  G O ",
            " O RKKR BKKB GKKG O ",
            " O R  R B  B G  G O ",
            " OOOOOOOOOOOOOOOOOO ",
            " O                O ",
            " O B  B G  G R  R O ",
            " O BKKB GKKG RKKR O ",
            " O B  B G  G R  R O ",
            " OOOOOOOOOOOOOOOOOO ",
            " O                O ",
            "OOO              OOO",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "R": Palettes.ember[3],
            "B": Palettes.indigo[2],
            "G": Palettes.moss[2],
            "K": Palettes.ink[1],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }

    // MARK: - Game room

    /// Upright arcade cabinet, 12×20, two frames: the screen brightens and
    /// its sprites move between frames.
    private static func arcadeCabinetSprite() -> PixelSprite {
        let frameA = [
            " OOOOOOOOOO ",
            " OMMMMMMMMO ",
            " OmmmmmmmmO ",
            " OOOOOOOOOO ",
            " OKKKKKKKKO ",
            " OKOOOOOOKO ",
            " OKOSSSSOKO ",
            " OKOSGSSOKO ",
            " OKOSSSGOKO ",
            " OKOOOOOOKO ",
            " OKKKKKKKKO ",
            "OOOOOOOOOOOO",
            "OKKRKKKKBKKO",
            "OOOOOOOOOOOO",
            " OKKKKKKKKO ",
            " OKkkkkkkKO ",
            " OKKKKKKKKO ",
            " OKkkkkkkKO ",
            " OKKKKKKKKO ",
            " OOOOOOOOOO ",
        ]
        var frameB = frameA
        frameB[6] = " OKOssssOKO "
        frameB[7] = " OKOssGsOKO "
        frameB[8] = " OKOGsssOKO "
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "M": Palettes.plum[2],
            "m": Palettes.plum[2],
            "K": Palettes.ink[2],
            "k": Palettes.ink[2],
            "S": Palettes.ink[3],
            "s": Palettes.indigo[4],
            "G": Palettes.moss[1],
            "R": Palettes.ember[2],
            "B": Palettes.indigo[2],
        ]
        return PixelSprite(frames: [frameA, frameB], palette: palette)
    }

    /// Foosball table, 24×13: green felt with a centre line, two rods of red
    /// and blue players with handles poking out both sides, wooden body.
    private static func foosballTableSprite() -> PixelSprite {
        let grid = [
            " OOOOOOOOOOOOOOOOOOOOOO ",
            " OGGGGGGGGGGWGGGGGGGGGO ",
            "HOrRrrrRrrrRWrrRrrrRrrOH",
            " OGGGGGGGGGGWGGGGGGGGGO ",
            "HOrrrBrrrBrrWBrrrBrrrBOH",
            " OGGGGGGGGGGWGGGGGGGGGO ",
            " OOOOOOOOOOOOOOOOOOOOOO ",
            " OTTTTTTTTTTTTTTTTTTTTO ",
            " OttttttttttttttttttttO ",
            " OOOOOOOOOOOOOOOOOOOOOO ",
            "   OtO            OtO   ",
            "   OtO            OtO   ",
            "   OOO            OOO   ",
        ]
        let palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "G": Palettes.moss[2],
            "W": Palettes.stone[0],
            "r": Palettes.stone[2],
            "R": Palettes.ember[3],
            "B": Palettes.indigo[2],
            "H": Palettes.ink[2],
            "T": Palettes.skinTones[2].base,
            "t": Palettes.sand[2],
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }
}
