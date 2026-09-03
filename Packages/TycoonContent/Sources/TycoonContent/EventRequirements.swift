/// The gate an event has to clear before it can be drawn.
///
/// Pure data: `TycoonContent` knows nothing about `GameState`, so the
/// engine's narrative system evaluates every field. Absent fields are
/// `nil` / `false` and mean "don't care", so a def that omits the whole
/// `requires` object is eligible from day one — which is why the ten
/// launch events still decode and behave exactly as they did.
///
/// JSON:
///
///     "requires": {
///       "minTier": "studio", "minHeadcount": 6, "minYear": 2,
///       "hasLiveProduct": true, "flagsAll": ["journalist_met"],
///       "flagsNone": ["sued_by_cofounder"]
///     }
public struct EventRequirements: Codable, Equatable, Sendable {
    // MARK: Company

    /// Office tier raw value the studio must have reached ("garage",
    /// "loft", "studio", "campus").
    public var minTier: String?
    /// Office tier raw value the studio must not have passed.
    public var maxTier: String?
    public var minHeadcount: Int?
    public var maxHeadcount: Int?
    public var minReputation: Double?
    public var maxReputation: Double?
    public var minCash: Int?
    public var maxCash: Int?
    /// 1-based game year.
    public var minYear: Int?
    public var maxYear: Int?
    /// Requires (or forbids) a product in development.
    public var hasProductInDev: Bool?
    /// Requires (or forbids) at least one product on the market.
    public var hasLiveProduct: Bool?
    /// Requires at least one product — live or in development — on this
    /// topic.
    public var topicID: String?
    /// Requires an outstanding company loan.
    public var hasLoan: Bool?
    /// Requires at least this many employees with the given department
    /// role raw value ("lawyer", "hr", "ops").
    public var requiresDepartment: String?
    /// Requires at least one bond between two employees.
    public var hasFriendship: Bool?

    // MARK: Founder life

    /// Minimum relationship stage raw value ("single", "dating",
    /// "partner", "married").
    public var minStage: String?
    /// Maximum relationship stage raw value.
    public var maxStage: String?
    public var requiresChildren: Bool?
    public var minChildren: Int?
    /// Home tier raw value the founder must have reached.
    public var minHome: String?
    public var minWallet: Int?
    public var maxWallet: Int?
    public var maxRelationships: Double?
    public var minRelationships: Double?
    public var maxEnergy: Double?
    public var maxMood: Double?
    /// Work schedule raw value the founder must be on ("crunch" etc.).
    public var schedule: String?
    /// Evenings the founder must still have this week (WS-E). On an
    /// *option* this gate greys rather than hides: the sheet shows the
    /// option with "No evenings left this week" under it, which is the
    /// point — on crunch that is one evening, and it may already be
    /// spent. Always met by a balance with no evening budget.
    public var minEveningsLeft: Int?

    // MARK: Story

    /// Every one of these narrative flags must be raised.
    public var flagsAll: [String]
    /// None of these narrative flags may be raised.
    public var flagsNone: [String]

    public init(
        minTier: String? = nil,
        maxTier: String? = nil,
        minHeadcount: Int? = nil,
        maxHeadcount: Int? = nil,
        minReputation: Double? = nil,
        maxReputation: Double? = nil,
        minCash: Int? = nil,
        maxCash: Int? = nil,
        minYear: Int? = nil,
        maxYear: Int? = nil,
        hasProductInDev: Bool? = nil,
        hasLiveProduct: Bool? = nil,
        topicID: String? = nil,
        hasLoan: Bool? = nil,
        requiresDepartment: String? = nil,
        hasFriendship: Bool? = nil,
        minStage: String? = nil,
        maxStage: String? = nil,
        requiresChildren: Bool? = nil,
        minChildren: Int? = nil,
        minHome: String? = nil,
        minWallet: Int? = nil,
        maxWallet: Int? = nil,
        maxRelationships: Double? = nil,
        minRelationships: Double? = nil,
        maxEnergy: Double? = nil,
        maxMood: Double? = nil,
        schedule: String? = nil,
        minEveningsLeft: Int? = nil,
        flagsAll: [String] = [],
        flagsNone: [String] = []
    ) {
        self.minTier = minTier
        self.maxTier = maxTier
        self.minHeadcount = minHeadcount
        self.maxHeadcount = maxHeadcount
        self.minReputation = minReputation
        self.maxReputation = maxReputation
        self.minCash = minCash
        self.maxCash = maxCash
        self.minYear = minYear
        self.maxYear = maxYear
        self.hasProductInDev = hasProductInDev
        self.hasLiveProduct = hasLiveProduct
        self.topicID = topicID
        self.hasLoan = hasLoan
        self.requiresDepartment = requiresDepartment
        self.hasFriendship = hasFriendship
        self.minStage = minStage
        self.maxStage = maxStage
        self.requiresChildren = requiresChildren
        self.minChildren = minChildren
        self.minHome = minHome
        self.minWallet = minWallet
        self.maxWallet = maxWallet
        self.maxRelationships = maxRelationships
        self.minRelationships = minRelationships
        self.maxEnergy = maxEnergy
        self.maxMood = maxMood
        self.schedule = schedule
        self.minEveningsLeft = minEveningsLeft
        self.flagsAll = flagsAll
        self.flagsNone = flagsNone
    }

