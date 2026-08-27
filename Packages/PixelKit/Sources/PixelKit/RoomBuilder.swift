/// Generates the room background sprite (walls + floor + 1px dark outline
/// frame) for a tier. Patterns are fixed modular functions — deterministic,
/// no randomness.
enum RoomBuilder {
    /// The office room at a time of day.
    ///
    /// Scaffold placeholder: delegates straight to `room(...)` and ignores
    /// `time`, so every hour draws today's daylight room. WS-D tints the
    /// wall and floor per `time` behind this signature; WS-C calls it from
    /// day one.
    static func officeRoom(
        tier: OfficeTierStyle,
        width: Int,
        height: Int,
        wallHeight: Int,
        time: TimeOfDay = .day
    ) -> PixelSprite {
        room(tier: tier, width: width, height: height, wallHeight: wallHeight)
    }

    static func room(tier: OfficeTierStyle, width: Int, height: Int, wallHeight: Int) -> PixelSprite {
        var rows: [String] = []
        rows.reserveCapacity(height)
        let bulbX = width / 2
        for y in 0..<height {
            var chars: [Character] = []
            chars.reserveCapacity(width)
            for x in 0..<width {
                chars.append(character(tier: tier, x: x, y: y, width: width, height: height, wallHeight: wallHeight, bulbX: bulbX))
            }
            rows.append(String(chars))
        }
        return PixelSprite(frames: [rows], palette: palette(for: tier))
    }

    private static func character(
        tier: OfficeTierStyle, x: Int, y: Int,
        width: Int, height: Int, wallHeight: Int, bulbX: Int
    ) -> Character {
        // 1px dark outline frame so the scene reads on light and dark surroundings.
        if x == 0 || y == 0 || x == width - 1 || y == height - 1 { return "O" }

        if y < wallHeight {
            // Garage charm: a bare bulb hanging from the ceiling on a cord.
            if tier == .garage {
                if x == bulbX && (1...3).contains(y) { return "E" }
                if (bulbX - 1...bulbX).contains(x) && (4...5).contains(y) { return "Y" }
            }
            if y == wallHeight - 1 { return "B" } // baseboard
            return "A"
        }

        // Floor patterns.
        switch tier {
        case .garage:
            // Concrete with sparse deterministic speckle.
            return (x * 7 + y * 13) % 31 == 0 ? "D" : "C"
        case .loft:
            // Wood planks: seam row every 3rd line, staggered plank ends.
            if y % 3 == 2 { return "D" }
            return (x + (y / 3) * 7) % 14 == 0 ? "D" : "C"
        case .studio:
            // Two-tone carpet checker.
            return ((x / 2) + (y / 2)).isMultiple(of: 2) ? "C" : "D"
        case .campus:
            // Large tiles.
            return (x % 12 == 0 || (y - wallHeight) % 6 == 0) ? "D" : "C"
        }
    }

    private static func palette(for tier: OfficeTierStyle) -> [Character: RGBA] {
        var palette: [Character: RGBA] = ["O": Palettes.outline]
        switch tier {
        case .garage:
            palette["A"] = RGBA(r: 124, g: 118, b: 112)
            palette["B"] = RGBA(r: 86, g: 80, b: 76)
            palette["C"] = RGBA(r: 158, g: 154, b: 148)
            palette["D"] = RGBA(r: 144, g: 140, b: 134)
            palette["E"] = RGBA(r: 60, g: 56, b: 54)
            palette["Y"] = RGBA(r: 255, g: 222, b: 120)
        case .loft:
            palette["A"] = RGBA(r: 216, g: 198, b: 174)
            palette["B"] = RGBA(r: 140, g: 120, b: 100)
            palette["C"] = RGBA(r: 182, g: 140, b: 96)
            palette["D"] = RGBA(r: 156, g: 116, b: 76)
        case .studio:
            palette["A"] = RGBA(r: 190, g: 194, b: 204)
            palette["B"] = RGBA(r: 120, g: 122, b: 134)
            palette["C"] = RGBA(r: 128, g: 132, b: 158)
            palette["D"] = RGBA(r: 120, g: 124, b: 149)
        case .campus:
            palette["A"] = RGBA(r: 224, g: 226, b: 232)
            palette["B"] = RGBA(r: 150, g: 152, b: 160)
            palette["C"] = RGBA(r: 203, g: 205, b: 212)
            palette["D"] = RGBA(r: 192, g: 194, b: 202)
        }
        return palette
    }
}
