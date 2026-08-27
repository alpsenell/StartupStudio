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
        SpriteRenderStats.recordRender()
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

/// How many frames have been rasterized, for the performance suite.
///
/// `PixelSprite.renderFrame` is the expensive step (a full RGBA buffer plus
/// a `CGImage`); everything else in the pipeline is arithmetic. Counting
/// renders is therefore the cheapest honest proxy for "did the cache work",
/// and `OfficePerfTests` asserts it goes to zero after warm-up.
enum SpriteRenderStats {
    /// The counter for the task currently measuring. Task-local so two
    /// tests measuring in parallel cannot see each other's rasterizations.
    @TaskLocal private static var active: Counter?

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func increment() {
            lock.lock()
            value += 1
            lock.unlock()
        }

        func read() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    static func recordRender() { active?.increment() }

    /// Runs `body` and reports how many sprite frames it rasterized.
    static func rasterizations(during body: () -> Void) -> Int {
        let counter = Counter()
        return $active.withValue(counter) {
            body()
            return counter.read()
        }
    }
}

/// Shared, keyed store of composed person sprites.
///
/// `SpriteLibrary.person` builds a brand-new `PixelSprite` — and so a brand
/// new frame cache — on every call, which meant the office re-rasterized
/// every sprite on every rebuild: at 4× speed on a campus that is ~130
/// sprites four times a second. This is the `NSCache`-backed store that
/// makes identical people share one instance, and therefore one frame
/// cache, for the life of the process.
///
/// Route *every* person lookup through it: the office composer and the
/// director do, and any other scene that draws repeated people should too.
/// `NSCache` evicts under memory pressure, so a miss is always safe.
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

    /// The sprite for `key`, building it with `make` only on a miss.
    public static func sprite(for key: Key, make: () -> PixelSprite) -> PixelSprite {
        if let hit = store.object(forKey: KeyBox(key)) { return hit.sprite }
        let sprite = make()
        store.setObject(SpriteBox(sprite), forKey: KeyBox(key))
        return sprite
    }

    /// Convenience for the common case: a person in a pose.
    public static func person(
        appearance: CharacterAppearance,
        pose: SpriteLibrary.PersonPose,
        isFounder: Bool = false,
        role: RoleLook = .none
    ) -> PixelSprite {
        sprite(for: Key(appearance: appearance, pose: pose, isFounder: isFounder, role: role)) {
            SpriteLibrary.person(appearance: appearance, pose: pose, isFounder: isFounder, role: role)
        }
    }

    /// The sprite for an arbitrary string key.
    ///
    /// People are not the only thing rebuilt per frame: the room itself is
    /// a 260×144 grid of strings on a campus, and desks, monitors, bubbles
    /// and props are all rebuilt on every call too. Anything whose art is a
    /// pure function of a few parameters belongs here, keyed by those
    /// parameters — `"room.campus.260x144.36.night"`, `"desk"`, and so on.
    public static func shared(_ key: String, make: () -> PixelSprite) -> PixelSprite {
        let boxed = key as NSString
        if let hit = named.object(forKey: boxed) { return hit.sprite }
        let sprite = make()
        named.setObject(SpriteBox(sprite), forKey: boxed)
        return sprite
    }

    /// Empties the cache. Tests use it to measure a cold pipeline; the app
    /// never needs to.
    public static func removeAll() {
        store.removeAllObjects()
        named.removeAllObjects()
    }

    // MARK: Storage

    /// One entry per (appearance × pose × founder × role) actually seen. A
    /// campus of forty people in four poses is 160 entries of ~1 KB.
    nonisolated(unsafe) private static let store: NSCache<KeyBox, SpriteBox> = {
        let cache = NSCache<KeyBox, SpriteBox>()
        cache.countLimit = 512
        return cache
    }()

    /// Rooms, furniture, props, bubbles and effect art, keyed by the
    /// parameters they are built from.
    nonisolated(unsafe) private static let named: NSCache<NSString, SpriteBox> = {
        let cache = NSCache<NSString, SpriteBox>()
        cache.countLimit = 256
        return cache
    }()

    private final class KeyBox: NSObject {
        let key: Key

        init(_ key: Key) { self.key = key }

        override var hash: Int { key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            (object as? KeyBox)?.key == key
        }
    }

    private final class SpriteBox: NSObject {
        let sprite: PixelSprite

        init(_ sprite: PixelSprite) { self.sprite = sprite }
    }
}
