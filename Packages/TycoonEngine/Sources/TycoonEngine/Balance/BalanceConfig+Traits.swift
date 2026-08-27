/// The `"traits"` block of `Balance.json` — the dials behind the trait
/// effects that reach the whole team.
///
/// The per-trait numbers live in `Traits.json` (content); the per-employee
/// clamps live as constants on `TraitEffects`, whose hook signatures are
/// fixed by the scaffold and take no balance. What is left here is
/// everything `TraitSystem` applies across the roster — the mentor's
/// teaching, the jokester's and grumbler's mood, the showman's press — plus
/// the founder's cost for interviewing a candidate.
///
/// Every field decodes with a default, so a balance file that predates the
/// block still loads. WS-F owns this file and the `"traits"` object.
extension BalanceConfig {
    public struct TraitBalance: Codable, Equatable, Sendable {
        /// Multiplies every trait's `teamGrowthBonus` before it is applied.
        public var teamGrowthStrength: Double
        /// Cap on the combined team skill-growth bonus, however many
        /// mentors are on payroll.
        public var teamGrowthLimit: Double
        /// Cap on the combined daily team morale nudge, either way.
        public var teamMoraleLimit: Double
        /// Cap on the combined daily reputation trickle from the roster.
        public var reputationBonusCap: Double
        /// Reputation above which the trickle stops — showmen get you
        /// noticed, they don't make you a household name.
        public var reputationBonusCeiling: Double
        /// Founder energy spent interviewing one candidate.
        public var interviewEnergyCost: Double

        public init(
            teamGrowthStrength: Double = 1,
            teamGrowthLimit: Double = 1.2,
            teamMoraleLimit: Double = 1.2,
            reputationBonusCap: Double = 0.06,
            reputationBonusCeiling: Double = 70,
            interviewEnergyCost: Double = 6
        ) {
            self.teamGrowthStrength = teamGrowthStrength
            self.teamGrowthLimit = teamGrowthLimit
            self.teamMoraleLimit = teamMoraleLimit
            self.reputationBonusCap = reputationBonusCap
            self.reputationBonusCeiling = reputationBonusCeiling
            self.interviewEnergyCost = interviewEnergyCost
        }

        public static let `default` = TraitBalance()
    }
}

// MARK: - Codable

// Hand-written so a `"traits"` object that lists only some of the dials
// still decodes: every key reads with `decodeIfPresent`.

extension BalanceConfig.TraitBalance {
    private enum CodingKeys: String, CodingKey {
        case teamGrowthStrength, teamGrowthLimit, teamMoraleLimit
        case reputationBonusCap, reputationBonusCeiling, interviewEnergyCost
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BalanceConfig.TraitBalance.default
        self.init(
            teamGrowthStrength: try container.decodeIfPresent(Double.self, forKey: .teamGrowthStrength)
                ?? fallback.teamGrowthStrength,
            teamGrowthLimit: try container.decodeIfPresent(Double.self, forKey: .teamGrowthLimit)
                ?? fallback.teamGrowthLimit,
            teamMoraleLimit: try container.decodeIfPresent(Double.self, forKey: .teamMoraleLimit)
                ?? fallback.teamMoraleLimit,
            reputationBonusCap: try container.decodeIfPresent(Double.self, forKey: .reputationBonusCap)
                ?? fallback.reputationBonusCap,
            reputationBonusCeiling: try container.decodeIfPresent(
                Double.self, forKey: .reputationBonusCeiling
            ) ?? fallback.reputationBonusCeiling,
            interviewEnergyCost: try container.decodeIfPresent(Double.self, forKey: .interviewEnergyCost)
                ?? fallback.interviewEnergyCost
        )
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"traits"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.TraitBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.TraitBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
