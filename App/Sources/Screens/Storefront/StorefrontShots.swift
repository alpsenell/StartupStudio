import PixelKit
import SwiftUI

/// The three "screenshots" a product shows on its storefront page, drawn
/// deterministically from its type, topic and id — no art assets, no
/// randomness, and the same product always draws the same strip.
///
/// The split of responsibilities is the one the doc asks for read the way
/// that carries the most information: the **type** picks the device chrome
/// (a phone for a mobile app, a browser window for a web app, a monitor
/// for a desktop tool, a wide screen for a game, a sidebar console for
/// SaaS and enterprise), and the **topic** picks both the UI motif inside
/// the screen (a feed for social, a chart for finance, a map for
/// logistics, a player for music…) and the tint. Six types × twelve topics
/// therefore read as seventy-two distinct strips rather than six.
///
/// The three shots are the three pages every real store listing has: the
/// home screen (the motif), a detail page (a hero band over the motif),
/// and a stats page (a bar chart in the product's own colour). The seed
/// varies the numbers inside them, so two fitness apps differ.
///
/// Grids are `PixelSprite` frames, exactly like `ProductBoxArt`, so the
/// determinism test can compare rows of characters and the view is one
/// `Image` with `.interpolation(.none)`.
enum StorefrontShots {
    /// Shots per product. Three, as an app-store listing has.
    static let shotCount = 3

    /// Grid size in pixels. 9:16, so a phone fills it and every other
    /// chrome sits inside the same frame.
    static let width = 32
    static let height = 56

    // MARK: Sprites

    /// The sprite for one shot, `shot` in `0..<shotCount`.
    static func sprite(typeID: String, topicID: String, seed: UInt64, shot: Int) -> PixelSprite {
        PixelSprite(
            frames: [grid(typeID: typeID, topicID: topicID, seed: seed, shot: shot)],
            palette: palette(topicID: topicID)
        )
    }

    /// The character grid for one shot. The unit the determinism test
    /// compares.
    static func grid(typeID: String, topicID: String, seed: UInt64, shot: Int) -> [String] {
        var canvas = ShotCanvas()
        let shotSeed = mix(seed, UInt64(bitPattern: Int64(shot)) &+ 1)
        let screen = chrome(for: typeID).draw(into: &canvas)
        paint(shot: shot, in: screen, motif: motif(for: topicID), seed: shotSeed, canvas: &canvas)
        return canvas.rows
    }

    // MARK: Palette

    /// The same six hues, chosen by the same FNV-1a hash of the topic, as
    /// `ProductBoxArt` — deliberately duplicated rather than shared,
    /// because the box art's table is private to its own component and the
    /// one thing that must hold is that a product's shots are the colour
    /// of its box.
    private static let hues: [(base: PixelSprite.RGBA, shade: PixelSprite.RGBA)] = [
        (.init(r: 94, g: 96, b: 206), .init(r: 66, g: 68, b: 156)),
        (.init(r: 224, g: 120, b: 86), .init(r: 176, g: 88, b: 60)),
        (.init(r: 62, g: 156, b: 138), .init(r: 42, g: 116, b: 102)),
        (.init(r: 217, g: 164, b: 65), .init(r: 168, g: 124, b: 44)),
        (.init(r: 196, g: 87, b: 78), .init(r: 148, g: 60, b: 54)),
        (.init(r: 138, g: 154, b: 75), .init(r: 100, g: 116, b: 52)),
    ]

    private static func palette(topicID: String) -> [Character: PixelSprite.RGBA] {
        let hue = hues[Int(hash(topicID) % UInt64(hues.count))]
        return [
            // Backdrop behind the device: the topic's shade, so the strip
            // reads as three tinted tiles from across the room.
            "K": hue.shade,
            // Device body and outline.
            "O": PixelSprite.RGBA(r: 32, g: 30, b: 42),
            "F": PixelSprite.RGBA(r: 58, g: 56, b: 74),
            // The screen: paper, its dim rules, and the accent.
            "P": PixelSprite.RGBA(r: 244, g: 238, b: 226),
            "G": PixelSprite.RGBA(r: 200, g: 204, b: 216),
            "A": hue.base,
            "S": hue.shade,
        ]
    }

    // MARK: Chrome (the type)

    /// The device a product type is shown on.
    enum Chrome {
        case phone
        case browser
        case monitor
        case widescreen
        case console

