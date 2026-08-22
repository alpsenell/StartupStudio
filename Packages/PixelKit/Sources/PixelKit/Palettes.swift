typealias RGBA = PixelSprite.RGBA

/// The shared color sets characters draw from. Muted-but-warm, tuned to sit
/// next to the app's indigo accent world.
enum Palettes {
    /// (base, shade) pairs, light to deep.
    static let skinTones: [(base: RGBA, shade: RGBA)] = [
        (RGBA(r: 255, g: 219, b: 182), RGBA(r: 233, g: 190, b: 152)),
        (RGBA(r: 240, g: 196, b: 151), RGBA(r: 216, g: 168, b: 124)),
        (RGBA(r: 208, g: 158, b: 110), RGBA(r: 183, g: 132, b: 88)),
        (RGBA(r: 166, g: 112, b: 74), RGBA(r: 140, g: 90, b: 58)),
        (RGBA(r: 118, g: 79, b: 54), RGBA(r: 96, g: 62, b: 42)),
    ]

    /// (base, shade) pairs.
    static let hairColors: [(base: RGBA, shade: RGBA)] = [
        (RGBA(r: 52, g: 48, b: 56), RGBA(r: 38, g: 35, b: 42)),      // black
        (RGBA(r: 92, g: 64, b: 44), RGBA(r: 72, g: 49, b: 34)),      // dark brown
        (RGBA(r: 140, g: 92, b: 52), RGBA(r: 114, g: 73, b: 41)),    // chestnut
        (RGBA(r: 216, g: 180, b: 102), RGBA(r: 190, g: 152, b: 80)), // blonde
        (RGBA(r: 156, g: 74, b: 50), RGBA(r: 128, g: 58, b: 39)),    // auburn
        (RGBA(r: 108, g: 110, b: 150), RGBA(r: 86, g: 88, b: 124)),  // dyed indigo-gray
    ]

    /// (base, shade) pairs — warm palette mixing with the indigo accent world.
    static let shirtColors: [(base: RGBA, shade: RGBA)] = [
        (RGBA(r: 94, g: 96, b: 206), RGBA(r: 76, g: 77, b: 172)),    // indigo
        (RGBA(r: 224, g: 120, b: 86), RGBA(r: 196, g: 98, b: 68)),   // coral
        (RGBA(r: 217, g: 164, b: 65), RGBA(r: 188, g: 138, b: 50)),  // mustard
        (RGBA(r: 62, g: 156, b: 138), RGBA(r: 48, g: 128, b: 112)),  // teal
        (RGBA(r: 196, g: 87, b: 78), RGBA(r: 168, g: 68, b: 60)),    // warm red
        (RGBA(r: 217, g: 140, b: 166), RGBA(r: 190, g: 114, b: 140)),// dusty pink
        (RGBA(r: 138, g: 154, b: 75), RGBA(r: 114, g: 128, b: 60)),  // olive
        (RGBA(r: 107, g: 127, b: 215), RGBA(r: 88, g: 105, b: 184)), // slate blue
    ]

    // Shared fixed tones.
    static let outline = RGBA(r: 32, g: 30, b: 42)
    static let eye = RGBA(r: 40, g: 36, b: 48)
    static let pants = RGBA(r: 54, g: 50, b: 66)
    static let chair = RGBA(r: 72, g: 66, b: 88)
    static let hoodie = RGBA(r: 78, g: 74, b: 168)
    static let hoodieShade = RGBA(r: 64, g: 60, b: 140)
}

/// Small grid utilities for composing authored pixel art.
enum PixelGrid {
    /// Lays `top` over `base` (top-left aligned, optionally shifted down by
    /// `offsetY`). Space pixels in the overlay keep the base pixel; anything
    /// else replaces it.
    static func overlay(base: [String], top: [String], offsetY: Int = 0) -> [String] {
        var out = base
        for (sourceY, row) in top.enumerated() {
            let y = sourceY + offsetY
            guard (0..<out.count).contains(y) else { continue }
            var chars = Array(out[y])
            for (x, ch) in row.enumerated() where ch != " " && x < chars.count {
                chars[x] = ch
            }
            out[y] = String(chars)
        }
        return out
    }
}
