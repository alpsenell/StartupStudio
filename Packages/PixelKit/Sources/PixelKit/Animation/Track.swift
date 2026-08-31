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

    /// A leg too short to be worth turning around for.
    ///
    /// An L-route out of a desk row starts with a sidestep into the nearest
    /// clear lane, which can be four pixels in the opposite direction to
    /// the whole rest of the journey. Played literally that is a walker who
    /// faces right for one second, forward for one, then left for five — a
    /// twitch, not a turn.
    static let turnThreshold: Double = 8

    /// The heading of the longest horizontal leg in the journey, if there
    /// is one. This is the direction the walk is *about*, as opposed to the
    /// direction any one leg happens to point.
    var dominantHeading: Facing? {
        var best: (distance: Double, facing: Facing)?
        for leg in legs {
            let dx = leg.to.x - leg.from.x
            guard abs(dx) > abs(leg.to.y - leg.from.y), abs(dx) > 0.5 else { continue }
            if best == nil || abs(dx) > best!.distance {
                best = (abs(dx), dx < 0 ? .left : .right)
            }
        }
        return best?.facing
    }

    /// Which way the traveller faces at `t`.
    ///
    /// Sideways legs face the way they are going and everything else faces
    /// the viewer — except that a sidestep shorter than `turnThreshold`
    /// borrows the journey's dominant heading instead of flipping the
    /// sprite for one second and flipping it straight back.
    public func heading(at t: TimeInterval) -> Facing {
        guard isMoving(at: t) else { return .forward }
        let leg = leg(at: t)
        let dx = leg.to.x - leg.from.x
        guard abs(dx) > 0.5, abs(dx) > abs(leg.to.y - leg.from.y) else { return .forward }
        if leg.from.distance(to: leg.to) < Self.turnThreshold, let dominant = dominantHeading {
            return dominant
        }
        return dx < 0 ? .left : .right
    }

    /// An L-shaped route between two points by way of a corridor line and,
    /// optionally, a set of vertical lanes.
    ///
    /// People in this office never cut diagonally across the floor. They
    /// step sideways out of their row into the nearest clear lane between
    /// two desk columns, walk that lane down to the front corridor, cross
    /// the room along it, then reverse the manoeuvre at the other end. With
    /// no lanes given the route degenerates to the plain three-leg dog-leg
    /// (out, across, in), and when both ends already sit on the corridor it
    /// collapses to one straight walk.
    ///
    /// - Parameter lanes: x positions of the clear vertical lanes. The
    ///   nearest one to each end is used.
    public static func route(
        from origin: ScenePoint,
        to destination: ScenePoint,
        corridorY: Double,
        lanes: [Double] = [],
        departingAt start: TimeInterval,
        speed: Double
    ) -> Track {
        var track = Track(parkedAt: origin, from: start)
        guard origin != destination else { return track }

        /// Anything within a couple of pixels of the corridor counts as
        /// already being on it — no detour worth walking.
        func onCorridor(_ point: ScenePoint) -> Bool { abs(point.y - corridorY) <= 2 }
        func lane(near x: Double) -> Double {
            lanes.min { abs($0 - x) < abs($1 - x) } ?? x
        }

        if !onCorridor(origin) {
            let out = lane(near: origin.x)
            track.append(to: ScenePoint(x: out, y: origin.y), speed: speed)
            track.append(to: ScenePoint(x: out, y: corridorY), speed: speed)
        }
        if onCorridor(destination) {
            track.append(to: ScenePoint(x: destination.x, y: corridorY), speed: speed)
        } else {
            let into = lane(near: destination.x)
            track.append(to: ScenePoint(x: into, y: corridorY), speed: speed)
            track.append(to: ScenePoint(x: into, y: destination.y), speed: speed)
        }
        track.append(to: destination, speed: speed)
        return track
    }
}
