/// The authored person pose: 14×18, seated facing the viewer, drawn as three
/// frames — typing A (hands up), typing B (hands down), and A-with-a-blink.
///
/// Character key:
///   O outline   S/s skin + shade   H/h hair + shade   T/t shirt + shade
///   E eyes      P pants/lap        C chair            D/d founder hoodie
enum PersonArt {
    static let width = 14
    static let height = 18

    /// Typing frame A — hands raised to the desk edge.
    static let frameA: [String] = [
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
        "  OPPPPPPPPO  ",
        " OCPPPPPPPPCO ",
        "  CCCCCCCCCC  ",
        "   CC    CC   ",
    ]

    /// Typing frame B — hands dropped onto the keyboard, head bobbed one
    /// pixel lower (hunched over the keys).
    static let frameB: [String] = {
        var rows = frameA
        for y in stride(from: 7, through: 2, by: -1) {
            rows[y] = frameA[y - 1]
        }
        rows[1] = "              "
        rows[12] = " OTOTttttTOTO "
        rows[13] = " OSOPPPPPPOSO "
        return rows
    }()

    /// Frame A with closed eyes, shown occasionally by the animation cycle.
    static let frameABlink: [String] = {
        var rows = frameA
        rows[4] = "   OSsSSsSO   "
        return rows
    }()

    /// Hair overlays, one per style, laid over the bald base head.
    /// Order: short, spiky, curly, bun, long, bald.
    static let hairOverlays: [[String]] = [
        // 0 — short
        [
            "              ",
            "     HHHH     ",
            "    HHHHHH    ",
            "    Hh  hH    ",
        ],
        // 1 — spiky
        [
            "    H H H     ",
            "     HHHH     ",
            "    HHHHHH    ",
            "    H    H    ",
        ],
        // 2 — curly
        [
            "    HH  HH    ",
            "   HHHHHHHH   ",
            "  HHHHHHHHHH  ",
            "   HH    HH   ",
            "   H      H   ",
        ],
        // 3 — bun
        [
            "      HH      ",
            "     HHHH     ",
            "    HHHHHH    ",
            "    H    H    ",
        ],
        // 4 — long
        [
            "              ",
            "     HHHH     ",
            "    HHHHHH    ",
            "    Hh  hH    ",
            "    H    H    ",
            "    H    H    ",
            "   Hh    hH   ",
            "   H      H   ",
        ],
        // 5 — bald
        [
            "              ",
        ],
    ]

    /// The founder's subtle distinguishing detail: an indigo hoodie collar
    /// draped across the chest, with the hood hanging at the sides. Kept off
    /// the head rows so the typing head-bob does not disturb it.
    static let hoodieOverlay: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "   DdDDDDdD   ",
        "   D      D   ",
    ]
}
