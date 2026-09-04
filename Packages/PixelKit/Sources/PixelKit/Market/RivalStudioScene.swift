import SwiftUI

/// How big a rival studio is, in the four rungs the profile draws: the
/// app maps strength onto one. PixelKit never sees the number.
public enum StrengthBand: String, Sendable, Equatable, Hashable, CaseIterable {
    case minnow, small, mid, large

    /// The building's footprint.
    var size: (width: Int, height: Int) {
        switch self {
        case .minnow: (18, 14)
        case .small: (24, 22)
        case .mid: (30, 32)
        case .large: (38, 44)
        }
    }
}

/// Everything a rival's studio scene is a function of.
public struct RivalStudioInput: Sendable, Equatable, Hashable {
    /// Strength, as the building's size.
    public var band: StrengthBand
    /// Reputation 0…1, as the share of windows lit.
    public var reputation: Double
    /// The incumbent: a fortress instead of an office block.
    public var isFortress: Bool
    /// The studio can be bought today: a price tag hangs outside.
    public var forSale: Bool
    /// The rival founder's appearance seed, for the portrait on the plaque.
    public var founderSeed: UInt64
    public var timeOfDay: TimeOfDay

    public init(
        band: StrengthBand,
        reputation: Double,
        isFortress: Bool = false,
        forSale: Bool = false,
        founderSeed: UInt64 = 0,
        timeOfDay: TimeOfDay = .day
    ) {
        self.band = band
        self.reputation = min(1, max(0, reputation))
        self.isFortress = isFortress
        self.forSale = forSale
        self.founderSeed = founderSeed
        self.timeOfDay = timeOfDay
    }
}

/// Pure layout for the studio scene: a street backdrop, the building on
/// the pavement, the tree and the lamp that give it scale, and the price
/// tag when it is for sale. Deterministic — no draws.
public enum RivalStudioComposer {
    public static let sceneSize: (width: Int, height: Int) = (96, 60)
    /// The first pavement row; buildings stand on it.
    public static let groundY = 48

    public static func compose(_ input: RivalStudioInput) -> [PlacedSprite] {
        let time = input.timeOfDay
        var placements: [PlacedSprite] = [
            PlacedSprite(
                sprite: SpriteCache.shared("rival.backdrop.\(time.rawValue)") {
                    RivalSpriteLibrary.backdrop(time: time)
                },
                x: 0, y: 0, kind: .room, animation: .still, phase: 0
            ),
        ]

        let tree = CitySpriteLibrary.tree(season: .summer)
        placements.append(PlacedSprite(
            sprite: tree, x: 3, y: groundY + 1 - tree.height,
            kind: .cityProp("tree"), animation: .still, phase: 0
        ))

        let lit = litPercent(input)
        let building: PixelSprite
        if input.isFortress {
            building = SpriteCache.shared("rival.fortress.\(input.founderSeed).\(lit).\(time.rawValue)") {
                RivalSpriteLibrary.fortress(litFraction: input.reputation, seed: input.founderSeed, time: time)
            }
        } else {
            building = SpriteCache.shared("rival.studio.\(input.band.rawValue).\(input.founderSeed).\(lit).\(time.rawValue)") {
                RivalSpriteLibrary.studio(band: input.band, litFraction: input.reputation, seed: input.founderSeed, time: time)
            }
        }
        // Centred, nudged left when the tag needs the kerb beside it.
        let buildingX = (sceneSize.width - building.width) / 2 - (input.forSale ? 5 : 0)
        placements.append(PlacedSprite(
            sprite: building, x: buildingX, y: groundY + 1 - building.height,
            kind: .cityProp(input.isFortress ? "fortress" : "studio"),
            animation: .toggle(period: 4), phase: 0
        ))

        if input.forSale {
            let sign = SpriteCache.shared("rival.forSale") { RivalSpriteLibrary.forSaleSign() }
            placements.append(PlacedSprite(
                sprite: sign, x: buildingX + building.width + 3, y: groundY + 1 - sign.height,
                kind: .cityProp("forSale"), animation: .toggle(period: 3), phase: 1
            ))
        }

        let lamp = CitySpriteLibrary.streetlight(time: time)
        placements.append(PlacedSprite(
            sprite: lamp, x: sceneSize.width - 6, y: groundY + 1 - lamp.height,
            kind: .cityProp("streetlight"), animation: .toggle(period: 5), phase: 0
        ))
        return placements
    }

    private static func litPercent(_ input: RivalStudioInput) -> Int {
        Int((input.reputation * 100).rounded())
    }
}

/// A rival's studio on its street, on the shared pixel renderer.
public struct RivalStudioScene: View {
    private let placements: [PlacedSprite]

    public init(input: RivalStudioInput) {
        self.placements = RivalStudioComposer.compose(input)
    }

