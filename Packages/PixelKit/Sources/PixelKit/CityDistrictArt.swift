import Foundation

// MARK: S4 (city)

/// The city's buildings in their districts' characters — Old Town brick
/// and awnings, Suburbs houses, Midtown mid-rises and cafés, Tech Park
/// glass, Downtown towers and neon — plus the places the founder's life
/// puts on the map (the five networking rooms, the hospital, the
/// courthouse, the school, the office they moved out of) and the moving
/// and seasonal dressing (cars, a boat, snow, leaves).
///
/// Every building is two frames: the hour's lighting, then the same with a
/// few windows switched (a light going on upstairs), driven with a slow
/// `.toggle` so a night city twinkles rather than blinks. All colors are
/// master-palette steps; the hour shades walls toward ink with
/// `Palettes.shaded` exactly as the generic `building` does.
extension CitySpriteLibrary {
    // MARK: Lighting

    /// Which windows are lit at an hour: none by day (glass shows the sky),
    /// a few in the morning, half at dusk, most at night. `twinkle` flips
    /// about one in nine, for the second frame.
    struct CityWindows {
        let time: TimeOfDay
        let seed: Int

        func color(_ column: Int, _ row: Int, twinkle: Bool) -> RGBA {
            let hash = Self.hash(column, row, seed)
            var lit: Bool
            switch time {
            case .day: lit = false
            case .morning: lit = hash % 10 < 2
            case .dusk: lit = hash % 10 < 5
            case .night: lit = hash % 10 < 7
            }
            if twinkle, hash % 9 == 4, time != .day { lit.toggle() }
            if lit { return hash % 7 == 0 ? Palettes.gold[2] : Palettes.gold[1] }
            if time.needsArtificialLight { return Palettes.ink[2] }
            return hash % 5 == 0 ? Palettes.sky[1] : Palettes.sky[2]
        }

        static func hash(_ a: Int, _ b: Int, _ c: Int) -> Int {
            var h = UInt32(truncatingIfNeeded: a &* 73_856_093) ^ UInt32(truncatingIfNeeded: b &* 19_349_663)
            h ^= UInt32(truncatingIfNeeded: c &* 83_492_791)
            h = (h ^ (h >> 13)) &* 0x5BD1_E995
            return Int(h ^ (h >> 15))
        }
    }

    /// Draws a 1px outline round the canvas's own edge.
    static func outlineEdge(_ canvas: inout PixelCanvas, fromY top: Int = 0) {
        for x in 0..<canvas.width {
            canvas.set(x: x, y: top, Palettes.outline)
            canvas.set(x: x, y: canvas.height - 1, Palettes.outline)
        }
        for y in top..<canvas.height {
            canvas.set(x: 0, y: y, Palettes.outline)
            canvas.set(x: canvas.width - 1, y: y, Palettes.outline)
        }
    }

    /// Two frames from one painter: the hour's light, then the twinkle.
    static func lit(width: Int, height: Int, paint: (inout PixelCanvas, Bool) -> Void) -> PixelSprite {
        var a = PixelCanvas(width: width, height: height)
        paint(&a, false)
        var b = a
        paint(&b, true)
        return a.sprite(followedBy: [b])
    }

    // MARK: The five districts' buildings

    /// The generic building for a lot, in the district's character.
    static func districtBuilding(
        district: DistrictStyle, width: Int, height: Int, variant: Int, time: TimeOfDay, season: Season
    ) -> PixelSprite {
        switch district {
        case .oldTown: rowhouse(width: width, height: height, variant: variant, time: time, season: season)
        case .suburbs: house(width: width, height: height, variant: variant, time: time, season: season)
        case .midtown: midrise(width: width, height: height, variant: variant, time: time, season: season)
        case .techPark: glassBlock(width: width, height: height, variant: variant, time: time)
        case .downtown: tower(width: width, height: height, variant: variant, time: time, season: season)
        }
    }

    /// Old Town: a brick rowhouse with a tiled roof, arched upstairs
    /// windows and a striped shop awning over a lit shop window.
    static func rowhouse(width: Int, height: Int, variant: Int, time: TimeOfDay, season: Season) -> PixelSprite {
        let w = max(10, width), h = max(14, height)
        let night = time.darkness
        let bricks = [Palettes.sand[2], Palettes.ember[3], Palettes.clay[2], Palettes.sand[3]]
        let wall = Palettes.shaded(bricks[variant % bricks.count], by: night)
        let mortar = Palettes.shaded(Palettes.stepped(bricks[variant % bricks.count], by: 1), by: night)
        let roof = Palettes.shaded(variant % 2 == 0 ? Palettes.ember[4] : Palettes.sand[4], by: night)
        let awnings = [Palettes.ember[2], Palettes.moss[2], Palettes.indigo[2], Palettes.gold[2]]
        let awning = Palettes.shaded(awnings[variant % awnings.count], by: night * 0.6)
        let stripe = Palettes.shaded(Palettes.stone[0], by: night * 0.6)
        let windows = CityWindows(time: time, seed: w * 31 + h * 7 + variant)
        let shop = time.needsArtificialLight ? Palettes.gold[1] : Palettes.sky[2]

        return lit(width: w, height: h) { canvas, twinkle in
            canvas.fill(x: 0, y: 3, width: w, height: h - 3, wall)
            // Mortar courses every third row, with staggered joints.
            for y in stride(from: 5, to: h - 7, by: 3) {
                canvas.hLine(x: 1, y: y, length: w - 2, mortar)
            }
            // The roof: a pitched band with a chimney at one end.
            canvas.fill(x: 0, y: 1, width: w, height: 3, roof)
            canvas.fill(x: variant % 2 == 0 ? w - 4 : 2, y: 0, width: 2, height: 2, Palettes.shaded(Palettes.clay[3], by: night))
            if season == .winter { canvas.hLine(x: 1, y: 1, length: w - 2, Palettes.stone[0]) }
            // Upstairs windows: 2×3 with a dark arch pixel and a sill.
            var row = 0
            var y = 6
            while y + 3 < h - 8 {
                var column = 0
                var x = 2
                while x + 2 <= w - 2 {
                    let glass = windows.color(column, row, twinkle: twinkle)
                    canvas.fill(x: x, y: y + 1, width: 2, height: 2, glass)
                    canvas.hLine(x: x, y: y, length: 2, Palettes.shaded(Palettes.ink[1], by: night))
                    canvas.hLine(x: x, y: y + 3, length: 2, Palettes.shaded(Palettes.stone[1], by: night))
                    x += 4
                    column += 1
                }
                y += 5
                row += 1
            }
            // The awning, scalloped, over the shop front.
            let awningY = h - 7
            for x in 1..<(w - 1) {
                let color = (x / 2) % 2 == 0 ? awning : stripe
                canvas.set(x: x, y: awningY, color)
                canvas.set(x: x, y: awningY + 1, color)
                if x % 2 == 1 { canvas.set(x: x, y: awningY + 2, color) }
            }
            // Shop window and door.
            canvas.fill(x: 2, y: h - 4, width: w / 2 - 2, height: 3, shop)
            canvas.fill(x: w - 5, y: h - 5, width: 3, height: 4, Palettes.shaded(Palettes.sand[4], by: night))
            outlineEdge(&canvas, fromY: 1)
        }
    }

