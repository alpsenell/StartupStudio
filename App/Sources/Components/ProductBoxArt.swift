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
    ///   - typeID: the product type id ("mobile", "saas", …); picks the
    ///     silhouette.
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

    /// The 24×24 grid: an outlined box, a type-specific device silhouette,
    /// and a small deterministic pattern in the corner.
    private static func grid(typeID: String, seed: UInt64) -> [String] {
        var rows = [String](repeating: String(repeating: "B", count: 24), count: 24)

        // Outline and inner shade.
        rows[0] = String(repeating: "O", count: 24)
        rows[23] = String(repeating: "O", count: 24)
        for y in 1..<23 {
            var line = Array(rows[y])
            line[0] = "O"
            line[23] = "O"
            // A slab of shade down the right third gives the box depth.
            for x in 16..<23 { line[x] = "S" }
            rows[y] = String(line)
        }

        // The device silhouette, centered.
        for (offsetY, row) in silhouette(typeID: typeID).enumerated() {
            let y = 5 + offsetY
            guard rows.indices.contains(y) else { continue }
            var line = Array(rows[y])
            for (offsetX, pixel) in row.enumerated() where pixel != " " {
                let x = 5 + offsetX
                if line.indices.contains(x) { line[x] = pixel }
            }
            rows[y] = String(line)
        }

        // Four "sticker" pixels along the bottom, driven by the seed, so
        // two products of the same type and topic still differ.
        var line = Array(rows[20])
        for index in 0..<4 {
            let on = (seed >> UInt64(index * 3)) & 1 == 1
            let x = 3 + index * 3
            if line.indices.contains(x) { line[x] = on ? "L" : "D" }
        }
        rows[20] = String(line)
        return rows
    }

    /// 14×12 device shapes, one per product type family.
    private static func silhouette(typeID: String) -> [String] {
        switch typeID {
        case "mobile":
            [
                "    OOOOOO    ",
                "    OLLLLO    ",
                "    OLGGLO    ",
                "    OLGGLO    ",
                "    OLGGLO    ",
                "    OLGGLO    ",
                "    OLGGLO    ",
                "    OLLLLO    ",
                "    OOOOOO    ",
                "              ",
                "              ",
                "              ",
            ]
        case "web":
            [
                " OOOOOOOOOOOO ",
                " OLLLLLLLLLLO ",
                " ODDDDDDDDDDO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLLLLLLLLLLO ",
                " OOOOOOOOOOOO ",
                "      OO      ",
                "    OOOOOO    ",
                "              ",
                "              ",
            ]
        case "game":
            [
                "   OOOOOOOO   ",
                "  OLLLLLLLLO  ",
                "  OLGGGGGGLO  ",
                "  OLGGGGGGLO  ",
                "  OLLLLLLLLO  ",
                "  ODLOOOOLDO  ",
                "  OLLLLLLLLO  ",
                "   OOOOOOOO   ",
                "              ",
                "              ",
                "              ",
                "              ",
            ]
        case "saas", "enterprise":
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
        default:
            // Desktop and anything new: a monitor on a stand.
            [
                " OOOOOOOOOOOO ",
                " OLLLLLLLLLLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLGGGGGGGGLO ",
                " OLLLLLLLLLLO ",
                " OOOOOOOOOOOO ",
                "     OOOO     ",
                "   OOOOOOOO   ",
                "              ",
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

    var body: some View {
        let sprite = ProductBoxArt.sprite(typeID: typeID, topicID: topicID, seed: seed)
        Image(decorative: sprite.cgImage(frame: 0), scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