    public var body: some View {
        PixelSceneView(
            placements: placements,
            sceneSize: RivalStudioComposer.sceneSize,
            accessibilityLabel: "Rival studio"
        )
    }
}

// MARK: - Sprites

/// The studio scene's art: the street it stands on, the office block that
/// grows with strength and lights up with reputation, the incumbent's
/// fortress, and the price tag.
public enum RivalSpriteLibrary {
    /// The street: a two-tone sky for the hour with a dithered horizon,
    /// stars after dark, the pavement and the road, and the frame.
    public static func backdrop(time: TimeOfDay) -> PixelSprite {
        let (width, height) = RivalStudioComposer.sceneSize
        let groundY = RivalStudioComposer.groundY
        var canvas = PixelCanvas(width: width, height: height)
        let sky = skyTones(for: time)
        let horizon = groundY * 11 / 20

        for y in 0..<groundY {
            let tone: RGBA = if y < horizon - 2 {
                sky.top
            } else if y >= horizon + 1 {
                sky.bottom
            } else {
                // Two rows of checker between the tones, the office
                // window's own horizon.
                ((y + 0) % 2 == 0) ? sky.top : sky.bottom
            }
            canvas.hLine(x: 0, y: y, length: width, tone)
        }
        if horizon >= 3 {
            for x in 0..<width where (x + horizon) % 2 == 0 {
                canvas.set(x: x, y: horizon - 1, sky.bottom)
            }
        }
        if time == .night {
            for (x, y) in [(9, 5), (27, 11), (41, 4), (58, 8), (70, 14), (84, 6), (90, 17), (19, 19)] {
                canvas.set(x: x, y: y, Palettes.gold[0])
            }
        }

        let night = time.darkness
        let pavement = Palettes.shaded(Palettes.stone[2], by: night)
        let kerb = Palettes.shaded(Palettes.stone[3], by: night)
        let asphalt = Palettes.shaded(Palettes.ink[1], by: night)
        let dash = Palettes.shaded(Palettes.stone[1], by: night * 0.5)
        canvas.fill(x: 0, y: groundY, width: width, height: 6, pavement)
        canvas.hLine(x: 0, y: groundY + 5, length: width, kerb)
        canvas.fill(x: 0, y: groundY + 6, width: width, height: height - groundY - 6, asphalt)
        for x in stride(from: 2, to: width, by: 6) {
            canvas.fill(x: x, y: groundY + 9, width: 3, height: 1, dash)
        }

        canvas.hLine(x: 0, y: 0, length: width, Palettes.outline)
        canvas.hLine(x: 0, y: height - 1, length: width, Palettes.outline)
        canvas.vLine(x: 0, y: 0, length: height, Palettes.outline)
        canvas.vLine(x: width - 1, y: 0, length: height, Palettes.outline)
        return canvas.sprite()
    }

    private static func skyTones(for time: TimeOfDay) -> (top: RGBA, bottom: RGBA) {
        switch time {
        case .morning: (Palettes.sky[1], Palettes.stone[0])
        case .day: (Palettes.sky[1], Palettes.sky[0])
        case .dusk: (Palettes.plum[2], Palettes.ember[0])
        case .night: (Palettes.ink[3], Palettes.indigo[4])
        }
    }