    /// Suburbs: a house with a pitched roof, a chimney, two windows and a
    /// door. Snow sits on the roof in winter.
    static func house(width: Int, height: Int, variant: Int, time: TimeOfDay, season: Season) -> PixelSprite {
        let w = max(10, width), h = max(10, height)
        let night = time.darkness
        let roofs = [Palettes.ember[3], Palettes.sand[3], Palettes.indigo[3], Palettes.moss[3]]
        let walls = [Palettes.sand[0], Palettes.stone[0], Palettes.gold[0], Palettes.clay[0]]
        let roof = Palettes.shaded(roofs[variant % roofs.count], by: night)
        let roofShade = Palettes.shaded(Palettes.stepped(roofs[variant % roofs.count], by: 1), by: night)
        let wall = Palettes.shaded(walls[variant % walls.count], by: night)
        let wallShade = Palettes.shaded(Palettes.stepped(walls[variant % walls.count], by: 1), by: night)
        let roofHeight = max(4, h * 2 / 5)
        let windows = CityWindows(time: time, seed: w * 13 + variant)

        return lit(width: w, height: h) { canvas, twinkle in
            // Walls.
            canvas.fill(x: 1, y: roofHeight, width: w - 2, height: h - roofHeight, wall)
            canvas.fill(x: w - 3, y: roofHeight, width: 2, height: h - roofHeight, wallShade)
            // Roof: a triangle widening to the eaves.
            let center = Double(w - 1) / 2
            for y in 0..<roofHeight {
                let half = (Double(y + 1) / Double(roofHeight)) * (Double(w) / 2)
                let left = Int((center - half).rounded()), right = Int((center + half).rounded())
                for x in max(0, left)...min(w - 1, right) {
                    let edge = x == max(0, left) || x == min(w - 1, right) || y == 0
                    canvas.set(x: x, y: y, edge ? Palettes.outline : (x > Int(center) ? roofShade : roof))
                }
                if season == .winter, y > 0 {
                    canvas.set(x: max(0, left) + 1, y: y, Palettes.stone[0])
                    canvas.set(x: min(w - 1, right) - 1, y: y, Palettes.stone[0])
                }
            }
            if season == .winter { canvas.set(x: Int(center), y: 1, Palettes.stone[0]) }
            // Chimney.
            let chimneyX = variant % 2 == 0 ? w * 3 / 4 - 1 : w / 4
            canvas.fill(x: chimneyX, y: max(0, roofHeight / 2 - 2), width: 2, height: 3, Palettes.shaded(Palettes.clay[3], by: night))
            // Two windows with a cross, and a door.
            let windowY = roofHeight + 2
            if windowY + 3 <= h - 1 {
                for (index, x) in [2, w - 6].enumerated() where x >= 2 {
                    canvas.fill(x: x, y: windowY, width: 3, height: 3, windows.color(index, 0, twinkle: twinkle))
                    canvas.set(x: x + 1, y: windowY + 1, Palettes.shaded(Palettes.stone[0], by: night))
                }
            }
            canvas.fill(x: w / 2 - 1, y: h - 5, width: 3, height: 4, Palettes.shaded(roofs[(variant + 1) % roofs.count], by: night))
            // Walls' outline (the roof drew its own).
            for y in roofHeight..<h {
                canvas.set(x: 0, y: y, Palettes.outline)
                canvas.set(x: w - 1, y: y, Palettes.outline)
            }
            canvas.hLine(x: 0, y: h - 1, length: w, Palettes.outline)
        }
    }

    /// Midtown: a mid-rise with a cornice, piers between the bays, and a
    /// glazed shop floor. Some carry a water tank on the roof.
    static func midrise(width: Int, height: Int, variant: Int, time: TimeOfDay, season: Season) -> PixelSprite {
        let w = max(10, width), h = max(14, height)
        let night = time.darkness
        let walls = [Palettes.stone[1], Palettes.clay[1], Palettes.sand[1], Palettes.stone[2]]
        let wall = Palettes.shaded(walls[variant % walls.count], by: night)
        let pier = Palettes.shaded(Palettes.stepped(walls[variant % walls.count], by: 1), by: night)
        let cornice = Palettes.shaded(Palettes.stone[3], by: night)
        let tank = variant % 2 == 1
        let top = tank ? 4 : 0
        let windows = CityWindows(time: time, seed: w * 17 + h + variant * 5)
        let shop = time.needsArtificialLight ? Palettes.gold[1] : Palettes.sky[1]
        let signs = [Palettes.teal[2], Palettes.ember[2], Palettes.plum[2], Palettes.indigo[2]]

        return lit(width: w, height: h) { canvas, twinkle in
            if tank {
                // A timber water tank on legs.
                let tx = w - 7
                canvas.fill(x: tx, y: 0, width: 4, height: 2, Palettes.shaded(Palettes.sand[3], by: night))
                canvas.set(x: tx, y: 2, Palettes.outline)
                canvas.set(x: tx + 3, y: 2, Palettes.outline)
                canvas.set(x: tx, y: 3, Palettes.outline)
                canvas.set(x: tx + 3, y: 3, Palettes.outline)
                if season == .winter { canvas.hLine(x: tx, y: 0, length: 4, Palettes.stone[0]) }
            }
            canvas.fill(x: 0, y: top, width: w, height: h - top, wall)
            canvas.fill(x: 0, y: top, width: w, height: 2, cornice)
            if season == .winter { canvas.hLine(x: 1, y: top, length: w - 2, Palettes.stone[0]) }
            // Bays of 2×2 windows between piers.
            var row = 0
            var y = top + 4
            while y + 2 <= h - 7 {
                var column = 0
                var x = 2
                while x + 2 <= w - 2 {
                    canvas.fill(x: x, y: y, width: 2, height: 2, windows.color(column, row, twinkle: twinkle))
                    if x + 2 < w - 2 { canvas.vLine(x: x + 2, y: y - 1, length: 4, pier) }
                    x += 4
                    column += 1
                }
                y += 4
                row += 1
            }
            // The shop floor: a sign strip, then glass and a door.
            canvas.hLine(x: 1, y: h - 7, length: w - 2, Palettes.shaded(signs[variant % signs.count], by: night * 0.5))
            canvas.fill(x: 2, y: h - 5, width: w - 4, height: 3, shop)
            canvas.fill(x: w / 2 - 1, y: h - 5, width: 2, height: 4, Palettes.shaded(Palettes.ink[2], by: night))
            outlineEdge(&canvas, fromY: top)
        }
    }

