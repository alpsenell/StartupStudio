/// Room backgrounds for the home tiers: walls that change with the hour,
/// warm floors that keep catching lamplight after the walls have gone to
/// evening, a panelled door, a woven rug, and the same skirting shadow and
/// depth banding as the office rooms.
///
/// Deterministic modular patterns, no randomness.
extension RoomBuilder {
    struct Rect: Equatable {
        let x: Int, y: Int, width: Int, height: Int

        func contains(_ x: Int, _ y: Int) -> Bool {
            (self.x..<self.x + width).contains(x) && (self.y..<self.y + height).contains(y)
        }
    }

    // MARK: - Home schemes

    /// Wall and floor tones per tier per hour. The design rule: the walls
    /// carry the hour (cream morning → sunset amber → indigo night) and the
    /// floors stay warm, because the lamp and the fireplace are on. That
    /// keeps the founder and the furniture readable at every hour while
    /// still making a night at home feel like night.
    static func homeSurfaces(tier: HomeTierStyle, time: TimeOfDay = .night) -> Surfaces {
        let p = Palettes.self
        // Warm boards, the shared floor of the first three tiers.
        let boardsBright = (light: Tone(p.sand, 1), dark: Tone(p.sand, 2))
        let boards = (light: Tone(p.sand, 2), dark: Tone(p.sand, 3))
        // Pale marble, penthouse only.
        let marble: [(light: Tone, dark: Tone)] = [
            (Tone(p.stone, 0), Tone(p.stone, 1)),
            (Tone(p.stone, 1), Tone(p.stone, 2)),
            (Tone(p.stone, 2), Tone(p.stone, 3)),
            (Tone(p.stone, 3), Tone(p.stone, 4)),
        ]

        func surfaces(
            wall: Tone, texture: Tone, trim: Tone, accent: RGBA, baseboard: Tone,
            floor: (light: Tone, dark: Tone)
        ) -> Surfaces {
            Surfaces(
                wall: wall, wallTexture: texture, trim: trim, accent: accent,
                baseboard: baseboard, floorLight: floor.light, floorDark: floor.dark
            )
        }

        // The hour's wall, shared by the first three tiers with a per-tier
        // daylight color.
        func eveningWall(_ time: TimeOfDay, day: Tone, morning: Tone) -> (wall: Tone, texture: Tone, accent: RGBA) {
            switch time {
            case .morning: (morning, morning.deeper(), p.gold[1])
            case .day: (day, day.deeper(), p.teal[2])
            case .dusk: (Tone(p.ember, 4), Tone(p.ink, 4), p.ember[1])
            case .night: (Tone(p.indigo, 4), Tone(p.ink, 4), p.gold[2])
            }
        }

        let floor: (light: Tone, dark: Tone) = time == .morning ? boardsBright : boards

        switch tier {
        case .studioFlat:
            let w = eveningWall(time, day: Tone(p.clay, 1), morning: Tone(p.clay, 0))
            return surfaces(
                wall: w.wall, texture: w.texture, trim: Tone(p.clay, 3), accent: w.accent,
                baseboard: Tone(p.ink, 4), floor: floor
            )
        case .apartment:
            let w = eveningWall(time, day: Tone(p.stone, 1), morning: Tone(p.sky, 0))
            return surfaces(
                wall: w.wall, texture: w.texture, trim: Tone(p.stone, 3), accent: w.accent,
                baseboard: Tone(p.ink, 4), floor: floor
            )
        case .house:
            let w = eveningWall(time, day: Tone(p.moss, 1), morning: Tone(p.moss, 0))
            return surfaces(
                wall: w.wall, texture: w.texture, trim: Tone(p.sand, 3), accent: w.accent,
                baseboard: Tone(p.sand, 4), floor: floor
            )
        case .penthouse:
            let wall: Tone
            switch time {
            case .morning, .day: wall = Tone(p.ink, 0)
            case .dusk: wall = Tone(p.ink, 1)
            case .night: wall = Tone(p.ink, 3)
            }
            let marbleStep: Int
            switch time {
            case .morning: marbleStep = 0
            case .day: marbleStep = 1
            case .dusk: marbleStep = 2
            case .night: marbleStep = 3
            }
            return surfaces(
                wall: wall, texture: wall.deeper(), trim: Tone(p.indigo, 2), accent: p.indigo[2],
                baseboard: Tone(p.ink, 4), floor: marble[marbleStep]
            )
        }
    }

    // MARK: - Home room

    /// Door on the back wall, right side: 10 wide, 22 tall, sitting on the
    /// baseboard. Scenes put the suitcase at its foot.
    static func doorFrame(width: Int, wallHeight: Int) -> (x: Int, y: Int, width: Int, height: Int) {
        (x: width - 15, y: wallHeight - 23, width: 10, height: 22)
    }