    private enum CodingKeys: String, CodingKey {
        case minTier, maxTier, minHeadcount, maxHeadcount, minReputation, maxReputation
        case minCash, maxCash, minYear, maxYear, hasProductInDev, hasLiveProduct
        case topicID, hasLoan, requiresDepartment, hasFriendship
        case minStage, maxStage, requiresChildren, minChildren, minHome
        case minWallet, maxWallet, maxRelationships, minRelationships
        case maxEnergy, maxMood, schedule, minEveningsLeft, flagsAll, flagsNone
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            minTier: try container.decodeIfPresent(String.self, forKey: .minTier),
            maxTier: try container.decodeIfPresent(String.self, forKey: .maxTier),
            minHeadcount: try container.decodeIfPresent(Int.self, forKey: .minHeadcount),
            maxHeadcount: try container.decodeIfPresent(Int.self, forKey: .maxHeadcount),
            minReputation: try container.decodeIfPresent(Double.self, forKey: .minReputation),
            maxReputation: try container.decodeIfPresent(Double.self, forKey: .maxReputation),
            minCash: try container.decodeIfPresent(Int.self, forKey: .minCash),
            maxCash: try container.decodeIfPresent(Int.self, forKey: .maxCash),
            minYear: try container.decodeIfPresent(Int.self, forKey: .minYear),
            maxYear: try container.decodeIfPresent(Int.self, forKey: .maxYear),
            hasProductInDev: try container.decodeIfPresent(Bool.self, forKey: .hasProductInDev),
            hasLiveProduct: try container.decodeIfPresent(Bool.self, forKey: .hasLiveProduct),
            topicID: try container.decodeIfPresent(String.self, forKey: .topicID),
            hasLoan: try container.decodeIfPresent(Bool.self, forKey: .hasLoan),
            requiresDepartment: try container.decodeIfPresent(String.self, forKey: .requiresDepartment),
            hasFriendship: try container.decodeIfPresent(Bool.self, forKey: .hasFriendship),
            minStage: try container.decodeIfPresent(String.self, forKey: .minStage),
            maxStage: try container.decodeIfPresent(String.self, forKey: .maxStage),
            requiresChildren: try container.decodeIfPresent(Bool.self, forKey: .requiresChildren),
            minChildren: try container.decodeIfPresent(Int.self, forKey: .minChildren),
            minHome: try container.decodeIfPresent(String.self, forKey: .minHome),
            minWallet: try container.decodeIfPresent(Int.self, forKey: .minWallet),
            maxWallet: try container.decodeIfPresent(Int.self, forKey: .maxWallet),
            maxRelationships: try container.decodeIfPresent(Double.self, forKey: .maxRelationships),
            minRelationships: try container.decodeIfPresent(Double.self, forKey: .minRelationships),
            maxEnergy: try container.decodeIfPresent(Double.self, forKey: .maxEnergy),
            maxMood: try container.decodeIfPresent(Double.self, forKey: .maxMood),
            schedule: try container.decodeIfPresent(String.self, forKey: .schedule),
            minEveningsLeft: try container.decodeIfPresent(Int.self, forKey: .minEveningsLeft),
            flagsAll: try container.decodeIfPresent([String].self, forKey: .flagsAll) ?? [],
            flagsNone: try container.decodeIfPresent([String].self, forKey: .flagsNone) ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(minTier, forKey: .minTier)
        try container.encodeIfPresent(maxTier, forKey: .maxTier)
        try container.encodeIfPresent(minHeadcount, forKey: .minHeadcount)
        try container.encodeIfPresent(maxHeadcount, forKey: .maxHeadcount)
        try container.encodeIfPresent(minReputation, forKey: .minReputation)
        try container.encodeIfPresent(maxReputation, forKey: .maxReputation)
        try container.encodeIfPresent(minCash, forKey: .minCash)
        try container.encodeIfPresent(maxCash, forKey: .maxCash)
        try container.encodeIfPresent(minYear, forKey: .minYear)
        try container.encodeIfPresent(maxYear, forKey: .maxYear)
        try container.encodeIfPresent(hasProductInDev, forKey: .hasProductInDev)
        try container.encodeIfPresent(hasLiveProduct, forKey: .hasLiveProduct)
        try container.encodeIfPresent(topicID, forKey: .topicID)
        try container.encodeIfPresent(hasLoan, forKey: .hasLoan)
        try container.encodeIfPresent(requiresDepartment, forKey: .requiresDepartment)
        try container.encodeIfPresent(hasFriendship, forKey: .hasFriendship)
        try container.encodeIfPresent(minStage, forKey: .minStage)
        try container.encodeIfPresent(maxStage, forKey: .maxStage)
        try container.encodeIfPresent(requiresChildren, forKey: .requiresChildren)
        try container.encodeIfPresent(minChildren, forKey: .minChildren)
        try container.encodeIfPresent(minHome, forKey: .minHome)
        try container.encodeIfPresent(minWallet, forKey: .minWallet)
        try container.encodeIfPresent(maxWallet, forKey: .maxWallet)
        try container.encodeIfPresent(maxRelationships, forKey: .maxRelationships)
        try container.encodeIfPresent(minRelationships, forKey: .minRelationships)
        try container.encodeIfPresent(maxEnergy, forKey: .maxEnergy)
        try container.encodeIfPresent(maxMood, forKey: .maxMood)
        try container.encodeIfPresent(schedule, forKey: .schedule)
        try container.encodeIfPresent(minEveningsLeft, forKey: .minEveningsLeft)
        if !flagsAll.isEmpty { try container.encode(flagsAll, forKey: .flagsAll) }
        if !flagsNone.isEmpty { try container.encode(flagsNone, forKey: .flagsNone) }
    }
}

