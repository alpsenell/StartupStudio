import Foundation

/// The fixed geometry of the market map: twelve cells in a 4×3 grid, each a
/// name strip over a square block area, on a 116×105 scene.
///
/// A district's *position* is its catalog index and never moves, so a
/// topic keeps its place on the map as the numbers change; what moves is
/// the block's footprint inside its cell, which the market's size decides.
/// Every pixel of the map belongs to exactly one cell (or the frame), so a
/// tap anywhere on a district — its strip, its block, the pavement round
/// it — lands on that district.
public enum MarketMapLayout {
    /// An integer rect in scene pixels.
    public struct Rect: Sendable, Equatable, Hashable {
        public let x: Int, y: Int, width: Int, height: Int

        public init(x: Int, y: Int, width: Int, height: Int) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public func contains(x px: Int, y py: Int) -> Bool {
            px >= x && px < x + width && py >= y && py < y + height
        }
    }

    public static let columns = 4
    public static let rows = 3
    /// The most districts the map can place.
    public static var slots: Int { columns * rows }

    /// The square each district's block sits in, and the widest a block
    /// can be.
    public static let blockArea = 27
    /// The smallest block a market shrinks to. Chosen so a small district
    /// still fits the fortress and one of the studio's own buildings.
    public static let minBlock = 19
    /// The name strip above each block, where the app lays the label.
    public static let stripHeight = 6
    /// The road between cells, and the frame round the map.
    public static let gap = 2
    public static let margin = 1

    public static var cellWidth: Int { blockArea }
    public static var cellHeight: Int { stripHeight + blockArea }

    public static var sceneSize: (width: Int, height: Int) {
        (
            margin * 2 + columns * cellWidth + (columns - 1) * gap,
            margin * 2 + rows * cellHeight + (rows - 1) * gap
        )
    }

    /// The whole cell — strip plus block area — for the district at
    /// `index`, or nil past the last slot.
    public static func cellFrame(index: Int) -> Rect? {
        guard (0..<slots).contains(index) else { return nil }
        let column = index % columns
        let row = index / columns
        return Rect(
            x: margin + column * (cellWidth + gap),
            y: margin + row * (cellHeight + gap),
            width: cellWidth,
            height: cellHeight
        )
    }

    /// The name strip of the district at `index`.
    public static func stripFrame(index: Int) -> Rect? {
        cellFrame(index: index).map { Rect(x: $0.x, y: $0.y, width: $0.width, height: stripHeight) }
    }

    /// The square the block is drawn in, under the strip.
    public static func blockAreaFrame(index: Int) -> Rect? {
        cellFrame(index: index).map {
            Rect(x: $0.x, y: $0.y + stripHeight, width: blockArea, height: blockArea)
        }
    }

    /// The block itself: sized by the market, centred in its area.
    public static func blockFrame(index: Int, size: Double) -> Rect? {
        guard let area = blockAreaFrame(index: index) else { return nil }
        let side = blockSide(size: size)
        return Rect(
            x: area.x + (area.width - side) / 2,
            y: area.y + (area.height - side) / 2,
            width: side,
            height: side
        )
    }

    /// The block's side for a market size, `minBlock`…`blockArea`.
    public static func blockSide(size: Double) -> Int {
        let clamped = min(1, max(0, size))
        return minBlock + Int((Double(blockArea - minBlock) * clamped).rounded())
    }

    /// The district index under a scene-pixel point, or nil on the frame,
    /// outside the map, or past `count` districts. The roads between cells
    /// belong to the cell on their left / above, so no tap falls through.
    public static func hitTest(x: Int, y: Int, count: Int = slots) -> Int? {
        let size = sceneSize
        guard x >= margin, y >= margin, x < size.width - margin, y < size.height - margin else { return nil }
        let column = min(columns - 1, (x - margin) / (cellWidth + gap))
        let row = min(rows - 1, (y - margin) / (cellHeight + gap))
        let index = row * columns + column
        return index < min(count, slots) ? index : nil
    }

    /// How `PixelSceneView` fits the scene into a view of `size` under
    /// `.fitWidth`: the integer pixel scale and the drawn origin. Exposed
    /// so an overlay laid over the scene lands on the same pixels.
    public static func fit(in size: CGSize) -> (scale: Int, origin: CGPoint) {
        let scene = sceneSize
        let scale = max(1, Int(size.width) / scene.width)
        let drawnWidth = CGFloat(scene.width * scale)
        let drawnHeight = CGFloat(scene.height * scale)
        return (
            scale,
            CGPoint(
                x: ((size.width - drawnWidth) / 2).rounded(.down),
                y: ((size.height - drawnHeight) / 2).rounded(.down)
            )
        )
    }

    /// A scene rect in view points for the fit `fit(in:)` reported.
    public static func viewRect(_ rect: Rect, scale: Int, origin: CGPoint) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(rect.x * scale),
            y: origin.y + CGFloat(rect.y * scale),
            width: CGFloat(rect.width * scale),
            height: CGFloat(rect.height * scale)
        )
    }
}
