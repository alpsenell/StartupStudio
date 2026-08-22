#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// 4x-scale PNG previews of the home scenes, the new poses and the home
/// props. Scenes are rendered from the exact `HomeSceneComposer.compose`
/// output the SwiftUI view draws.
@Suite("Home preview PNGs", .serialized)
struct HomePreviewPNGTests {
    static let outputDirectory = PreviewPNGTests.outputDirectory.appendingPathComponent("home", isDirectory: true)
    static let scale = PreviewPNGTests.scale
    let painter = PreviewPNGTests()

    func renderScene(tier: HomeTierStyle, occupants: HomeOccupants, activity: HomeActivity, mood: MoodLevel, tick: Int) -> CGImage {
        let size = HomeSceneComposer.sceneSize(for: tier)
        let context = painter.makeCanvas(width: size.width * Self.scale, height: size.height * Self.scale, background: nil)
        for placement in HomeSceneComposer.compose(tier: tier, occupants: occupants, activity: activity, mood: mood) {
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

    // MARK: Required scenes

    @Test func studioSleeping() throws {
        let image = renderScene(
            tier: .studioFlat,
            occupants: HomeOccupants(founder: CharacterAppearance(seed: 7)),
            activity: .sleeping, mood: .okay, tick: 2
        )
        try writePNG(image, named: "studio_sleeping.png")
    }

    @Test func apartmentDinnerWithPartner() throws {
        let image = renderScene(
            tier: .apartment,
            occupants: HomeOccupants(founder: CharacterAppearance(seed: 7), partner: CharacterAppearance(seed: 21)),
            activity: .dinner, mood: .great, tick: 5
        )
        try writePNG(image, named: "apartment_dinner_partner.png")
    }

    @Test func houseGamingWithKids() throws {
        let image = renderScene(
            tier: .house,
            occupants: HomeOccupants(
                founder: CharacterAppearance(seed: 7),
                partner: CharacterAppearance(seed: 21),
                children: [CharacterAppearance(seed: 31), CharacterAppearance(seed: 34)]
            ),
            activity: .gaming, mood: .great, tick: 3
        )
        try writePNG(image, named: "house_gaming_kids.png")
    }

    @Test func penthouseAway() throws {
        let image = renderScene(
            tier: .penthouse,
            occupants: HomeOccupants(founder: CharacterAppearance(seed: 7), partner: CharacterAppearance(seed: 21)),
            activity: .away, mood: .low, tick: 4
        )
        try writePNG(image, named: "penthouse_away.png")
    }

    /// Bonus coverage: the remaining activities render in every tier.
    @Test func everyActivityRendersInEveryTier() throws {
        let family = HomeOccupants(
            founder: CharacterAppearance(seed: 7),
            partner: CharacterAppearance(seed: 21),
            children: [CharacterAppearance(seed: 31), CharacterAppearance(seed: 34), CharacterAppearance(seed: 35)]
        )
        for tier in HomeTierStyle.allCases {
            for activity in HomeActivity.allCases {
                let image = renderScene(tier: tier, occupants: family, activity: activity, mood: .low, tick: 1)
                try writePNG(image, named: "extra_\(tier.rawValue)_\(activity.rawValue).png")
            }
        }
    }

    // MARK: Sheets

    @Test func posesSheet() throws {
        // Columns: seated, standing, seatedCouch, holdingBaby, exercising, lying (×2 frames each);
        // rows: three appearances (first rendered as the founder), children + baby on a final row.
        let appearances = [CharacterAppearance(seed: 22), CharacterAppearance(seed: 17), CharacterAppearance(seed: 12)]
        let gap = 3
        let columnWidths = [14, 14, 14, 14, 14, 24].map { $0 * 2 + gap * 3 }
        let width = gap + columnWidths.reduce(0, +)
        let rowHeight = 22 + gap
        let height = gap + rowHeight * appearances.count + 14 + gap
        let context = painter.makeCanvas(
            width: width * Self.scale, height: height * Self.scale, background: .init(r: 70, g: 72, b: 98)
        )
        let canvasHeight = height * Self.scale

        for (row, appearance) in appearances.enumerated() {
            let isFounder = row == 0
            let sprites: [PixelSprite] = [
                SpriteLibrary.person(appearance: appearance, pose: .seated, isFounder: isFounder),
                SpriteLibrary.person(appearance: appearance, pose: .standing, isFounder: isFounder),
                SpriteLibrary.person(appearance: appearance, pose: .seatedCouch, isFounder: isFounder),
                SpriteLibrary.person(appearance: appearance, pose: .holdingBaby, isFounder: isFounder),
                SpriteLibrary.exercisingPerson(appearance: appearance, isFounder: isFounder),
                SpriteLibrary.person(appearance: appearance, pose: .lying, isFounder: isFounder),
            ]
            var x = gap
            let y = gap + row * rowHeight
            for sprite in sprites {
                for frame in 0..<2 {
                    painter.blit(sprite, frame: frame, x: x, y: y + (22 - sprite.height), into: context, canvasHeight: canvasHeight)
                    x += sprite.width + gap
                }
                x += gap
            }
        }
        // Kids (two frames each) and the baby.
        var x = gap
        let y = gap + rowHeight * appearances.count
        for appearance in appearances {
            let child = SpriteLibrary.child(appearance: appearance)
            for frame in 0..<2 {
                painter.blit(child, frame: frame, x: x, y: y, into: context, canvasHeight: canvasHeight)
                x += child.width + gap
            }
            x += gap
        }
        let baby = SpriteLibrary.baby()
        for frame in 0..<2 {
            painter.blit(baby, frame: frame, x: x, y: y + 4, into: context, canvasHeight: canvasHeight)
            x += baby.width + gap
        }
        try writePNG(context.makeImage()!, named: "poses_sheet.png")
    }

    @Test func homePropsSheet() throws {
        // Row 1: the 16 home props, bottom-aligned, in HomePropName order (frame 1 for animated ones).
        // Row 2: mood bubbles great/low, zzz (two frames), controller (two frames), book.
        let props = SpriteLibrary.HomePropName.allCases.map(SpriteLibrary.homeProp)
        let gap = 4
        let row1Height = props.map(\.height).max()!
        let row1Width = props.map(\.width).reduce(0, +) + gap * (props.count + 1)
        let extras: [(PixelSprite, Int)] = [
            (SpriteLibrary.moodBubble(.great), 0), (SpriteLibrary.moodBubble(.low), 0),
            (SpriteLibrary.zzzBubble(), 0), (SpriteLibrary.zzzBubble(), 1),
            (SpriteLibrary.controller(), 0), (SpriteLibrary.controller(), 1),
            (SpriteLibrary.book(), 0),
        ]
        let row2Y = 2 + row1Height + gap
        let height = row2Y + extras.map { $0.0.height }.max()! + gap
        let context = painter.makeCanvas(
            width: row1Width * Self.scale, height: height * Self.scale, background: .init(r: 56, g: 64, b: 104)
        )
        let canvasHeight = height * Self.scale

        var x = gap
        for prop in props {
            painter.blit(prop, frame: prop.frameCount - 1, x: x, y: 2 + row1Height - prop.height, into: context, canvasHeight: canvasHeight)
            x += prop.width + gap
        }
        x = gap
        for (sprite, frame) in extras {
            painter.blit(sprite, frame: frame, x: x, y: row2Y, into: context, canvasHeight: canvasHeight)
            x += sprite.width + gap
        }
        try writePNG(context.makeImage()!, named: "home_props_sheet.png")
    }
}
#endif
