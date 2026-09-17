import PixelKit
import SwiftUI

/// Generated cover art for a product: a 24×24 pixel "box" built
/// deterministically from the product's type, topic and id.
///
/// Every shipped product gets a face the player recognizes in the journal
/// and on launch day, with no art assets and no randomness — the same
/// product always draws the same box.
enum ProductBoxArt {
    /// Builds the sprite for a product.
    ///
    /// - Parameters:
    ///   - typeID: the product type id as `ProductTypes.json` spells it
    ///     ("mobile_app", "saas_platform", …); picks the silhouette.
    ///   - topicID: the topic id; picks the palette.
    ///   - seed: the product id's low bits; picks the pattern variation.
    static func sprite(typeID: String, topicID: String, seed: UInt64) -> PixelSprite {
        let palette = palette(topicID: topicID, seed: seed)
        return PixelSprite(frames: [grid(typeID: typeID, seed: seed)], palette: palette)
    }

    /// Six hues, chosen by hashing the topic so a "fitness" app is always
    /// the same green.
    private static let hues: [(base: PixelSprite.RGBA, shade: PixelSprite.RGBA)] = [
        (.init(r: 94, g: 96, b: 206), .init(r: 66, g: 68, b: 156)),
        (.init(r: 224, g: 120, b: 86), .init(r: 176, g: 88, b: 60)),
        (.init(r: 62, g: 156, b: 138), .init(r: 42, g: 116, b: 102)),
        (.init(r: 217, g: 164, b: 65), .init(r: 168, g: 124, b: 44)),
        (.init(r: 196, g: 87, b: 78), .init(r: 148, g: 60, b: 54)),
        (.init(r: 138, g: 154, b: 75), .init(r: 100, g: 116, b: 52)),
    ]

    private static func palette(topicID: String, seed: UInt64) -> [Character: PixelSprite.RGBA] {
        let hue = hues[Int(hash(topicID) % UInt64(hues.count))]
        return [
            "O": PixelSprite.RGBA(r: 32, g: 30, b: 42),
            "B": hue.base,
            "S": hue.shade,
            "L": PixelSprite.RGBA(r: 244, g: 238, b: 226),
            "G": PixelSprite.RGBA(r: 200, g: 204, b: 216),
            "D": PixelSprite.RGBA(r: 58, g: 56, b: 74),
        ]
    }

    /// The 24×24 grid: a boxed cover with a darker spine down the right
    /// edge, the type's device silhouette in the middle, and a row of
    /// "sticker" pixels along the bottom that varies with the seed.
    private static func grid(typeID: String, seed: UInt64) -> [String] {
        var rows = [String](repeating: String(repeating: "B", count: 24), count: 24)

        // Outline, and the three-column spine on the right that gives the
        // box its thickness.
        rows[0] = String(repeating: "O", count: 24)
        rows[23] = String(repeating: "O", count: 24)
        for y in 1..<23 {
            var line = Array(rows[y])
            line[0] = "O"
            line[23] = "O"
            line[20] = "O"
            line[21] = "S"
            line[22] = "S"
            rows[y] = String(line)
        }

        // The device silhouette, centred in the cover area (columns 1-19).
        let art = silhouette(typeID: typeID)
        let artWidth = art.first?.count ?? 0
        let originX = max(1, (20 - artWidth) / 2)
        for (offsetY, row) in art.enumerated() {
            let y = 4 + offsetY
            guard rows.indices.contains(y) else { continue }
            var line = Array(rows[y])
            for (offsetX, pixel) in row.enumerated() where pixel != " " {
                let x = originX + offsetX
                if x < 20, line.indices.contains(x) { line[x] = pixel }
            }
            rows[y] = String(line)
        }

        // Four "sticker" pixels along the bottom, driven by the seed, so
        // two products of the same type and topic still differ.
        var line = Array(rows[20])
        for index in 0..<4 {
            let on = (seed >> UInt64(index * 3)) & 1 == 1
            let x = 4 + index * 3
            if line.indices.contains(x) { line[x] = on ? "L" : "D" }
        }
        rows[20] = String(line)
        return rows
    }

    /// The device families the catalog's six types draw as. Two of them
    /// share a shape — a SaaS platform and an enterprise tool are both the
    /// stack of panes — and the monitor is both the desktop tool's own
    /// shape and the fallback for a type this file has never heard of.
    enum Silhouette: String, CaseIterable {
        case handset, browser, cartridge, stack, monitor
    }

