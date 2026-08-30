import Foundation

/// What a person is doing — controls the desk-side status bubble and the
/// animation choice. Purely cosmetic; the app maps simulation state onto it.
///
/// The role statuses (`testing`, `legal`, `peopleOps`, `operations`) get
/// their own bubbles: a bug, a set of scales, two people, and a wrench.
public enum WorkStatus: String, Sendable, Equatable, Codable, CaseIterable {
    case idle, coding, designing, marketing, researching
    case testing, legal, peopleOps, operations
}

/// One person to place in the office scene.
///
/// The fields after `isFounder` are what WS-C's director reads to make the
/// room feel alive — they all default to today's behavior (`.okay` mood, no
/// friends, no speech, no role accessory), so an occupant built the old way
/// composes exactly the old scene.
public struct Occupant: Sendable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var appearance: CharacterAppearance
    public var status: WorkStatus
    public var isFounder: Bool
    /// Drives the slump / cheer poses and the mood cloud.
    public var mood: MoodLevel
    /// Who this person is friends with; the director sends friends to chat.
    public var friendIDs: [UUID]
    /// A transient line shown in a speech bubble when tapped.
    public var speech: String?
    /// The role accessory WS-D draws on the sprite.
    public var role: RoleLook
    /// Shown on the name plate when the player taps this person.
    public var name: String?
    /// Out of the building today — a trip, leave, an off-site. Their desk
    /// stays empty with a note stuck to the monitor instead of a person.
    public var isAway: Bool

    public init(
        id: UUID,
        appearance: CharacterAppearance,
        status: WorkStatus,
        isFounder: Bool = false,
        mood: MoodLevel = .okay,
        friendIDs: [UUID] = [],
        speech: String? = nil,
        role: RoleLook = .none,
        name: String? = nil,
        isAway: Bool = false
    ) {
        self.id = id
        self.appearance = appearance
        self.status = status
        self.isFounder = isFounder
        self.mood = mood
        self.friendIDs = friendIDs
        self.speech = speech
        self.role = role
        self.name = name
        self.isAway = isAway
    }
}
