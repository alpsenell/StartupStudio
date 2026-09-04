#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// PNG previews of the market map, rendered from the exact placement list
/// `MarketMapView` draws.
@Suite("Market map preview PNGs", .serialized)
struct MarketMapPreviewPNGTests {
    static let outputDirectory = PreviewPNGTests.outputDirectory.appendingPathComponent("market", isDirectory: true)
    static let scale = 4
    let painter = PreviewPNGTests()

    func render(_ placements: [PlacedSprite], size: (width: Int, height: Int), tick: Int) -> CGImage {
        let canvasHeight = size.height * Self.scale
        let context = painter.makeCanvas(width: size.width * Self.scale, height: canvasHeight, background: nil)
        for placement in placements {
            painter.blit(
                placement.sprite, frame: placement.frameIndex(atTick: tick),
                x: placement.x, y: placement.y, into: context, canvasHeight: canvasHeight
            )
        }
        return context.makeImage()!
    }

    func writePNG(_ image: CGImage, named name: String) throws {
        try FileManager.default.createDirectory(at: Self.outputDirectory, withIntermediateDirectories: true)
        let url = Self.outputDirectory.appendingPathComponent(name)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination), "failed writing \(name)")
    }

    @Test func theMarketMapMidGameAndFresh() throws {
        for tick in [0, 3] {
            let image = render(
                MarketMapComposer.compose(MarketMapTests.midGame()),
                size: MarketMapLayout.sceneSize, tick: tick
            )
            try writePNG(image, named: "market_map_midgame_\(tick).png")
        }
        let fresh = render(
            MarketMapComposer.compose(MarketMapTests.fresh()),
            size: MarketMapLayout.sceneSize, tick: 0
        )
        try writePNG(fresh, named: "market_map_fresh.png")
    }

    @Test func theMarkerSheet() throws {
        var sprites: [PixelSprite] = [
            MarketSpriteLibrary.playerBuilding(),
            MarketSpriteLibrary.rivalFlag(),
            MarketSpriteLibrary.fortress(),
            MarketSpriteLibrary.siegeMarker(),
        ]
        sprites += MarketWeather.allCases.map(MarketSpriteLibrary.weather)
        sprites += StandingBand.allCases.map { MarketSpriteLibrary.districtBlock(side: 19, band: $0) }
        let gap = 3
        let width = gap + sprites.reduce(0) { $0 + $1.width + gap }
        let rowHeight = sprites.map(\.height).max() ?? 1
        let height = gap * 2 + rowHeight * 2 + gap
        let canvasHeight = height * Self.scale
        let context = painter.makeCanvas(
            width: width * Self.scale, height: canvasHeight, background: .init(r: 64, g: 60, b: 80)
        )
        var x = gap
        for sprite in sprites {
            for frame in 0..<min(2, sprite.frameCount) {
                painter.blit(
                    sprite, frame: frame, x: x, y: gap + frame * (rowHeight + gap),
                    into: context, canvasHeight: canvasHeight
                )
            }
            x += sprite.width + gap
        }
        try writePNG(context.makeImage()!, named: "market_markers_sheet.png")
    }
}
#endif
