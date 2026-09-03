import Foundation

extension BalanceConfig {
    /// The founding origins' day-0 deltas (WS-H, iteration 5). `.garage`
    /// applies none of them; every harness `newGame` call is a garage.
    ///
    /// Every number here is a *delta applied once*, on day 0, never a
    /// multiplier read by a system — which is what keeps the pacing gates
    /// pinned: a garage run never touches this block, and a non-garage run
    /// is a different starting state playing the same rules.
    ///
    /// Every field has a default (the shipped value), so an older
    /// `Balance.json` without the block, or with `"origins": {}`, still
    /// decodes to exactly the origins the game shipped with.
    public struct OriginBalance: Codable, Equatable, Sendable {
        // MARK: Co-founded

        /// The second person's skills on day 0. Flat and middling: a pair
        /// of hands, not a prodigy. ~120 total puts them at `.mid`.
        public var cofounderCoding: Double
        public var cofounderDesign: Double
        public var cofounderMarketing: Double
        /// What they own, forever: `equityRemaining` starts at
        /// `100 − cofounderEquity`. Every valuation, exit and net-worth line
        /// reads `equityRemaining`, so the cost falls out of the arithmetic
        /// rather than being a second rule.
        public var cofounderEquity: Double
        /// Where the bond with the founder starts. Somebody who signed the
        /// incorporation papers with you is not a stranger.
        public var cofounderBond: Double
        /// Where their loyalty starts.
        public var cofounderLoyalty: Double
        /// The office tier (raw value) from which a co-founder expects to
        /// be paid. Below it they work for equity: salary $0 and exempt
        /// from the underpaid morale penalty. Reaching it sets their salary
        /// to fair pay the day the office is upgraded.
        public var cofounderPaidFromTier: String

        // MARK: Spin-out

        /// The signed contract's total points (code + design).
        public var spinOutContractPoints: Double
        /// The share of those points that is code.
        public var spinOutContractCodeSplit: Double
        /// What the client pays on delivery.
        public var spinOutContractPayout: Int
        /// Days from day 0 to the deadline; 84 is twelve weeks.
        public var spinOutContractDeadlineDays: Int
        /// The skill the client expects from the crew — the contract grades
        /// the first team the way any other does.
        public var spinOutContractRequiredSkill: Double
        /// The company's reputation on day 0 (a garage starts at 10).
        public var spinOutReputation: Double
        /// How long the non-compete locks one topic, in weeks.
        public var spinOutLockWeeks: Int

        // MARK: Mortgaged

        /// What the bank has already lent against the flat: `loanBalance`
        /// and the guaranteed slice both start here, and company cash is
        /// `startingCash` plus this.
        public var mortgagedLoan: Int
        /// The home tier (raw value) the founder owns — and pays rent on.
        public var mortgagedHome: String

        public init(
            cofounderCoding: Double = 40,
            cofounderDesign: Double = 40,
            cofounderMarketing: Double = 40,
            cofounderEquity: Double = 30,
            cofounderBond: Double = 40,
            cofounderLoyalty: Double = 70,
            cofounderPaidFromTier: String = OfficeTier.loft.rawValue,
            spinOutContractPoints: Double = 100,
            spinOutContractCodeSplit: Double = 0.65,
            spinOutContractPayout: Int = 9_000,
            spinOutContractDeadlineDays: Int = 84,
            spinOutContractRequiredSkill: Double = 35,
            spinOutReputation: Double = 15,
            spinOutLockWeeks: Int = 52,
            mortgagedLoan: Int = 25_000,
            mortgagedHome: String = HomeTier.apartment.rawValue
        ) {
            self.cofounderCoding = cofounderCoding
            self.cofounderDesign = cofounderDesign
            self.cofounderMarketing = cofounderMarketing
            self.cofounderEquity = cofounderEquity
            self.cofounderBond = cofounderBond
            self.cofounderLoyalty = cofounderLoyalty
            self.cofounderPaidFromTier = cofounderPaidFromTier
            self.spinOutContractPoints = spinOutContractPoints
            self.spinOutContractCodeSplit = spinOutContractCodeSplit
            self.spinOutContractPayout = spinOutContractPayout
            self.spinOutContractDeadlineDays = spinOutContractDeadlineDays
            self.spinOutContractRequiredSkill = spinOutContractRequiredSkill
            self.spinOutReputation = spinOutReputation
            self.spinOutLockWeeks = spinOutLockWeeks
            self.mortgagedLoan = mortgagedLoan
            self.mortgagedHome = mortgagedHome
        }