    /// A rival's office block, sized by its band: plaster or stone walls,
    /// the red roof band every rival wears, the founder's portrait on a
    /// plaque once the building is tall enough to carry one, a grid of
    /// windows lit in the proportion `litFraction` names, and a door.
    /// Two frames: the sign band pulses.
    public static func studio(
        band: StrengthBand, litFraction: Double, seed: UInt64, time: TimeOfDay
    ) -> PixelSprite {
        let size = band.size
        let night = time.darkness
        let plaster = band == .minnow || band == .small
        let wall = Palettes.shaded(plaster ? Palettes.clay[1] : Palettes.stone[1], by: night)
        let wallShade = Palettes.shaded(plaster ? Palettes.clay[2] : Palettes.stone[2], by: night)
        var canvas = PixelCanvas(width: size.width, height: size.height)

        canvas.fill(x: 0, y: 0, width: size.width, height: size.height, wall)
        canvas.fill(x: size.width - 3, y: 0, width: 3, height: size.height, wallShade)
        canvas.fill(x: 0, y: 0, width: size.width, height: 3, Palettes.ember[3])

        // The sign band, and the plaque where there is room for one — a
        // studio has to be mid-sized before its founder's face goes on
        // the wall; below that the door would sit on the plaque.
        let signY = 4
        canvas.fill(x: 1, y: signY, width: size.width - 2, height: 3, Palettes.ember[2])
        let hasPlaque = size.height >= 30
        let plaque = (x: 3, y: signY + 4, side: 12)
        if hasPlaque {
            stampPlaque(into: &canvas, x: plaque.x, y: plaque.y, seed: seed)
        }

        // The door, and the windows in a grid around it and the plaque.
        let doorX = size.width / 2 - 2
        let doorY = size.height - 6
        let lit = litWindow(time: time)
        let dark = Palettes.ink[2]
        var index = 0
        var y = signY + 4
        while y + 2 <= size.height - 2 {
            var x = 2
            while x + 2 <= size.width - 2 {
                let onPlaque = hasPlaque
                    && x + 2 > plaque.x && x < plaque.x + plaque.side
                    && y + 2 > plaque.y && y < plaque.y + plaque.side
                let onDoor = x + 2 > doorX - 1 && x < doorX + 5 && y + 2 > doorY - 1
                if !onPlaque, !onDoor {
                    canvas.fill(x: x, y: y, width: 2, height: 2, isLit(index, litFraction, seed) ? lit : dark)
                    index += 1
                }
                x += 4
            }
            y += 4
        }
        canvas.fill(x: doorX, y: doorY, width: 4, height: 5, Palettes.sand[4])
        canvas.fill(x: doorX + 1, y: doorY + 1, width: 2, height: 3, lit)

        outline(&canvas, width: size.width, height: size.height)

        var pulsed = canvas
        pulsed.fill(x: 1, y: signY, width: size.width - 2, height: 1, Palettes.ember[1])
        return canvas.sprite(followedBy: [pulsed])
    }

    /// The incumbent's fortress, 44×44: two towers under a banner, a
    /// battlemented wall, the founder's plaque over the gate, and arrow
    /// slits lit by reputation. Two frames: the banner flaps.
    public static func fortress(litFraction: Double, seed: UInt64, time: TimeOfDay) -> PixelSprite {
        let width = 44, height = 44
        let night = time.darkness
        let stone = Palettes.shaded(Palettes.stone[3], by: night)
        let stoneShade = Palettes.shaded(Palettes.stone[4], by: night)
        var canvas = PixelCanvas(width: width, height: height)

        // Towers, then the wall between them.
        for towerX in [0, width - 10] {
            canvas.fill(x: towerX, y: 6, width: 10, height: height - 6, stone)
            canvas.fill(x: towerX + 7, y: 6, width: 3, height: height - 6, stoneShade)
            for x in stride(from: towerX, to: towerX + 10, by: 3) {
                canvas.fill(x: x, y: 4, width: 2, height: 2, stone)
            }
        }
        canvas.fill(x: 10, y: 14, width: width - 20, height: height - 14, stone)
        canvas.fill(x: width - 13, y: 14, width: 3, height: height - 14, stoneShade)
        for x in stride(from: 10, to: width - 10, by: 3) {
            canvas.fill(x: x, y: 12, width: 2, height: 2, stone)
        }

        // Arrow slits, lit by reputation.
        let lit = Palettes.gold[2]
        let dark = Palettes.ink[3]
        var index = 0
        for towerX in [0, width - 10] {
            for y in stride(from: 10, to: height - 8, by: 8) {
                canvas.fill(x: towerX + 4, y: y, width: 1, height: 3, isLit(index, litFraction, seed) ? lit : dark)
                index += 1
            }
        }
        for y in stride(from: 18, to: height - 12, by: 8) {
            for x in [12, width - 15] {
                canvas.fill(x: x, y: y, width: 1, height: 3, isLit(index, litFraction, seed) ? lit : dark)
                index += 1
            }
        }

        // The plaque over the gate, and the gate.
        stampPlaque(into: &canvas, x: width / 2 - 6, y: 16, seed: seed)
        canvas.fill(x: width / 2 - 4, y: height - 10, width: 8, height: 9, Palettes.sand[4])
        canvas.set(x: width / 2 - 4, y: height - 10, stone)
        canvas.set(x: width / 2 + 3, y: height - 10, stone)
        canvas.fill(x: width / 2 - 2, y: height - 8, width: 4, height: 7, Palettes.ink[3])

        // The seams where the towers meet the wall, so the three masses
        // read as three.
        canvas.vLine(x: 9, y: 14, length: height - 14, stoneShade)
        canvas.vLine(x: width - 10, y: 14, length: height - 14, stoneShade)

        // The banner on the left tower.
        canvas.vLine(x: 3, y: 0, length: 6, Palettes.stone[2])
        canvas.fill(x: 4, y: 0, width: 5, height: 3, Palettes.ember[3])

        // The outline follows the silhouette — merlons, towers, wall —
        // rather than the sprite's rectangle, which would draw a line
        // across the sky between the battlements.
        silhouetteOutline(&canvas)

        var flapped = canvas
        flapped.fill(x: 4, y: 0, width: 5, height: 3, Palettes.ember[2])
        flapped.set(x: 8, y: 1, Palettes.ember[3])
        return canvas.sprite(followedBy: [flapped])
    }

