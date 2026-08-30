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
    /// Where the PNG suites write. Set `PIXELKIT_PREVIEW_DIR` to review
    /// them somewhere specific; otherwise they land in a temp folder that
    /// exists on every machine.
    static let outputDirectory = URL(
        fileURLWithPath: ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "pixelkit-previews",
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
        // A grid of every room prop (four across), then the desk, both
        // monitor frames, and the non-idle status bubbles.
        let props = SpriteLibrary.PropName.allCases.map(SpriteLibrary.prop)
        let gap = 4
        let columns = 6
        let cellWidth = props.map(\.width).max()! + gap
        let cellHeight = props.map(\.height).max()! + gap
        let rows = (props.count + columns - 1) / columns

        let desk = SpriteLibrary.desk()
        let monitor = SpriteLibrary.monitor()
        let bubbles = WorkStatus.allCases.filter { $0 != .idle }.map(SpriteLibrary.statusBubble)

        let width = gap + columns * cellWidth
        let extrasY = gap + rows * cellHeight
        let height = extrasY + max(desk.height, monitor.height) + gap + bubbles[0].height + gap

        let context = makeCanvas(
            width: width * Self.scale,
            height: height * Self.scale,
            background: .init(r: 190, g: 178, b: 166)
        )
        let canvasHeight = height * Self.scale

        for (index, prop) in props.enumerated() {
            let column = index % columns
            let row = index / columns
            blit(
                prop, frame: 0,
                x: gap + column * cellWidth,
                y: gap + row * cellHeight + (cellHeight - gap - prop.height),
                into: context, canvasHeight: canvasHeight
            )
        }

        var x = gap
        blit(desk, frame: 0, x: x, y: extrasY, into: context, canvasHeight: canvasHeight)
        x += desk.width + gap
        blit(monitor, frame: 0, x: x, y: extrasY, into: context, canvasHeight: canvasHeight)
        x += monitor.width + gap
        blit(monitor, frame: 1, x: x, y: extrasY, into: context, canvasHeight: canvasHeight)

        x = gap
        let bubbleY = extrasY + max(desk.height, monitor.height) + gap
        for bubble in bubbles {
            blit(bubble, frame: 0, x: x, y: bubbleY, into: context, canvasHeight: canvasHeight)
            x += bubble.width + gap
        }

        try writePNG(context.makeImage()!, named: "props_sheet.png")
    }

    /// Every tier's room at every hour, with the lighting overlay on top —
    /// the sheet to look at when judging whether an evening in the office
    /// reads as an evening.
    @Test func officeRoomsByHour() throws {
        let gap = 6
        let cellWidth = 130
        let cellHeight = 70
        let hours = TimeOfDay.allCases
        let width = gap + hours.count * (cellWidth + gap)
        let height = gap + OfficeTierStyle.allCases.count * (cellHeight + gap)
        let canvasHeight = height * Self.scale
        let context = makeCanvas(
            width: width * Self.scale, height: canvasHeight, background: .init(r: 32, g: 30, b: 42)
        )
        for (row, tier) in OfficeTierStyle.allCases.enumerated() {
            for (column, hour) in hours.enumerated() {
                let x = gap + column * (cellWidth + gap)
                let y = gap + row * (cellHeight + gap)
                let room = RoomBuilder.officeRoom(
                    tier: tier, width: cellWidth, height: cellHeight, wallHeight: 34, time: hour
                )
                blit(room, frame: 0, x: x, y: y, into: context, canvasHeight: canvasHeight)
                let overlay = SpriteLibrary.lightingOverlay(width: cellWidth, height: cellHeight, time: hour)
                blit(overlay, frame: 0, x: x, y: y, into: context, canvasHeight: canvasHeight)
            }
        }
        try writePNG(context.makeImage()!, named: "office_rooms_by_hour.png")
    }

    /// Every window: office and home, four hours, three kinds of weather.
    @Test func windowSheet() throws {
        let gap = 3
        let sample = SpriteLibrary.window(style: .office)
        let columns = TimeOfDay.allCases.count * Weather.allCases.count
        let width = gap + columns * (sample.width + gap)
        let height = gap + WindowStyle.allCases.count * (sample.height + gap)
        let canvasHeight = height * Self.scale
        let context = makeCanvas(
            width: width * Self.scale, height: canvasHeight, background: .init(r: 112, g: 100, b: 92)
        )
        for (row, style) in WindowStyle.allCases.enumerated() {
            var column = 0
            for time in TimeOfDay.allCases {
                for weather in Weather.allCases {
                    blit(
                        SpriteLibrary.window(style: style, time: time, weather: weather), frame: 0,
                        x: gap + column * (sample.width + gap),
                        y: gap + row * (sample.height + gap),
                        into: context, canvasHeight: canvasHeight
                    )
                    column += 1
                }
            }
        }
        try writePNG(context.makeImage()!, named: "windows_sheet.png")
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