        public static let `default` = OriginBalance()

        // MARK: Derived

        /// The co-founder's day-0 skill set.
        public var cofounderSkills: SkillSet {
            SkillSet(coding: cofounderCoding, design: cofounderDesign, marketing: cofounderMarketing)
        }

        /// The tier from which a co-founder draws a salary; an unknown raw
        /// value reads as the loft.
        public var cofounderPaidFrom: OfficeTier {
            OfficeTier(rawValue: cofounderPaidFromTier) ?? .loft
        }

        /// The home a mortgaged founder starts in; an unknown raw value
        /// reads as the apartment.
        public var mortgagedHomeTier: HomeTier {
            HomeTier(rawValue: mortgagedHome) ?? .apartment
        }

        /// The first day a product may be started in the locked topic.
        public var spinOutLockDays: Int {
            spinOutLockWeeks * GameState.daysPerWeek
        }
    }
}

// MARK: - Codable

// Hand-written decode so `"origins": {}` — and a balance file with no
// `origins` key at all — reads as the shipped origins rather than failing
// on a missing field.
extension BalanceConfig.OriginBalance {
    private enum CodingKeys: String, CodingKey {
        case cofounderCoding, cofounderDesign, cofounderMarketing, cofounderEquity
        case cofounderBond, cofounderLoyalty, cofounderPaidFromTier
        case spinOutContractPoints, spinOutContractCodeSplit, spinOutContractPayout
        case spinOutContractDeadlineDays, spinOutContractRequiredSkill
        case spinOutReputation, spinOutLockWeeks
        case mortgagedLoan, mortgagedHome
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.default
        self.init(
            cofounderCoding: try container.decodeIfPresent(Double.self, forKey: .cofounderCoding)
                ?? fallback.cofounderCoding,
            cofounderDesign: try container.decodeIfPresent(Double.self, forKey: .cofounderDesign)
                ?? fallback.cofounderDesign,
            cofounderMarketing: try container.decodeIfPresent(Double.self, forKey: .cofounderMarketing)
                ?? fallback.cofounderMarketing,
            cofounderEquity: try container.decodeIfPresent(Double.self, forKey: .cofounderEquity)
                ?? fallback.cofounderEquity,
            cofounderBond: try container.decodeIfPresent(Double.self, forKey: .cofounderBond)
                ?? fallback.cofounderBond,
            cofounderLoyalty: try container.decodeIfPresent(Double.self, forKey: .cofounderLoyalty)
                ?? fallback.cofounderLoyalty,
            cofounderPaidFromTier: try container.decodeIfPresent(String.self, forKey: .cofounderPaidFromTier)
                ?? fallback.cofounderPaidFromTier,
            spinOutContractPoints: try container.decodeIfPresent(Double.self, forKey: .spinOutContractPoints)
                ?? fallback.spinOutContractPoints,
            spinOutContractCodeSplit: try container.decodeIfPresent(Double.self, forKey: .spinOutContractCodeSplit)
                ?? fallback.spinOutContractCodeSplit,
            spinOutContractPayout: try container.decodeIfPresent(Int.self, forKey: .spinOutContractPayout)
                ?? fallback.spinOutContractPayout,
            spinOutContractDeadlineDays: try container.decodeIfPresent(Int.self, forKey: .spinOutContractDeadlineDays)
                ?? fallback.spinOutContractDeadlineDays,
            spinOutContractRequiredSkill: try container.decodeIfPresent(Double.self, forKey: .spinOutContractRequiredSkill)
                ?? fallback.spinOutContractRequiredSkill,
            spinOutReputation: try container.decodeIfPresent(Double.self, forKey: .spinOutReputation)
                ?? fallback.spinOutReputation,
            spinOutLockWeeks: try container.decodeIfPresent(Int.self, forKey: .spinOutLockWeeks)
                ?? fallback.spinOutLockWeeks,
            mortgagedLoan: try container.decodeIfPresent(Int.self, forKey: .mortgagedLoan)
                ?? fallback.mortgagedLoan,
            mortgagedHome: try container.decodeIfPresent(String.self, forKey: .mortgagedHome)
                ?? fallback.mortgagedHome
        )
    }
}
