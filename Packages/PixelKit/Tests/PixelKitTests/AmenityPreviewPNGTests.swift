#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// 4x-scale PNG previews of the amenity zones and the role status bubbles.
/// Scenes are rendered from the exact `SceneComposer.compose(tier:occupants:amenities:)`
/// output the SwiftUI view draws.
@Suite("Amenity preview PNGs", .serialized)
struct AmenityPreviewPNGTests {
    static let outputDirectory = PreviewPNGTests.outputDirectory.appendingPathComponent("amenities", isDirectory: true)
    static let scale = PreviewPNGTests.scale
    let painter = PreviewPNGTests()

    func renderScene(tier: OfficeTierStyle, occupants: [Occupant], amenities: Set<AmenityStyle>, tick: Int) -> CGImage {
        let size = SceneComposer.sceneSize(for: tier)
        let context = painter.makeCanvas(width: size.width * Self.scale, height: size.height * Self.scale, background: nil)
        for placement in SceneComposer.compose(tier: tier, occupants: occupants, amenities: amenities) {
            painter.blit(
                placement.sprite,
                frame: placement.frameIndex(atTick: tick),
                x: placement.x, y: placement.y,
                into: context, canvasHeight: size.height * Self.scale
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

    /// Mixed statuses cycling through every non-idle status plus idle, so the
    /// four role bubbles and a break-taker all show up.
    static let mixedStatuses: [WorkStatus] = [
        .coding, .testing, .designing, .legal, .marketing, .peopleOps, .researching, .operations, .idle,
    ]

    func crowd(count: Int, seedBase: UInt64) -> [Occupant] {
        (0..<count).map {
            painter.occupant(
                seed: seedBase + UInt64($0),
                status: Self.mixedStatuses[$0 % Self.mixedStatuses.count],
                isFounder: $0 == 0
            )
        }
    }

    // MARK: Required previews

    @Test func studioAllAmenities() throws {
        let image = renderScene(
            tier: .studio,
            occupants: crowd(count: 14, seedBase: 700),
            amenities: Set(AmenityStyle.allCases),
            tick: 6
        )
        try writePNG(image, named: "studio_all_amenities.png")
    }

    @Test func campusAll() throws {
        let image = renderScene(
            tier: .campus,
            occupants: crowd(count: 30, seedBase: 1200),
            amenities: Set(AmenityStyle.allCases),
            tick: 3
        )
        try writePNG(image, named: "campus_all.png")
    }

    @Test func loftGameRoom() throws {
        let image = renderScene(
            tier: .loft,
            occupants: crowd(count: 6, seedBase: 300),
            amenities: [.gameRoom],
            tick: 5
        )
        try writePNG(image, named: "loft_gameroom.png")
    }

    @Test func amenityPropsSheet() throws {
        // Every amenity prop bottom-aligned left→right in declaration order;
        // a second row shows frame 1 of the animated props (treadmill,
        // arcade cabinet, vending machine) for comparison.
        let names = SpriteLibrary.AmenityPropName.allCases
        let props = names.map(SpriteLibrary.amenityProp)
        let gap = 4
        let rowHeight = props.map(\.height).max()!
        let width = props.map(\.width).reduce(0, +) + gap * (props.count + 1)
        let height = 2 + rowHeight + gap + rowHeight + 2
        let context = painter.makeCanvas(
            width: width * Self.scale, height: height * Self.scale,
            background: .init(r: 128, g: 132, b: 158) // studio carpet
        )
        let canvasHeight = height * Self.scale

        var x = gap
        for prop in props {
            painter.blit(prop, frame: 0, x: x, y: 2 + rowHeight - prop.height, into: context, canvasHeight: canvasHeight)
            if prop.frameCount > 1 {
                painter.blit(prop, frame: 1, x: x, y: 2 + rowHeight + gap + rowHeight - prop.height, into: context, canvasHeight: canvasHeight)
            }
            x += prop.width + gap
        }
        try writePNG(context.makeImage()!, named: "amenity_props_sheet.png")
    }

    @Test func roleBubblesSheet() throws {
        // Row 1: the four new role bubbles — testing, legal, peopleOps,
        // operations. Row 2: the original four for comparison.
        let rows: [[WorkStatus]] = [
            [.testing, .legal, .peopleOps, .operations],
            [.coding, .designing, .marketing, .researching],
        ]
        let gap = 4
        let bubble = SpriteLibrary.statusBubble(.testing)
        let width = gap + rows[0].count * (bubble.width + gap)
        let height = gap + rows.count * (bubble.height + gap)
        let context = painter.makeCanvas(
            width: width * Self.scale, height: height * Self.scale,
            background: .init(r: 182, g: 140, b: 96) // loft floor
        )
        for (rowIndex, statuses) in rows.enumerated() {
            for (column, status) in statuses.enumerated() {
                painter.blit(
                    SpriteLibrary.statusBubble(status), frame: 0,
                    x: gap + column * (bubble.width + gap),
                    y: gap + rowIndex * (bubble.height + gap),
                    into: context, canvasHeight: height * Self.scale
                )
            }
        }
        try writePNG(context.makeImage()!, named: "role_bubbles_sheet.png")
    }
}
#endif