/// What kind of moment an event is — drives the icon, tint and journal
/// filter the app picks, and lets the catalog tests check the spread.
public enum EventCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case press, legal, tech, team, market, money, personal, investor, office, family
}

/// One answer to a narrative event.
///
/// JSON:
///
///     { "id": "lawyer", "label": "Call a lawyer",
///       "detail": "Costs $4,000 · they go quiet",
///       "effects": [{ "type": "cash", "amount": -4000 }],
///       "setFlags": ["cofounder_lawyered"],
///       "followUpEventID": "ex_cofounder_verdict", "followUpDelayDays": 21 }
public struct EventChoice: Codable, Equatable, Sendable, Identifiable {
    /// Stable id, unique within its event.
    public var id: String
    /// The button label, e.g. "Call a lawyer".
    public var label: String
    /// One-line consequence under the label. When absent, the app builds
    /// one from the effects' summaries.
    public var detail: String?
    /// What taking this option does.
    public var effects: [EventEffect]
    /// Narrative flags raised by taking it.
    public var setFlags: [String]
    /// Narrative flags cleared by taking it.
    public var clearFlags: [String]
    /// The event scheduled by taking it, if any.
    public var followUpEventID: String?
    /// How many days later the follow-up fires (default 7).
    public var followUpDelayDays: Int
    /// Hides the option unless the state clears this gate.
    public var requires: EventRequirements?

    public init(
        id: String,
        label: String,
        detail: String? = nil,
        effects: [EventEffect] = [],
        setFlags: [String] = [],
        clearFlags: [String] = [],
        followUpEventID: String? = nil,
        followUpDelayDays: Int = 7,
        requires: EventRequirements? = nil
    ) {
        self.id = id
        self.label = label
        self.detail = detail
        self.effects = effects
        self.setFlags = setFlags
        self.clearFlags = clearFlags
        self.followUpEventID = followUpEventID
        self.followUpDelayDays = followUpDelayDays
        self.requires = requires
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, detail, effects, setFlags, clearFlags
        case followUpEventID, followUpDelayDays, requires
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            label: try container.decode(String.self, forKey: .label),
            detail: try container.decodeIfPresent(String.self, forKey: .detail),
            effects: try container.decodeIfPresent([EventEffect].self, forKey: .effects) ?? [],
            setFlags: try container.decodeIfPresent([String].self, forKey: .setFlags) ?? [],
            clearFlags: try container.decodeIfPresent([String].self, forKey: .clearFlags) ?? [],
            followUpEventID: try container.decodeIfPresent(String.self, forKey: .followUpEventID),
            followUpDelayDays: try container.decodeIfPresent(Int.self, forKey: .followUpDelayDays) ?? 7,
            requires: try container.decodeIfPresent(EventRequirements.self, forKey: .requires)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(detail, forKey: .detail)
        if !effects.isEmpty { try container.encode(effects, forKey: .effects) }
        if !setFlags.isEmpty { try container.encode(setFlags, forKey: .setFlags) }
        if !clearFlags.isEmpty { try container.encode(clearFlags, forKey: .clearFlags) }
        try container.encodeIfPresent(followUpEventID, forKey: .followUpEventID)
        try container.encode(followUpDelayDays, forKey: .followUpDelayDays)
        try container.encodeIfPresent(requires, forKey: .requires)
    }
}
