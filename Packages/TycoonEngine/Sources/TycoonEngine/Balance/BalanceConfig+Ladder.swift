import Foundation

// Iteration 15 — K3 (the ladder). Two things a person on payroll can be
// given besides money (docs/product/iteration-15-pm/company.md §3, §4):
//
// - **A room to run.** A lead the founder *promoted* (`Employee.leadSinceDay`
//   is set) on a build softens Brooks's crowding penalty for up to `span`
//   of the others on it, by `penaltyFactor`. Two promoted leads on one
//   build cancel each other out. A promoted lead with fewer than
//   `idleMinCrew` others to lead has their morale *target* moved by
//   `idleMoraleDelta` — a drift, not a jump. Hired-in leads (skills ≥ 210
//   at hire) are never read: the campus fixture has three of them on
//   builds and the investor bots must not move.
// - **A piece of the company.** `grantEquity` gives 1% or 2% for a pay
//   cut of `payCut[0]` or `payCut[1]` of fair pay, `loyalty` and `bond`,
//   vesting over `vestDays` after a `cliffDays` cliff, with at most
//   `poolMax` percentage points out at once. A holder reads fair pay off
//   the salary before the cut, and a poacher weighs every unvested point
//   at `poachUnvestedWeight` against the target's score.
//
// Read only when the player promotes to lead or grants, so the defaults
// are the shipped numbers and nothing here moves a run that did neither.
// `"ladder"` is an optional key: a balance file without it reads these.

extension BalanceConfig {

    // MARK: - The ladder

    public struct LadderBalance: Codable, Equatable, Sendable {
        public var leads: LeadBalance
        public var grants: GrantBalance

        public init(leads: LeadBalance = .default, grants: GrantBalance = .default) {
            self.leads = leads
            self.grants = grants
        }

        /// The shipped numbers.
        public static let `default` = LadderBalance()

        private enum CodingKeys: String, CodingKey { case leads, grants }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                leads: try container.decodeIfPresent(LeadBalance.self, forKey: .leads) ?? .default,
                grants: try container.decodeIfPresent(GrantBalance.self, forKey: .grants) ?? .default
            )
        }
    }

    /// A promoted lead on a build.
    public struct LeadBalance: Codable, Equatable, Sendable {
        /// What a promoted lead does to Brooks's penalty for the people
        /// they lead: 0.5 halves it (0.1 → 0.05 per extra head).
        public var penaltyFactor: Double
        /// How many of the others one lead can carry; the rest pay full.
        public var span: Int
        /// Fewer others than this on their build and a lead has nothing
        /// to lead.
        public var idleMinCrew: Int
        /// Added to an idle promoted lead's morale target.
        public var idleMoraleDelta: Double

        public init(
            penaltyFactor: Double = 0.5,
            span: Int = 6,
            idleMinCrew: Int = 3,
            idleMoraleDelta: Double = -4
        ) {
            self.penaltyFactor = penaltyFactor
            self.span = span
            self.idleMinCrew = idleMinCrew
            self.idleMoraleDelta = idleMoraleDelta
        }

        public static let `default` = LeadBalance()

        private enum CodingKeys: String, CodingKey {
            case penaltyFactor, span, idleMinCrew, idleMoraleDelta
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                penaltyFactor: try container.decodeIfPresent(Double.self, forKey: .penaltyFactor)
                    ?? fallback.penaltyFactor,
                span: try container.decodeIfPresent(Int.self, forKey: .span) ?? fallback.span,
                idleMinCrew: try container.decodeIfPresent(Int.self, forKey: .idleMinCrew)
                    ?? fallback.idleMinCrew,
                idleMoraleDelta: try container.decodeIfPresent(Double.self, forKey: .idleMoraleDelta)
                    ?? fallback.idleMoraleDelta
            )
        }
    }

    /// Options instead of pay.
    public struct GrantBalance: Codable, Equatable, Sendable {
        /// The pay cut, as a fraction of fair pay, for a 1% and a 2% grant.
        public var payCut: [Double]
        /// Loyalty on the day of the grant.
        public var loyalty: Double
        /// Bond with the founder on the day of the grant.
        public var bond: Double
        /// Leaving before this many days returns every point.
        public var cliffDays: Int
        /// Fully vested after this many days; straight-line after the cliff.
        public var vestDays: Int
        /// The most option points out at once.
        public var poolMax: Double
        /// Taken off a rival's poach score per unvested point: the part of
        /// the company a poacher's offer would have to buy out.
        public var poachUnvestedWeight: Double

        public init(
            payCut: [Double] = [0.2, 0.35],
            loyalty: Double = 25,
            bond: Double = 10,
            cliffDays: Int = 364,
            vestDays: Int = 1_456,
            poolMax: Double = 10,
            poachUnvestedWeight: Double = 20
        ) {
            self.payCut = payCut
            self.loyalty = loyalty
            self.bond = bond
            self.cliffDays = cliffDays
            self.vestDays = vestDays
            self.poolMax = poolMax
            self.poachUnvestedWeight = poachUnvestedWeight
        }

        public static let `default` = GrantBalance()

        /// The two sizes on offer, in percentage points.
        public static let sizes = [1, 2]

        /// The pay cut for a grant of `percent` points, as a fraction of
        /// fair pay; 0 for a size that is not on offer.
        public func payCutFraction(percent: Int) -> Double {
            guard let index = Self.sizes.firstIndex(of: percent), index < payCut.count else { return 0 }
            return payCut[index]
        }

        private enum CodingKeys: String, CodingKey {
            case payCut, loyalty, bond, cliffDays, vestDays, poolMax, poachUnvestedWeight
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                payCut: try container.decodeIfPresent([Double].self, forKey: .payCut) ?? fallback.payCut,
                loyalty: try container.decodeIfPresent(Double.self, forKey: .loyalty) ?? fallback.loyalty,
                bond: try container.decodeIfPresent(Double.self, forKey: .bond) ?? fallback.bond,
                cliffDays: try container.decodeIfPresent(Int.self, forKey: .cliffDays) ?? fallback.cliffDays,
                vestDays: try container.decodeIfPresent(Int.self, forKey: .vestDays) ?? fallback.vestDays,
                poolMax: try container.decodeIfPresent(Double.self, forKey: .poolMax) ?? fallback.poolMax,
                poachUnvestedWeight: try container.decodeIfPresent(
                    Double.self, forKey: .poachUnvestedWeight
                ) ?? fallback.poachUnvestedWeight
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"ladder"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.LadderBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.LadderBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
