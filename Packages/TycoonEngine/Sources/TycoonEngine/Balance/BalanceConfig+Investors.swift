/// The `"investors"` block of `Balance.json` — when investors come
/// knocking, how hard a board leans, and what it takes to go public.
///
/// The per-persona terms (check size, equity ask, valuation floor) live in
/// `Investors.json`; these are the cadences, gates and pressures that apply
/// to all of them. Every field decodes with a default, so a balance file
/// that predates the block still loads. WS-F owns this file and the
/// `"investors"` object.
extension BalanceConfig {
    public struct InvestorBalance: Codable, Equatable, Sendable {
        /// Offer checks fire on days where `day % offerIntervalDays == 0`.
        public var offerIntervalDays: Int
        /// At most one offer per this many days, whatever the checks say.
        public var offerCooldownDays: Int
        /// Chance a check where the company qualifies produces an offer.
        public var offerChance: Double
        /// Reputation the company needs before anyone returns a call.
        public var minReputation: Double
        /// Days the player has to answer an offer.
        public var responseDays: Int
        /// The earliest day an offer can arrive — nobody funds a company
        /// that is two weeks old.
        public var earliestOfferDay: Int

        /// Board reviews run every quarter.
        public var reviewIntervalDays: Int
        /// Pressure added by a missed quarter, removed by a met one.
        /// The share of board pressure that survives a new board-seat
        /// round. `0` — the default — is the old full pardon.
        public var raisePressureRelief: Double
        public var pressurePerMiss: Double
        public var pressurePerHit: Double
        /// Pressure at which the board formally demands a plan.
        public var boardWarningPressure: Double
        /// Pressure at which the board replaces the founder.
        public var boardOustPressure: Double
        /// Quarterly revenue growth the `mrrGrowth` board wants.
        public var expectedQuarterlyRevenueGrowth: Double
        /// Products the `shipCadence` board wants each quarter.
        public var expectedQuarterlyShips: Int
        /// Headcount growth the `headcount` board wants each quarter.
        public var expectedQuarterlyHeadcountGrowth: Int

        /// The valuation an IPO needs.
        public var ipoValuationFloor: Int
        /// Consecutive profitable quarters an IPO needs.
        public var ipoProfitableQuarters: Int
        /// Whether an IPO needs a live subscription product.
        public var ipoRequiresSubscription: Bool
        /// The founder's slice is cashed out at this multiple of the
        /// valuation when the bell rings.
        public var ipoValuationMultiple: Double
        /// What an investor prices the company at, over what an acquirer
        /// would pay for it today (`GameState.companyValuation`). A round
        /// is bought forward; an acquisition is bought as-is.
        public var roundValuationPremium: Double
        /// How harshly a board of `patienceWeeks` reacts, relative to this
        /// many weeks. A twelve-week fund is twice as quick to lose
        /// patience as a twenty-four-week one.
        public var patienceReferenceWeeks: Double

        /// A rival with at least this much of the player's valuation, and
        /// the player at or above `strategicMinReputation`, makes a
        /// *strategic* approach instead of a distress buyout — the premium
        /// is the reward for building something worth having.
        public var strategicDominanceFactor: Double
        public var strategicMinReputation: Double
        public var strategicPremiumMin: Double
        public var strategicPremiumMax: Double

        // MARK: Iteration 5 — Still yours (WS-G)

        // Gates, not multipliers: nothing reads them until the founder
        // asks whether they can declare, and no pacing bot ever does.

        /// Consecutive profitable quarters the *Still yours* ending needs.
        public var independentProfitableQuarters: Int
        /// Reputation the *Still yours* ending needs.
        public var independentMinReputation: Double
        /// The earliest day the founder can call the company built.
        public var independentMinDay: Int