    /// A price tag on a post: the studio can be bought. Two frames, the
    /// tag swinging one pixel.
    public static func forSaleSign() -> PixelSprite {
        let tag = [
            "    O    ",
            "   OTO   ",
            "  OThTO  ",
            " OTTTTTO ",
            "OTTTTTTTO",
            "OTTGGGTTO",
            "OTTTTTTTO",
            "OTTGGGTTO",
            "OTTTTTTTO",
            "OOOOOOOOO",
        ]
        let tagSprite = PixelSprite(frames: [tag], palette: [
            "O": Palettes.outline,
            "T": Palettes.ember[2],
            "h": Palettes.stone[0],
            "G": Palettes.gold[1],
        ])
        var a = PixelCanvas(width: 12, height: 16)
        a.fill(x: 0, y: 0, width: 12, height: 1, Palettes.stone[3])
        a.fill(x: 0, y: 0, width: 2, height: 16, Palettes.stone[3])
        a.stamp(tagSprite, x: 2, y: 1)
        var b = PixelCanvas(like: a)
        b.fill(x: 0, y: 0, width: 12, height: 1, Palettes.stone[3])
        b.fill(x: 0, y: 0, width: 2, height: 16, Palettes.stone[3])
        b.stamp(tagSprite, x: 3, y: 1)
        return a.sprite(followedBy: [b])
    }

    // MARK: Helpers

    /// The rival founder's portrait on a 12×12 plaque — the same bust the
    /// Rivals screen shows, so the scene and the roster agree.
    private static func stampPlaque(into canvas: inout PixelCanvas, x: Int, y: Int, seed: UInt64) {
        let portrait = SpriteLibrary.person(appearance: CharacterAppearance(seed: seed), pose: .portrait)
        canvas.fill(x: x, y: y, width: 12, height: 12, Palettes.stone[0])
        canvas.stamp(portrait, x: x + 1, y: y + 1)
        canvas.hLine(x: x, y: y, length: 12, Palettes.outline)
        canvas.hLine(x: x, y: y + 11, length: 12, Palettes.outline)
        canvas.vLine(x: x, y: y, length: 12, Palettes.outline)
        canvas.vLine(x: x + 11, y: y, length: 12, Palettes.outline)
    }

    /// Whether window `index` is lit: a fixed scatter per seed, so the
    /// proportion follows `fraction` and the pattern never flickers
    /// between rebuilds.
    private static func isLit(_ index: Int, _ fraction: Double, _ seed: UInt64) -> Bool {
        let scatter = (index * 37 + Int(seed % 11) * 13) % 100
        return scatter < Int((fraction * 100).rounded())
    }

    private static func litWindow(time: TimeOfDay) -> RGBA {
        time.needsArtificialLight ? Palettes.gold[1] : Palettes.sky[1]
    }

    private static func outline(_ canvas: inout PixelCanvas, width: Int, height: Int) {
        canvas.hLine(x: 0, y: 0, length: width, Palettes.outline)
        canvas.hLine(x: 0, y: height - 1, length: width, Palettes.outline)
        canvas.vLine(x: 0, y: 0, length: height, Palettes.outline)
        canvas.vLine(x: width - 1, y: 0, length: height, Palettes.outline)
    }

    /// Inks every painted pixel that borders a transparent one, or the
    /// sprite's bottom edge: a 1px outline inside the shape's silhouette.
    private static func silhouetteOutline(_ canvas: inout PixelCanvas) {
        var edges: [(Int, Int)] = []
        for y in 0..<canvas.height {
            for x in 0..<canvas.width where canvas.color(x: x, y: y) != nil {
                let exposed = y == canvas.height - 1
                    || canvas.color(x: x - 1, y: y) == nil
                    || canvas.color(x: x + 1, y: y) == nil
                    || canvas.color(x: x, y: y - 1) == nil
                    || canvas.color(x: x, y: y + 1) == nil
                if exposed { edges.append((x, y)) }
            }
        }
        for (x, y) in edges {
            canvas.set(x: x, y: y, Palettes.outline)
        }
    }
}

#Preview("Rival studios") {
    VStack(spacing: 8) {
        RivalStudioScene(input: RivalStudioInput(band: .small, reputation: 0.4, founderSeed: 21))
        RivalStudioScene(input: RivalStudioInput(band: .large, reputation: 0.8, forSale: true, founderSeed: 7, timeOfDay: .night))
        RivalStudioScene(input: RivalStudioInput(band: .large, reputation: 0.7, isFortress: true, founderSeed: 0xBEEF))
    }
    .padding()
}