        /// Draws the device and returns the rectangle of live screen.
        func draw(into canvas: inout ShotCanvas) -> Rect {
            canvas.fill(Rect(x: 0, y: 0, width: width, height: height), "K")
            switch self {
            case .phone:
                let body = Rect(x: 4, y: 3, width: 24, height: 50)
                canvas.fill(body, "O")
                let screen = body.inset(by: 2)
                canvas.fill(screen, "P")
                // Status bar and home indicator, in the device's own ink.
                canvas.fill(Rect(x: screen.x + 8, y: screen.y, width: 8, height: 1), "F")
                canvas.fill(
                    Rect(x: screen.x + 6, y: screen.maxY - 1, width: 12, height: 1), "F"
                )
                return Rect(
                    x: screen.x, y: screen.y + 2, width: screen.width, height: screen.height - 4
                )
            case .browser:
                let body = Rect(x: 1, y: 10, width: 30, height: 36)
                canvas.fill(body, "O")
                let chromeBar = Rect(x: body.x + 1, y: body.y + 1, width: body.width - 2, height: 4)
                canvas.fill(chromeBar, "F")
                // Three window dots and an address field.
                for index in 0..<3 {
                    canvas.set(x: chromeBar.x + 1 + index * 2, y: chromeBar.y + 1, "P")
                }
                canvas.fill(Rect(x: chromeBar.x + 8, y: chromeBar.y + 1, width: 18, height: 2), "G")
                let screen = Rect(
                    x: body.x + 1, y: chromeBar.maxY, width: body.width - 2, height: body.maxY - chromeBar.maxY - 1
                )
                canvas.fill(screen, "P")
                return screen
            case .monitor:
                let body = Rect(x: 1, y: 8, width: 30, height: 32)
                canvas.fill(body, "O")
                let screen = body.inset(by: 2)
                canvas.fill(screen, "P")
                // Stand and base.
                canvas.fill(Rect(x: 13, y: body.maxY, width: 6, height: 5), "F")
                canvas.fill(Rect(x: 8, y: body.maxY + 5, width: 16, height: 2), "O")
                return screen
            case .widescreen:
                let body = Rect(x: 0, y: 13, width: 32, height: 26)
                canvas.fill(body, "O")
                let screen = body.inset(by: 2)
                canvas.fill(screen, "P")
                // Letterbox bars above and below, as a game's own frame.
                canvas.fill(Rect(x: 0, y: 6, width: 32, height: 5), "F")
                canvas.fill(Rect(x: 0, y: 41, width: 32, height: 5), "F")
                return screen
            case .console:
                let body = Rect(x: 1, y: 6, width: 30, height: 42)
                canvas.fill(body, "O")
                let inner = body.inset(by: 2)
                canvas.fill(inner, "P")
                // A sidebar of navigation rows: the shape every admin
                // console has and no consumer app does.
                let sidebar = Rect(x: inner.x, y: inner.y, width: 7, height: inner.height)
                canvas.fill(sidebar, "F")
                for row in 0..<5 {
                    canvas.fill(
                        Rect(x: sidebar.x + 1, y: sidebar.y + 2 + row * 4, width: 5, height: 2), "G"
                    )
                }
                return Rect(
                    x: sidebar.maxX + 1, y: inner.y, width: inner.maxX - sidebar.maxX - 1,
                    height: inner.height
                )
            }
        }
    }

    /// The device for a product type id. Matched by prefix, so
    /// `mobile_app` and a future `mobile_game` both get the phone and
    /// anything unrecognized gets the monitor.
    static func chrome(for typeID: String) -> Chrome {
        if typeID.hasPrefix("mobile") { return .phone }
        if typeID.hasPrefix("web") { return .browser }
        if typeID.hasPrefix("game") { return .widescreen }
        if typeID.hasPrefix("saas") || typeID.hasPrefix("enterprise") { return .console }
        return .monitor
    }

    // MARK: Motifs (the topic)

    /// What the app looks like it does.
    enum Motif {
        /// Avatar + two lines, repeating: social, dating's discover page.
        case feed
        /// A bar chart with a baseline: finance.
        case chart
        /// Streets, blocks and a pin: travel, logistics, food delivery.
        case map
        /// Labelled progress bars: fitness, health.
        case meter
        /// A checked list: productivity, education.
        case list
        /// Cover art, a scrubber and a waveform: music.
        case player
        /// A grid of tiles: gaming.
        case grid
        /// A stacked card with two buttons: dating.
        case cards
    }

    /// The motif for a topic id. Every id in `Topics.json` is named; an
    /// unknown topic falls back to the feed, the most generic app shape.
    static func motif(for topicID: String) -> Motif {
        switch topicID {
        case "social": .feed
        case "finance": .chart
        case "travel", "logistics", "food_delivery": .map
        case "fitness", "health": .meter
        case "productivity", "education": .list
        case "music": .player
        case "gaming": .grid
        case "dating": .cards
        default: .feed
        }
    }

