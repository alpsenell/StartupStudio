#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// PNG previews of the rival studio at every band and at day and night,
/// plus the fortress, rendered from the exact placement list
/// `RivalStudioScene` draws.
@Suite("Rival studio preview PNGs", .serialized)
struct RivalStudioPreviewPNGTests {
    static let outputDirectory = PreviewPNGTests.outputDirectory.appendingPathComponent("market", isDirectory: true)
    static let scale = 4
    let painter = PreviewPNGTests()

    func render(_ placements: [PlacedSprite], tick: Int) -> CGImage {
        let size = RivalStudioComposer.sceneSize
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

    @Test func theRivalStudiosByBandAndHour() throws {
        for time in [TimeOfDay.day, .dusk, .night] {
            for (index, band) in StrengthBand.allCases.enumerated() {
                let input = RivalStudioInput(
                    band: band, reputation: [0.2, 0.45, 0.7, 0.9][index],
                    forSale: band == .small, founderSeed: 21 + UInt64(index) * 9, timeOfDay: time
                )
                try writePNG(render(RivalStudioComposer.compose(input), tick: 1), named: "rival_studio_\(band.rawValue)_\(time.rawValue).png")
            }
            let fortress = RivalStudioInput(
                band: .large, reputation: 0.75, isFortress: true, forSale: time == .night,
                founderSeed: 0xBEEF, timeOfDay: time
            )
            try writePNG(render(RivalStudioComposer.compose(fortress), tick: 2), named: "rival_studio_fortress_\(time.rawValue).png")
        }
    }
}
#endif
