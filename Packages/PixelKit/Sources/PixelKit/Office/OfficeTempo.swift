import Foundation

/// What the room feels like, read off the scene input rather than asked for.
///
/// Nothing in the engine says "this team is in crunch" — but the input
/// already carries the hour, the team's morale and everybody's work status,
/// and a floor still full of people building something at ten at night *is*
/// crunch. Reading it here keeps the animation honest (it can only say
/// things the scene actually knows) and keeps it a pure function of the
/// input, which is what the memoized director requires.
///
/// The tempo is a *rate* control only. It never puts anyone in a pose their
/// plan did not choose, and — importantly — it never touches the plans
/// themselves, however tempting "crunch means fewer coffee breaks" is:
/// `OfficeSceneView` rolls `timeOfDay` forward on its own four-minute loop,
/// so a plan that read the hour would reshuffle the moment dusk turned into
/// night and teleport half the floor mid-walk. Crunch shows in the hands
/// and the feet, which can change rate mid-stride without anybody noticing.
public enum OfficeTempo: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Late, and still shipping. Hands move faster, walks are quicker,
    /// breaks are shorter and rarer.
    case crunch
    /// Morale is on the floor. Everything is a beat slower.
    case flagging
    /// An ordinary day.
    case steady
    /// A team having a good week: quicker breaths, more excuses to get up.
    case buoyant

    /// The reading for a scene.
    ///
    /// Order matters: crunch outranks morale, because a good mood at
    /// midnight still looks like crunch from across the room.
    public static func reading(for input: OfficeSceneInput) -> OfficeTempo {
        // Crunch is a fact the input carries now, not a guess from the
        // hour: the room's own clock rolls through dusk and night every
        // four minutes, and reading crunch off it said "crunch" half the
        // time whatever the team was on.
        if input.pressure.crunch { return .crunch }
        switch input.ambience.teamMood {
        case .great: return .buoyant
        case .okay: return .steady
        case .low: return .flagging
        }
    }

    /// Multiplier on walking cadence. Crunch does not make anyone walk
    /// *further* — the plans are unchanged — it makes the steps quicker
    /// over the same ground, which is what hurrying looks like.
    public var walkScale: Double {
        switch self {
        case .crunch: 1.3
        case .flagging: 0.85
        case .steady: 1
        case .buoyant: 1.1
        }
    }

    /// Steps per second of the typing chart. `ActorRhythm.typingChart` runs
    /// sixteen steps, so eight a second is a two-second loop.
    public var typingStepsPerSecond: Double {
        switch self {
        case .crunch: 11
        case .flagging: 5
        case .steady: 8
        case .buoyant: 9
        }
    }

    /// Nudge to every idle toggle period, in legacy ticks. A longer period
    /// is a slower breath.
    public var breathBias: Int {
        switch self {
        case .crunch: -1
        case .flagging: 2
        case .steady: 0
        case .buoyant: -1
        }
    }
}