    /// Midtown: a café — a low front with a striped awning and two
    /// umbrella tables out on the pavement.
    static func cafe(width: Int, variant: Int, time: TimeOfDay) -> PixelSprite {
        let w = max(12, width), h = 10
        let night = time.darkness
        let awnings = [Palettes.plum[2], Palettes.ember[2], Palettes.teal[2]]
        let awning = Palettes.shaded(awnings[variant % awnings.count], by: night * 0.5)
        let stripe = Palettes.shaded(Palettes.stone[0], by: night * 0.5)
        let glow = time.needsArtificialLight ? Palettes.gold[0] : Palettes.sky[1]

        return lit(width: w, height: h) { canvas, twinkle in
            canvas.fill(x: 1, y: 1, width: w - 2, height: h - 2, Palettes.shaded(Palettes.sand[0], by: night))
            outlineEdge(&canvas)
            for x in 0..<w {
                let color = (x / 2) % 2 == 0 ? awning : stripe
                canvas.set(x: x, y: 2, color)
                canvas.set(x: x, y: 3, color)
                if x % 2 == 0 { canvas.set(x: x, y: 4, color) }
            }
            canvas.fill(x: 2, y: 5, width: w - 7, height: 3, twinkle && time.needsArtificialLight ? Palettes.gold[1] : glow)
            canvas.fill(x: w - 4, y: 5, width: 2, height: 4, Palettes.shaded(Palettes.sand[4], by: night))
            canvas.hLine(x: 3, y: 1, length: 5, Palettes.shaded(Palettes.ink[3], by: night))   // the name board
        }
    }

    /// Tech Park: a glass box — curtain wall with mullions, floor lines, a
    /// diagonal reflection by day and whole lit floors at night, a logo
    /// on the parapet.
    static func glassBlock(width: Int, height: Int, variant: Int, time: TimeOfDay) -> PixelSprite {
        let w = max(10, width), h = max(12, height)
        let night = time.darkness
        let glassTones = [Palettes.sky[3], Palettes.teal[3], Palettes.sky[2], Palettes.teal[2]]
        let glass = Palettes.shaded(glassTones[variant % glassTones.count], by: night)
        let floorLine = Palettes.shaded(Palettes.stepped(glassTones[variant % glassTones.count], by: 1), by: night)
        let mullion = Palettes.shaded(Palettes.stone[1], by: night)
        let logos = [Palettes.teal[1], Palettes.indigo[2], Palettes.ember[2], Palettes.moss[2]]
        let windows = CityWindows(time: time, seed: w * 29 + h * 3 + variant)

        return lit(width: w, height: h) { canvas, twinkle in
            canvas.fill(x: 0, y: 0, width: w, height: h, glass)
            // Parapet with the tenant's logo.
            canvas.fill(x: 0, y: 0, width: w, height: 3, Palettes.shaded(Palettes.stone[2], by: night))
            canvas.fill(x: w / 2 - 1, y: 1, width: 3, height: 1, logos[variant % logos.count])
            canvas.set(x: w / 2, y: 0, logos[variant % logos.count])
            // Floors.
            var floor = 0
            for y in stride(from: 4, to: h - 4, by: 3) {
                canvas.hLine(x: 1, y: y + 2, length: w - 2, floorLine)
                for x in 1..<(w - 1) where x % 4 != 0 {
                    let pane = windows.color(x / 4, floor, twinkle: twinkle)
                    if pane != Palettes.sky[1], pane != Palettes.sky[2] {
                        canvas.hLine(x: x, y: y, length: 1, pane)
                        canvas.hLine(x: x, y: y + 1, length: 1, pane)
                    }
                }
                floor += 1
            }
            for x in stride(from: 4, to: w - 1, by: 4) { canvas.vLine(x: x, y: 3, length: h - 7, mullion) }
            // The day's reflection: a pale diagonal streak across the glass.
            if !time.needsArtificialLight {
                for step in 0..<(h - 7) {
                    let x = w - 3 - step / 2
                    guard x > 1 else { break }
                    canvas.set(x: x, y: 3 + step, Palettes.sky[1])
                }
            }
            // Entrance canopy.
            canvas.fill(x: w / 2 - 3, y: h - 4, width: 6, height: 1, Palettes.shaded(Palettes.stone[3], by: night))
            canvas.fill(x: w / 2 - 1, y: h - 3, width: 2, height: 2, time.needsArtificialLight ? Palettes.gold[0] : Palettes.sky[1])
            outlineEdge(&canvas)
        }
    }

