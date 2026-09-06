import Foundation

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
    /// A crunch week: asleep on the couch with the laptop still open, the
    /// takeaway cartons where dinner should be.
    case crunching
    /// Away, and it shows: the partner eats alone at the table with the
    /// second place setting untouched.
    case awayPartnerAlone

    /// Whether the founder themself is in the room. The two `away` variants
    /// draw the household without them.
    public var isFounderHome: Bool { self != .away && self != .awayPartnerAlone }
}

/// The founder's mood, shown as a bubble above their head:
/// heart / nothing / storm cloud.
public enum MoodLevel: String, Sendable, Equatable, Codable, CaseIterable {
    case great, okay, low
}

// MARK: Iteration 9 — L3 (children who grow up)

/// How old a child in the home scene is. Mirrors the engine's
/// `ChildStage` by raw value, the way `HomeTierStyle` mirrors `HomeTier` —
/// PixelKit never imports the engine.
public enum ChildStageStyle: String, Sendable, Equatable, Codable, CaseIterable {
    case baby, toddler, school, teen, grown

    /// Where on the ladder, for "teen or older" rules.
    public var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// A teenager and a grown child stand at adult height; the younger
    /// three have their own smaller bodies.
    public var isAdultSized: Bool { self == .grown }
}

/// Who lives here.
///
/// The appearances are what the scene draws. The names and the one note
/// are what VoiceOver says: the picture and the spoken room are the same
/// household, so they are one type. Everything but the founder's
/// appearance has a default, and the original initializer still takes
/// bare appearances — a caller that only wants the picture is unchanged.
public struct HomeOccupants: Sendable, Equatable {
    /// One of the children: their look, the id the app knows them by, and
    /// their name. The id is what a `HomeHitRegion.child` carries back.
    public struct Child: Sendable, Equatable, Identifiable {
        public var id: UUID
        public var appearance: CharacterAppearance
        public var name: String?
        /// Iteration 9 — L3: how old they are, which is how big they are
        /// drawn. Defaults to `.school`, the size the scene drew before
        /// children had ages, so a caller that does not know about stages
        /// gets exactly the picture it used to.
        public var stage: ChildStageStyle

        public init(
            id: UUID,
            appearance: CharacterAppearance,
            name: String? = nil,
            stage: ChildStageStyle = .school
        ) {
            self.id = id
            self.appearance = appearance
            self.name = name
            self.stage = stage
        }
    }

    public var founder: CharacterAppearance
    /// The founder's own name, for the label over their figure.
    public var founderName: String?
    public var partner: CharacterAppearance?
    public var partnerName: String?
    /// One short thing worth knowing about the partner — "affection
    /// sliding". Spoken, never drawn.
    public var partnerNote: String?
    /// 0...3 rendered; extras are ignored.
    public var childList: [Child]

    /// Whether a cat lives here. Cats arrive with the house.
    public var hasCat: Bool

    /// The children as bare appearances, which is all the composer needs.
    /// Setting it rebuilds the list with derived ids, so the picture-only
    /// callers keep working and still get stable region identities.
    public var children: [CharacterAppearance] {
        get { childList.map(\.appearance) }
        set {
            childList = newValue.enumerated().map {
                Child(id: Self.derivedChildID(index: $0.offset), appearance: $0.element)
            }
        }
    }

    /// The picture-only initializer: appearances, nothing spoken.
    public init(
        founder: CharacterAppearance,
        partner: CharacterAppearance? = nil,
        children: [CharacterAppearance] = [],
        hasCat: Bool = false
    ) {
        self.founder = founder
        self.founderName = nil
        self.partner = partner
        self.partnerName = nil
        self.partnerNote = nil
        self.childList = children.enumerated().map {
            Child(id: Self.derivedChildID(index: $0.offset), appearance: $0.element)
        }
        self.hasCat = hasCat
    }

    /// The full initializer: the household with its names, for a scene
    /// that is going to be read out as well as looked at.
    public init(
        founder: CharacterAppearance,
        founderName: String?,
        partner: CharacterAppearance? = nil,
        partnerName: String? = nil,
        partnerNote: String? = nil,
        children: [Child] = [],
        hasCat: Bool = false
    ) {
        self.founder = founder
        self.founderName = founderName
        self.partner = partner
        self.partnerName = partnerName
        self.partnerNote = partnerNote
        self.childList = children
        self.hasCat = hasCat
    }

    /// A stable id for a child the caller did not name one for: the same
    /// index always produces the same UUID, so a region's identity never
    /// changes under VoiceOver between two renders of the same room.
    public static func derivedChildID(index: Int) -> UUID {
        let n = UInt8(truncatingIfNeeded: index)
        // "H" for home, then the index: recognisable in a log, and stable.
        return UUID(uuid: (0x48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, n))
    }
}

/// What the founder's life is under, read by the home the way the office
/// reads the company. One thing in the room per meter, so the picture and
/// the numbers under it never disagree.
public struct HomeSignals: Sendable, Equatable, Hashable {
    /// Relationships are low: the partner keeps to their end of the couch
    /// under a low bubble, and there is no heart at dinner.
    public var relationshipsLow: Bool
    /// Health is low: takeaway boxes by the couch.
    public var healthLow: Bool
    /// The wallet will not cover the next rent: unpaid bills on the table.
    public var billsDue: Bool

    public init(relationshipsLow: Bool = false, healthLow: Bool = false, billsDue: Bool = false) {
        self.relationshipsLow = relationshipsLow
        self.healthLow = healthLow
        self.billsDue = billsDue
    }

    public static let none = HomeSignals()
}
