/// Builds the room background sprite for a tier: walls with trim and
/// texture, a floor with depth banding and a skirting shadow, and the fixed
/// wall dressing that gives each tier its personality.
///
/// Everything static about a room is baked into this one sprite. The
/// dressing therefore costs nothing at draw time, can never drift outside
/// the room, and never collides with the desk lattice: it lives in the
/// *upper wall band* (above head height for the back desk row) and in the
/// narrow floor margins the desk grid leaves free.
///
/// Patterns are fixed modular functions — deterministic, no randomness.
enum RoomBuilder {
    // MARK: - Tones

    /// One master-palette color, remembered as its ramp position so the art
    /// can ask for "the same color, one step deeper" and always land on a
    /// real palette entry (blending-and-snapping usually rounds back to
    /// where it started, which is why depth banding needs this).
    struct Tone: Equatable {
        let ramp: Palettes.Ramp
        let index: Int

        init(_ ramp: Palettes.Ramp, _ index: Int) {
            self.ramp = ramp
            self.index = index
        }

        var color: RGBA { ramp[index] }
        func deeper(_ steps: Int = 1) -> Tone { Tone(ramp, min(index + steps, 4)) }
        func lighter(_ steps: Int = 1) -> Tone { Tone(ramp, max(index - steps, 0)) }
        var luminance: Double { Palettes.luminance(color) }

        static func == (lhs: Tone, rhs: Tone) -> Bool {
            lhs.ramp.name == rhs.ramp.name && lhs.index == rhs.index
        }
    }

    /// The surface scheme for one room at one hour: what the wall, the trim
    /// and the floor are made of. Exposed so the palette gate can measure
    /// wall-vs-floor contrast without having to guess which pixels are wall.
    struct Surfaces {
        let wall: Tone
        let wallTexture: Tone
        /// The horizontal trim line that breaks up the wall.
        let trim: Tone
        /// The accent stripe: the tier's signature color.
        let accent: RGBA
        let baseboard: Tone
        /// Floor tones nearest the camera (front of the room).
        let floorLight: Tone
        let floorDark: Tone

        /// Floor tones at the back wall — one ramp step deeper, which is
        /// what makes the room read as having depth.
        var farFloorLight: Tone { floorLight.deeper() }
        var farFloorDark: Tone { floorDark.deeper() }

        /// The floor in three depth bands, back to front.
        func floor(band: Int) -> (light: Tone, dark: Tone) {
            switch band {
            case 0: (floorLight.deeper(), floorDark.deeper())
            case 1: (floorLight, floorDark.deeper())
            default: (floorLight, floorDark)
            }
        }

        var wallLuminance: Double { wall.luminance }
        var floorLuminance: Double { (floorLight.luminance + floorDark.luminance) / 2 }
        /// The wall/floor separation the art direction gate measures.
        var contrast: Double { abs(wallLuminance - floorLuminance) }
    }

    // MARK: - Office schemes

