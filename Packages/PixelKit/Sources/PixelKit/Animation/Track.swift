import Foundation

/// A chain of `Motion`s that make up one journey.
///
/// Office walks are L-shaped: down the desk column into the front corridor,
/// along the corridor, then up to the destination. Each leg is its own
/// `Motion` so the walker can face a different way on each one, and the
/// track ties them into a single thing with a start, an end and a position
/// at any `t`.
///
/// Legs are expected to be contiguous and ordered; `append(to:speed:)`
/// guarantees it.
public struct Track: Sendable, Equatable, Hashable {
    public private(set) var legs: [Motion]

    /// An empty track that parks a sprite at one point forever.
    public init(parkedAt point: ScenePoint, from start: TimeInterval = 0) {
        self.legs = [Motion.hold(at: point, start: start, duration: 0)]
    }

    public init(legs: [Motion]) {
        precondition(!legs.isEmpty, "a Track needs at least one leg")
        self.legs = legs
    }

    /// Where the journey begins.
    public var origin: ScenePoint { legs[0].from }
    /// Where the journey ends.
    public var destination: ScenePoint { legs[legs.count - 1].to }
    /// Scene time of the first leg's departure.
    public var start: TimeInterval { legs[0].start }
    /// Scene time the last leg lands.
    public var end: TimeInterval { legs[legs.count - 1].end }
    /// Total travel time.
    public var duration: TimeInterval { end - start }

    /// Extends the track with a leg to `point`, departing the moment the
    /// previous leg lands. Legs whose distance is zero are dropped so a
    /// dog-leg that happens to be straight stays one motion, and the
    /// zero-duration "parked" leg a track starts life with is replaced by
    /// the first real one.
    public mutating func append(to point: ScenePoint, speed: Double) {
        let last = legs[legs.count - 1]
        guard last.to != point else { return }
        let leg = Motion.walk(from: last.to, to: point, start: last.end, speed: speed)
        if legs.count == 1, last.duration == 0 {
            legs[0] = leg
        } else {
            legs.append(leg)
        }
    }

    /// The leg in flight at `t`, or the nearest one when `t` falls outside
    /// the journey (the first leg before it starts, the last one after).
    public func leg(at t: TimeInterval) -> Motion {
        if t <= legs[0].start { return legs[0] }
        for leg in legs where t < leg.end { return leg }
        return legs[legs.count - 1]
    }

    /// Where the traveller is at `t`.
    public func position(at t: TimeInterval) -> ScenePoint {
        leg(at: t).position(at: t)
    }

    /// Whether the traveller is actually moving at `t` (as opposed to
    /// waiting to leave, or already arrived).
    public func isMoving(at t: TimeInterval) -> Bool {
        t > start && t < end
    }

    /// An L-shaped route between two points by way of a corridor line.
    ///
    /// People in this office never cut diagonally across the floor: they
    /// step out of their row into the corridor, walk it, then step in. When
    /// both ends already sit on the corridor the dog-leg collapses to a
    /// single straight walk.
    public static func route(
        from origin: ScenePoint,
        to destination: ScenePoint,
        corridorY: Double,
        departingAt start: TimeInterval,
        speed: Double
    ) -> Track {
        var track = Track(parkedAt: origin, from: start)
        if origin.y != corridorY {
            track.append(to: ScenePoint(x: origin.x, y: corridorY), speed: speed)
        }
        if destination.x != origin.x {
            track.append(to: ScenePoint(x: destination.x, y: corridorY), speed: speed)
        }
        track.append(to: destination, speed: speed)
        return track
    }
}
