import Foundation

/// What an actor's body is doing. Maps onto WS-D's `SpriteLibrary.PersonPose`
/// at draw time; kept separate so the behavior layer can talk about
/// intentions ("taking a break") rather than about art.
public enum ActorPose: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Seated at a desk, typing.
    case desk
    /// On the move. The walk sprite and its flip come from the leg's heading.
    case walk
    /// Standing still, facing the room.
    case stand
    /// Standing with a mug — the coffee machine, the kitchenette.
    case coffee
    /// Turned toward someone, mid-conversation.
    case chat
    /// Arms up: a stretch, or a celebration.
    case cheer
    /// Shoulders down. Low morale, or a bad review.
    case slump
    /// Carrying a cardboard box to the door. Last day.
    case carryBox

    /// The art WS-D draws for this pose.
    var personPose: SpriteLibrary.PersonPose {
        switch self {
        case .desk: .seated
        case .walk: .walkRight
        case .stand: .standing
        case .coffee: .coffee
        case .chat: .chat
        case .cheer: .cheer
        case .slump: .slump
        case .carryBox: .carryBox
        }
    }
}

/// Which way an actor faces. Horizontal walks flip the sprite; everything
/// else faces the viewer.
public enum Facing: String, Sendable, Equatable, Hashable, CaseIterable {
    case left, right, forward

    /// Whether the sprite is mirrored when drawn.
    public var flipsX: Bool { self == .left }
}

/// A small icon floating above an actor's head for the length of a segment.
public enum ActorBubble: Sendable, Equatable, Hashable {
    /// The work-status bubble (`</>`, brush, bug…), shown transiently.
    case status(WorkStatus)
    /// Ellipsis: two people talking.
    case chatter
    /// A grey rain cloud: morale is in the floor.
    case gloom
    /// A light bulb: research landed.
    case idea
    /// A steaming mug.
    case mug
    /// A name plate with an optional line under it, shown when tapped.
    case nameTag(name: String, line: String?)
}

/// One stretch of an actor's day with a single intention.
///
/// Segments tile the plan back-to-back with no gaps: `end` of one is `start`
/// of the next, and every boundary sits on a whole second so the director's
/// output only changes once a second.
public struct ActorSegment: Sendable, Equatable, Hashable {
    public var start: TimeInterval
    public var end: TimeInterval
    public var pose: ActorPose
    /// Where the body is over this segment. Parked for anything stationary.
    public var track: Track
    /// What floats above the head for this segment, if anything.
    public var bubble: ActorBubble?
    /// The waypoint this segment belongs to, for tests and hit-testing.
    public var waypointID: String?

    public init(
        start: TimeInterval,
        end: TimeInterval,
        pose: ActorPose,
        track: Track,
        bubble: ActorBubble? = nil,
        waypointID: String? = nil
    ) {
        self.start = start
        self.end = end
        self.pose = pose
        self.track = track
        self.bubble = bubble
        self.waypointID = waypointID
    }

    public func contains(_ t: TimeInterval) -> Bool { t >= start && t < end }
}

/// Where an actor is and what it is doing at one instant.
public struct ActorState: Sendable, Equatable {
    public var position: ScenePoint
    public var pose: ActorPose
    public var facing: Facing
    public var bubble: ActorBubble?
    public var waypointID: String?
}

/// One occupant's whole day, as a tiled list of segments.
///
/// A plan is built once per office day by `OfficeBehaviors` and is a pure
/// function of the occupant's id and the day index, so the same person does
/// the same things at the same times every time the scene is evaluated.
public struct ActorPlan: Sendable, Equatable, Hashable {
    public var id: UUID
    /// Which desk cell this actor belongs to, in `SceneComposer`'s indexing
    /// (`deskCapacity` is the founder's own desk).
    public var seatIndex: Int
    /// Where this actor stands when they get up. Feet-anchor, scene pixels.
    public var deskAnchor: ScenePoint
    /// Contiguous, ordered, whole-second segments.
    public var segments: [ActorSegment]

    public init(id: UUID, seatIndex: Int, deskAnchor: ScenePoint, segments: [ActorSegment]) {
        self.id = id
        self.seatIndex = seatIndex
        self.deskAnchor = deskAnchor
        self.segments = segments
    }

    /// The segment covering `t`, clamped to the ends of the plan.
    public func segment(at t: TimeInterval) -> ActorSegment {
        if let hit = segments.first(where: { $0.contains(t) }) { return hit }
        return t < (segments.first?.start ?? 0) ? segments[0] : segments[segments.count - 1]
    }

    /// Position, pose, facing and bubble at `t`.
    public func state(at t: TimeInterval) -> ActorState {
        let segment = segment(at: t)
        let leg = segment.track.leg(at: t)
        let position = leg.position(at: t)
        let moving = segment.track.isMoving(at: t)
        let pose: ActorPose = segment.pose == .walk && !moving ? .stand : segment.pose
        let facing: Facing
        if moving, abs(leg.to.x - leg.from.x) > 0.5 {
            facing = leg.to.x < leg.from.x ? .left : .right
        } else {
            facing = .forward
        }
        return ActorState(
            position: position,
            pose: pose,
            facing: facing,
            bubble: segment.bubble,
            waypointID: segment.waypointID
        )
    }

    /// Every distinct non-desk waypoint this plan visits — the shape
    /// `OfficeDirectorTests` asserts on.
    public var visitedWaypointIDs: [String] {
        var seen: [String] = []
        for segment in segments {
            guard let id = segment.waypointID, id != "desk", !seen.contains(id) else { continue }
            seen.append(id)
        }
        return seen
    }
}