    // MARK: Painting the three pages

    /// Shot 0 is the home screen (the motif alone), shot 1 the detail page
    /// (a hero band in the product's colour, then the motif under it), and
    /// shot 2 the stats page (a bar chart, whatever the topic is — every
    /// app has one).
    private static func paint(
        shot: Int, in screen: Rect, motif: Motif, seed: UInt64, canvas: inout ShotCanvas
    ) {
        guard screen.width > 4, screen.height > 6 else { return }
        switch shot {
        case 0:
            paint(motif: motif, in: screen, seed: seed, canvas: &canvas)
        case 1:
            // A hero band, a title rule under it, then the motif in what
            // is left — the shape of a detail page.
            let heroHeight = max(4, screen.height / 4)
            let hero = Rect(x: screen.x, y: screen.y, width: screen.width, height: heroHeight)
            canvas.fill(hero, "A")
            canvas.fill(
                Rect(x: hero.x + 1, y: hero.maxY, width: max(1, hero.width - 8), height: 1), "S"
            )
            let rest = Rect(
                x: screen.x, y: hero.maxY + 2, width: screen.width, height: screen.maxY - hero.maxY - 2
            )
            if rest.height > 4 {
                paint(motif: motif, in: rest, seed: mix(seed, 7), canvas: &canvas)
            }
        default:
            paintChart(in: screen, seed: seed, canvas: &canvas, withAxis: true)
        }
    }

    private static func paint(motif: Motif, in rect: Rect, seed: UInt64, canvas: inout ShotCanvas) {
        switch motif {
        case .feed: paintFeed(in: rect, seed: seed, canvas: &canvas)
        case .chart: paintChart(in: rect, seed: seed, canvas: &canvas, withAxis: false)
        case .map: paintMap(in: rect, seed: seed, canvas: &canvas)
        case .meter: paintMeter(in: rect, seed: seed, canvas: &canvas)
        case .list: paintList(in: rect, seed: seed, canvas: &canvas)
        case .player: paintPlayer(in: rect, seed: seed, canvas: &canvas)
        case .grid: paintGrid(in: rect, seed: seed, canvas: &canvas)
        case .cards: paintCards(in: rect, seed: seed, canvas: &canvas)
        }
    }

    private static func paintFeed(in rect: Rect, seed: UInt64, canvas: inout ShotCanvas) {
        var y = rect.y + 1
        var index = 0
        while y + 5 <= rect.maxY {
            canvas.fill(Rect(x: rect.x + 1, y: y, width: 4, height: 4), "A")
            let long = rect.width - 8
            let short = max(2, long - Int(bit(seed, index) ? 3 : 6))
            canvas.fill(Rect(x: rect.x + 6, y: y, width: long, height: 1), "G")
            canvas.fill(Rect(x: rect.x + 6, y: y + 2, width: short, height: 1), "G")
            y += 6
            index += 1
        }
    }

    private static func paintChart(
        in rect: Rect, seed: UInt64, canvas: inout ShotCanvas, withAxis: Bool
    ) {
        let plot = withAxis
            ? Rect(x: rect.x + 2, y: rect.y + 2, width: rect.width - 3, height: rect.height - 4)
            : rect.inset(by: 1)
        guard plot.width > 3, plot.height > 3 else { return }
        if withAxis {
            canvas.fill(Rect(x: plot.x - 1, y: plot.y, width: 1, height: plot.height + 1), "G")
            canvas.fill(Rect(x: plot.x - 1, y: plot.maxY, width: plot.width + 1, height: 1), "G")
        }
        let barWidth = 2
        let step = barWidth + 1
        let count = max(1, plot.width / step)
        for index in 0..<count {
            // Heights walk the seed's bits, so the chart is different for
            // every product but the same one every time.
            let level = Int((seed >> UInt64((index * 5) % 60)) & 0x7)
            let barHeight = max(1, (plot.height * (level + 2)) / 10)
            canvas.fill(
                Rect(
                    x: plot.x + index * step, y: plot.maxY - barHeight,
                    width: barWidth, height: barHeight
                ),
                index.isMultiple(of: 2) ? "A" : "S"
            )
        }
    }