    /// Downtown: a tower with a set-back crown, a dense grid of windows, a
    /// spire on the tall ones and a neon band that comes on after dark
    /// (and stutters on the second frame).
    static func tower(width: Int, height: Int, variant: Int, time: TimeOfDay, season: Season) -> PixelSprite {
        let w = max(10, width), h = max(16, height)
        let night = time.darkness
        let bodies = [Palettes.ink[1], Palettes.stone[3], Palettes.indigo[4], Palettes.sky[4]]
        let body = Palettes.shaded(bodies[variant % bodies.count], by: night * 0.5)
        let bodyShade = Palettes.shaded(Palettes.stepped(bodies[variant % bodies.count], by: 1), by: night * 0.5)
        let neons = [Palettes.plum[1], Palettes.teal[1], Palettes.ember[1], Palettes.gold[1]]
        let neonOn = neons[variant % neons.count]
        let neonOff = Palettes.shaded(Palettes.stepped(neonOn, by: 2), by: night * 0.3)
        let spire = h >= 34
        let crown = spire ? 6 : 3
        let windows = CityWindows(time: time, seed: w * 11 + h * 19 + variant)

        return lit(width: w, height: h) { canvas, twinkle in
            if spire {
                canvas.vLine(x: w / 2, y: 0, length: 3, Palettes.shaded(Palettes.stone[2], by: night))
                canvas.set(x: w / 2, y: 0, time.needsArtificialLight && !twinkle ? Palettes.ember[2] : Palettes.stone[2])
            }
            // Set-back crown, then the shaft.
            canvas.fill(x: 3, y: crown - 3, width: w - 6, height: 3, bodyShade)
            canvas.fill(x: 0, y: crown, width: w, height: h - crown, body)
            canvas.fill(x: w - 3, y: crown, width: 2, height: h - crown, bodyShade)
            if season == .winter { canvas.hLine(x: 3, y: crown - 3, length: w - 6, Palettes.stone[0]) }
            // The neon band just under the crown.
            let neonLit = time.needsArtificialLight && !(twinkle && variant % 2 == 0)
            canvas.hLine(x: 2, y: crown + 2, length: w - 4, neonLit ? neonOn : neonOff)
            // Windows: 1×2 slots on a tight grid.
            var row = 0
            for y in stride(from: crown + 5, to: h - 5, by: 3) {
                var column = 0
                for x in stride(from: 2, to: w - 2, by: 2) {
                    canvas.vLine(x: x, y: y, length: 2, windows.color(column, row, twinkle: twinkle))
                    column += 1
                }
                row += 1
            }
            // Lobby.
            canvas.fill(x: 2, y: h - 4, width: w - 4, height: 3, time.needsArtificialLight ? Palettes.gold[0] : Palettes.sky[2])
            canvas.vLine(x: w / 2, y: h - 4, length: 3, Palettes.ink[3])
            // Outline the crown and the shaft.
            for x in 3..<(w - 3) { canvas.set(x: x, y: crown - 3, Palettes.outline) }
            canvas.vLine(x: 3, y: crown - 3, length: 3, Palettes.outline)
            canvas.vLine(x: w - 4, y: crown - 3, length: 3, Palettes.outline)
            canvas.hLine(x: 0, y: crown, length: 4, Palettes.outline)
            canvas.hLine(x: w - 4, y: crown, length: 4, Palettes.outline)
            canvas.vLine(x: 0, y: crown, length: h - crown, Palettes.outline)
            canvas.vLine(x: w - 1, y: crown, length: h - crown, Palettes.outline)
            canvas.hLine(x: 0, y: h - 1, length: w, Palettes.outline)
        }
    }

    // MARK: Signs

    /// A 3×5 pixel font for the few words the map writes on its signs.
    private static let signFont: [Character: [String]] = [
        "A": [".#.", "#.#", "###", "#.#", "#.#"],
        "B": ["##.", "#.#", "##.", "#.#", "##."],
        "D": ["##.", "#.#", "#.#", "#.#", "##."],
        "E": ["###", "#..", "##.", "#..", "###"],
        "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
        "L": ["#..", "#..", "#..", "#..", "###"],
        "M": ["#.#", "###", "###", "#.#", "#.#"],
        "O": ["###", "#.#", "#.#", "#.#", "###"],
        "R": ["##.", "#.#", "##.", "#.#", "#.#"],
        "T": ["###", ".#.", ".#.", ".#.", ".#."],
        "W": ["#.#", "#.#", "###", "###", "#.#"],
        "<": ["..#", ".#.", "#..", ".#.", "..#"],
        ">": ["#..", ".#.", "..#", ".#.", "#.."],
        "/": ["..#", "..#", ".#.", "#..", "#.."],
        " ": ["...", "...", "...", "...", "..."],
    ]

    /// Pixel width of `text` in the sign font.
    static func signTextWidth(_ text: String) -> Int { max(0, text.count * 4 - 1) }

    /// Writes `text` into the canvas with its top-left at (x, y).
    static func writeSign(_ text: String, into canvas: inout PixelCanvas, x: Int, y: Int, color: RGBA) {
        for (index, character) in text.enumerated() {
            guard let glyph = signFont[character] else { continue }
            for (row, line) in glyph.enumerated() {
                for (column, pixel) in line.enumerated() where pixel == "#" {
                    canvas.set(x: x + index * 4 + column, y: y + row, color)
                }
            }
        }
    }

    // MARK: The networking rooms

