/// A random event in the founder's personal life.
///
/// Static content — game saves reference life events by their stable `id`.
public struct LifeEventDef: Codable, Equatable, Sendable, Identifiable {
    /// What the event does to the founder when it fires.
    ///
    /// JSON format (human-editable; every field is optional and defaults
    /// to 0 / `nil`, so only the non-zero deltas need listing):
    ///
    ///     { "mood": 8 }
    ///     { "energy": -10, "coldDays": 5 }
    ///     { "wallet": -300, "awayDays": 3, "awayReason": "Family emergency" }
    public struct Impact: Codable, Equatable, Sendable {
        /// Meter deltas, applied with the engine's 0...100 clamp.
        public var energy: Double
        public var health: Double
        public var mood: Double
        public var relationships: Double
        /// Personal-wallet delta in dollars.
        public var wallet: Int
        /// `> 0`: the founder catches a cold for this many days.
        public var coldDays: Int
        /// `> 0`: the founder is away (produces nothing) for this many days.
        public var awayDays: Int
        /// Why the founder is away, e.g. "Family emergency".
        public var awayReason: String?

        public init(
            energy: Double = 0,
            health: Double = 0,
            mood: Double = 0,
            relationships: Double = 0,
            wallet: Int = 0,
            coldDays: Int = 0,
            awayDays: Int = 0,
            awayReason: String? = nil
        ) {
            self.energy = energy
            self.health = health
            self.mood = mood
            self.relationships = relationships
            self.wallet = wallet
            self.coldDays = coldDays
            self.awayDays = awayDays
            self.awayReason = awayReason
        }

        private enum CodingKeys: String, CodingKey {
            case energy, health, mood, relationships, wallet, coldDays, awayDays, awayReason
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                energy: try container.decodeIfPresent(Double.self, forKey: .energy) ?? 0,
                health: try container.decodeIfPresent(Double.self, forKey: .health) ?? 0,
                mood: try container.decodeIfPresent(Double.self, forKey: .mood) ?? 0,
                relationships: try container.decodeIfPresent(Double.self, forKey: .relationships) ?? 0,
                wallet: try container.decodeIfPresent(Int.self, forKey: .wallet) ?? 0,
                coldDays: try container.decodeIfPresent(Int.self, forKey: .coldDays) ?? 0,
                awayDays: try container.decodeIfPresent(Int.self, forKey: .awayDays) ?? 0,
                awayReason: try container.decodeIfPresent(String.self, forKey: .awayReason)
            )
        }

