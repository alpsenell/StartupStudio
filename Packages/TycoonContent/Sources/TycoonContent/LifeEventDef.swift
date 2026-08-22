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

    public init(
        id: String,
        headline: String,
        weight: Int,
        minStage: String? = nil,
        requiresChildren: Bool = false,
        maxRelationships: Double? = nil,
        impact: Impact
    ) {
        self.id = id
        self.headline = headline
        self.weight = weight
        self.minStage = minStage
        self.requiresChildren = requiresChildren
        self.maxRelationships = maxRelationships
        self.impact = impact
    }

    private enum CodingKeys: String, CodingKey {
        case id, headline, weight, minStage, requiresChildren, maxRelationships, impact
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
            impact: try container.decode(Impact.self, forKey: .impact)
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
    }
}