    /// A networking room in its district's clothes, with its sign. When the
    /// room is `open` tonight the sign is lit whatever the hour and a crowd
    /// stands out front (second frame shuffles them).
    static func venue(
        _ style: CityVenueStyle, width: Int, height: Int, time: TimeOfDay, season: Season, open: Bool
    ) -> PixelSprite {
        let w = width, h = height
        let night = time.darkness
        let signLit = open || time.needsArtificialLight
        let windows = CityWindows(time: open ? .night : time, seed: w * 3 + h * 5 + 101)

        func crowd(_ canvas: inout PixelCanvas, twinkle: Bool) {
            guard open else { return }
            let shirts = [Palettes.ember[2], Palettes.teal[2], Palettes.indigo[1], Palettes.gold[1], Palettes.plum[1]]
            for index in 0..<5 {
                let x = 2 + index * max(3, (w - 4) / 5) + (twinkle && index % 2 == 0 ? 1 : 0)
                guard x < w - 2 else { break }
                canvas.set(x: x, y: h - 3, Palettes.sand[1])                 // a head
                canvas.set(x: x, y: h - 2, shirts[index % shirts.count])     // a shirt
            }
        }

        switch style {
        case .hackerHouse:
            // A house with every light on and a green "</>" on a board
            // over the roof.
            let base = house(width: w, height: h - 6, variant: 3, time: open ? .night : time, season: season)
            return lit(width: w, height: h) { canvas, twinkle in
                canvas.stamp(base, x: 0, y: 6, frame: twinkle ? 1 : 0)
                let boardWidth = signTextWidth("</>") + 4
                let boardX = (w - boardWidth) / 2
                canvas.fill(x: boardX, y: 0, width: boardWidth, height: 7, Palettes.ink[3])
                canvas.hLine(x: boardX, y: 0, length: boardWidth, Palettes.outline)
                canvas.vLine(x: boardX, y: 0, length: 7, Palettes.outline)
                canvas.vLine(x: boardX + boardWidth - 1, y: 0, length: 7, Palettes.outline)
                writeSign("</>", into: &canvas, x: boardX + 2, y: 1,
                          color: signLit && !(twinkle && open) ? Palettes.moss[1] : Palettes.moss[3])
                crowd(&canvas, twinkle: twinkle)
            }
        case .coworkingMixer:
            // A converted brick warehouse: sawtooth roof, tall arched
            // windows, "WORK" across the front.
            return lit(width: w, height: h) { canvas, twinkle in
                let brick = Palettes.shaded(Palettes.ember[3], by: night)
                canvas.fill(x: 0, y: 3, width: w, height: h - 3, brick)
                for x in 0..<w {
                    let tooth = x % 6
                    for y in 0..<3 where y >= 2 - min(tooth, 2) {
                        canvas.set(x: x, y: y, Palettes.shaded(tooth < 3 ? Palettes.stone[3] : Palettes.sky[3], by: night))
                    }
                }
                if season == .winter { for x in stride(from: 0, to: w, by: 6) { canvas.set(x: x + 2, y: 0, Palettes.stone[0]) } }
                let signY = 4
                canvas.fill(x: 1, y: signY, width: w - 2, height: 7, Palettes.shaded(Palettes.ink[3], by: night * 0.5))
                writeSign("WORK", into: &canvas, x: (w - signTextWidth("WORK")) / 2, y: signY + 1,
                          color: signLit ? Palettes.gold[1] : Palettes.sand[1])
                var column = 0
                for x in stride(from: 2, to: w - 3, by: 5) {
                    canvas.fill(x: x, y: signY + 9, width: 3, height: h - signY - 13, windows.color(column, 0, twinkle: twinkle))
                    canvas.hLine(x: x, y: signY + 9, length: 3, Palettes.shaded(Palettes.sand[2], by: night))
                    column += 1
                }
                crowd(&canvas, twinkle: twinkle)
                outlineEdge(&canvas)
            }
        case .conferenceBar:
            // The conference hotel: a glass lobby and "BAR" in plum neon.
            let base = midrise(width: w, height: h, variant: 0, time: open ? .night : time, season: season)
            return lit(width: w, height: h) { canvas, twinkle in
                canvas.stamp(base, x: 0, y: 0, frame: twinkle ? 1 : 0)
                let text = "BAR"
                let boardX = (w - signTextWidth(text)) / 2 - 1
                canvas.fill(x: boardX, y: 3, width: signTextWidth(text) + 2, height: 7, Palettes.shaded(Palettes.ink[4], by: 0))
                writeSign(text, into: &canvas, x: boardX + 1, y: 4,
                          color: signLit && !(twinkle && open) ? Palettes.plum[1] : Palettes.plum[3])
                crowd(&canvas, twinkle: twinkle)
            }
        case .rooftopParty:
            // A tower with a terrace on the roof and string lights that
            // chase along it.
            let base = tower(width: w, height: h - 3, variant: 2, time: time, season: season)
            return lit(width: w, height: h) { canvas, twinkle in
                canvas.stamp(base, x: 0, y: 3, frame: twinkle ? 1 : 0)
                // The terrace rail and the string of bulbs over it.
                canvas.hLine(x: 1, y: 3 + 3, length: w - 2, Palettes.shaded(Palettes.stone[2], by: night))
                let bulbs = [Palettes.gold[1], Palettes.plum[1], Palettes.teal[1]]
                for x in stride(from: 1, to: w - 1, by: 2) {
                    let sag = (x / 2) % 3 == 1 ? 1 : 0
                    let lit = signLit ? bulbs[(x / 2 + (twinkle ? 1 : 0)) % bulbs.count] : Palettes.stone[3]
                    canvas.set(x: x, y: 1 + sag, lit)
                }
                canvas.vLine(x: 1, y: 1, length: 5, Palettes.outline)
                canvas.vLine(x: w - 2, y: 1, length: 5, Palettes.outline)
                if open {
                    for (index, x) in stride(from: 4, to: w - 4, by: 4).enumerated() {
                        canvas.set(x: x + (twinkle && index % 2 == 0 ? 1 : 0), y: 4, Palettes.sand[1])
                        canvas.set(x: x + (twinkle && index % 2 == 0 ? 1 : 0), y: 5, bulbs[index % bulbs.count])
                    }
                }
            }
        case .demoDay:
            // The accelerator's hall: a long curved roof, a glass front and
            // a "DEMO" banner.
            return lit(width: w, height: h) { canvas, twinkle in
                let roof = Palettes.shaded(Palettes.stone[2], by: night)
                for x in 0..<w {
                    let arch = Int((Double(abs(x - w / 2)) / Double(w / 2) * 3).rounded())
                    for y in arch..<4 { canvas.set(x: x, y: y, y == arch ? Palettes.outline : roof) }
                }
                if season == .winter { canvas.hLine(x: w / 2 - 5, y: 1, length: 10, Palettes.stone[0]) }
                canvas.fill(x: 0, y: 4, width: w, height: h - 4, Palettes.shaded(Palettes.teal[3], by: night))
                canvas.fill(x: 2, y: 5, width: w - 4, height: 7, Palettes.shaded(Palettes.indigo[3], by: night * 0.5))
                writeSign("DEMO", into: &canvas, x: (w - signTextWidth("DEMO")) / 2, y: 6,
                          color: signLit && !(twinkle && open) ? Palettes.stone[0] : Palettes.indigo[1])
                for x in stride(from: 2, to: w - 2, by: 3) {
                    canvas.vLine(x: x, y: 13, length: h - 14, windows.color(x, 0, twinkle: twinkle))
                }
                crowd(&canvas, twinkle: twinkle)
                for y in 4..<h {
                    canvas.set(x: 0, y: y, Palettes.outline)
                    canvas.set(x: w - 1, y: y, Palettes.outline)
                }
                canvas.hLine(x: 0, y: h - 1, length: w, Palettes.outline)
            }
        }
    }

    // MARK: The founder's places

