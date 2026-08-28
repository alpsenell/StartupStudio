#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// Contact sheets for the character system: every pose, every role look,
/// and the appearance space (skin, hair, glasses, beard, outfit).
///
/// These are the images to look at when judging whether a crowd of forty
/// people reads — one glance should tell you who the founder is, who is on
/// a headset and who is wearing a blazer.
@Suite("Pose sheet PNGs", .serialized)
struct PoseSheetPNGTests {
    static let outputDirectory = PreviewPNGTests.outputDirectory
    static let scale = PreviewPNGTests.scale
    let painter = PreviewPNGTests()

    func writePNG(_ image: CGImage, named name: String) throws {
        try FileManager.default.createDirectory(at: Self.outputDirectory, withIntermediateDirectories: true)
        let url = Self.outputDirectory.appendingPathComponent(name)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination), "failed writing \(name)")
    }

    /// Three looks that between them cover light/dark skin, long/short hair,
    /// glasses, a beard and all three outfits.
    var appearances: [CharacterAppearance] {
        var founder = CharacterAppearance(seed: 22)
        founder.glasses = 0
        var second = CharacterAppearance(seed: 17)
        second.hasBeard = true
        second.outfit = 2
        var third = CharacterAppearance(seed: 12)
        third.glasses = 1
        third.outfit = 1
        return [founder, second, third]
    }

    /// Every pose × every frame, three appearances deep. The founder row is
    /// drawn first so the indigo hoodie is easy to compare against the rest.
    @Test func posesV2Sheet() throws {
        let poses = SpriteLibrary.PersonPose.allCases
        let gap = 3
        let cellHeight = 24

        // Measure first: poses have different widths and frame counts.
        var columnWidths: [Int] = []
        for pose in poses {
            let sprite = SpriteLibrary.person(appearance: appearances[0], pose: pose)
            columnWidths.append(sprite.frameCount * (sprite.width + gap) + gap)
        }
        let width = gap + columnWidths.reduce(0, +)
        let height = gap + (cellHeight + gap) * appearances.count
        let canvasHeight = height * Self.scale
        let context = painter.makeCanvas(
            width: width * Self.scale, height: canvasHeight, background: .init(r: 46, g: 42, b: 60)
        )

        for (row, appearance) in appearances.enumerated() {
            var x = gap
            let y = gap + row * (cellHeight + gap)
            for pose in poses {
                let sprite = SpriteLibrary.person(appearance: appearance, pose: pose, isFounder: row == 0)
                for frame in 0..<sprite.frameCount {
                    painter.blit(
                        sprite, frame: frame, x: x + gap, y: y + (cellHeight - sprite.height),
                        into: context, canvasHeight: canvasHeight
                    )
                    x += sprite.width + gap
                }
                x += gap
            }
        }
        try writePNG(context.makeImage()!, named: "poses_v2.png")
    }

    /// One row per role look, so the accessories can be compared side by
    /// side: founder hoodie, QA headset, designer beret, marketer phone,
    /// lawyer tie, HR lanyard, ops clipboard.
    @Test func roleLooksSheet() throws {
        let roles = RoleLook.allCases
        let showcase: [SpriteLibrary.PersonPose] = [.seated, .standing, .walkRight, .coffee, .chat, .portrait]
        let gap = 4
        let cellWidth = 16
        let cellHeight = 24
        let width = gap + showcase.count * (cellWidth + gap)
        let height = gap + roles.count * (cellHeight + gap)
        let canvasHeight = height * Self.scale
        let context = painter.makeCanvas(
            width: width * Self.scale, height: canvasHeight, background: .init(r: 64, g: 60, b: 80)
        )

        let appearance = CharacterAppearance(seed: 101)
        for (row, role) in roles.enumerated() {
            let y = gap + row * (cellHeight + gap)
            for (column, pose) in showcase.enumerated() {
                let sprite = SpriteLibrary.person(
                    appearance: appearance, pose: pose, isFounder: role == .founder, role: role
                )
                painter.blit(
                    sprite, frame: 0,
                    x: gap + column * (cellWidth + gap) + (cellWidth - sprite.width) / 2,
                    y: y + (cellHeight - sprite.height),
                    into: context, canvasHeight: canvasHeight
                )
            }
        }
        try writePNG(context.makeImage()!, named: "role_looks.png")
    }

    /// The appearance space: a grid of seeds, each drawn standing, so the
    /// spread of skin, hair, glasses, beards and outfits is visible at once.
    @Test func appearanceGridSheet() throws {
        let columns = 12
        let rows = 6
        let gap = 3
        let width = gap + columns * (14 + gap)
        let height = gap + rows * (22 + gap)
        let canvasHeight = height * Self.scale
        let context = painter.makeCanvas(
            width: width * Self.scale, height: canvasHeight, background: .init(r: 190, g: 178, b: 166)
        )
        for row in 0..<rows {
            for column in 0..<columns {
                let seed = UInt64(row * columns + column) &* 2_654_435_761 &+ 11
                let sprite = SpriteLibrary.person(
                    appearance: CharacterAppearance(seed: seed), pose: .standing
                )
                painter.blit(
                    sprite, frame: 0,
                    x: gap + column * (14 + gap), y: gap + row * (22 + gap),
                    into: context, canvasHeight: canvasHeight
                )
            }
        }
        try writePNG(context.makeImage()!, named: "appearance_grid.png")
    }

    /// The master palette itself: eleven ramps of five, then the character
    /// ramps. If a sprite ever looks off, this is the reference.
    @Test func masterPaletteSheet() throws {
        let swatch = 12
        let gap = 2
        let rows = Palettes.ramps.count + 3
        let width = gap + 12 * (swatch + gap)
        let height = gap + rows * (swatch + gap)
        let canvasHeight = height * Self.scale
        let context = painter.makeCanvas(
            width: width * Self.scale, height: canvasHeight, background: .init(r: 32, g: 30, b: 42)
        )

        func drawSwatch(_ color: PixelSprite.RGBA, column: Int, row: Int) {
            let block = PixelSprite(
                frames: [Array(repeating: String(repeating: "C", count: swatch), count: swatch)],
                palette: ["C": color]
            )
            painter.blit(
                block, frame: 0,
                x: gap + column * (swatch + gap), y: gap + row * (swatch + gap),
                into: context, canvasHeight: canvasHeight
            )
        }

        for (row, ramp) in Palettes.ramps.enumerated() {
            for (column, color) in ramp.all.enumerated() { drawSwatch(color, column: column, row: row) }
        }
        let characterRows = [
            Palettes.skinTones.flatMap { [$0.base, $0.shade] },
            Palettes.hairColors.flatMap { [$0.base, $0.shade] },
            Palettes.shirtColors.flatMap { [$0.base, $0.shade] },
        ]
        for (offset, colors) in characterRows.enumerated() {
            for (column, color) in colors.prefix(12).enumerated() {
                drawSwatch(color, column: column, row: Palettes.ramps.count + offset)
            }
        }
        try writePNG(context.makeImage()!, named: "master_palette.png")
    }

    // MARK: Invariants the sheets are evidence for

    @Test func everyPoseFitsItsCanvasAcrossAppearances() {
        for pose in SpriteLibrary.PersonPose.allCases {
            var sizes = Set<[Int]>()
            for seed in stride(from: UInt64(0), to: 300, by: 7) {
                for role in RoleLook.allCases {
                    let sprite = SpriteLibrary.person(
                        appearance: CharacterAppearance(seed: seed), pose: pose, role: role
                    )
                    sizes.insert([sprite.width, sprite.height])
                    // Nothing may draw outside the pose's own canvas.
                    for frame in sprite.frames {
                        #expect(frame.count == sprite.height)
                        #expect(frame.allSatisfy { $0.count == sprite.width })
                    }
                }
            }
            #expect(sizes.count == 1, "\(pose) keeps one canvas across every appearance and role")
        }
    }

    @Test func walkingIsAFourFrameCycleAndTheDirectionsMirror() {
        let appearance = CharacterAppearance(seed: 5)
        let right = SpriteLibrary.person(appearance: appearance, pose: .walkRight)
        let left = SpriteLibrary.person(appearance: appearance, pose: .walkLeft)
        #expect(right.frameCount == 4)
        #expect(left.frameCount == 4)
        #expect(right != left, "the two directions face opposite ways")
        for index in 0..<4 {
            #expect(left.frames[index] == right.frames[index].map { String($0.reversed()) })
        }
        #expect(Set(right.frames.map { $0.joined() }).count == 4, "four distinct frames")
    }

    @Test func portraitIsATenByTenBustThatBlinks() {
        for seed in stride(from: UInt64(1), to: 200, by: 11) {
            let portrait = SpriteLibrary.person(appearance: CharacterAppearance(seed: seed), pose: .portrait)
            #expect(portrait.width == 10 && portrait.height == 10)
            #expect(portrait.frameCount == 2)
            #expect(portrait.frames[0] != portrait.frames[1], "the second frame is a blink")
            let bytes = rgbaBytes(of: portrait.cgImage(frame: 0))
            #expect(bytes.contains { $0 != 0 })
        }
    }

    @Test func everyRoleLookIsVisiblyDifferent() {
        let appearance = CharacterAppearance(seed: 77)
        var seen: [String: RoleLook] = [:]
        for role in RoleLook.allCases {
            let sprite = SpriteLibrary.person(appearance: appearance, pose: .standing, role: role)
            let key = sprite.frames[0].joined()
            #expect(seen[key] == nil, "\(role) looks identical to \(String(describing: seen[key]))")
            seen[key] = role
        }
    }

    @Test func accessoriesRideTheHeadBobAndTheSlump() {
        var appearance = CharacterAppearance(seed: 3)
        appearance.glasses = 1
        appearance.hasBeard = true
        // In the slump the head is two rows lower; the glasses must be too.
        let standing = SpriteLibrary.person(appearance: appearance, pose: .standing)
        let slump = SpriteLibrary.person(appearance: appearance, pose: .slump)
        func glassRow(_ sprite: PixelSprite) -> Int? {
            sprite.frames[0].firstIndex { $0.contains("N") }
        }
        let standingRow = try? #require(glassRow(standing))
        let slumpRow = try? #require(glassRow(slump))
        #expect(standingRow != nil && slumpRow != nil)
        if let standingRow, let slumpRow {
            #expect(slumpRow == standingRow + 2, "the glasses follow the head down")
        }
    }
}
#endif
