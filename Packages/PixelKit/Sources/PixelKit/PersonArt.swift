/// The authored office person: 14×18, seated facing the viewer, drawn as
/// three frames — typing A (hands up), typing B (hands down), and A with a
/// blink.
///
/// Every adult pose in the game keeps its head in rows 1–6, columns 3–10 of
/// a 14-wide canvas. That single rule is what lets one set of hair, glasses,
/// beard and role-accessory overlays drop onto every pose in every scene.
///
/// Character key:
///   O outline   S/s skin + shade   H/h hair + shade   T/t shirt + shade
///   E eyes      P pants/lap        C chair            D/d founder hoodie
///   N accessory dark   n lens glass   M metal   W/w paper
///   R/r accent warm    G/g accent green   V/v blazer   Q collar
///   Y gold             I indigo          K shoe/dark
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

    // MARK: - Face accessories

    /// Glasses: two lenses either side of a bridge, sitting on the eye row
    /// with the pupils left showing so a person in glasses still blinks.
    /// Style 0 is a thin wire pair, style 1 adds a brow bar and a bottom rim
    /// so it reads from across a campus.
    static let glassesOverlays: [[String]] = [
        // 0 — wire rims
        [
            "              ",
            "              ",
            "              ",
            "              ",
            "   Nn NN nN   ",
        ],
        // 1 — bold frames
        [
            "              ",
            "              ",
            "              ",
            "   NN    NN   ",
            "   Nn NN nN   ",
            "   NN    NN   ",
        ],
    ]

    /// Beard: sideburns, jaw and chin in the hair's shade tone, so it always
    /// matches the head it grows on.
    static let beardOverlay: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "    h    h    ",
        "    hhhhhh    ",
    ]

    // MARK: - Outfits

    /// The founder's hoodie. The indigo comes from the palette — a founder
    /// sprite recolors its whole shirt to the hoodie tones — and this
    /// overlay adds what makes it a *hoodie*: the hood bunched at the neck
    /// and two gold drawstrings down the chest.
    static let hoodieOverlay: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "   dd    dd   ",
        "  ddddddddd   ",
        "  dd      dd  ",
        "   d      d   ",
        "    Y    Y    ",
        "    Y    Y    ",
    ]

    /// Outfit 0 — a plain hoodie in the wearer's own shirt color: the same
    /// silhouette as the founder's, without the indigo.
    static let casualHoodieOverlay: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "   tt    tt   ",
        "  ttttttttt   ",
        "  tt      tt  ",
        "   t      t   ",
    ]

    /// Outfit 1 — an open-collar shirt: two collar points and a button
    /// placket, and nothing else, so the shirt colour still reads.
    static let shirtOverlay: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "     Q  Q     ",
        "      QQ      ",
        "      Q       ",
        "      Q       ",
    ]

    /// Outfit 2 — a blazer: dark lapels and sleeves over a light shirt
    /// front, leaving the chest in the wearer's own colour.
    static let blazerOverlay: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "   VQ    QV   ",
        "  VVQ    QVV  ",
        " VVvQ    QvVV ",
        " VVv      vVV ",
        " VVv      vVV ",
        " VVv      vVV ",
    ]

    /// Every body outfit, in `CharacterAppearance.outfit` order.
    static let outfitOverlays: [[String]] = [casualHoodieOverlay, shirtOverlay, blazerOverlay]

    // MARK: - Role accessories

    /// One overlay per role, drawn over the finished body. Each is a single
    /// unmistakable silhouette cue — the point is that a glance at a crowded
    /// campus tells you who is who.
    static func roleOverlay(_ role: RoleLook) -> [String]? {
        switch role {
        case .none, .founder:
            return nil
        case .qa:
            // Headset: band over the crown, cups at both ears, boom mic.
            return [
                "     NNNN     ",
                "    N    N    ",
                "   NN    NN   ",
                "   Nn    nN   ",
                "   N      NRR ",
            ]
        case .designer:
            // Beret, tilted, with a stalk.
            return [
                "     RRRRr    ",
                "    RRRRRRr   ",
                "     rrrr     ",
            ]
        case .marketer:
            // Phone held to the ear, with a call blip.
            return [
                "              ",
                "              ",
                "              ",
                "          NN  ",
                "          Nn  ",
                "          NN  ",
            ]
        case .lawyer:
            // Necktie down the chest.
            return [
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "      RR      ",
                "      RR      ",
                "      rr      ",
                "      RR      ",
                "      rr      ",
            ]
        case .hr:
            // Lanyard: a cord around the neck and a badge on the chest.
            return [
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "    G    G    ",
                "     G  G     ",
                "      GG      ",
                "     QQQQ     ",
                "     QNNQ     ",
                "     QQQQ     ",
            ]
        case .ops:
            // Clipboard tucked under one arm.
            return [
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                "              ",
                " NQQQN        ",
                " NQQQN        ",
                " NQQQN        ",
                " NNNNN        ",
            ]
        }
    }
}