        public init(
            offerIntervalDays: Int = 7,
            offerCooldownDays: Int = 56,
            offerChance: Double = 0.45,
            minReputation: Double = 25,
            responseDays: Int = 7,
            earliestOfferDay: Int = 120,
            reviewIntervalDays: Int = 91,
            raisePressureRelief: Double = 0,
            pressurePerMiss: Double = 22,
            pressurePerHit: Double = 18,
            boardWarningPressure: Double = 60,
            boardOustPressure: Double = 100,
            expectedQuarterlyRevenueGrowth: Double = 0.1,
            expectedQuarterlyShips: Int = 1,
            expectedQuarterlyHeadcountGrowth: Int = 1,
            ipoValuationFloor: Int = 5_000_000,
            ipoProfitableQuarters: Int = 3,
            ipoRequiresSubscription: Bool = false,
            ipoValuationMultiple: Double = 1.4,
            roundValuationPremium: Double = 2.5,
            patienceReferenceWeeks: Double = 26,
            strategicDominanceFactor: Double = 2,
            strategicMinReputation: Double = 60,
            strategicPremiumMin: Double = 1.5,
            strategicPremiumMax: Double = 2.5,
            independentProfitableQuarters: Int = 8,
            independentMinReputation: Double = 70,
            independentMinDay: Int = 728
        ) {
            self.offerIntervalDays = offerIntervalDays
            self.offerCooldownDays = offerCooldownDays
            self.offerChance = offerChance
            self.minReputation = minReputation
            self.responseDays = responseDays
            self.earliestOfferDay = earliestOfferDay
            self.reviewIntervalDays = reviewIntervalDays
            self.raisePressureRelief = raisePressureRelief
            self.pressurePerMiss = pressurePerMiss
            self.pressurePerHit = pressurePerHit
            self.boardWarningPressure = boardWarningPressure
            self.boardOustPressure = boardOustPressure
            self.expectedQuarterlyRevenueGrowth = expectedQuarterlyRevenueGrowth
            self.expectedQuarterlyShips = expectedQuarterlyShips
            self.expectedQuarterlyHeadcountGrowth = expectedQuarterlyHeadcountGrowth
            self.ipoValuationFloor = ipoValuationFloor
            self.ipoProfitableQuarters = ipoProfitableQuarters
            self.ipoRequiresSubscription = ipoRequiresSubscription
            self.ipoValuationMultiple = ipoValuationMultiple
            self.roundValuationPremium = roundValuationPremium
            self.patienceReferenceWeeks = patienceReferenceWeeks
            self.strategicDominanceFactor = strategicDominanceFactor
            self.strategicMinReputation = strategicMinReputation
            self.strategicPremiumMin = strategicPremiumMin
            self.strategicPremiumMax = strategicPremiumMax
            self.independentProfitableQuarters = independentProfitableQuarters
            self.independentMinReputation = independentMinReputation
            self.independentMinDay = independentMinDay
        }

        public static let `default` = InvestorBalance()
    }
}

// MARK: - Codable

// Hand-written so an `"investors"` object that lists only some of the
// tunables still decodes: every key reads with `decodeIfPresent`.

