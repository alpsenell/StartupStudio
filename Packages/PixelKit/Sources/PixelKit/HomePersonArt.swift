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

    // MARK: Office-life poses (WS-D v2)

    /// Side view facing right, 14×22. The head keeps rows 1–6 so every
    /// overlay still lands; the eyes shift to the leading side and the torso
    /// narrows, which is all it takes to read as a profile at this scale.
    static let sideBase: [String] = [
        "              ",
        "    OSSSSO    ",
        "   OSSSSSSO   ",
        "   OSSSSSSO   ",
        "   OSSSESSO   ",
        "   OSSSSSSO   ",
        "    OsSSsO    ",
        "   OTTssTTO   ",
        "   OTTTTTTO   ",
        "  OTTTTTTTTO  ",
        "  OTTTTTTTtO  ",
        "  OTTTTTTTtO  ",
        "  OTttttttTO  ",
        "   OPPPPPPO   ",
        "   OPPPPPPO   ",
        "   OPPPPPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "  OKKKOOKKKO  ",
        "  OOOOOOOOOO  ",
    ]

    /// Legs mid-stride: one foot planted forward, one trailing.
    private static let strideLegs: [String] = [
        "   OPPOOPPO   ",
        "  OPPO  OPPO  ",
        " OPPO    OPPO ",
        " OPPO    OPPO ",
        "OKKKO    OKKKO",
        "OOOOO    OOOOO",
    ]

    /// Legs passing under the body.
    private static let passingLegs: [String] = [
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "   OPPOOPPO   ",
        "  OKKKOOKKKO  ",
        "  OOOOOOOOOO  ",
    ]

    /// The four side-view walk frames, facing right: contact (hand forward),
    /// passing (body lifted a pixel), contact (hand trailing), passing again
    /// with a head bob. Mirror them for `walkLeft`.
    static let walkRightFrames: [[String]] = {
        func legs(_ rows: [String], _ replacement: [String]) -> [String] {
            var out = rows
            for (index, row) in replacement.enumerated() { out[16 + index] = row }
            return out
        }
        func hand(_ rows: [String], forward: Bool?) -> [String] {
            var out = rows
            switch forward {
            case .some(true): out[12] = "  OTttttttSO  "
            case .some(false): out[12] = "  OSttttttTO  "
            case nil: out[12] = "  OTttttttTO  "
            }
            return out
        }
        /// Lifts the whole body one pixel (the walk bounce).
        func lifted(_ rows: [String]) -> [String] {
            Array(rows.dropFirst()) + [String(repeating: " ", count: rows[0].count)]
        }
        let contactForward = hand(legs(sideBase, strideLegs), forward: true)
        let passing = lifted(hand(legs(sideBase, passingLegs), forward: nil))
        let contactBack = hand(legs(sideBase, strideLegs), forward: false)
        let passingBob = lifted(headBob(hand(legs(sideBase, passingLegs), forward: nil)))
        return [contactForward, passing, contactBack, passingBob]
    }()

    /// Head offsets for the four walk frames (the lifted frames carry their
    /// hair up with them; the last one bobs).
    static let walkHeadOffsets = [0, -1, 0, 0]

    /// Arms flung up in celebration, feet planted, 14×22.
    static let cheerDown: [String] = [
        "              ",
        " OTOOSSSSOOTO ",
        " OTOSSSSSSOTO ",
        " OTOSSSSSSOTO ",
        " OTOSESSESOTO ",
        " OTOSSSSSSOTO ",
        " OTO OsSSsO O ",
        " OTTOTTssTTOO ",
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

    /// The airborne half of the cheer: same arms, knees tucked, whole body
    /// a pixel off the ground.
    static let cheerUp: [String] = {
        var rows = Array(cheerDown.dropFirst()) + [String(repeating: " ", count: 14)]
        rows[16] = "   OPPOOPPO   "
        rows[17] = "  OKKKOOKKKO  "
        rows[18] = "  OOOOOOOOOO  "
        rows[19] = "              "
        rows[20] = "              "
        rows[21] = "              "
        return rows
    }()

    /// Defeated: head hanging two rows lower, shoulders rolled forward.
    static let slumpA: [String] = [
        "              ",
        "              ",
        "              ",
        "    OSSSSO    ",
        "   OSSSSSSO   ",
        "   OSsSSsSO   ",
        "   OSSSSSSO   ",
        "    OsSSsO    ",
        "  OTTTssTTTO  ",
        " OTTTTTTTTTTO ",
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

    /// The slump's slow breath: the head sinks one more pixel.
    static let slumpB: [String] = {
        var rows = slumpA
        for y in stride(from: 8, through: 4, by: -1) { rows[y] = slumpA[y - 1] }
        rows[3] = "              "
        return rows
    }()

    /// The same defeat, in a chair. Rows 0-13 are the standing slump — the
    /// hanging head, the rolled shoulders, the hands fallen into the lap —
    /// and rows 14-17 are the office pose's own lap and chair, which begin
    /// at exactly the hip line both poses share (`" OOOPPPPPPOOO "`). So a
    /// miserable person at their desk stays in their seat: only the top of
    /// them changes, which is the whole point.
    static let seatedSlumpA: [String] =
        Array(slumpA[0...13]) + Array(PersonArt.frameA[14...17])

    /// The seated slump's slow breath, taken from the standing one so the
    /// two read as the same person.
    static let seatedSlumpB: [String] =
        Array(slumpB[0...13]) + Array(PersonArt.frameA[14...17])

    /// A mug held at chest height, and the same mug raised for a sip.
    static let mugLow: [String] = [
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
        "         OOO  ",
        "         OQO  ",
        "         OQO  ",
        "         OOO  ",
    ]

    static let mugHigh: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "       OOO    ",
        "       OQO    ",
        "       OOO    ",
    ]

    /// One arm swung out mid-sentence, and the same arm dropped.
    static let gestureUp: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "            OO",
        "           OTO",
        "           OTO",
        "          OTTO",
        "              ",
    ]

    static let gestureDown: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "            OO",
        "           OTO",
        "           OTO",
        "          OTTO",
    ]

    /// A cardboard box carried in both hands, hiding the lower torso.
    static let boxOverlay: [String] = [
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              ",
        " OOOOOOOOOOOO ",
        " OXXXXXXXXXXO ",
        " OXXxxxxxxXXO ",
        " OXXXXXXXXXXO ",
        " OXXXXXXXXXXO ",
        " OOOOOOOOOOOO ",
        "  SS      SS  ",
    ]

    /// Walking toward the camera, 14x22: the standing torso with the legs
    /// alternating a forward step. Motion reads from the legs and the head
    /// bob, not from moving the sprite, so it works in a fixed slot too.
    static let walkDownFrames: [[String]] = {
        var stepA = standingA
        stepA[18] = "   OPPOOPPO   "
        stepA[19] = "   OPPO OKKKO "
        stepA[20] = "  OKKKO       "
        stepA[21] = "  OOOO        "

        var stepB = headBob(standingA)
        stepB[18] = "   OPPOOPPO   "
        stepB[19] = " OKKKO OPPO   "
        stepB[20] = "       OKKKO  "
        stepB[21] = "        OOOO  "
        return [stepA, stepB]
    }()

    /// The carried box, lifted one pixel — a box is heavy, so the carry
    /// animation is a shift of the load, not of the person.
    static let boxOverlayLifted: [String] = {
        var rows = Array(boxOverlay.dropFirst()) + [String(repeating: " ", count: 14)]
        return rows
    }()

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