    private static func paintMap(in rect: Rect, seed: UInt64, canvas: inout ShotCanvas) {
        let area = rect.inset(by: 1)
        guard area.width > 4, area.height > 4 else { return }
        canvas.fill(area, "G")
        // Two roads crossing, their positions walked off the seed.
        let roadY = area.y + 1 + Int(seed % UInt64(max(1, area.height - 2)))
        let roadX = area.x + 1 + Int((seed >> 8) % UInt64(max(1, area.width - 2)))
        canvas.fill(Rect(x: area.x, y: roadY, width: area.width, height: 1), "P")
        canvas.fill(Rect(x: roadX, y: area.y, width: 1, height: area.height), "P")
        // City blocks in the quadrants the roads leave.
        var y = area.y + 1
        var index = 0
        while y + 2 <= area.maxY {
            var x = area.x + 1
            while x + 2 <= area.maxX {
                if x != roadX, y != roadY, bit(seed, index) {
                    canvas.fill(Rect(x: x, y: y, width: 2, height: 2), "S")
                }
                x += 3
                index += 1
            }
            y += 3
        }
        // The pin, on the crossing.
        canvas.fill(Rect(x: roadX - 1, y: roadY - 2, width: 3, height: 3), "A")
        canvas.set(x: roadX, y: roadY + 1, "A")
    }

    private static func paintMeter(in rect: Rect, seed: UInt64, canvas: inout ShotCanvas) {
        var y = rect.y + 2
        var index = 0
        while y + 3 <= rect.maxY {
            let track = Rect(x: rect.x + 2, y: y, width: rect.width - 4, height: 2)
            canvas.fill(track, "G")
            let level = Int((seed >> UInt64((index * 7) % 56)) & 0x7)
            let filled = max(1, (track.width * (level + 2)) / 9)
            canvas.fill(Rect(x: track.x, y: track.y, width: filled, height: 2), "A")
            y += 5
            index += 1
        }
    }

    private static func paintList(in rect: Rect, seed: UInt64, canvas: inout ShotCanvas) {
        var y = rect.y + 1
        var index = 0
        while y + 2 <= rect.maxY {
            let done = bit(seed, index)
            canvas.fill(Rect(x: rect.x + 2, y: y, width: 2, height: 2), done ? "A" : "G")
            let lineWidth = max(2, rect.width - 8 - (index % 3))
            canvas.fill(Rect(x: rect.x + 6, y: y, width: lineWidth, height: 1), "G")
            y += 4
            index += 1
        }
    }

    private static func paintPlayer(in rect: Rect, seed: UInt64, canvas: inout ShotCanvas) {
        let side = min(rect.width - 4, rect.height / 2)
        guard side > 3 else { return paintFeed(in: rect, seed: seed, canvas: &canvas) }
        let art = Rect(x: rect.x + (rect.width - side) / 2, y: rect.y + 1, width: side, height: side)
        canvas.fill(art, "A")
        canvas.fill(art.inset(by: side / 3), "P")
        // Scrubber.
        let scrub = Rect(x: rect.x + 2, y: art.maxY + 2, width: rect.width - 4, height: 1)
        canvas.fill(scrub, "G")
        canvas.fill(
            Rect(x: scrub.x, y: scrub.y, width: max(1, scrub.width * Int(2 + seed % 6) / 8), height: 1),
            "S"
        )
        // Waveform under it.
        let baseline = scrub.y + 3
        var x = rect.x + 2
        var index = 0
        while x < rect.maxX - 1, baseline + 1 <= rect.maxY {
            let level = Int((seed >> UInt64((index * 3) % 60)) & 0x3) + 1
            let top = max(rect.y, baseline - level)
            canvas.fill(Rect(x: x, y: top, width: 1, height: min(level * 2, rect.maxY - top + 1)), "A")
            x += 2
            index += 1
        }
    }

    private static func paintGrid(in rect: Rect, seed: UInt64, canvas: inout ShotCanvas) {
        let tile = 5
        var y = rect.y + 1
        var index = 0
        while y + tile <= rect.maxY {
            var x = rect.x + 2
            while x + tile <= rect.maxX {
                canvas.fill(Rect(x: x, y: y, width: tile - 1, height: tile - 1), bit(seed, index) ? "A" : "S")
                x += tile + 1
                index += 1
            }
            y += tile + 1
        }
    }