    /// Every tier at every hour, hand-tuned so the wall and the floor always
    /// separate by at least 18% perceived luminance (`PaletteTests`).
    ///
    /// The hours are not a single global dimming curve: a garage floor keeps
    /// catching the bare bulb long after its walls have gone to ink, and a
    /// campus atrium keeps its cool tile bright while the off-white walls
    /// drop into evening grey. Rooms are lit, not tinted.
    static func officeSurfaces(tier: OfficeTierStyle, time: TimeOfDay = .day) -> Surfaces {
        let p = Palettes.self
        switch (tier, time) {
        // Garage: raw warm concrete under one bare bulb.
        case (.garage, .morning):
            return Surfaces(
                wall: Tone(p.clay, 3), wallTexture: Tone(p.clay, 4), trim: Tone(p.clay, 4),
                accent: p.ember[2], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.clay, 0), floorDark: Tone(p.clay, 1)
            )
        case (.garage, .day):
            return Surfaces(
                wall: Tone(p.clay, 3), wallTexture: Tone(p.clay, 4), trim: Tone(p.clay, 4),
                accent: p.ember[2], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.clay, 1), floorDark: Tone(p.clay, 2)
            )
        case (.garage, .dusk):
            return Surfaces(
                wall: Tone(p.ember, 4), wallTexture: Tone(p.ink, 4), trim: Tone(p.ink, 4),
                accent: p.gold[2], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.clay, 2), floorDark: Tone(p.clay, 3)
            )
        case (.garage, .night):
            return Surfaces(
                wall: Tone(p.ink, 3), wallTexture: Tone(p.ink, 4), trim: Tone(p.ink, 4),
                accent: p.gold[1], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.clay, 2), floorDark: Tone(p.clay, 3)
            )

        // Loft: cream plaster over oak boards.
        case (.loft, .morning):
            return Surfaces(
                wall: Tone(p.sand, 0), wallTexture: Tone(p.sand, 1), trim: Tone(p.sand, 3),
                accent: p.teal[2], baseboard: Tone(p.sand, 4),
                floorLight: Tone(p.sand, 1), floorDark: Tone(p.sand, 2)
            )
        case (.loft, .day):
            return Surfaces(
                wall: Tone(p.sand, 0), wallTexture: Tone(p.sand, 1), trim: Tone(p.sand, 3),
                accent: p.teal[2], baseboard: Tone(p.sand, 4),
                floorLight: Tone(p.sand, 2), floorDark: Tone(p.sand, 3)
            )
        case (.loft, .dusk):
            return Surfaces(
                wall: Tone(p.sand, 1), wallTexture: Tone(p.sand, 2), trim: Tone(p.sand, 4),
                accent: p.ember[2], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.sand, 3), floorDark: Tone(p.sand, 4)
            )
        case (.loft, .night):
            return Surfaces(
                wall: Tone(p.sand, 2), wallTexture: Tone(p.sand, 3), trim: Tone(p.ink, 4),
                accent: p.gold[1], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.sand, 4), floorDark: Tone(p.ink, 3)
            )

        // Studio: sage walls, warm oak, a designer's room.
        case (.studio, .morning):
            return Surfaces(
                wall: Tone(p.teal, 0), wallTexture: Tone(p.teal, 1), trim: Tone(p.moss, 3),
                accent: p.ember[2], baseboard: Tone(p.moss, 4),
                floorLight: Tone(p.sand, 2), floorDark: Tone(p.sand, 3)
            )
        case (.studio, .day):
            return Surfaces(
                wall: Tone(p.moss, 0), wallTexture: Tone(p.moss, 1), trim: Tone(p.moss, 3),
                accent: p.ember[2], baseboard: Tone(p.moss, 4),
                floorLight: Tone(p.sand, 2), floorDark: Tone(p.sand, 3)
            )
        case (.studio, .dusk):
            return Surfaces(
                wall: Tone(p.moss, 1), wallTexture: Tone(p.moss, 2), trim: Tone(p.moss, 4),
                accent: p.ember[1], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.sand, 3), floorDark: Tone(p.sand, 4)
            )
        case (.studio, .night):
            return Surfaces(
                wall: Tone(p.indigo, 4), wallTexture: Tone(p.ink, 4), trim: Tone(p.indigo, 3),
                accent: p.gold[1], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.sand, 2), floorDark: Tone(p.sand, 3)
            )

        // Campus: off-white walls, an indigo brand stripe, cool tile.
        case (.campus, .morning):
            return Surfaces(
                wall: Tone(p.stone, 0), wallTexture: Tone(p.stone, 1), trim: Tone(p.stone, 3),
                accent: p.indigo[2], baseboard: Tone(p.stone, 4),
                floorLight: Tone(p.stone, 1), floorDark: Tone(p.sky, 2)
            )
        case (.campus, .day):
            return Surfaces(
                wall: Tone(p.stone, 0), wallTexture: Tone(p.stone, 1), trim: Tone(p.stone, 3),
                accent: p.indigo[2], baseboard: Tone(p.stone, 4),
                floorLight: Tone(p.stone, 2), floorDark: Tone(p.stone, 3)
            )
        case (.campus, .dusk):
            return Surfaces(
                wall: Tone(p.stone, 1), wallTexture: Tone(p.stone, 2), trim: Tone(p.stone, 4),
                accent: p.indigo[2], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.stone, 3), floorDark: Tone(p.stone, 4)
            )
        case (.campus, .night):
            return Surfaces(
                wall: Tone(p.stone, 3), wallTexture: Tone(p.stone, 4), trim: Tone(p.ink, 4),
                accent: p.indigo[1], baseboard: Tone(p.ink, 4),
                floorLight: Tone(p.stone, 4), floorDark: Tone(p.ink, 2)
            )
        }
    }

    // MARK: - Office room

    /// The office room at a time of day: surfaces, trim, depth-banded floor,
    /// skirting shadow, and the tier's baked-in wall dressing.
    ///
    /// `amenityRects` are the floor zones the composer is about to lay on
    /// top (`SceneComposer.zoneFrames`). Baked dressing that would land
    /// under one is not drawn at all: it would be invisible, and a
    /// half-covered prop reads as a bug. See `floorDressing`.
    static func officeRoom(
        tier: OfficeTierStyle,
        width: Int,
        height: Int,
        wallHeight: Int,
        time: TimeOfDay = .day,
        amenityRects: [SceneRect] = []
    ) -> PixelSprite {
        let surfaces = officeSurfaces(tier: tier, time: time)
        var canvas = PixelCanvas(width: width, height: height)
        paintShell(&canvas, tier: tier, surfaces: surfaces, wallHeight: wallHeight)
        dressOffice(
            &canvas, tier: tier, surfaces: surfaces, wallHeight: wallHeight,
            time: time, amenityRects: amenityRects
        )
        return canvas.sprite()
    }

    /// Daylight office room — the call site every existing composer uses.
    static func room(
        tier: OfficeTierStyle, width: Int, height: Int, wallHeight: Int,
        amenityRects: [SceneRect] = []
    ) -> PixelSprite {
        officeRoom(
            tier: tier, width: width, height: height, wallHeight: wallHeight,
            time: .day, amenityRects: amenityRects
        )
    }

    // MARK: Floor dressing

    /// A rectangle in scene pixels. The office layout already speaks in
    /// these tuples (`OfficeWaypoints.furnitureRects`,
    /// `SceneComposer.zoneFrames`); this is the same shape with a name.
    typealias SceneRect = (x: Int, y: Int, width: Int, height: Int)

    /// One piece of dressing that stands on the room floor.
    ///
    /// Floor dressing is baked into the room bitmap, *under* everything the
    /// composer places on top of it, so the positions live here as data
    /// rather than buried in the painting code: the amenity zones can be
    /// asked whether they are about to sit on one, and a test can prove
    /// they never do. Wall dressing needs none of this — nothing is ever
    /// placed against the wall band.
    struct FloorProp: Equatable {
        var name: SpriteLibrary.PropName
        /// Left edge.
        var x: Int
        /// The floor line the prop's feet stand on (its bottom edge).
        var floorY: Int

        var rect: SceneRect {
            let sprite = SpriteLibrary.prop(name)
            return (x: x, y: floorY - sprite.height, width: sprite.width, height: sprite.height)
        }
    }

    /// Everything a tier stands on its floor, before the amenity zones get
    /// a say. `officeRoom` draws the subset that stays clear of them.
    static func floorDressing(
        tier: OfficeTierStyle, width: Int, height: Int, wallHeight: Int
    ) -> [FloorProp] {
        switch tier {
        case .garage:
            return [
                FloorProp(name: .cardboardBoxes, x: 2, floorY: height - 3),
                FloorProp(name: .pizzaBoxes, x: width - 21, floorY: height - 3),
            ]
        case .loft:
            return [
                FloorProp(name: .beanbag, x: width - 19, floorY: height - 3),
                FloorProp(name: .bookshelfOffice, x: width - 24, floorY: height - 15),
            ]
        case .studio:
            return [
                FloorProp(name: .serverRack, x: 1, floorY: height - 2),
                FloorProp(name: .kitchenette, x: width - 28, floorY: height - 2),
                FloorProp(name: .pingPongTable, x: width / 2 - 17, floorY: height - 2),
            ]
        case .campus:
            // The lift is part of the back wall; reception sits out on the
            // floor where visitors would actually meet it — directly under
            // the lift, to the right of the strip the amenity zones can
            // claim, with the atrium figs beside it. The whole lobby run is
            // anchored off `floorZoneReserve` so it cannot drift back under
            // a vending machine when a zone's art changes size.
            let reserve = SceneComposer.floorZoneReserve(for: .campus)
            let lobbyStart = (reserve.map { $0.x + $0.width + 4 }) ?? (width / 2 - 11)
            let reception = SpriteLibrary.prop(.receptionDesk)
            let plant = SpriteLibrary.prop(.atriumPlant)
            return [
                FloorProp(name: .elevatorDoors, x: width - 62, floorY: wallHeight + 2),
                FloorProp(name: .receptionDesk, x: lobbyStart, floorY: height - 2),
                FloorProp(
                    name: .atriumPlant, x: lobbyStart + reception.width + 2, floorY: height - 2
                ),
                FloorProp(
                    name: .atriumPlant,
                    x: lobbyStart + reception.width + plant.width + 4, floorY: height - 2
                ),
            ]
        }
    }

    /// The floor dressing a room actually paints: everything the tier owns,
    /// minus anything an amenity zone is about to be laid over. The single
    /// definition, shared by `dressOffice` and the composer invariant test.
    static func visibleFloorDressing(
        tier: OfficeTierStyle, width: Int, height: Int, wallHeight: Int,
        amenityRects: [SceneRect]
    ) -> [FloorProp] {
        floorDressing(tier: tier, width: width, height: height, wallHeight: wallHeight)
            .filter { prop in !amenityRects.contains { intersects(prop.rect, $0) } }
    }

    static func intersects(_ a: SceneRect, _ b: SceneRect) -> Bool {
        a.x < b.x + b.width && b.x < a.x + a.width
            && a.y < b.y + b.height && b.y < a.y + a.height
    }

    // MARK: Shell

    /// Walls, trim, floor pattern, depth bands, skirting shadow, outline.
    private static func paintShell(
        _ canvas: inout PixelCanvas, tier: OfficeTierStyle, surfaces s: Surfaces, wallHeight: Int
    ) {
        let width = canvas.width
        let height = canvas.height
        // The trim line sits a third of the way down the wall — high enough
        // to stay clear of the back row's heads.
        let trimY = max(2, wallHeight / 3)

        for y in 0..<height {
            for x in 0..<width {
                if x == 0 || y == 0 || x == width - 1 || y == height - 1 {
                    canvas.set(x: x, y: y, Palettes.outline)
                    continue
                }
                if y < wallHeight {
                    canvas.set(x: x, y: y, wallColor(x: x, y: y, trimY: trimY, wallHeight: wallHeight, s: s))
                } else {
                    canvas.set(x: x, y: y, floorColor(
                        tier: tier, x: x, y: y, wallHeight: wallHeight, height: height, s: s
                    ))
                }
            }
        }

        // Skirting shadow: the wall casts one soft pixel row onto the floor,
        // plus a second, fainter row — the cheapest depth cue there is.
        for x in 1..<(width - 1) {
            if let under = canvas.color(x: x, y: wallHeight) {
                canvas.set(x: x, y: wallHeight, Palettes.blended(under, toward: Palettes.ink[4], amount: 0.45))
            }
            if let under = canvas.color(x: x, y: wallHeight + 1) {
                canvas.set(x: x, y: wallHeight + 1, Palettes.blended(under, toward: Palettes.ink[4], amount: 0.18))
            }
        }
    }

    private static func wallColor(
        x: Int, y: Int, trimY: Int, wallHeight: Int, s: Surfaces
    ) -> RGBA {
        // Baseboard: two rows at the bottom of the wall.
        if y >= wallHeight - 2 { return s.baseboard.color }
        // Trim: a line with the tier's accent stripe riding just under it.
        if y == trimY { return s.trim.color }
        if y == trimY + 1 { return s.accent }
        // Wall texture: one faint vertical seam per plaster panel. Anything
        // busier turns into visual noise behind the people, which is the
        // opposite of what a background is for.
        return x % 24 == 5 ? s.wallTexture.color : s.wall.color
    }

    private static func floorColor(
        tier: OfficeTierStyle, x: Int, y: Int, wallHeight: Int, height: Int, s: Surfaces
    ) -> RGBA {
        let depth = max(1, height - wallHeight)
        let fromWall = y - wallHeight
        // Three depth bands: the floor steps one ramp tone deeper for each
        // third further from the camera, so the room recedes instead of
        // reading as one flat sheet.
        let band = min(2, fromWall * 3 / depth)
        let tones = s.floor(band: band)
        let light = tones.light.color
        let dark = tones.dark.color

        switch tier {
        case .garage:
            // Poured concrete: expansion joints, nothing else. Concrete is
            // meant to look like a big empty slab.
            if fromWall % 16 == 11 { return dark }
            return x % 38 == 7 ? dark : light
        case .loft, .studio:
            // Boards: a seam every few rows and a sparse staggered plank end.
            let seam = tier == .loft ? 4 : 5
            if fromWall % seam == seam - 1 { return dark }
            return (x + (fromWall / seam) * 13) % 47 == 0 ? dark : light
        case .campus:
            // Large tiles with grout lines.
            return (x % 16 == 0 || fromWall % 8 == 0) ? dark : light
        }
    }

    // MARK: Dressing

    /// The top band of the wall — above every head and speech bubble in the
    /// back desk row, so anything hung here can never be covered.
    private static func wallBand(wallHeight: Int) -> (top: Int, bottom: Int) {
        (top: 2, bottom: max(4, wallHeight - 18))
    }

    /// Per-tier wall dressing and floor clutter, baked into the room.
    private static func dressOffice(
        _ canvas: inout PixelCanvas, tier: OfficeTierStyle, surfaces s: Surfaces,
        wallHeight: Int, time: TimeOfDay, amenityRects: [SceneRect]
    ) {
        let width = canvas.width
        let height = canvas.height
        let band = wallBand(wallHeight: wallHeight)

        /// Hangs a sprite in the wall band, bottom-aligned to it, and gives
        /// it a one-pixel cast shadow down the wall.
        func hang(_ sprite: PixelSprite, x: Int, bottomInset: Int = 0) {
            let y = max(band.top, band.bottom - sprite.height - bottomInset)
            canvas.stamp(sprite, x: x, y: y)
            for px in (x + 1)..<(x + sprite.width) {
                if let under = canvas.color(x: px, y: y + sprite.height) {
                    canvas.set(x: px, y: y + sprite.height, Palettes.blended(under, toward: Palettes.ink[4], amount: 0.3))
                }
            }
        }

        /// Stands a sprite on the floor at (x, its feet at `floorY`) with a
        /// contact shadow.
        func stand(_ sprite: PixelSprite, x: Int, floorY: Int) {
            canvas.stamp(sprite, x: x, y: floorY - sprite.height)
            canvas.contactShadow(x: x, y: floorY, width: sprite.width)
        }

        // Floor dressing first, and only where an amenity zone is not about
        // to be laid on top of it: a prop drawn under a vending machine is
        // not dressing, it is a smudge. On a crowded studio this is how the
        // makeshift ping-pong table gives way to a real game room.
        for prop in visibleFloorDressing(
            tier: tier, width: width, height: height, wallHeight: wallHeight,
            amenityRects: amenityRects
        ) {
            stand(SpriteLibrary.prop(prop.name), x: prop.x, floorY: prop.floorY)
        }

        let window = SpriteLibrary.window(style: .office, time: time)
        let backFloor = wallHeight + 2

        switch tier {
        case .garage:
            // A cord and a bare bulb, a small high window, a band poster,
            // the pegboard, and the founder's own clutter in the corners the
            // desk grid never reaches.
            hang(window, x: 10)
            hang(SpriteLibrary.prop(.poster), x: 30)
            hang(SpriteLibrary.prop(.pegboard), x: 50)
            let bulbX = width / 2 + 16
            canvas.vLine(x: bulbX, y: 1, length: 4, Palettes.ink[3])
            canvas.stamp(SpriteLibrary.prop(.bulb), x: bulbX - 2, y: 4)
            // Extension cord snaking along the skirting.
            for x in stride(from: 20, to: width - 24, by: 1) {
                canvas.set(x: x, y: backFloor + ((x / 7) % 2), Palettes.ink[3])
            }

        case .loft:
            hang(window, x: 12)
            hang(window, x: width - 12 - window.width)
            // The bike goes on the wall, the way it does in every real loft.
            hang(SpriteLibrary.prop(.bike), x: 28)
            hang(SpriteLibrary.prop(.wallClock), x: 56)
            hang(SpriteLibrary.prop(.poster), x: 68)

        case .studio:
            hang(window, x: 6)
            hang(window, x: width - 6 - window.width)
            hang(SpriteLibrary.prop(.framedReviews), x: width / 2 - 34)
            hang(SpriteLibrary.prop(.wallClock), x: width / 2 + 22)

        case .campus:
            for index in 0..<3 {
                hang(window, x: 22 + index * ((width - 44) / 3))
            }
            hang(SpriteLibrary.prop(.ledSign), x: width / 2 - 11, bottomInset: 3)
        }
    }
}