    /// The hospital: a white block with a red cross on the roof, blue
    /// glass, and an ambulance at the door.
    static func hospital(width: Int, height: Int, time: TimeOfDay) -> PixelSprite {
        let w = width, h = height
        let night = time.darkness
        let windows = CityWindows(time: time == .day ? .day : .night, seed: 404)
        return lit(width: w, height: h) { canvas, twinkle in
            canvas.fill(x: 0, y: 4, width: w, height: h - 4, Palettes.shaded(Palettes.stone[0], by: night))
            canvas.fill(x: w - 3, y: 4, width: 2, height: h - 4, Palettes.shaded(Palettes.stone[1], by: night))
            // The cross on a white plinth.
            let cx = w / 2
            canvas.fill(x: cx - 3, y: 0, width: 7, height: 5, Palettes.stone[0])
            canvas.fill(x: cx - 1, y: 0, width: 3, height: 5, Palettes.ember[3])
            canvas.fill(x: cx - 3, y: 1, width: 7, height: 3, Palettes.ember[3])
            canvas.fill(x: cx - 2, y: 2, width: 5, height: 1, twinkle && time.needsArtificialLight ? Palettes.ember[1] : Palettes.ember[3])
            // Two floors of wards.
            var row = 0
            for y in stride(from: 7, to: h - 8, by: 4) {
                var column = 0
                for x in stride(from: 2, to: w - 3, by: 3) {
                    canvas.fill(x: x, y: y, width: 2, height: 2, windows.color(column, row, twinkle: twinkle))
                    column += 1
                }
                row += 1
            }
            // The red stripe and the entrance canopy.
            canvas.hLine(x: 1, y: h - 8, length: w - 2, Palettes.shaded(Palettes.ember[3], by: night * 0.5))
            canvas.fill(x: 3, y: h - 6, width: 9, height: 1, Palettes.shaded(Palettes.stone[3], by: night))
            canvas.fill(x: 5, y: h - 5, width: 4, height: 4, time.needsArtificialLight ? Palettes.gold[0] : Palettes.sky[1])
            // An ambulance on the forecourt, blue light turning.
            let ax = w - 12
            canvas.fill(x: ax, y: h - 5, width: 9, height: 3, Palettes.stone[0])
            canvas.hLine(x: ax, y: h - 4, length: 9, Palettes.ember[3])
            canvas.fill(x: ax + 6, y: h - 5, width: 2, height: 1, Palettes.sky[2])
            canvas.set(x: ax + 2, y: h - 6, twinkle ? Palettes.sky[1] : Palettes.sky[3])
            canvas.hLine(x: ax + 1, y: h - 2, length: 7, Palettes.ink[4])
            for y in 4..<h {
                canvas.set(x: 0, y: y, Palettes.outline)
                canvas.set(x: w - 1, y: y, Palettes.outline)
            }
            canvas.hLine(x: 0, y: 4, length: w, Palettes.outline)
            canvas.hLine(x: 0, y: h - 1, length: w, Palettes.outline)
        }
    }

    /// The courthouse: a pediment, five columns on three steps, a dark
    /// hall behind them, and a gold pin of the scales in the gable.
    static func courthouse(width: Int, height: Int, time: TimeOfDay, season: Season) -> PixelSprite {
        let w = width, h = height
        let night = time.darkness
        let stone = Palettes.shaded(Palettes.stone[1], by: night)
        let column = Palettes.shaded(Palettes.stone[0], by: night)
        let shade = Palettes.shaded(Palettes.stone[3], by: night)
        let pediment = 6
        return lit(width: w, height: h) { canvas, twinkle in
            for y in 0..<pediment {
                let half = Int(Double(y + 1) / Double(pediment) * Double(w / 2))
                for x in max(0, w / 2 - half)..<min(w, w / 2 + half + 1) {
                    let edge = x == max(0, w / 2 - half) || x == min(w, w / 2 + half + 1) - 1 || y == 0
                    canvas.set(x: x, y: y, edge ? Palettes.outline : stone)
                }
            }
            if season == .winter { canvas.set(x: w / 2, y: 1, Palettes.stone[0]) }
            canvas.set(x: w / 2, y: 3, Palettes.gold[1])
            // Entablature.
            canvas.fill(x: 0, y: pediment, width: w, height: 2, shade)
            // The hall behind the columns: dark by day, lit at night.
            canvas.fill(x: 1, y: pediment + 2, width: w - 2, height: h - pediment - 5,
                        time.needsArtificialLight ? (twinkle ? Palettes.gold[2] : Palettes.gold[1]) : Palettes.ink[2])
            // Five columns.
            for index in 0..<5 {
                let x = 2 + index * (w - 5) / 4
                canvas.fill(x: x, y: pediment + 2, width: 2, height: h - pediment - 5, column)
                canvas.set(x: x + 1, y: pediment + 3, shade)
            }
            // Three steps.
            canvas.hLine(x: 0, y: h - 3, length: w, stone)
            canvas.hLine(x: 0, y: h - 2, length: w, shade)
            canvas.hLine(x: 0, y: h - 1, length: w, Palettes.outline)
            canvas.vLine(x: 0, y: pediment, length: h - pediment, Palettes.outline)
            canvas.vLine(x: w - 1, y: pediment, length: h - pediment, Palettes.outline)
        }
    }

    /// The school: red brick, a row of big windows, a bell cupola with a
    /// clock, and a flag.
    static func school(width: Int, height: Int, time: TimeOfDay, season: Season) -> PixelSprite {
        let w = width, h = height
        let night = time.darkness
        let brick = Palettes.shaded(Palettes.ember[3], by: night)
        let trim = Palettes.shaded(Palettes.sand[0], by: night)
        let windows = CityWindows(time: time == .night ? .dusk : time, seed: 7_070)
        return lit(width: w, height: h) { canvas, twinkle in
            // Cupola and flag.
            let cx = w / 2
            canvas.fill(x: cx - 2, y: 1, width: 5, height: 4, trim)
            canvas.set(x: cx, y: 0, Palettes.outline)
            canvas.set(x: cx, y: 2, Palettes.ink[3])                         // the clock
            canvas.vLine(x: w - 4, y: 0, length: 5, Palettes.stone[3])
            canvas.fill(x: w - 3, y: 0, width: 2, height: 2, twinkle ? Palettes.indigo[1] : Palettes.indigo[2])
            // Roof and walls.
            canvas.fill(x: 0, y: 5, width: w, height: 2, Palettes.shaded(Palettes.ink[1], by: night))
            if season == .winter { canvas.hLine(x: 1, y: 5, length: w - 2, Palettes.stone[0]) }
            canvas.fill(x: 0, y: 7, width: w, height: h - 7, brick)
            var column = 0
            for x in stride(from: 2, to: w - 3, by: 4) {
                canvas.fill(x: x, y: 9, width: 3, height: 3, windows.color(column, 0, twinkle: twinkle))
                canvas.hLine(x: x, y: 12, length: 3, trim)
                column += 1
            }
            canvas.fill(x: cx - 2, y: h - 4, width: 4, height: 3, Palettes.shaded(Palettes.sand[3], by: night))
            for y in 5..<h {
                canvas.set(x: 0, y: y, Palettes.outline)
                canvas.set(x: w - 1, y: y, Palettes.outline)
            }
            canvas.hLine(x: 0, y: 5, length: w, Palettes.outline)
            canvas.hLine(x: 0, y: h - 1, length: w, Palettes.outline)
        }
    }