    /// The family a product type draws as, or `nil` for an id the catalog
    /// does not contain. `ProductBoxArtTests` walks `ContentCatalog` and
    /// fails if any shipped type lands here as `nil` — which is how the
    /// keys drifted from "mobile"/"web" to the real ids for a year
    /// without anybody noticing that every box on the shelf was the same
    /// monitor.
    static func family(typeID: String) -> Silhouette? {
        switch typeID {
        case "mobile_app": .handset
        case "web_app": .browser
        case "game": .cartridge
        case "saas_platform", "enterprise_tool": .stack
        case "desktop_tool": .monitor
        default: nil
        }
    }

    /// 14×14 device shapes, one per family.
    private static func silhouette(typeID: String) -> [String] {
        switch family(typeID: typeID) ?? .monitor {
        case .handset:
            [
                "   OOOOOOOO   ",
                "   OLLLLLLO   ",
                "   OLGGGGLO   ",
                "   OLGGGGLO   ",
                "   OLGGGGLO   ",
                "   OLGGGGLO   ",
                "   OLGGGGLO   ",
                "   OLGGGGLO   ",
                "   OLLLLLLO   ",
                "   OLLDDLLO   ",
                "   OOOOOOOO   ",
                "              ",
            ]
        case .browser:
            // A browser window: title bar with three dots, no stand —
            // otherwise it reads as the desktop monitor.
            [
                " OOOOOOOOOOOO ",
                " ODDDDDDDDDDO ",
                " ODLDLDLDDDDO ",
                " ODDDDDDDDDDO ",
                " OLLLLLLLLLLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLLLLLLLLLLO ",
                " OOOOOOOOOOOO ",
                "              ",
            ]
        case .cartridge:
            [
                "  OOOOOOOOOO  ",
                " OLLLLLLLLLLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLLLLLLLLLLO ",
                " ODLOOOOOOLDO ",
                " OLLLLLLLLLLO ",
                "  OOOOOOOOOO  ",
                "              ",
                "              ",
                "              ",
            ]
        case .stack:
            [
                "  OOOOOOOOOO  ",
                "  OLLLLLLLLO  ",
                "  ODGGGGGGDO  ",
                "  OOOOOOOOOO  ",
                "  OLLLLLLLLO  ",
                "  ODGGGGGGDO  ",
                "  OOOOOOOOOO  ",
                "  OLLLLLLLLO  ",
                "  ODGGGGGGDO  ",
                "  OOOOOOOOOO  ",
                "              ",
                "              ",
            ]
        case .monitor:
            // The desktop tool, and anything the catalog gains later: a
            // monitor on a stand.
            [
                " OOOOOOOOOOOO ",
                " OLLLLLLLLLLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLLLLLLLLLLO ",
                " OOOOOOOOOOOO ",
                "     OOOO     ",
                "   OOOOOOOO   ",
                "              ",
                "              ",
            ]
        }
    }

    /// FNV-1a, so the same topic string always picks the same hue.
    private static func hash(_ string: String) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01B3
        }
        return value
    }
}

/// The generated box art, drawn crisp at any size.
struct ProductBoxArtView: View {
    let typeID: String
    let topicID: String
    let seed: UInt64
    var size: CGFloat = 96
    // MARK: Iteration 18 — the studio mark
    /// The studio's glyph, stamped into the cover's bottom-left corner the
    /// way a publisher's logo sits on a box. `nil` — every product of
    /// every company that never picked a mark — draws the box exactly as
    /// it has always been drawn.
    var markSeed: UInt64? = nil
    // MARK: end of Iteration 18

    var body: some View {
        let sprite = ProductBoxArt.sprite(typeID: typeID, topicID: topicID, seed: seed)
        Image(decorative: sprite.cgImage(frame: 0), scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(width: size, height: size)
            // MARK: Iteration 18 — the studio mark
            .overlay(alignment: .bottomLeading) {
                if let markSeed {
                    // The cover is columns 1–19 of the 24-wide box and the
                    // spine owns the right edge, so the stamp sits two
                    // pixels in from the outline on the cover's own side.
                    StudioMarkView(seed: markSeed, size: size * 7 / 24)
                        .padding(.leading, size * 2 / 24)
                        .padding(.bottom, size * 2 / 24)
                }
            }
            // MARK: end of Iteration 18
            .accessibilityHidden(true)
    }
}
