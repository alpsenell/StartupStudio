import Foundation

// Iteration 9 — L3 owns this file: a child at four sizes.
//
// The home scene has always drawn one 8×13 chibi whatever the child's age
// was, because there was no age. Now there is: a swaddled baby, a stubby
// toddler, the original school-age chibi, and a teenager who is nearly as
// tall as the adults and drawn thinner than them.
//
// Palette rule: every character in these grids is one the shared
// `personPalette` already resolves, so nothing here introduces a colour
// that is not in `Palettes.swift`.

extension HomePersonArt {
    /// Stubby toddler, 8×11: the child body with the legs taken out and
    /// the head left the same size, which is what makes a toddler read as
    /// a toddler. Rows 0–1 are headroom so the bounce frame has somewhere
    /// to go.
    static let toddlerBody: [String] = [
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
        " OKOOKO ",
    ]

    /// Teenager, 10×18: taller than the chibi and narrower than an adult,
    /// with the long torso and the too-long legs of somebody who grew six
    /// inches in a summer.
    static let teenBody: [String] = [
        "          ",
        "          ",
        "   OOOO   ",
        "  OSSSSO  ",
        " OSSSSSSO ",
        " OSESSESO ",
        " OSSSSSSO ",
        "  OsSSsO  ",
        "   OSSO   ",
        "  OTTTTO  ",
        " OTtTTtTO ",
        " OTTTTTTO ",
        " OTTTTTTO ",
        "  OTTTTO  ",
        "  OPPPPO  ",
        "  OPOOPO  ",
        "  OPOOPO  ",
        "  OKOOKO  ",
    ]

    /// The child hair overlays widened by one pixel each side, for the
    /// ten-wide teenager. Same styles, same order.
    static let teenHairOverlays: [[String]] = childHairOverlays.map { style in
        style.map { " \($0) " }
    }
}

extension SpriteLibrary {
    /// A child of the household at their own age. Two frames each, the
    /// second lifted a pixel — the same bounce the chibi has always had,
    /// which is what keeps a room of four people feeling alive.
    ///
    /// `.school` is the sprite `child(appearance:)` has always returned,
    /// byte for byte, so the default path is unchanged.
    public static func child(
        appearance: CharacterAppearance,
        stage: ChildStageStyle
    ) -> PixelSprite {
        switch stage {
        case .baby:
            return baby()
        case .toddler:
            return bouncing(
                body: HomePersonArt.toddlerBody,
                hair: HomePersonArt.childHairOverlays,
                appearance: appearance
            )
        case .school:
            return child(appearance: appearance)
        case .teen:
            return bouncing(
                body: HomePersonArt.teenBody,
                hair: HomePersonArt.teenHairOverlays,
                appearance: appearance
            )
        case .grown:
            return person(appearance: appearance, pose: .standing)
        }
    }

    /// The two-frame bounce shared by the toddler and the teenager: the
    /// hair laid on at the chibi's offset, then the whole grid lifted one
    /// pixel for frame B.
    private static func bouncing(
        body: [String],
        hair: [[String]],
        appearance: CharacterAppearance
    ) -> PixelSprite {
        let style = hair[appearance.hairStyle % hair.count]
        let grounded = PixelGrid.overlay(base: body, top: style, offsetY: 1)
        let airborne = Array(grounded.dropFirst())
            + [String(repeating: " ", count: grounded[0].count)]
        return PixelSprite(frames: [grounded, airborne], palette: personPalette(appearance))
    }
}
