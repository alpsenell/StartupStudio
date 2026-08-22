#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// Writes 4x-scale PNG previews of the sprite art and the composed scenes.
/// Scenes are rendered from the exact `SceneComposer.compose` output the
/// SwiftUI view draws, so these previews exercise the real layout.
@Suite("Preview PNGs", .serialized)
struct PreviewPNGTests {
    static let outputDirectory = URL(
        fileURLWithPath: "/private/tmp/claude-502/-Users-alpsenel-Desktop-personal-projects-MobileGame/04e78738-c779-4903-a77a-70055d5ae19c/scratchpad/pixelkit",
        isDirectory: true
    )
    static let scale = 4

    // MARK: Rendering helpers

    func makeCanvas(width: Int, height: Int, background: PixelSprite.RGBA?) -> CGContext {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .none
        context.setAllowsAntialiasing(false)
        if let bg = background {
            context.setFillColor(
                CGColor(
                    colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                    components: [CGFloat(bg.r) / 255, CGFloat(bg.g) / 255, CGFloat(bg.b) / 255, CGFloat(bg.a) / 255]
                )!
            )
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return context
    }

    /// Draws a sprite frame with its top-left corner at (x, y) in top-left
    /// canvas coordinates, at the shared preview scale.
    func blit(_ sprite: PixelSprite, frame: Int, x: Int, y: Int, into context: CGContext, canvasHeight: Int) {
        let s = Self.scale
        context.draw(
            sprite.cgImage(frame: frame),
            in: CGRect(
                x: x * s,
                y: canvasHeight - (y + sprite.height) * s,
                width: sprite.width * s,
                height: sprite.height * s
            )
        )
    }

    func renderScene(tier: OfficeTierStyle, occupants: [Occupant], tick: Int) -> CGImage {
        let size = SceneComposer.sceneSize(for: tier)
        let context = makeCanvas(width: size.width * Self.scale, height: size.height * Self.scale, background: nil)
        for placement in SceneComposer.compose(tier: tier, occupants: occupants) {
            blit(
                placement.sprite,
                frame: placement.frameIndex(atTick: tick),
                x: placement.x,
                y: placement.y,
                into: context,
                canvasHeight: size.height * Self.scale
            )
        }
        return context.makeImage()!
    }

    func writePNG(_ image: CGImage, named name: String) throws {
        try FileManager.default.createDirectory(at: Self.outputDirectory, withIntermediateDirectories: true)
        let url = Self.outputDirectory.appendingPathComponent(name)
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination), "failed writing \(name)")
    }

    func occupant(seed: UInt64, status: WorkStatus, isFounder: Bool = false) -> Occupant {
        Occupant(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", seed))!,
            appearance: CharacterAppearance(seed: seed),
            status: status,
            isFounder: isFounder
        )
    }

    // MARK: The four required previews

    @Test func characterLineup() throws {
        // 10 seeds side by side; typing frame A on the top row, frame B below.
        // Seeds chosen to cover all six hair styles and all five skin tones.
        // Column 0 is rendered as the founder; its mustard shirt keeps the
        // indigo hoodie collar visible.
        let seeds: [UInt64] = [22, 17, 2, 12, 15, 6, 18, 43, 39, 88]
        let cell = PersonArt.width + 2
        let width = 2 + seeds.count * cell
        let height = 2 + (PersonArt.height + 2) * 2
        let context = makeCanvas(
            width: width * Self.scale,
            height: height * Self.scale,
            background: .init(r: 228, g: 224, b: 216)
        )
        for (column, seed) in seeds.enumerated() {
            let person = SpriteLibrary.person(appearance: CharacterAppearance(seed: seed), isFounder: column == 0)
            for frame in 0..<2 {
                blit(
                    person, frame: frame,
                    x: 2 + column * cell,
                    y: 2 + frame * (PersonArt.height + 2),
                    into: context, canvasHeight: height * Self.scale
                )
            }
        }
        try writePNG(context.makeImage()!, named: "character_lineup.png")
    }

    @Test func garageScene() throws {
        let image = renderScene(
            tier: .garage,
            occupants: [
                occupant(seed: 7, status: .coding, isFounder: true),
                occupant(seed: 21, status: .coding),
                occupant(seed: 34, status: .designing),
            ],
            tick: 6
        )
        try writePNG(image, named: "garage_scene.png")
    }

    @Test func loftScene() throws {
        let image = renderScene(
            tier: .loft,
            occupants: [
                occupant(seed: 101, status: .coding, isFounder: true),
                occupant(seed: 102, status: .designing),
                occupant(seed: 103, status: .marketing),
                occupant(seed: 104, status: .researching),
                occupant(seed: 105, status: .idle),
            ],
            tick: 5
        )
        try writePNG(image, named: "loft_scene.png")
    }

    @Test func propsSheet() throws {
        // Row 1 (props, bottom-aligned, left→right): plant, garageDoor,
        //   toolbox, whiteboard, coffeeMachine, windowDay.
        // Row 2: desk, monitor frame 0 (dim), monitor frame 1 (bright).
        // Row 3 (bubbles, left→right): coding, designing, marketing,
        //   researching (idle is intentionally empty and omitted).
        let props = SpriteLibrary.PropName.allCases.map(SpriteLibrary.prop)
        let gap = 4
        let row1Height = props.map(\.height).max()!
        let row1Width = props.map(\.width).reduce(0, +) + gap * (props.count + 1)

        let desk = SpriteLibrary.desk()
        let monitor = SpriteLibrary.monitor()
        let bubbles = WorkStatus.allCases.filter { $0 != .idle }.map(SpriteLibrary.statusBubble)

        let width = max(row1Width, 96)
        let row2Y = 2 + row1Height + gap
        let row3Y = row2Y + max(desk.height, monitor.height) + gap
        let height = row3Y + bubbles[0].height + 2

        let context = makeCanvas(
            width: width * Self.scale,
            height: height * Self.scale,
            background: .init(r: 208, g: 202, b: 192)
        )
        let canvasHeight = height * Self.scale

        var x = gap
        for prop in props {
            blit(prop, frame: 0, x: x, y: 2 + row1Height - prop.height, into: context, canvasHeight: canvasHeight)
            x += prop.width + gap
        }

        x = gap
        blit(desk, frame: 0, x: x, y: row2Y, into: context, canvasHeight: canvasHeight)
        x += desk.width + gap
        blit(monitor, frame: 0, x: x, y: row2Y, into: context, canvasHeight: canvasHeight)
        x += monitor.width + gap
        blit(monitor, frame: 1, x: x, y: row2Y, into: context, canvasHeight: canvasHeight)

        x = gap
        for bubble in bubbles {
            blit(bubble, frame: 0, x: x, y: row3Y, into: context, canvasHeight: canvasHeight)
            x += bubble.width + gap
        }

        try writePNG(context.makeImage()!, named: "props_sheet.png")
    }

    /// Bonus coverage: the two remaining tiers render end-to-end too.
    @Test func studioAndCampusScenesRender() throws {
        let studio = renderScene(
            tier: .studio,
            occupants: (0..<9).map {
                occupant(seed: UInt64($0 + 400), status: WorkStatus.allCases[$0 % 5], isFounder: $0 == 0)
            },
            tick: 4
        )
        try writePNG(studio, named: "studio_scene.png")

        let campus = renderScene(
            tier: .campus,
            occupants: (0..<28).map {
                occupant(seed: UInt64($0 + 900), status: WorkStatus.allCases[($0 + 1) % 5], isFounder: $0 == 0)
            },
            tick: 9
        )
        try writePNG(campus, named: "campus_scene.png")
    }
}
#endif
