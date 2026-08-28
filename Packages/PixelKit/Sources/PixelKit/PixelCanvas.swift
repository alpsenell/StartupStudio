/// A mutable character grid that other sprites can be stamped into.
///
/// Room backgrounds are authored as one big sprite so the wall dressing —
/// posters, shelves, windows, trim, the skirting shadow — costs nothing at
/// draw time and can never drift out of the room's own bounds. `PixelCanvas`
/// is how a `PixelSprite` (with its own palette) gets merged into that grid:
/// colors are de-duplicated and re-keyed onto free characters as they are
/// needed.
struct PixelCanvas {
    /// Characters available for auto-allocated colors. Printable ASCII,
    /// minus space (always transparent) — comfortably more slots than the
    /// master palette has colors.
    private static let alphabet: [Character] = Array(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&*+,-./:;<=>?@[]^_{|}~"
    )

    private(set) var rows: [[Character]]
    private(set) var palette: [Character: RGBA]
    private var characterForColor: [UInt32: Character] = [:]
    private var nextSlot = 0

    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        rows = Array(repeating: Array(repeating: " ", count: self.width), count: self.height)
        palette = [:]
    }

    /// A blank canvas that inherits another canvas's color-to-character
    /// assignments. Two frames of the same sprite must agree on what each
    /// character means, and painting them independently does not guarantee
    /// that — building the second one `like:` the first does.
    init(like other: PixelCanvas) {
        width = other.width
        height = other.height
        rows = Array(repeating: Array(repeating: " ", count: width), count: height)
        palette = other.palette
        characterForColor = other.characterForColor
        nextSlot = other.nextSlot
    }

    // MARK: Colors

    /// The character that draws `color`, allocating one on first use. When
    /// the alphabet runs out the nearest already-allocated color wins, so a
    /// pathological canvas degrades in quality rather than trapping.
    mutating func key(for color: RGBA) -> Character {
        let id = colorID(color)
        if let existing = characterForColor[id] { return existing }
        guard nextSlot < Self.alphabet.count else { return nearestAllocated(color) }
        let character = Self.alphabet[nextSlot]
        nextSlot += 1
        characterForColor[id] = character
        palette[character] = color
        return character
    }

    private func colorID(_ color: RGBA) -> UInt32 {
        (UInt32(color.a) << 24) | (UInt32(color.r) << 16) | (UInt32(color.g) << 8) | UInt32(color.b)
    }

    private func nearestAllocated(_ color: RGBA) -> Character {
        var best: Character = Self.alphabet[0]
        var bestDistance = Int.max
        for (character, candidate) in palette {
            let dr = Int(candidate.r) - Int(color.r)
            let dg = Int(candidate.g) - Int(color.g)
            let db = Int(candidate.b) - Int(color.b)
            let distance = dr * dr + dg * dg + db * db
            if distance < bestDistance {
                bestDistance = distance
                best = character
            }
        }
        return best
    }

    // MARK: Drawing

    /// Paints one pixel, clipped to the canvas.
    mutating func set(x: Int, y: Int, _ color: RGBA) {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return }
        rows[y][x] = key(for: color)
    }

    /// Reads a pixel's color (nil where the canvas is transparent).
    func color(x: Int, y: Int) -> RGBA? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        return palette[rows[y][x]]
    }

    /// Fills a rectangle, clipped to the canvas.
    mutating func fill(x: Int, y: Int, width w: Int, height h: Int, _ color: RGBA) {
        guard w > 0, h > 0 else { return }
        let character = key(for: color)
        for py in max(0, y)..<min(height, y + h) {
            for px in max(0, x)..<min(width, x + w) {
                rows[py][px] = character
            }
        }
    }

    /// Draws a horizontal run.
    mutating func hLine(x: Int, y: Int, length: Int, _ color: RGBA) {
        fill(x: x, y: y, width: length, height: 1, color)
    }

    /// Draws a vertical run.
    mutating func vLine(x: Int, y: Int, length: Int, _ color: RGBA) {
        fill(x: x, y: y, width: 1, height: length, color)
    }

    /// Stamps a sprite frame with its top-left at (x, y). Transparent
    /// sprite pixels leave the canvas untouched; translucent ones are
    /// composited over whatever is already there so glows and shadows read.
    mutating func stamp(_ sprite: PixelSprite, x: Int, y: Int, frame: Int = 0) {
        let grid = sprite.frames[min(frame, sprite.frameCount - 1)]
        for (row, line) in grid.enumerated() {
            for (column, character) in line.enumerated() {
                guard character != " ", let source = sprite.palette[character] else { continue }
                let px = x + column
                let py = y + row
                guard (0..<width).contains(px), (0..<height).contains(py) else { continue }
                if source.a == 255 {
                    rows[py][px] = key(for: source)
                } else if let under = color(x: px, y: py) {
                    rows[py][px] = key(for: composite(over: under, source))
                } else {
                    rows[py][px] = key(for: source)
                }
            }
        }
    }

    /// Source-over of a translucent master color onto an opaque one, snapped
    /// back onto the master palette so stamping can never leak a new color.
    private func composite(over background: RGBA, _ color: RGBA) -> RGBA {
        guard background.a == 255 else { return color }
        return Palettes.blended(background, toward: color, amount: Double(color.a) / 255)
    }

    /// Lays a soft contact shadow on the floor under a sprite footprint: a
    /// one-pixel band, inset a little at both ends so it reads as cast light
    /// rather than a black bar.
    mutating func contactShadow(x: Int, y: Int, width w: Int, inset: Int = 1) {
        for px in (x + inset)..<(x + w - inset) {
            guard let under = color(x: px, y: y) else { continue }
            set(x: px, y: y, Palettes.shaded(under, by: 0.34))
        }
    }

    // MARK: Output

    /// The finished single-frame sprite.
    func sprite() -> PixelSprite {
        sprite(followedBy: [])
    }

    /// The finished multi-frame sprite: this canvas's grid, then each of
    /// `others` (which must have been built `like:` this one).
    func sprite(followedBy others: [PixelCanvas]) -> PixelSprite {
        var merged = palette
        for other in others { merged.merge(other.palette) { first, _ in first } }
        let frames = ([self] + others).map { canvas in canvas.rows.map { String($0) } }
        return PixelSprite(frames: frames, palette: merged)
    }
}