        /// The founder-meter effect this impact is shorthand for. The cold
        /// and away windows are separate effects, so the narrative system
        /// reads those off the impact directly.
        public var asEffect: EventEffect {
            .founderMeters(
                energy: energy, health: health, mood: mood,
                relationships: relationships, wallet: wallet
            )
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(energy, forKey: .energy)
            try container.encode(health, forKey: .health)
            try container.encode(mood, forKey: .mood)
            try container.encode(relationships, forKey: .relationships)
            try container.encode(wallet, forKey: .wallet)
            try container.encode(coldDays, forKey: .coldDays)
            try container.encode(awayDays, forKey: .awayDays)
            try container.encodeIfPresent(awayReason, forKey: .awayReason)
        }
    }

    /// Stable string id, e.g. "caught_cold".
    public var id: String
    /// Newsfeed headline, e.g. "Your partner got a promotion — dinner's on them!".
    public var headline: String
    /// Relative pick probability, >= 1.
    public var weight: Int
    /// Minimum relationship stage raw value ("single" / "dating" / "partner"
    /// / "married") the founder must have reached; `nil` = any.
    public var minStage: String?
    /// Fires only once the founder has at least one child. Default `false`.
    public var requiresChildren: Bool
    /// Fires only while the relationships meter is strictly below this.
    public var maxRelationships: Double?
    /// What happens when the event fires.
    public var impact: Impact
    /// The paragraph shown in the decision sheet. Choice-less events don't
    /// need one.
    public var body: String?
    /// Effects beyond `impact`, applied after it — the same vocabulary
    /// company events use, so a life beat can also move team morale or
    /// raise a story flag.
    public var effects: [EventEffect]
    /// The full v2 gate, evaluated on top of `minStage` /
    /// `requiresChildren` / `maxRelationships` (which stay for the
    /// catalogs written before it existed).
    public var requires: EventRequirements?
    /// The answers offered. Empty means the event just happens.
    public var choices: [EventChoice]
    /// Days before this event can be drawn again. 0 = no cooldown.
    public var cooldownDays: Int
    /// Fires at most once per run.
    public var once: Bool
    /// Icon/tint/journal bucket.
    public var category: EventCategory
    /// How long the player has to answer a choice. Default 5 days.
    public var respondByDays: Int
    /// Which option the deadline picks. Defaults to the last one.
    public var autoChoiceIndex: Int?
    /// Follow-up halves of a storyline are never drawn directly.
    public var followUpOnly: Bool

    public init(
        id: String,
        headline: String,
        weight: Int,
        minStage: String? = nil,
        requiresChildren: Bool = false,
        maxRelationships: Double? = nil,
        impact: Impact,
        body: String? = nil,
        effects: [EventEffect] = [],
        requires: EventRequirements? = nil,
        choices: [EventChoice] = [],
        cooldownDays: Int = 0,
        once: Bool = false,
        category: EventCategory = .personal,
        respondByDays: Int = 5,
        autoChoiceIndex: Int? = nil,
        followUpOnly: Bool = false
    ) {
        self.id = id
        self.headline = headline
        self.weight = weight
        self.minStage = minStage
        self.requiresChildren = requiresChildren
        self.maxRelationships = maxRelationships
        self.impact = impact
        self.body = body
        self.effects = effects
        self.requires = requires
        self.choices = choices
        self.cooldownDays = cooldownDays
        self.once = once
        self.category = category
        self.respondByDays = respondByDays
        self.autoChoiceIndex = autoChoiceIndex
        self.followUpOnly = followUpOnly
    }

    /// Every effect the event applies on its own: the founder-meter impact
    /// first, then `effects`.
    public var unconditionalEffects: [EventEffect] {
        [impact.asEffect] + effects
    }

    private enum CodingKeys: String, CodingKey {
        case id, headline, weight, minStage, requiresChildren, maxRelationships, impact
        case body, effects, requires, choices, cooldownDays, once, category
        case respondByDays, autoChoiceIndex, followUpOnly
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            headline: try container.decode(String.self, forKey: .headline),
            weight: try container.decode(Int.self, forKey: .weight),
            minStage: try container.decodeIfPresent(String.self, forKey: .minStage),
            requiresChildren: try container.decodeIfPresent(Bool.self, forKey: .requiresChildren) ?? false,
            maxRelationships: try container.decodeIfPresent(Double.self, forKey: .maxRelationships),
            impact: try container.decode(Impact.self, forKey: .impact),
            body: try container.decodeIfPresent(String.self, forKey: .body),
            effects: try container.decodeIfPresent([EventEffect].self, forKey: .effects) ?? [],
            requires: try container.decodeIfPresent(EventRequirements.self, forKey: .requires),
            choices: try container.decodeIfPresent([EventChoice].self, forKey: .choices) ?? [],
            cooldownDays: try container.decodeIfPresent(Int.self, forKey: .cooldownDays) ?? 0,
            once: try container.decodeIfPresent(Bool.self, forKey: .once) ?? false,
            category: try container.decodeIfPresent(EventCategory.self, forKey: .category) ?? .personal,
            respondByDays: try container.decodeIfPresent(Int.self, forKey: .respondByDays) ?? 5,
            autoChoiceIndex: try container.decodeIfPresent(Int.self, forKey: .autoChoiceIndex),
            followUpOnly: try container.decodeIfPresent(Bool.self, forKey: .followUpOnly) ?? false
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(headline, forKey: .headline)
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(minStage, forKey: .minStage)
        try container.encode(requiresChildren, forKey: .requiresChildren)
        try container.encodeIfPresent(maxRelationships, forKey: .maxRelationships)
        try container.encode(impact, forKey: .impact)
        try container.encodeIfPresent(body, forKey: .body)
        if !effects.isEmpty { try container.encode(effects, forKey: .effects) }
        try container.encodeIfPresent(requires, forKey: .requires)
        if !choices.isEmpty { try container.encode(choices, forKey: .choices) }
        if cooldownDays != 0 { try container.encode(cooldownDays, forKey: .cooldownDays) }
        if once { try container.encode(once, forKey: .once) }
        try container.encode(category, forKey: .category)
        try container.encode(respondByDays, forKey: .respondByDays)
        try container.encodeIfPresent(autoChoiceIndex, forKey: .autoChoiceIndex)
        if followUpOnly { try container.encode(followUpOnly, forKey: .followUpOnly) }
    }
}
