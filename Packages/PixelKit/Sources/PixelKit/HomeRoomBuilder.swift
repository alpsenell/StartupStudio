/// Evening room backgrounds for the home tiers: cool night walls, warm wood
/// (or marble) floors, a door on the back wall, and the same 1px dark frame
/// as the office rooms. Deterministic modular patterns, no randomness.
extension RoomBuilder {
    struct Rect: Equatable {
        let x: Int, y: Int, width: Int, height: Int

        func contains(_ x: Int, _ y: Int) -> Bool {
            (self.x..<self.x + width).contains(x) && (self.y..<self.y + height).contains(y)
        }
    }

    static func homeRoom(tier: HomeTierStyle, width: Int, height: Int, wallHeight: Int, rug: Rect? = nil) -> PixelSprite {
        var rows: [String] = []
        rows.reserveCapacity(height)
        for y in 0..<height {
            var chars: [Character] = []
            chars.reserveCapacity(width)
            for x in 0..<width {
                chars.append(homeCharacter(tier: tier, x: x, y: y, width: width, height: height, wallHeight: wallHeight, rug: rug))
            }
            rows.append(String(chars))
        }
        return PixelSprite(frames: [rows], palette: homePalette(for: tier))
    }

    /// Door on the back wall, right side: 10 wide, 22 tall, sitting on the
    /// baseboard. Scenes put the suitcase at its foot.
    static func doorFrame(width: Int, wallHeight: Int) -> (x: Int, y: Int, width: Int, height: Int) {
        (x: width - 15, y: wallHeight - 23, width: 10, height: 22)
    }

    private static func homeCharacter(
        tier: HomeTierStyle, x: Int, y: Int, width: Int, height: Int, wallHeight: Int, rug: Rect?
    ) -> Character {
        if x == 0 || y == 0 || x == width - 1 || y == height - 1 { return "O" }

        if y < wallHeight {
            if y == wallHeight - 1 { return "B" } // baseboard

            let door = doorFrame(width: width, wallHeight: wallHeight)
            if (door.x..<door.x + door.width).contains(x) && (door.y..<door.y + door.height).contains(y) {
                let edge = x == door.x || x == door.x + door.width - 1 || y == door.y
                if edge { return "f" }
                if x == door.x + door.width - 3 && y == door.y + door.height / 2 { return "K" } // knob
                // Two recessed panels.
                let panelX = (door.x + 2..<door.x + door.width - 2).contains(x)
                let upper = (door.y + 3..<door.y + 9).contains(y)
                let lower = (door.y + 12..<door.y + door.height - 2).contains(y)
                return panelX && (upper || lower) ? "g" : "F"
            }

            switch tier {
            case .house:
                // Wainscot panelling on the lower wall with a trim line.
                if y == wallHeight - 13 { return "T" }
                if y > wallHeight - 13 { return x % 8 == 0 ? "T" : "W" }
                return "A"
            case .penthouse:
                // Subtle vertical seams between wall panels.
                return x % 44 == 3 && x > 3 ? "B" : "A"
            default:
                return "A"
            }
        }

        // Rug: a bordered weave with an inset band.
        if let rug, rug.contains(x, y) {
            let dx = min(x - rug.x, rug.x + rug.width - 1 - x)
            let dy = min(y - rug.y, rug.y + rug.height - 1 - y)
            let inset = min(dx, dy)
            if inset == 0 || inset == 2 { return "R" }
            return (x + y).isMultiple(of: 5) && inset > 3 ? "R" : "r"
        }

        // Floors.
        let fy = y - wallHeight
        switch tier {
        case .studioFlat:
            // Narrow worn planks: seam every 3rd row, staggered ends.
            if fy % 3 == 2 { return "D" }
            return (x + (fy / 3) * 5) % 11 == 0 ? "D" : "C"
        case .apartment:
            // Wider oak planks.
            if fy % 4 == 3 { return "D" }
            return (x + (fy / 4) * 9) % 16 == 0 ? "D" : "C"
        case .house:
            // Broad walnut boards.
            if fy % 5 == 4 { return "D" }
            return (x + (fy / 5) * 11) % 20 == 0 ? "D" : "C"
        case .penthouse:
            // Large pale tiles with grout.
            return (x % 12 == 0 || fy % 6 == 5) ? "D" : "C"
        }
    }

    private static func homePalette(for tier: HomeTierStyle) -> [Character: RGBA] {
        var palette: [Character: RGBA] = [
            "O": Palettes.outline,
            "F": RGBA(r: 110, g: 78, b: 54),  // door
            "g": RGBA(r: 96, g: 66, b: 46),   // door panel
            "f": RGBA(r: 58, g: 42, b: 34),   // door frame
            "K": RGBA(r: 236, g: 204, b: 120), // knob
        ]
        switch tier {
        case .studioFlat:
            palette["A"] = RGBA(r: 70, g: 72, b: 98)
            palette["B"] = RGBA(r: 46, g: 46, b: 66)
            palette["C"] = RGBA(r: 124, g: 90, b: 60)
            palette["D"] = RGBA(r: 102, g: 72, b: 48)
        case .apartment:
            palette["A"] = RGBA(r: 56, g: 64, b: 104)
            palette["B"] = RGBA(r: 38, g: 42, b: 72)
            palette["C"] = RGBA(r: 152, g: 112, b: 72)
            palette["D"] = RGBA(r: 128, g: 92, b: 58)
            palette["R"] = RGBA(r: 150, g: 70, b: 76)
            palette["r"] = RGBA(r: 178, g: 92, b: 96)
        case .house:
            palette["A"] = RGBA(r: 84, g: 70, b: 100)
            palette["W"] = RGBA(r: 64, g: 52, b: 80)
            palette["T"] = RGBA(r: 104, g: 88, b: 120)
            palette["B"] = RGBA(r: 46, g: 38, b: 58)
            palette["C"] = RGBA(r: 112, g: 74, b: 48)
            palette["D"] = RGBA(r: 92, g: 60, b: 40)
            palette["R"] = RGBA(r: 58, g: 110, b: 104)
            palette["r"] = RGBA(r: 76, g: 136, b: 128)
        case .penthouse:
            palette["A"] = RGBA(r: 42, g: 46, b: 66)
            palette["B"] = RGBA(r: 30, g: 32, b: 48)
            palette["C"] = RGBA(r: 98, g: 102, b: 122)
            palette["D"] = RGBA(r: 84, g: 88, b: 108)
            palette["R"] = RGBA(r: 64, g: 70, b: 104)
            palette["r"] = RGBA(r: 84, g: 92, b: 130)
        }
        return palette
    }
}