    /// Where the school would be when no child is at one: a sandpit, a
    /// swing and a slide.
    static func playground(width: Int, height: Int, time: TimeOfDay) -> PixelSprite {
        let w = width, h = height
        let night = time.darkness
        return lit(width: w, height: h) { canvas, twinkle in
            canvas.fill(x: 1, y: h - 4, width: 8, height: 3, Palettes.shaded(Palettes.sand[1], by: night))
            canvas.hLine(x: 1, y: h - 5, length: 8, Palettes.shaded(Palettes.sand[3], by: night))
            // Swing frame.
            let sx = 11
            canvas.hLine(x: sx, y: h - 9, length: 7, Palettes.shaded(Palettes.stone[3], by: night))
            canvas.vLine(x: sx, y: h - 9, length: 8, Palettes.shaded(Palettes.stone[3], by: night))
            canvas.vLine(x: sx + 6, y: h - 9, length: 8, Palettes.shaded(Palettes.stone[3], by: night))
            let sway = twinkle ? 1 : 0
            canvas.vLine(x: sx + 3 + sway, y: h - 8, length: 4, Palettes.shaded(Palettes.stone[2], by: night))
            canvas.hLine(x: sx + 2 + sway, y: h - 4, length: 3, Palettes.shaded(Palettes.ember[2], by: night))
            // Slide.
            let lx = w - 7
            guard lx > sx + 7 else { return }
            canvas.vLine(x: lx, y: h - 8, length: 7, Palettes.shaded(Palettes.stone[3], by: night))
            for step in 0..<6 { canvas.set(x: lx + 1 + step, y: h - 8 + step, Palettes.shaded(Palettes.ember[2], by: night)) }
        }
    }

    /// The office the company moved out of: the district's own walls with
    /// its windows boarded, and a "TO LET" board on posts in front.
    static func formerOffice(district: DistrictStyle, width: Int, height: Int, time: TimeOfDay) -> PixelSprite {
        let w = max(14, width), h = max(16, height)
        let night = time.darkness
        let wall = Palettes.shaded(district.wall.base, by: night)
        let wallShade = Palettes.shaded(district.wall.shade, by: night)
        let board = Palettes.shaded(Palettes.sand[3], by: night * 0.6)
        return lit(width: w, height: h) { canvas, twinkle in
            canvas.fill(x: 0, y: 0, width: w, height: h, wall)
            canvas.fill(x: w - 3, y: 0, width: 2, height: h, wallShade)
            canvas.fill(x: 0, y: 0, width: w, height: 3, Palettes.shaded(district.roof.base, by: night))
            // Boarded windows: a dark pane crossed by a plank.
            for y in stride(from: 5, to: h - 6, by: 5) {
                for x in stride(from: 2, to: w - 4, by: 5) {
                    canvas.fill(x: x, y: y, width: 3, height: 3, Palettes.ink[3])
                    canvas.hLine(x: x - 1, y: y + 1, length: 5, board)
                }
            }
            outlineEdge(&canvas)
            // The board: "TO" over "LET", gold on white, on two posts.
            let boardWidth = 13, boardHeight = 13
            let bx = w - boardWidth - 1, by = h - boardHeight - 1
            canvas.fill(x: bx, y: by, width: boardWidth, height: boardHeight - 2, Palettes.stone[0])
            canvas.hLine(x: bx, y: by, length: boardWidth, Palettes.outline)
            canvas.hLine(x: bx, y: by + boardHeight - 3, length: boardWidth, Palettes.outline)
            canvas.vLine(x: bx, y: by, length: boardHeight - 2, Palettes.outline)
            canvas.vLine(x: bx + boardWidth - 1, y: by, length: boardHeight - 2, Palettes.outline)
            let ink = twinkle && time.needsArtificialLight ? Palettes.ember[2] : Palettes.ember[3]
            writeSign("TO", into: &canvas, x: bx + 3, y: by + 1, color: ink)
            writeSign("LET", into: &canvas, x: bx + 1, y: by + 5, color: ink)
            canvas.vLine(x: bx + 2, y: by + boardHeight - 2, length: 2, Palettes.sand[4])
            canvas.vLine(x: bx + boardWidth - 3, y: by + boardHeight - 2, length: 2, Palettes.sand[4])
        }
    }

    // MARK: Dressing

    /// A sprite with every color shaded toward ink for the hour — trees,
    /// benches and landmarks sit in the same light as the buildings.
    static func shaded(_ sprite: PixelSprite, for time: TimeOfDay) -> PixelSprite {
        guard time.darkness > 0 else { return sprite }
        return PixelSprite(
            frames: sprite.frames,
            palette: sprite.palette.mapValues { color in
                color == Palettes.outline ? color : Palettes.shaded(color, by: time.darkness)
            }
        )
    }