    private static func paintCards(in rect: Rect, seed: UInt64, canvas: inout ShotCanvas) {
        let card = Rect(
            x: rect.x + 2, y: rect.y + 1, width: rect.width - 4, height: max(4, rect.height - 8)
        )
        // The card behind, peeking out: a stack, which is what the shape
        // means.
        canvas.fill(Rect(x: card.x + 2, y: card.y + 2, width: card.width, height: card.height), "S")
        canvas.fill(card, "A")
        canvas.fill(card.inset(by: 2), "P")
        canvas.fill(
            Rect(x: card.x + 3, y: card.maxY - 4, width: max(1, card.width - 6), height: 1), "G"
        )
        // Two buttons under it.
        let buttonY = card.maxY + 2
        guard buttonY + 2 <= rect.maxY else { return }
        let buttonWidth = max(2, (rect.width - 8) / 2)
        canvas.fill(Rect(x: rect.x + 2, y: buttonY, width: buttonWidth, height: 3), bit(seed, 0) ? "S" : "G")
        canvas.fill(
            Rect(x: rect.maxX - 1 - buttonWidth, y: buttonY, width: buttonWidth, height: 3), "A"
        )
    }

    // MARK: Grid plumbing

    /// An integer rectangle in grid pixels.
    struct Rect {
        var x: Int
        var y: Int
        var width: Int
        var height: Int

        var maxX: Int { x + width - 1 }
        var maxY: Int { y + height - 1 }

        func inset(by amount: Int) -> Rect {
            Rect(
                x: x + amount, y: y + amount,
                width: max(0, width - amount * 2), height: max(0, height - amount * 2)
            )
        }
    }

    /// A mutable character grid, clipped at the edges so a motif can never
    /// paint outside the shot.
    struct ShotCanvas {
        private(set) var rows: [String]
        private var cells: [[Character]]

        init() {
            cells = [[Character]](
                repeating: [Character](repeating: "K", count: StorefrontShots.width),
                count: StorefrontShots.height
            )
            rows = cells.map { String($0) }
        }

        mutating func set(x: Int, y: Int, _ character: Character) {
            guard cells.indices.contains(y), cells[y].indices.contains(x) else { return }
            cells[y][x] = character
            rows[y] = String(cells[y])
        }

        mutating func fill(_ rect: Rect, _ character: Character) {
            guard rect.width > 0, rect.height > 0 else { return }
            for y in rect.y...rect.maxY {
                guard cells.indices.contains(y) else { continue }
                var line = cells[y]
                for x in rect.x...rect.maxX where line.indices.contains(x) {
                    line[x] = character
                }
                cells[y] = line
                rows[y] = String(line)
            }
        }
    }

    /// One bit of the seed, for the yes/no decisions inside a motif.
    private static func bit(_ seed: UInt64, _ index: Int) -> Bool {
        (seed >> UInt64(index % 64)) & 1 == 1
    }

    /// Folds a shot index into the product seed so the three pages differ
    /// without another hash function.
    private static func mix(_ seed: UInt64, _ salt: UInt64) -> UInt64 {
        var value = seed ^ (salt &* 0x9E37_79B9_7F4A_7C15)
        value ^= value >> 30
        value = value &* 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        return value
    }

    /// FNV-1a, the same one `ProductBoxArt` uses, so a topic picks the
    /// same hue in both.
    private static func hash(_ string: String) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01B3
        }
        return value
    }
}

/// One generated screenshot, drawn crisp at any size.
struct StorefrontShotView: View {
    let typeID: String
    let topicID: String
    let seed: UInt64
    let shot: Int
    var pixelScale: CGFloat = 3

    var body: some View {
        let sprite = StorefrontShots.sprite(
            typeID: typeID, topicID: topicID, seed: seed, shot: shot
        )
        Image(decorative: sprite.cgImage(frame: 0), scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(
                width: CGFloat(StorefrontShots.width) * pixelScale,
                height: CGFloat(StorefrontShots.height) * pixelScale
            )
            .accessibilityHidden(true)
    }
}

/// The horizontal strip of all three shots, each in a pixel frame.
///
/// Deliberately not a `ScrollView`: three shots always fit across a phone,
/// and a scroll view renders blank under `ImageRenderer`, which is how
/// every screen in this app is snapshotted. `ViewThatFits` picks the
/// largest whole-pixel scale that fits instead — a fractional scale would
/// give some sprite pixels two points and others three.
struct StorefrontShotStrip: View {
    let typeID: String
    let topicID: String
    let seed: UInt64
    /// Points per sprite pixel, largest first. Whole numbers only.
    var pixelScales: [CGFloat] = [3, 2]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(pixelScales, id: \.self) { scale in
                row(pixelScale: scale)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Three screenshots of the app")
    }

    private func row(pixelScale: CGFloat) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(0..<StorefrontShots.shotCount, id: \.self) { shot in
                StorefrontShotView(
                    typeID: typeID, topicID: topicID, seed: seed, shot: shot,
                    pixelScale: pixelScale
                )
                .overlay {
                    PixelPanelBorder(thickness: 3, corner: 3)
                        .fill(Theme.pixelInk)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
