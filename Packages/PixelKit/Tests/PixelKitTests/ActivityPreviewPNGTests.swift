#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// PNG previews of the thirteen activity vignettes, plus the invariants
/// that keep them honest: one fixed canvas, everything inside it, and at
/// least two things moving in every scene.
@Suite("Activity preview PNGs", .serialized)
struct ActivityPreviewPNGTests {
    static let outputDirectory = PreviewPNGTests.outputDirectory.appendingPathComponent("activities", isDirectory: true)
    static let scale = PreviewPNGTests.scale
    let painter = PreviewPNGTests()

    func renderScene(style: ActivitySceneStyle, tick: Int) -> CGImage {
        let size = ActivitySceneComposer.sceneSize()
        let context = painter.makeCanvas(
            width: size.width * Self.scale, height: size.height * Self.scale, background: nil
        )
        for placement in ActivitySceneComposer.compose(
            style: style,
            appearance: CharacterAppearance(seed: 7),
            companion: CharacterAppearance(seed: 21)
        ) {
            painter.blit(
                placement.sprite, frame: placement.frameIndex(atTick: tick),
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

    @Test func everyVignetteRenders() throws {
        for style in ActivitySceneStyle.allCases {
            try writePNG(renderScene(style: style, tick: 2), named: "\(style.rawValue).png")
        }
    }

    /// One sheet with all thirteen, three across, for judging them as a set.
    @Test func contactSheet() throws {
        let (cellWidth, cellHeight) = ActivitySceneComposer.sceneSize()
        let columns = 3
        let gap = 4
        let styles = ActivitySceneStyle.allCases
        let rows = (styles.count + columns - 1) / columns
        let width = gap + columns * (cellWidth + gap)
        let height = gap + rows * (cellHeight + gap)
        let canvasHeight = height * Self.scale
        let context = painter.makeCanvas(
            width: width * Self.scale, height: canvasHeight, background: .init(r: 46, g: 42, b: 60)
        )
        for (index, style) in styles.enumerated() {
            let originX = gap + (index % columns) * (cellWidth + gap)
            let originY = gap + (index / columns) * (cellHeight + gap)
            for placement in ActivitySceneComposer.compose(
                style: style, appearance: CharacterAppearance(seed: 7),
                companion: CharacterAppearance(seed: 21)
            ) {
                painter.blit(
                    placement.sprite, frame: placement.frameIndex(atTick: 2),
                    x: originX + placement.x, y: originY + placement.y,
                    into: context, canvasHeight: canvasHeight
                )
            }
        }
        try writePNG(context.makeImage()!, named: "activities_sheet.png")
    }

    // MARK: Invariants

    @Test func everyVignetteFitsItsCanvas() {
        let size = ActivitySceneComposer.sceneSize()
        for style in ActivitySceneStyle.allCases {
            let scene = ActivitySceneComposer.compose(style: style, appearance: CharacterAppearance(seed: 3))
            #expect(!scene.isEmpty)
            for placement in scene {
                #expect(placement.x >= 0 && placement.y >= 0, "\(style) \(placement.kind) origin")
                #expect(placement.x + placement.sprite.width <= size.width, "\(style) \(placement.kind) right edge")
                #expect(placement.y + placement.sprite.height <= size.height, "\(style) \(placement.kind) bottom edge")
            }
        }
    }

    @Test func everyVignetteHasAtLeastTwoMovingElements() {
        for style in ActivitySceneStyle.allCases {
            let scene = ActivitySceneComposer.compose(style: style, appearance: CharacterAppearance(seed: 3))
            let animated = scene.filter { $0.animation != .still && $0.sprite.frameCount > 1 }
            #expect(animated.count >= 2, "\(style) has \(animated.count) moving elements; a still vignette reads as a stall")
        }
    }

    @Test func everyVignetteShowsAPerson() {
        for style in ActivitySceneStyle.allCases {
            let scene = ActivitySceneComposer.compose(style: style, appearance: CharacterAppearance(seed: 3))
            #expect(scene.contains { $0.kind == .person }, "\(style) has nobody in it")
        }
    }

    @Test func compositionIsDeterministic() {
        for style in ActivitySceneStyle.allCases {
            let a = ActivitySceneComposer.compose(style: style, appearance: CharacterAppearance(seed: 9))
            let b = ActivitySceneComposer.compose(style: style, appearance: CharacterAppearance(seed: 9))
            #expect(a == b, "\(style)")
        }
    }

    @Test func frameIndexNeverExceedsFrameCount() {
        for style in ActivitySceneStyle.allCases {
            for placement in ActivitySceneComposer.compose(style: style, appearance: CharacterAppearance(seed: 4)) {
                for tick in 0..<24 {
                    let frame = placement.frameIndex(atTick: tick)
                    #expect(frame >= 0 && frame < placement.sprite.frameCount, "\(style) \(placement.kind)")
                }
            }
        }
    }

    /// The engine's weekend plans all map onto a vignette, except resting —
    /// which is what the home scene already shows.
    @Test func weekendActivitiesMapToScenes() {
        let expected: [String: ActivitySceneStyle?] = [
            "rest": nil,
            "gym": .gymSession,
            "dateNight": .dateNight,
            "friends": .friends,
            "hobby": .hobby,
            "familyTime": .familyTime,
            "vacation": .vacation,
            "doctor": .doctor,
            "spa": .spa,
            "networking": .networking,
        ]
        for (raw, style) in expected {
            #expect(ActivitySceneStyle(weekendActivity: raw) == style, "\(raw)")
        }
        #expect(ActivitySceneStyle(weekendActivity: "nonsense") == nil)
        #expect(ActivitySceneStyle.allCases.count == 13, "five instant scenes plus eight weekend plans")
        for style in ActivitySceneStyle.allCases {
            #expect(!style.sceneDescription.isEmpty, "\(style) needs an accessibility description")
        }
    }
}
#endif
