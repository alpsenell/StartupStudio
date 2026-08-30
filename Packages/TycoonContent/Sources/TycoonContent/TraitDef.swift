/// One employee personality trait, loaded from `Traits.json`.
///
/// Traits are the difference between a stat block and a person: they shift
/// how much someone produces, how fast they learn, how happy they are, how
/// long they hold on through a bad patch, and how hard a rival finds it to
/// hire them away. Every employee carries exactly two, derived from their
/// `appearanceSeed`, so the same face always has the same personality.
public struct TraitDef: Codable, Equatable, Sendable, Identifiable {
    /// What a trait does. Every field is optional in JSON and neutral by
    /// default, so a trait that only moves one number lists only that one.
    public struct Effects: Codable, Equatable, Sendable {
        /// Multiplies this person's daily product and contract output.
        public var outputMult: Double
        /// Multiplies how fast their own skills grow.
        public var skillGrowthMult: Double
        /// Shifts the morale they settle at.
        public var moraleTargetDelta: Double
        /// Extra (or fewer) days of misery they tolerate before resigning.
        public var quitStreakBonus: Int
        /// Multiplies their resistance to a rival's poach; above 1 makes
        /// them harder to hire away, below 1 easier.
        public var poachResist: Double
        /// How much faster *everyone else* learns while this person is on
        /// the team (the mentor's whole point).
        public var teamGrowthBonus: Double
        /// Daily morale nudge applied to every teammate — the jokester
        /// lifts the room, the grumbler drains it.
        public var teamMoraleBonus: Double
        /// Daily company reputation nudge while this person is on payroll
        /// (the showman, who is always on a podcast).
        public var dailyReputationBonus: Double
        /// Multiplies the hype this person's marketing generates — their own
        /// daily hype on a product, and their share of a campaign's push.
        public var hypeMult: Double
        /// Multiplies the chance a code point they wrote carries a bug.
        /// Below 1 is a careful pair of hands, above 1 a fast and loose one.
        public var bugMult: Double
        /// Multiplies how hard a crunch week lands on *this* person's
        /// morale. Above 1 takes it badly, below 1 barely notices.
        public var crunchMoraleMult: Double

        public init(
            outputMult: Double = 1,
            skillGrowthMult: Double = 1,
            moraleTargetDelta: Double = 0,
            quitStreakBonus: Int = 0,
            poachResist: Double = 1,
            teamGrowthBonus: Double = 0,
            teamMoraleBonus: Double = 0,
            dailyReputationBonus: Double = 0,
            hypeMult: Double = 1,
            bugMult: Double = 1,
            crunchMoraleMult: Double = 1
        ) {
            self.outputMult = outputMult
            self.skillGrowthMult = skillGrowthMult
            self.moraleTargetDelta = moraleTargetDelta
            self.quitStreakBonus = quitStreakBonus
            self.poachResist = poachResist
            self.teamGrowthBonus = teamGrowthBonus
            self.teamMoraleBonus = teamMoraleBonus
            self.dailyReputationBonus = dailyReputationBonus
            self.hypeMult = hypeMult
            self.bugMult = bugMult
            self.crunchMoraleMult = crunchMoraleMult
        }

        /// A trait that changes nothing — what an unknown trait id reads as.
        public static let neutral = Effects()
    }

    /// Stable id referenced by `Employee.traits`.
    public var id: String
    public var name: String
    /// Short description shown on trait chips.
    public var blurb: String?
    /// A first-person line for the candidate card, so a new hire arrives
    /// with a voice. WS-B's dialogue catalog takes precedence when it has
    /// something to say.
    public var bio: String?
    /// Whether the trait is, on the whole, something the player wants —
    /// drives the chip's tint.
    public var isPositive: Bool
    public var effects: Effects

    public init(
        id: String,
        name: String,
        blurb: String? = nil,
        bio: String? = nil,
        isPositive: Bool = true,
        effects: Effects = .neutral
    ) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.bio = bio
        self.isPositive = isPositive
        self.effects = effects
    }
}

// MARK: - Codable

// Hand-written so a `Traits.json` that lists only some fields still
// decodes: the optional prose reads as nil, `isPositive` as true, and an
// omitted `effects` block as neutral.

extension TraitDef {
    private enum CodingKeys: String, CodingKey {
        case id, name, blurb, bio, isPositive, effects
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            blurb: try container.decodeIfPresent(String.self, forKey: .blurb),
            bio: try container.decodeIfPresent(String.self, forKey: .bio),
            isPositive: try container.decodeIfPresent(Bool.self, forKey: .isPositive) ?? true,
            effects: try container.decodeIfPresent(Effects.self, forKey: .effects) ?? .neutral
        )
    }
}

extension TraitDef.Effects {
    private enum CodingKeys: String, CodingKey {
        case outputMult, skillGrowthMult, moraleTargetDelta, quitStreakBonus
        case poachResist, teamGrowthBonus, teamMoraleBonus, dailyReputationBonus
        case hypeMult, bugMult, crunchMoraleMult
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            outputMult: try container.decodeIfPresent(Double.self, forKey: .outputMult) ?? 1,
            skillGrowthMult: try container.decodeIfPresent(Double.self, forKey: .skillGrowthMult) ?? 1,
            moraleTargetDelta: try container.decodeIfPresent(Double.self, forKey: .moraleTargetDelta) ?? 0,
            quitStreakBonus: try container.decodeIfPresent(Int.self, forKey: .quitStreakBonus) ?? 0,
            poachResist: try container.decodeIfPresent(Double.self, forKey: .poachResist) ?? 1,
            teamGrowthBonus: try container.decodeIfPresent(Double.self, forKey: .teamGrowthBonus) ?? 0,
            teamMoraleBonus: try container.decodeIfPresent(Double.self, forKey: .teamMoraleBonus) ?? 0,
            dailyReputationBonus: try container.decodeIfPresent(
                Double.self, forKey: .dailyReputationBonus
            ) ?? 0,
            hypeMult: try container.decodeIfPresent(Double.self, forKey: .hypeMult) ?? 1,
            bugMult: try container.decodeIfPresent(Double.self, forKey: .bugMult) ?? 1,
            crunchMoraleMult: try container.decodeIfPresent(
                Double.self, forKey: .crunchMoraleMult
            ) ?? 1
        )
    }
}