    static func homeRoom(
        tier: HomeTierStyle, width: Int, height: Int, wallHeight: Int,
        rug: Rect? = nil, time: TimeOfDay = .night
    ) -> PixelSprite {
        let s = homeSurfaces(tier: tier, time: time)
        var canvas = PixelCanvas(width: width, height: height)
        let door = doorFrame(width: width, wallHeight: wallHeight)
        let trimY = max(2, wallHeight / 3)

        for y in 0..<height {
            for x in 0..<width {
                if x == 0 || y == 0 || x == width - 1 || y == height - 1 {
                    canvas.set(x: x, y: y, Palettes.outline)
                } else if y < wallHeight {
                    canvas.set(x: x, y: y, homeWallColor(
                        tier: tier, x: x, y: y, wallHeight: wallHeight, trimY: trimY, door: door, s: s
                    ))
                } else {
                    canvas.set(x: x, y: y, homeFloorColor(
                        tier: tier, x: x, y: y, wallHeight: wallHeight, height: height, rug: rug, s: s
                    ))
                }
            }
        }

        // Skirting shadow, matching the office rooms.
        for x in 1..<(width - 1) {
            if let under = canvas.color(x: x, y: wallHeight) {
                canvas.set(x: x, y: wallHeight, Palettes.blended(under, toward: Palettes.ink[4], amount: 0.45))
            }
            if let under = canvas.color(x: x, y: wallHeight + 1) {
                canvas.set(x: x, y: wallHeight + 1, Palettes.blended(under, toward: Palettes.ink[4], amount: 0.18))
            }
        }
        return canvas.sprite()
    }

    private static func homeWallColor(
        tier: HomeTierStyle, x: Int, y: Int, wallHeight: Int, trimY: Int,
        door: (x: Int, y: Int, width: Int, height: Int), s: Surfaces
    ) -> RGBA {
        if y >= wallHeight - 2 { return s.baseboard.color }

        if (door.x..<door.x + door.width).contains(x) && (door.y..<door.y + door.height).contains(y) {
            let edge = x == door.x || x == door.x + door.width - 1 || y == door.y
            if edge { return Palettes.sand[4] }
            if x == door.x + door.width - 3 && y == door.y + door.height / 2 { return Palettes.gold[1] } // knob
            let panelX = (door.x + 2..<door.x + door.width - 2).contains(x)
            let upper = (door.y + 3..<door.y + 9).contains(y)
            let lower = (door.y + 12..<door.y + door.height - 2).contains(y)
            return panelX && (upper || lower) ? Palettes.sand[3] : Palettes.sand[2]
        }

        switch tier {
        case .house:
            // Wainscot panelling on the lower wall with a chair rail.
            if y == wallHeight - 13 { return s.trim.color }
            if y > wallHeight - 13 { return x % 8 == 0 ? s.trim.color : s.wallTexture.color }
        case .penthouse:
            // Slim vertical seams between the wall panels, and a brand-color
            // reveal running under the ceiling.
            if y == trimY { return s.accent }
            if x % 44 == 3 && x > 3 { return s.wallTexture.color }
        case .apartment, .studioFlat:
            if y == trimY { return s.trim.color }
            if y == trimY + 1 { return s.accent }
        }
        return x % 24 == 5 ? s.wallTexture.color : s.wall.color
    }

    private static func homeFloorColor(
        tier: HomeTierStyle, x: Int, y: Int, wallHeight: Int, height: Int,
        rug: Rect?, s: Surfaces
    ) -> RGBA {
        // Rug: a bordered weave with an inset band, in the tier's accent.
        if let rug, rug.contains(x, y) {
            let dx = min(x - rug.x, rug.x + rug.width - 1 - x)
            let dy = min(y - rug.y, rug.y + rug.height - 1 - y)
            let inset = min(dx, dy)
            let border = rugTones(for: tier)
            if inset == 0 || inset == 2 { return border.dark }
            return (x + y).isMultiple(of: 5) && inset > 3 ? border.dark : border.light
        }

        let depth = height - wallHeight
        let fromWall = y - wallHeight
        let far = depth > 0 && fromWall * 3 < depth
        let light = (far ? s.farFloorLight : s.floorLight).color
        let dark = (far ? s.farFloorDark : s.floorDark).color

        // Board seams every few rows with sparse staggered plank ends: any
        // denser and the floor reads as brickwork instead of wood.
        switch tier {
        case .studioFlat:
            if fromWall % 4 == 3 { return dark }
            return (x + (fromWall / 4) * 11) % 29 == 0 ? dark : light
        case .apartment:
            if fromWall % 5 == 4 { return dark }
            return (x + (fromWall / 5) * 13) % 33 == 0 ? dark : light
        case .house:
            if fromWall % 6 == 5 { return dark }
            return (x + (fromWall / 6) * 17) % 37 == 0 ? dark : light
        case .penthouse:
            return (x % 16 == 0 || fromWall % 8 == 7) ? dark : light
        }
    }

    /// Each home's rug, in a color the tier's own palette already contains.
    private static func rugTones(for tier: HomeTierStyle) -> (light: RGBA, dark: RGBA) {
        switch tier {
        case .studioFlat: (Palettes.ember[2], Palettes.ember[3])
        case .apartment: (Palettes.ember[3], Palettes.ember[4])
        case .house: (Palettes.teal[3], Palettes.teal[4])
        case .penthouse: (Palettes.indigo[3], Palettes.indigo[4])
        }
    }
}
