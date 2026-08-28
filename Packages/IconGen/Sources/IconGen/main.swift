// IconGen — renders the 1024×1024 App Store icon from the game's own
// PixelKit sprites, so the icon is literally the game's art: a pixel
// character typing at a desk with a glowing monitor, on the brand indigo.
//
// Usage:
//   swift run --package-path Packages/IconGen IconGen [output.png ...]
//
// With no arguments it writes AppIcon.png into the app's asset catalog,
// locating the repo root by walking up from the working directory until it
// finds `project.yml`.

import CoreGraphics
import Foundation
import ImageIO
import PixelKit
import UniformTypeIdentifiers

// MARK: - Configuration

let canvasSize = 1024

/// Brand indigo family — background gradient and floor band. The values
/// are the master palette's own `indigo` ramp, so the icon is painted from
/// the same box of crayons as the game. Apple masks the corners; the full
/// square is filled.
let bgTop = (r: 94, g: 96, b: 206)       // indigo[2]
let bgBottom = (r: 44, g: 46, b: 104)    // indigo[4]
let floorColor = (r: 46, g: 42, b: 60)   // ink[3]
let floorEdge = (r: 32, g: 30, b: 42)    // ink[4]

// MARK: - Scene

/// One sprite frame placed in composition pixel space (origin top-left),
/// mirroring `SceneComposer.deskCell`'s desk-cell offsets so the icon is the
/// same composition the game draws.
struct Placement {
    let image: CGImage
    let x: Int
    let y: Int
}

func composition() -> [Placement] {
    // The v2 founder, authored rather than random: short chestnut hair and
    // medium skin — and the indigo hoodie, which is the
    // founder's whole identity in this game. The desk sits low enough that
    // the hoodie and its drawstrings still read.
    var appearance = CharacterAppearance(seed: 1)
    appearance.skinTone = 1
    appearance.hairStyle = 0
    appearance.hairColor = 2
    appearance.shirtColor = 1
    appearance.glasses = nil
    appearance.hasBeard = false
    appearance.outfit = 0

    let person = SpriteLibrary.person(
        appearance: appearance, pose: .seated, isFounder: true, role: .founder
    )
    let desk = SpriteLibrary.desk()
    let monitor = SpriteLibrary.monitor()
    // Desk-cell layout from SceneComposer, dropped a few pixels so the
    // hoodie is not hidden behind the monitor. Monitor frame 1 is the
    // bright screen-glow frame.
    return [
        Placement(image: person.cgImage(frame: 0), x: 8, y: 0),
        Placement(image: monitor.cgImage(frame: 1), x: 10, y: 10),
        Placement(image: desk.cgImage(frame: 0), x: 3, y: 16),
    ]
}

// MARK: - Rendering

func renderIcon() -> CGImage {
    let placements = composition()

    // Composition bounds in sprite pixel space.
    let minX = placements.map(\.x).min()!
    let minY = placements.map(\.y).min()!
    let maxX = placements.map { $0.x + $0.image.width }.max()!
    let maxY = placements.map { $0.y + $0.image.height }.max()!
    let compWidth = maxX - minX
    let compHeight = maxY - minY

    // Integer scale so pixels stay crisp; the composition fills ~66% of the
    // canvas width (Apple's masked corners leave generous margins).
    let scale = Int(Double(canvasSize) * 0.66) / compWidth
    let scaledWidth = compWidth * scale
    let scaledHeight = compHeight * scale

    // Centered horizontally; the composition's baseline sits on the floor
    // band, slightly below optical center.
    let floorY = 820
    let originX = (canvasSize - scaledWidth) / 2
    let originY = floorY - scaledHeight

    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil,
        width: canvasSize,
        height: canvasSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    func color(_ c: (r: Int, g: Int, b: Int)) -> CGColor {
        CGColor(
            colorSpace: space,
            components: [CGFloat(c.r) / 255, CGFloat(c.g) / 255, CGFloat(c.b) / 255, 1]
        )!
    }

    // Background: vertical indigo gradient, top-lighter.
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [color(bgTop), color(bgBottom)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: canvasSize), // CG is y-up: canvas top
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // Floor band grounding the desk, with a hard pixel edge.
    let edgeHeight = 8
    ctx.setFillColor(color(floorEdge))
    ctx.fill(CGRect(x: 0, y: canvasSize - floorY - edgeHeight, width: canvasSize, height: edgeHeight))
    ctx.setFillColor(color(floorColor))
    ctx.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize - floorY - edgeHeight))

    // Sprites, nearest-neighbor scaled.
    ctx.interpolationQuality = .none
    for placement in placements {
        let x = originX + (placement.x - minX) * scale
        let topY = originY + (placement.y - minY) * scale
        let width = placement.image.width * scale
        let height = placement.image.height * scale
        let rect = CGRect(
            x: x,
            y: canvasSize - topY - height, // flip: CG origin is bottom-left
            width: width,
            height: height
        )
        ctx.draw(placement.image, in: rect)
    }

    return ctx.makeImage()!
}

// MARK: - Output

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw IconGenError("Couldn't create PNG destination at \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IconGenError("Couldn't write PNG to \(url.path)")
    }
}

struct IconGenError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Walks up from the working directory to the directory containing
/// `project.yml` — the repo root.
func findRepoRoot() throws -> URL {
    var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while true {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) {
            return dir
        }
        let parent = dir.deletingLastPathComponent()
        guard parent.path != dir.path else {
            throw IconGenError(
                "Couldn't find project.yml above \(FileManager.default.currentDirectoryPath); "
                    + "run from inside the repo or pass explicit output paths"
            )
        }
        dir = parent
    }
}

// MARK: - Main

do {
    let explicitOutputs = CommandLine.arguments.dropFirst().map { URL(fileURLWithPath: $0) }
    let outputs: [URL]
    if explicitOutputs.isEmpty {
        let root = try findRepoRoot()
        outputs = [root.appendingPathComponent(
            "App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
        )]
    } else {
        outputs = explicitOutputs
    }

    let icon = renderIcon()
    precondition(icon.width == canvasSize && icon.height == canvasSize)
    for url in outputs {
        try writePNG(icon, to: url)
        print("Wrote \(icon.width)x\(icon.height) icon to \(url.path)")
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
