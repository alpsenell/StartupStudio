import Foundation

/// A point in scene pixel space, with sub-pixel precision while it travels.
///
/// Scene coordinates have their origin at the top-left, y growing downward —
/// the same space `PlacedSprite.x` / `.y` live in.
public struct ScenePoint: Sendable, Equatable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(x: Int, y: Int) {
        self.init(x: Double(x), y: Double(y))
    }

    /// The point snapped to whole scene pixels — what actually gets drawn,
    /// because a pixel person standing on a half pixel looks like mush.
    public var rounded: (x: Int, y: Int) {
        (Int(x.rounded()), Int(y.rounded()))
    }

    /// Straight-line distance to another point.
    public func distance(to other: ScenePoint) -> Double {
        let dx = other.x - x
        let dy = other.y - y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// A timed translation applied to a `PlacedSprite`.
///
/// A motion is *absolute in scene time*: it knows when it starts and how
/// long it runs, so evaluating the same motion at the same `t` always gives
/// the same point. Before `start` the sprite sits at `from`; after
/// `start + duration` it sits at `to` forever. That "clamp at both ends"
/// behavior is what lets the director hand the view a list of placements
/// once per second and still get smooth movement inside it.
public struct Motion: Sendable, Equatable, Hashable {
    public var from: ScenePoint
    public var to: ScenePoint
    /// Scene time (seconds) the movement begins.
    public var start: TimeInterval
    /// How long the movement lasts. Zero or less snaps instantly.
    public var duration: TimeInterval
    public var easing: Easing

    public init(
        from: ScenePoint,
        to: ScenePoint,
        start: TimeInterval,
        duration: TimeInterval,
        easing: Easing = .linear
    ) {
        self.from = from
        self.to = to
        self.start = start
        self.duration = duration
        self.easing = easing
    }

    /// Scene time the movement finishes.
    public var end: TimeInterval { start + max(0, duration) }

    /// Where the sprite is at scene time `t`.
    public func position(at t: TimeInterval) -> ScenePoint {
        guard duration > 0 else { return t < start ? from : to }
        if t <= start { return from }
        if t >= end { return to }
        let eased = easing.apply((t - start) / duration)
        return ScenePoint(
            x: from.x + (to.x - from.x) * eased,
            y: from.y + (to.y - from.y) * eased
        )
    }

    /// Whether `t` falls inside the moving window (used by the director to
    /// pick a walk pose over a standing one).
    public func isMoving(at t: TimeInterval) -> Bool {
        duration > 0 && t > start && t < end
    }

    /// A motion that holds a sprite still at one point for `duration`.
    /// Handy for keeping a dwell segment on the same timeline as the walks
    /// around it.
    public static func hold(at point: ScenePoint, start: TimeInterval, duration: TimeInterval) -> Motion {
        Motion(from: point, to: point, start: start, duration: duration, easing: .linear)
    }

    /// A straight walk at a fixed speed, with the duration derived from the
    /// distance and rounded **up to a whole second**.
    ///
    /// The rounding is deliberate: every plan boundary in the office lands
    /// on an integer second, which is what makes per-second memoization of
    /// the director exact. See `AnimationClock.secondBucket(at:)`.
    public static func walk(
        from: ScenePoint,
        to: ScenePoint,
        start: TimeInterval,
        speed: Double
    ) -> Motion {
        let seconds = max(1, (from.distance(to: to) / max(1, speed)).rounded(.up))
        return Motion(from: from, to: to, start: start, duration: seconds, easing: .linear)
    }
}
