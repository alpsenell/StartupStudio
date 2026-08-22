/// Authored home poses. Every adult pose keeps the head in the same place as
/// `PersonArt` (rows 1–6, columns 3–10 of a 14-wide canvas) so the shared
/// hair overlays and the founder hoodie collar drop straight on.
///
/// Character key (shared with `PersonArt`):
///   O outline   S/s skin + shade   H/h hair + shade   T/t shirt + shade
///   E eyes      P pants            K shoes            D/d founder hoodie
///   W/w baby blanket + shade       M dumbbell metal   B/b sleeping blanket + shade
enum HomePersonArt {
    /// Standing, 14×22, facing the viewer. Frame B bobs the head one pixel.
    static let standingA: [String] = [
        "              ",
        "    OSSSSO    ",
        "   OSSSSSSO   ",
        "   OSSSSSSO   ",
        "   OSESSESO   ",
        "   OSSSSSSO   ",
        "    OsSSsO    ",
        "   OTTssTTO   ",
        "  OTTTTTTTTO  ",
        " OTTtTTTTtTTO ",
        " OTOTTTTTTOTO ",
        " OTOtTTTTtOTO ",
        " OSOTttttTOSO ",
        " OOOPPPPPPOOO ",
        "   OPPPPPPO   ",
        "   OPPPPPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "  OKKKOOKKKO  ",
        "  OOOOOOOOOO  ",
    ]

    /// Relaxed on a couch, 14×20: hands in the lap, thighs toward the viewer,
    /// shins down. Frame B bobs the head (breathing).
    static let seatedCouchA: [String] = [
        "              ",
        "    OSSSSO    ",
        "   OSSSSSSO   ",
        "   OSSSSSSO   ",
        "   OSESSESO   ",
        "   OSSSSSSO   ",
        "    OsSSsO    ",
        "   OTTssTTO   ",
        "  OTTTTTTTTO  ",
        " OTTtTTTTtTTO ",
        " OTOTTTTTTOTO ",
        " OTOtTTTTtOTO ",
        " OSSOttttOSSO ",
        " OPPPPPPPPPPO ",
        " OPPPPPPPPPPO ",
        " OPPPPPPPPPPO ",
        " OPPPOOOOPPPO ",
        " OPPPO  OPPPO ",
        " OKKKO  OKKKO ",
        " OOOOO  OOOOO ",
    ]

    /// Lying in bed, 24×12: head on the pillow at the left (eyes closed), a
    /// blanket over the body with a knee bump at the right. Frame B lifts the
    /// blanket over the chest by one pixel (breathing).
    static let lyingA: [String] = [
        "                        ",
        "    OSSSSO              ",
        "   OSSSSSSO             ",
        "   OSSSSSSO             ",
        "   OSsSSsSO             ",
        "   OSSSSSSO      OOOOO  ",
        "    OsSSsO     OOBBBBBO ",
        "   OTTssTTOOOOBBBBBBBBBO",
        "  OBBBBBBBBBBBBBbBBBBBBO",
        " OBbBBBBBBBBBBBBBBBBBbBO",
        " OBBBBBBBBBBBBBBBBBBBBBO",
        " OOOOOOOOOOOOOOOOOOOOOOO",
    ]

    static let lyingB: [String] = {
        var rows = lyingA
        rows[6] = "    OsSSsO  OOOOOOBBBBBO"
        rows[7] = "   OTTssTTOBBBBBBBBBBBBO"
        return rows
    }()

    /// Standing and cradling a baby bundle, 14×22. Frame B shifts the bundle
    /// (rocking) and bobs the head.
    static let holdingBabyA: [String] = [
        "              ",
        "    OSSSSO    ",
        "   OSSSSSSO   ",
        "   OSSSSSSO   ",
        "   OSESSESO   ",
        "   OSSSSSSO   ",
        "    OsSSsO    ",
        "   OTTssTTO   ",
        "  OTTTTTTTTO  ",
        " OTTtTTTTtTTO ",
        " OTOWWWWWWOTO ",
        " OTOWwSSwWOTO ",
        " OSSWWWWWWSSO ",
        " OOOOOOOOOOOO ",
        "   OPPPPPPO   ",
        "   OPPPPPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "  OKKKOOKKKO  ",
        "  OOOOOOOOOO  ",
    ]