    /// A small garden tree, blossoming in spring.
    static func gardenTree(season: Season) -> PixelSprite {
        let grid = [
            "  OOO  ",
            " OFGFO ",
            "OFFFBFO",
            "OFBFFFO",
            " OFFFO ",
            "  OOO  ",
            "   T   ",
            "   T   ",
            "  OTO  ",
        ]
        let foliage = season.foliage
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline,
            "F": foliage.base,
            "G": foliage.highlight,
            "B": season == .spring ? Palettes.plum[0] : (season == .winter ? Palettes.stone[0] : foliage.highlight),
            "T": Palettes.sand[3],
        ])
    }

    /// A round garden bush, 4×4.
    static func bush(season: Season) -> PixelSprite {
        let grid = [
            " OO ",
            "OFGO",
            "OFFO",
            " OO ",
        ]
        let foliage = season.foliage
        return PixelSprite(frames: [grid], palette: [
            "O": Palettes.outline, "F": foliage.base, "G": foliage.highlight,
        ])
    }

    /// A park bench, 5×3.
    static func bench() -> PixelSprite {
        PixelSprite(frames: [[
            "SSSSS",
            "WWWWW",
            "O   O",
        ]], palette: ["S": Palettes.sand[3], "W": Palettes.sand[2], "O": Palettes.outline])
    }

    /// The plaza fountain: a stone basin with a jet that rises and falls
    /// (frozen still in winter).
    static func fountain(time: TimeOfDay, season: Season) -> PixelSprite {
        let high = [
            "    W    ",
            "   WwW   ",
            "    W    ",
            "  w S w  ",
            "OSSSSSSSO",
            "OBBBBBBBO",
            " OOOOOOO ",
        ]
        let low = [
            "         ",
            "    W    ",
            "   wWw   ",
            "  w S w  ",
            "OSSSSSSSO",
            "OBwBBBwBO",
            " OOOOOOO ",
        ]
        let night = time.darkness
        let water = season == .winter ? Palettes.stone[0] : Palettes.sky[1]
        let spray = season == .winter ? Palettes.stone[1] : Palettes.sky[0]
        let frames = season == .winter ? [low.map { $0.replacingOccurrences(of: "W", with: " ") }] : [high, low]
        return PixelSprite(frames: frames, palette: [
            "O": Palettes.outline,
            "S": Palettes.shaded(Palettes.stone[2], by: night),
            "B": Palettes.shaded(season == .winter ? Palettes.stone[1] : Palettes.sky[2], by: night),
            "W": water, "w": spray,
        ])
    }

    /// A car seen side-on for the east–west spine: 11×4, headlights on
    /// after dark.
    static func car(eastbound: Bool, tint: Int, time: TimeOfDay) -> PixelSprite {
        var canvas = PixelCanvas(width: 11, height: 4)
        let bodies = [Palettes.ember[2], Palettes.teal[2], Palettes.stone[0], Palettes.gold[2], Palettes.indigo[2]]
        let body = Palettes.shaded(bodies[tint % bodies.count], by: time.darkness * 0.4)
        canvas.fill(x: 1, y: 1, width: 9, height: 2, body)
        canvas.fill(x: 3, y: 0, width: 5, height: 1, Palettes.blended(body, toward: Palettes.ink[4], amount: 0.3))
        canvas.hLine(x: 1, y: 3, length: 9, Palettes.ink[4])
        let front = eastbound ? 10 : 0, back = eastbound ? 0 : 10
        canvas.set(x: front, y: 1, time.needsArtificialLight ? Palettes.gold[0] : Palettes.stone[1])
        canvas.set(x: back, y: 1, Palettes.ember[3])
        return canvas.sprite()
    }

    /// A car seen from above for the avenues: 3×6, nose toward travel.
    static func avenueCar(southbound: Bool, tint: Int, time: TimeOfDay) -> PixelSprite {
        var canvas = PixelCanvas(width: 3, height: 6)
        let bodies = [Palettes.teal[2], Palettes.ember[2], Palettes.stone[0], Palettes.plum[2], Palettes.gold[2]]
        let body = Palettes.shaded(bodies[tint % bodies.count], by: time.darkness * 0.4)
        canvas.fill(x: 0, y: 0, width: 3, height: 6, body)
        let nose = southbound ? 5 : 0, tail = southbound ? 0 : 5
        canvas.hLine(x: 0, y: southbound ? 3 : 2, length: 3, Palettes.ink[3])     // windscreen
        canvas.set(x: 0, y: nose, time.needsArtificialLight ? Palettes.gold[0] : Palettes.stone[1])
        canvas.set(x: 2, y: nose, time.needsArtificialLight ? Palettes.gold[0] : Palettes.stone[1])
        canvas.set(x: 0, y: tail, Palettes.ember[3])
        canvas.set(x: 2, y: tail, Palettes.ember[3])
        return canvas.sprite()
    }

    /// A river boat: a low hull and a cabin with portholes, bobbing.
    static func boat(time: TimeOfDay) -> PixelSprite {
        let up = [
            "   OOOO     ",
            "   OwWwO    ",
            "OOOOOOOOOOOO",
            " OHHHHHHHHO ",
            "  OOOOOOOO  ",
        ]
        let down = ["            "] + up.dropLast()
        return PixelSprite(frames: [up, down], palette: [
            "O": Palettes.outline,
            "W": Palettes.shaded(Palettes.stone[0], by: time.darkness),
            "w": time.needsArtificialLight ? Palettes.gold[1] : Palettes.sky[1],
            "H": Palettes.shaded(Palettes.ember[3], by: time.darkness),
        ])
    }

    /// Ripples drifting on the river: a band the width of the map with a
    /// scattering of pale dashes, shifted between two frames.
    static func riverRipples(width: Int, height: Int, time: TimeOfDay, season: Season) -> PixelSprite {
        let color = time.needsArtificialLight
            ? Palettes.translucent(Palettes.gold[1], 150)
            : Palettes.translucent(season == .winter ? Palettes.stone[0] : Palettes.sky[1], 190)
        func frame(_ offset: Int) -> [String] {
            (0..<height).map { y in
                String((0..<width).map { x -> Character in
                    guard y > 2, y < height - 3 else { return " " }
                    return (x + offset * 3 + y * 11) % 29 < 2 && (x / 29 + y) % 3 == 0 ? "R" : " "
                })
            }
        }
        return PixelSprite(frames: [frame(0), frame(1)], palette: ["R": color])
    }

    /// Whether the season draws weather over the map (summer does not).
    static func hasWeather(_ season: Season) -> Bool { season != .summer }

    /// Weather over the whole map: drifting snow in winter, falling leaves
    /// in autumn, blossom in spring; nothing in summer.
    static func seasonal(width: Int, height: Int, season: Season) -> PixelSprite? {
        let (character, color, modulus): (Character, RGBA, Int) = switch season {
        case .winter: ("S", Palettes.translucent(Palettes.stone[0], 220), 41)
        case .autumn: ("L", Palettes.ember[2], 173)
        case .spring: ("P", Palettes.plum[0], 211)
        case .summer: (" ", Palettes.stone[0], 0)
        }
        guard modulus > 0 else { return nil }
        func frame(_ offset: Int) -> [String] {
            (0..<height).map { y in
                String((0..<width).map { x -> Character in
                    let drift = season == .winter ? offset * 2 : offset
                    return ((x + drift) * 5 + (y - offset * 2) * 3 + (x / 7) * 13) % modulus == 0 ? character : " "
                })
            }
        }
        return PixelSprite(frames: [frame(0), frame(1), frame(2), frame(3)], palette: [character: color])
    }
}
// MARK: end S4
