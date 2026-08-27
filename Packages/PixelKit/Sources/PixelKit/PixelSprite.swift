import CoreGraphics
import Foundation

/// A paletted pixel sprite with one or more animation frames.
///
/// Grid rows are strings, one `Character` per pixel; the palette maps each
/// character to an RGBA color. `' '` (space) is always transparent and never
/// needs a palette entry.
public struct PixelSprite: Sendable, Equatable {
    /// A plain 8-bit RGBA color.
    public struct RGBA: Sendable, Equatable, Hashable {
        public var r, g, b, a: UInt8

        public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }
    }

    let frames: [[String]]
    let palette: [Character: RGBA]

    public let width: Int
    public let height: Int

    public var frameCount: Int { frames.count }

    private let cache = FrameCache()

    /// Creates a sprite from pixel grids.
    ///
    /// - Precondition: `isValid(frames:palette:)` — at least one frame, every
    ///   frame rectangular and the same size, and every non-space character
    ///   resolvable through the palette.
    public init(frames: [[String]], palette: [Character: RGBA]) {
        precondition(
            Self.isValid(frames: frames, palette: palette),
            "PixelSprite frames must be nonempty, rectangular, uniformly sized, and fully covered by the palette"
        )
        self.frames = frames
        self.palette = palette
        self.height = frames[0].count
        self.width = frames[0][0].count
    }

    /// The validation rule `init(frames:palette:)` enforces with a precondition,
    /// exposed so invalid grids can be checked without trapping.
    public static func isValid(frames: [[String]], palette: [Character: RGBA]) -> Bool {
        guard let first = frames.first, !first.isEmpty else { return false }
        let height = first.count
        let width = first[0].count
        guard width > 0 else { return false }
        for frame in frames {
            guard frame.count == height else { return false }
            for row in frame {
                guard row.count == width else { return false }
                for ch in row where ch != " " {
                    guard palette[ch] != nil else { return false }
                }
            }
        }
        return true
    }

    public static func == (lhs: PixelSprite, rhs: PixelSprite) -> Bool {
        lhs.frames == rhs.frames && lhs.palette == rhs.palette
    }

    /// The frame rendered as a `CGImage`, built once per frame and cached.
    /// Repeated calls (including on copies of this value) return the identical
    /// `CGImage` instance.
    public func cgImage(frame: Int) -> CGImage {
        precondition((0..<frameCount).contains(frame), "frame \(frame) out of range 0..<\(frameCount)")
        return cache.image(for: frame) { renderFrame(frame) }
    }

    private func renderFrame(_ index: Int) -> CGImage {
        var data = [UInt8](repeating: 0, count: width * height * 4)
        for (y, row) in frames[index].enumerated() {
            for (x, ch) in row.enumerated() {
                guard ch != " ", let color = palette[ch] else { continue }
                let offset = (y * width + x) * 4
                // Premultiplied-last RGBA.
                let alpha = UInt16(color.a)
                data[offset] = UInt8(UInt16(color.r) * alpha / 255)
                data[offset + 1] = UInt8(UInt16(color.g) * alpha / 255)
                data[offset + 2] = UInt8(UInt16(color.b) * alpha / 255)
                data[offset + 3] = color.a
            }
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}

/// Per-frame CGImage cache shared by all copies of a sprite value.
private final class FrameCache: @unchecked Sendable {
    private let lock = NSLock()
    private var images: [Int: CGImage] = [:]

    func image(for index: Int, make: () -> CGImage) -> CGImage {
        lock.lock()
        defer { lock.unlock() }
        if let cached = images[index] { return cached }
        let image = make()
        images[index] = image
        return image
    }
}

/// Shared, keyed store of composed person sprites.
///
/// `SpriteLibrary.person` builds a brand-new `PixelSprite` — and so a brand
/// new frame cache — on every call, which means the office re-rasterizes
/// every sprite on every rebuild. WS-C turns this into an `NSCache`-backed
/// store so identical people share one instance (and one frame cache).
///
/// Scaffold stub: `sprite(for:make:)` just calls `make()`, so behavior is
/// unchanged while call sites can already route through the cache.
public enum SpriteCache {
    /// What makes one composed person sprite different from another.
    public struct Key: Hashable, Sendable {
        public var appearance: CharacterAppearance
        public var pose: SpriteLibrary.PersonPose
        public var isFounder: Bool
        public var role: RoleLook

        public init(
            appearance: CharacterAppearance,
            pose: SpriteLibrary.PersonPose,
            isFounder: Bool,
            role: RoleLook = .none
        ) {
            self.appearance = appearance
            self.pose = pose
            self.isFounder = isFounder
            self.role = role
        }
    }

    /// The sprite for `key`, building it with `make` on a miss. Every call
    /// is a miss until WS-C lands the real cache.
    public static func sprite(for key: Key, make: () -> PixelSprite) -> PixelSprite {
        make()
    }
}