extension BalanceConfig.InvestorBalance {
    private enum CodingKeys: String, CodingKey {
        case offerIntervalDays, offerCooldownDays, offerChance, minReputation
        case responseDays, earliestOfferDay
        case reviewIntervalDays, pressurePerMiss, pressurePerHit, raisePressureRelief
        case boardWarningPressure, boardOustPressure
        case expectedQuarterlyRevenueGrowth, expectedQuarterlyShips
        case expectedQuarterlyHeadcountGrowth
        case ipoValuationFloor, ipoProfitableQuarters, ipoRequiresSubscription
        case ipoValuationMultiple, roundValuationPremium, patienceReferenceWeeks
        case strategicDominanceFactor, strategicMinReputation
        case strategicPremiumMin, strategicPremiumMax
        case independentProfitableQuarters, independentMinReputation, independentMinDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BalanceConfig.InvestorBalance.default
        self.init(
            offerIntervalDays: try container.decodeIfPresent(Int.self, forKey: .offerIntervalDays)
                ?? fallback.offerIntervalDays,
            offerCooldownDays: try container.decodeIfPresent(Int.self, forKey: .offerCooldownDays)
                ?? fallback.offerCooldownDays,
            offerChance: try container.decodeIfPresent(Double.self, forKey: .offerChance)
                ?? fallback.offerChance,
            minReputation: try container.decodeIfPresent(Double.self, forKey: .minReputation)
                ?? fallback.minReputation,
            responseDays: try container.decodeIfPresent(Int.self, forKey: .responseDays)
                ?? fallback.responseDays,
            earliestOfferDay: try container.decodeIfPresent(Int.self, forKey: .earliestOfferDay)
                ?? fallback.earliestOfferDay,
            reviewIntervalDays: try container.decodeIfPresent(Int.self, forKey: .reviewIntervalDays)
                ?? fallback.reviewIntervalDays,
            raisePressureRelief: try container.decodeIfPresent(
                Double.self, forKey: .raisePressureRelief
            ) ?? 0,
            pressurePerMiss: try container.decodeIfPresent(Double.self, forKey: .pressurePerMiss)
                ?? fallback.pressurePerMiss,
            pressurePerHit: try container.decodeIfPresent(Double.self, forKey: .pressurePerHit)
                ?? fallback.pressurePerHit,
            boardWarningPressure: try container.decodeIfPresent(Double.self, forKey: .boardWarningPressure)
                ?? fallback.boardWarningPressure,
            boardOustPressure: try container.decodeIfPresent(Double.self, forKey: .boardOustPressure)
                ?? fallback.boardOustPressure,
            expectedQuarterlyRevenueGrowth: try container.decodeIfPresent(
                Double.self, forKey: .expectedQuarterlyRevenueGrowth
            ) ?? fallback.expectedQuarterlyRevenueGrowth,
            expectedQuarterlyShips: try container.decodeIfPresent(
                Int.self, forKey: .expectedQuarterlyShips
            ) ?? fallback.expectedQuarterlyShips,
            expectedQuarterlyHeadcountGrowth: try container.decodeIfPresent(
                Int.self, forKey: .expectedQuarterlyHeadcountGrowth
            ) ?? fallback.expectedQuarterlyHeadcountGrowth,
            ipoValuationFloor: try container.decodeIfPresent(Int.self, forKey: .ipoValuationFloor)
                ?? fallback.ipoValuationFloor,
            ipoProfitableQuarters: try container.decodeIfPresent(
                Int.self, forKey: .ipoProfitableQuarters
            ) ?? fallback.ipoProfitableQuarters,
            ipoRequiresSubscription: try container.decodeIfPresent(
                Bool.self, forKey: .ipoRequiresSubscription
            ) ?? fallback.ipoRequiresSubscription,
            ipoValuationMultiple: try container.decodeIfPresent(
                Double.self, forKey: .ipoValuationMultiple
            ) ?? fallback.ipoValuationMultiple,
            roundValuationPremium: try container.decodeIfPresent(
                Double.self, forKey: .roundValuationPremium
            ) ?? fallback.roundValuationPremium,
            patienceReferenceWeeks: try container.decodeIfPresent(
                Double.self, forKey: .patienceReferenceWeeks
            ) ?? fallback.patienceReferenceWeeks,
            strategicDominanceFactor: try container.decodeIfPresent(
                Double.self, forKey: .strategicDominanceFactor
            ) ?? fallback.strategicDominanceFactor,
            strategicMinReputation: try container.decodeIfPresent(
                Double.self, forKey: .strategicMinReputation
            ) ?? fallback.strategicMinReputation,
            strategicPremiumMin: try container.decodeIfPresent(Double.self, forKey: .strategicPremiumMin)
                ?? fallback.strategicPremiumMin,
            strategicPremiumMax: try container.decodeIfPresent(Double.self, forKey: .strategicPremiumMax)
                ?? fallback.strategicPremiumMax,
            independentProfitableQuarters: try container.decodeIfPresent(
                Int.self, forKey: .independentProfitableQuarters
            ) ?? fallback.independentProfitableQuarters,
            independentMinReputation: try container.decodeIfPresent(
                Double.self, forKey: .independentMinReputation
            ) ?? fallback.independentMinReputation,
            independentMinDay: try container.decodeIfPresent(Int.self, forKey: .independentMinDay)
                ?? fallback.independentMinDay
        )
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"investors"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.InvestorBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.InvestorBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
