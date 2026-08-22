/// Home tiers mirroring the game's life progression (studio flat → apartment
/// → house → penthouse). Like `OfficeTierStyle`, a plain enum the app maps
/// onto; raw values match the engine's `HomeTier` by design.
public enum HomeTierStyle: String, Sendable, Equatable, Codable, CaseIterable {
    case studioFlat, apartment, house, penthouse

    /// Position in the progression, for "tier >= apartment" style rules.
    var rank: Int {
        switch self {
        case .studioFlat: 0
        case .apartment: 1
        case .house: 2
        case .penthouse: 3
        }
    }

    /// Only homes with a spare corner get a crib.
    var hasRoomForCrib: Bool { rank >= HomeTierStyle.apartment.rank }
}

/// What the founder is doing this evening. Drives where the founder is
/// placed and which pose/animation they get. Cosmetic only.
public enum HomeActivity: String, Sendable, Equatable, Codable, CaseIterable {
    /// On the couch, breathing.
    case relaxing
    /// In bed, zzz bubble.
    case sleeping
    /// On the couch with a wiggling controller; TV glows.
    case gaming
    /// At the table (opposite the partner when present, heart bubble).
    case dinner
    /// Dumbbells on the yoga mat, 2-frame up/down.
    case exercising
    /// In the armchair (or couch) with a book.
    case reading
    /// By the crib, rocking the baby.
    case withBaby
    /// Not home: suitcase by the door; partner and kids still shown.
    case away
}

/// The founder's mood, shown as a bubble above their head:
/// heart / nothing / storm cloud.
public enum MoodLevel: String, Sendable, Equatable, Codable, CaseIterable {
    case great, okay, low
}

/// Who lives here.
public struct HomeOccupants: Sendable, Equatable {
    public var founder: CharacterAppearance
    public var partner: CharacterAppearance?
    /// 0...3 rendered; extras are ignored.
    public var children: [CharacterAppearance]

    public init(founder: CharacterAppearance, partner: CharacterAppearance? = nil, children: [CharacterAppearance] = []) {
        self.founder = founder
        self.partner = partner
        self.children = children
    }
}
