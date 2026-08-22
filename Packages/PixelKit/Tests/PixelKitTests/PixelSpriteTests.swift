import CoreGraphics
import Testing
@testable import PixelKit

@Suite("PixelSprite validation")
struct PixelSpriteValidationTests {
    let palette: [Character: PixelSprite.RGBA] = [
        "R": .init(r: 255, g: 0, b: 0, a: 255),
        "G": .init(r: 0, g: 255, b: 0, a: 255),
        "B": .init(r: 0, g: 0, b: 255, a: 255),
    ]

    @Test func validSpriteExposesDimensions() {
        let sprite = PixelSprite(frames: [["RG", "BR"], ["GR", "RB"]], palette: palette)
        #expect(sprite.width == 2)
        #expect(sprite.height == 2)
        #expect(sprite.frameCount == 2)
    }

    @Test func singleFrameSprite() {
        let sprite = PixelSprite(frames: [["RGB"]], palette: palette)
        #expect(sprite.width == 3)
        #expect(sprite.height == 1)
        #expect(sprite.frameCount == 1)
    }

    @Test func validityAcceptsValidGrids() {
        #expect(PixelSprite.isValid(frames: [["RG", "BR"]], palette: palette))
        #expect(PixelSprite.isValid(frames: [["R "], ["G "]], palette: palette))
    }

    @Test func spacesAreAlwaysTransparentAndNeedNoPaletteEntry() {
        #expect(PixelSprite.isValid(frames: [["  ", "  "]], palette: [:]))
        let sprite = PixelSprite(frames: [["  ", "  "]], palette: [:])
        #expect(sprite.width == 2)
        #expect(sprite.height == 2)
    }

    @Test func rejectsEmptyFrameList() {
        #expect(!PixelSprite.isValid(frames: [], palette: palette))
    }

    @Test func rejectsFrameWithNoRows() {
        #expect(!PixelSprite.isValid(frames: [[]], palette: palette))
    }

    @Test func rejectsEmptyRowStrings() {
        #expect(!PixelSprite.isValid(frames: [[""]], palette: palette))
    }

    @Test func rejectsRaggedRows() {
        #expect(!PixelSprite.isValid(frames: [["RG", "B"]], palette: palette))
    }

    @Test func rejectsFramesOfDifferentSizes() {
        #expect(!PixelSprite.isValid(frames: [["RG", "BR"], ["RG"]], palette: palette))
        #expect(!PixelSprite.isValid(frames: [["RG"], ["RGB"]], palette: palette))
    }

    @Test func rejectsCharactersMissingFromPalette() {
        #expect(!PixelSprite.isValid(frames: [["RX"]], palette: palette))
    }
}

@Suite("PixelSprite CGImage rendering")
struct PixelSpriteImageTests {
    let palette: [Character: PixelSprite.RGBA] = [
        "R": .init(r: 255, g: 0, b: 0, a: 255),
        "G": .init(r: 0, g: 255, b: 0, a: 255),
        "B": .init(r: 0, g: 0, b: 255, a: 255),
    ]

    @Test func imageHasSpriteDimensionsForEveryFrame() {
        let sprite = PixelSprite(frames: [["RG", "BR"], ["GR", "RB"]], palette: palette)
        for frame in 0..<sprite.frameCount {
            let image = sprite.cgImage(frame: frame)
            #expect(image.width == 2)
            #expect(image.height == 2)
        }
    }

    @Test func knownSpriteRoundTripsExactBytes() {
        // R G
        // B (transparent)
        let sprite = PixelSprite(frames: [["RG", "B "]], palette: palette)
        let bytes = rgbaBytes(of: sprite.cgImage(frame: 0))
        #expect(pixel(bytes, width: 2, x: 0, y: 0) == (255, 0, 0, 255))
        #expect(pixel(bytes, width: 2, x: 1, y: 0) == (0, 255, 0, 255))
        #expect(pixel(bytes, width: 2, x: 0, y: 1) == (0, 0, 255, 255))
    }

    @Test func transparentPixelsHaveZeroAlpha() {
        let sprite = PixelSprite(frames: [["RG", "B "]], palette: palette)
        let bytes = rgbaBytes(of: sprite.cgImage(frame: 0))
        let p = pixel(bytes, width: 2, x: 1, y: 1)
        #expect(p.a == 0)
        #expect(p == (0, 0, 0, 0))
    }

    @Test func semiTransparentPaletteEntriesKeepTheirAlpha() {
        let glow: [Character: PixelSprite.RGBA] = ["G": .init(r: 200, g: 200, b: 200, a: 128)]
        let sprite = PixelSprite(frames: [["G"]], palette: glow)
        let bytes = rgbaBytes(of: sprite.cgImage(frame: 0))
        #expect(pixel(bytes, width: 1, x: 0, y: 0).a == 128)
    }

    @Test func cgImageIsCachedPerFrame() {
        let sprite = PixelSprite(frames: [["RG", "BR"], ["GR", "RB"]], palette: palette)
        let a1 = sprite.cgImage(frame: 0)
        let a2 = sprite.cgImage(frame: 0)
        let b1 = sprite.cgImage(frame: 1)
        #expect(a1 === a2)
        #expect(a1 !== b1)
        #expect(b1 === sprite.cgImage(frame: 1))
    }

    @Test func copiesShareTheFrameCache() {
        let sprite = PixelSprite(frames: [["RG"]], palette: palette)
        let copy = sprite
        #expect(sprite.cgImage(frame: 0) === copy.cgImage(frame: 0))
    }

    @Test func equalityComparesContentNotCache() {
        let a = PixelSprite(frames: [["RG"]], palette: palette)
        let b = PixelSprite(frames: [["RG"]], palette: palette)
        _ = a.cgImage(frame: 0) // warm one cache only
        #expect(a == b)
        let c = PixelSprite(frames: [["GR"]], palette: palette)
        #expect(a != c)
    }
}
