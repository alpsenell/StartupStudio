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
            "K": RGBA(r: 62, g: 60, b: 72),
            "R": RGBA(r: 222, g: 84, b: 70),
            "W": RGBA(r: 245, g: 245, b: 247),
            "A": RGBA(r: 214, g: 70, b: 60),
            "a": RGBA(r: 120, g: 190, b: 90),
            "B": RGBA(r: 126, g: 130, b: 156),
            "S": RGBA(r: 226, g: 220, b: 206),
            "P": RGBA(r: 150, g: 110, b: 78),
            "p": RGBA(r: 128, g: 92, b: 64),
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
            "W": RGBA(r: 236, g: 232, b: 222),
            "w": RGBA(r: 214, g: 208, b: 196),
            "P": RGBA(r: 110, g: 112, b: 130),
            "R": RGBA(r: 200, g: 80, b: 70),
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
            "B": RGBA(r: 70, g: 100, b: 190),
            "L": RGBA(r: 250, g: 240, b: 180),
            "l": RGBA(r: 214, g: 196, b: 120),
            "K": RGBA(r: 36, g: 40, b: 60),
            "k": RGBA(r: 54, g: 62, b: 96),
            "R": RGBA(r: 214, g: 70, b: 60),
            "Y": RGBA(r: 240, g: 200, b: 70),
            "G": RGBA(r: 90, g: 190, b: 110),
            "c": RGBA(r: 20, g: 22, b: 30),
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
            "S": RGBA(r: 150, g: 196, b: 232),
            "W": RGBA(r: 244, g: 246, b: 250),
            "I": RGBA(r: 94, g: 96, b: 206),
            "B": RGBA(r: 120, g: 170, b: 220),
            "K": RGBA(r: 40, g: 40, b: 48),
            "G": RGBA(r: 170, g: 166, b: 160),
            "g": RGBA(r: 134, g: 130, b: 126),
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
            "S": RGBA(r: 110, g: 220, b: 200),
            "s": RGBA(r: 70, g: 180, b: 160),
            "B": RGBA(r: 64, g: 66, b: 82),
            "b": RGBA(r: 104, g: 106, b: 124),
            "K": RGBA(r: 128, g: 130, b: 144),
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
            "R": RGBA(r: 214, g: 70, b: 60),
            "B": RGBA(r: 80, g: 104, b: 214),
            "G": RGBA(r: 90, g: 190, b: 110),
            "K": RGBA(r: 90, g: 92, b: 108),
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
            "M": RGBA(r: 214, g: 86, b: 160),
            "m": RGBA(r: 180, g: 66, b: 134),
            "K": RGBA(r: 58, g: 62, b: 96),
            "k": RGBA(r: 46, g: 50, b: 80),
            "S": RGBA(r: 28, g: 36, b: 64),
            "s": RGBA(r: 44, g: 62, b: 110),
            "G": RGBA(r: 120, g: 230, b: 130),
            "R": RGBA(r: 222, g: 84, b: 70),
            "B": RGBA(r: 90, g: 130, b: 230),
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
            "G": RGBA(r: 72, g: 150, b: 92),
            "W": RGBA(r: 236, g: 240, b: 236),
            "r": RGBA(r: 176, g: 182, b: 196),
            "R": RGBA(r: 214, g: 70, b: 60),
            "B": RGBA(r: 80, g: 104, b: 214),
            "H": RGBA(r: 70, g: 70, b: 82),
            "T": RGBA(r: 196, g: 158, b: 110),
            "t": RGBA(r: 168, g: 132, b: 88),
        ]
        return PixelSprite(frames: [grid], palette: palette)
    }
}