    static let holdingBabyB: [String] = {
        var rows = headBob(holdingBabyA)
        rows[11] = " OTOWWwSSwOTO "
        return rows
    }()

    /// Exercising with dumbbells, 14×22: frame A arms down, frame B arms up.
    static let exerciseDown: [String] = {
        var rows = standingA
        rows[12] = "MSMOttttttOMSM"
        return rows
    }()

    static let exerciseUp: [String] = [
        "MSM        MSM",
        "OTO OSSSSO OTO",
        "OTOOSSSSSSOOTO",
        "OTOOSSSSSSOOTO",
        "OTOOSESSESOOTO",
        "OTOOSSSSSSOOTO",
        "OTO OsSSsO OTO",
        "OTOOTTssTTOOTO",
        " OTTTTTTTTTTO ",
        " OTTtTTTTtTTO ",
        "  OTTTTTTTTO  ",
        "  OtTTTTTTtO  ",
        "  OTttttttTO  ",
        " OOOPPPPPPOOO ",
        "   OPPPPPPO   ",
        "   OPPPPPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "  OKKKOOKKKO  ",
        "  OOOOOOOOOO  ",
    ]

    /// The `PersonArt.frameB` trick: head rows slide down one pixel into the
    /// collar, torso stays put.
    static func headBob(_ frame: [String]) -> [String] {
        var rows = frame
        for y in stride(from: 7, through: 2, by: -1) {
            rows[y] = frame[y - 1]
        }
        rows[1] = String(repeating: " ", count: frame[0].count)
        return rows
    }

    // MARK: Child

    /// Chibi child, 8×13: big head, stubby body. Row 0 is headroom so frame B
    /// (the whole sprite shifted up one pixel) can bounce.
    static let childBody: [String] = [
        "        ",
        "        ",
        "        ",
        " OSSSSO ",
        "OSSSSSSO",
        "OSESSESO",
        "OSSSSSSO",
        " OsSSsO ",
        " OTTTTO ",
        "OStTTtSO",
        " OPPPPO ",
        " OPOOPO ",
        " OKOOKO ",
    ]

    /// Mini hair overlays, one per adult hair style (same order), laid over
    /// the child body from row 1.
    static let childHairOverlays: [[String]] = [
        // 0 — short
        ["        ", "  HHHH  ", " HHHHHH ", " Hh  hH "],
        // 1 — spiky
        [" H H H  ", "  HHHH  ", " HHHHHH ", " H    H "],
        // 2 — curly
        ["        ", " HH  HH ", "HHHHHHHH", " HH  HH "],
        // 3 — bun
        ["   HH   ", "  HHHH  ", " HHHHHH ", " H    H "],
        // 4 — long
        ["        ", "  HHHH  ", " HHHHHH ", " Hh  hH ", " H    H ", " H    H "],
        // 5 — bald: kids get a little cap of hair anyway
        ["        ", "   HH   ", " HHHHHH ", "        "],
    ]

    // MARK: Baby

    /// Swaddled baby, 10×6, face peeking out; frame B shifts the face.
    static let babyA: [String] = [
        "  OOOOOO  ",
        " OWWWWWWO ",
        "OWWwSSwWWO",
        "OWWwsSwWWO",
        " OWWWWWWO ",
        "  OOOOOO  ",
    ]

    static let babyB: [String] = [
        "  OOOOOO  ",
        " OWWWWWWO ",
        "OWWWwSSwWO",
        "OWWWwsSwWO",
        " OWWWWWWO ",
        "  OOOOOO  ",
    ]
}
