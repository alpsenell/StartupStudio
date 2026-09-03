import Foundation

extension BalanceConfig.RivalBalance {
    /// The Category Fight and the Incumbent (WS-A, iteration 5): what
    /// standing buys against a rival, what a challenge costs each side,
    /// how fast an out-sold studio bleeds, and when a giant shows up.
    ///
    /// Every knob here is reached only through a rival selling into a
    /// topic the player is selling into, so at `rivalCount = 0` — the
    /// pacing suite — none of it runs and the baseline table is
    /// byte-identical whatever these read. The one term that touches
    /// share directly, `shareFloorAtFullStanding`, is a no-op below the
    /// existing 0.30 floor (standing under ~55) and at standing 0
    /// exactly.
    ///
    /// The older constants of rival depth (share exponent, relevance
    /// window, price-war size) stay in `RivalDepthTuning`: the app and
    /// three other lanes read them by that name.
    public struct DepthBalance: Codable, Equatable, Sendable {
        // MARK: Standing holds share

        /// In a contested topic the player's share cannot fall below
        /// `shareFloorAtFullStanding × standing / maxStanding`. 0.55 at
        /// standing 100; only above the 0.30 hard floor once standing
        /// clears ~55, so early play reads exactly as it did.
        public var shareFloorAtFullStanding: Double

        // MARK: The challenge

        /// A rival launch into a topic where the player's standing is at
        /// least this opens a challenge…
        public var challengeMinStanding: Double
        /// …when the launch scores no more than this far below the
        /// player's best product there. Anything better is a challenge by
        /// definition.
        public var challengeQualityWindow: Double
        /// Weeks from the launch to the settlement.
        public var challengeWeeks: Int
        /// One challenge per topic per this many weeks.
        public var challengeCooldownWeeks: Int
        /// Share at settlement that counts as holding the category.
        public var challengeHoldShare: Double
        /// Held: the rival loses this much strength, the player gains this
        /// much standing.
        public var heldRivalStrengthLoss: Double
        public var heldStandingGain: Double
        /// Lost: the player loses this much standing, the rival gains this
        /// much strength and adds the topic to its focus.
        public var lostStandingLoss: Double
        public var lostRivalStrengthGain: Double

        // MARK: The strength bleed

        /// Weekly, in every topic where the player has something live and
        /// a rival sells too: the out-sold rival loses this much strength…
        public var strengthPerWeekBeaten: Double
        /// …and an out-sold player loses this much standing there.
        public var standingPerWeekBeaten: Double

        // MARK: The incumbent

        /// Master switch. Off, no incumbent is ever founded.
        public var incumbentEnabled: Bool
        /// The company valuation that first brings one…
        public var incumbentValuationFloor: Int
        /// …or this many dominated topics, whichever comes first.
        public var incumbentDominatedTopics: Int
        /// Strength = `factor × valuation / valuationPerStrength`, clamped.
        public var incumbentStrengthFactor: Double
        public var incumbentStrengthMin: Double
        public var incumbentStrengthMax: Double
        /// Reputation rolls uniformly in this band.
        public var incumbentReputationMin: Double
        public var incumbentReputationMax: Double
        /// Hold `challengeHoldShare` in both its topics for this many
        /// consecutive weeks and it retreats…
        public var incumbentRetreatWeeks: Int
        /// …paying the player this much reputation and this much standing
        /// in each of the two.
        public var incumbentRetreatReputationGain: Double
        public var incumbentRetreatStandingGain: Double

        public init(
            shareFloorAtFullStanding: Double = 0.55,
            challengeMinStanding: Double = 50,
            challengeQualityWindow: Double = 15,
            challengeWeeks: Int = 6,
            challengeCooldownWeeks: Int = 26,
            challengeHoldShare: Double = 0.5,
            heldRivalStrengthLoss: Double = 8,
            heldStandingGain: Double = 10,
            lostStandingLoss: Double = 20,
            lostRivalStrengthGain: Double = 5,
            strengthPerWeekBeaten: Double = 1.0,
            standingPerWeekBeaten: Double = 1.0,
            incumbentEnabled: Bool = true,
            incumbentValuationFloor: Int = 750_000,
            incumbentDominatedTopics: Int = 2,
            incumbentStrengthFactor: Double = 0.6,
            incumbentStrengthMin: Double = 70,
            incumbentStrengthMax: Double = 95,
            incumbentReputationMin: Double = 60,
            incumbentReputationMax: Double = 80,
            incumbentRetreatWeeks: Int = 26,
            incumbentRetreatReputationGain: Double = 5,
            incumbentRetreatStandingGain: Double = 15
        ) {
            self.shareFloorAtFullStanding = shareFloorAtFullStanding
            self.challengeMinStanding = challengeMinStanding
            self.challengeQualityWindow = challengeQualityWindow
            self.challengeWeeks = challengeWeeks
            self.challengeCooldownWeeks = challengeCooldownWeeks
            self.challengeHoldShare = challengeHoldShare
            self.heldRivalStrengthLoss = heldRivalStrengthLoss
            self.heldStandingGain = heldStandingGain
            self.lostStandingLoss = lostStandingLoss
            self.lostRivalStrengthGain = lostRivalStrengthGain
            self.strengthPerWeekBeaten = strengthPerWeekBeaten
            self.standingPerWeekBeaten = standingPerWeekBeaten
            self.incumbentEnabled = incumbentEnabled
            self.incumbentValuationFloor = incumbentValuationFloor
            self.incumbentDominatedTopics = incumbentDominatedTopics
            self.incumbentStrengthFactor = incumbentStrengthFactor
            self.incumbentStrengthMin = incumbentStrengthMin
            self.incumbentStrengthMax = incumbentStrengthMax
            self.incumbentReputationMin = incumbentReputationMin
            self.incumbentReputationMax = incumbentReputationMax
            self.incumbentRetreatWeeks = incumbentRetreatWeeks
            self.incumbentRetreatReputationGain = incumbentRetreatReputationGain
            self.incumbentRetreatStandingGain = incumbentRetreatStandingGain
        }

        /// The shipped numbers — the same ones `Balance.json` carries.
        public static let `default` = DepthBalance()

        /// The block with every effect switched off: no floor, no
        /// challenge, no bleed, no incumbent. What a game with the feature
        /// absent would measure; the neutrality tests run against it.
        public static let off = DepthBalance(
            shareFloorAtFullStanding: 0,
            challengeMinStanding: .infinity,
            strengthPerWeekBeaten: 0,
            standingPerWeekBeaten: 0,
            incumbentEnabled: false
        )
    }
}

// MARK: - Codable

// Hand-written so a `"depth"` object that lists only some of the tunables
// still decodes: every key reads with `decodeIfPresent` against the
// shipped default.

extension BalanceConfig.RivalBalance.DepthBalance {
    private enum CodingKeys: String, CodingKey {
        case shareFloorAtFullStanding
        case challengeMinStanding, challengeQualityWindow, challengeWeeks, challengeCooldownWeeks
        case challengeHoldShare, heldRivalStrengthLoss, heldStandingGain
        case lostStandingLoss, lostRivalStrengthGain
        case strengthPerWeekBeaten, standingPerWeekBeaten
        case incumbentEnabled, incumbentValuationFloor, incumbentDominatedTopics
        case incumbentStrengthFactor, incumbentStrengthMin, incumbentStrengthMax
        case incumbentReputationMin, incumbentReputationMax
        case incumbentRetreatWeeks, incumbentRetreatReputationGain, incumbentRetreatStandingGain
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = Self.default
        self.init(
            shareFloorAtFullStanding: try container.decodeIfPresent(Double.self, forKey: .shareFloorAtFullStanding)
                ?? base.shareFloorAtFullStanding,
            challengeMinStanding: try container.decodeIfPresent(Double.self, forKey: .challengeMinStanding)
                ?? base.challengeMinStanding,
            challengeQualityWindow: try container.decodeIfPresent(Double.self, forKey: .challengeQualityWindow)
                ?? base.challengeQualityWindow,
            challengeWeeks: try container.decodeIfPresent(Int.self, forKey: .challengeWeeks)
                ?? base.challengeWeeks,
            challengeCooldownWeeks: try container.decodeIfPresent(Int.self, forKey: .challengeCooldownWeeks)
                ?? base.challengeCooldownWeeks,
            challengeHoldShare: try container.decodeIfPresent(Double.self, forKey: .challengeHoldShare)
                ?? base.challengeHoldShare,
            heldRivalStrengthLoss: try container.decodeIfPresent(Double.self, forKey: .heldRivalStrengthLoss)
                ?? base.heldRivalStrengthLoss,
            heldStandingGain: try container.decodeIfPresent(Double.self, forKey: .heldStandingGain)
                ?? base.heldStandingGain,
            lostStandingLoss: try container.decodeIfPresent(Double.self, forKey: .lostStandingLoss)
                ?? base.lostStandingLoss,
            lostRivalStrengthGain: try container.decodeIfPresent(Double.self, forKey: .lostRivalStrengthGain)
                ?? base.lostRivalStrengthGain,
            strengthPerWeekBeaten: try container.decodeIfPresent(Double.self, forKey: .strengthPerWeekBeaten)
                ?? base.strengthPerWeekBeaten,
            standingPerWeekBeaten: try container.decodeIfPresent(Double.self, forKey: .standingPerWeekBeaten)
                ?? base.standingPerWeekBeaten,
            incumbentEnabled: try container.decodeIfPresent(Bool.self, forKey: .incumbentEnabled)
                ?? base.incumbentEnabled,
            incumbentValuationFloor: try container.decodeIfPresent(Int.self, forKey: .incumbentValuationFloor)
                ?? base.incumbentValuationFloor,
            incumbentDominatedTopics: try container.decodeIfPresent(Int.self, forKey: .incumbentDominatedTopics)
                ?? base.incumbentDominatedTopics,
            incumbentStrengthFactor: try container.decodeIfPresent(Double.self, forKey: .incumbentStrengthFactor)
                ?? base.incumbentStrengthFactor,
            incumbentStrengthMin: try container.decodeIfPresent(Double.self, forKey: .incumbentStrengthMin)
                ?? base.incumbentStrengthMin,
            incumbentStrengthMax: try container.decodeIfPresent(Double.self, forKey: .incumbentStrengthMax)
                ?? base.incumbentStrengthMax,
            incumbentReputationMin: try container.decodeIfPresent(Double.self, forKey: .incumbentReputationMin)
                ?? base.incumbentReputationMin,
            incumbentReputationMax: try container.decodeIfPresent(Double.self, forKey: .incumbentReputationMax)
                ?? base.incumbentReputationMax,
            incumbentRetreatWeeks: try container.decodeIfPresent(Int.self, forKey: .incumbentRetreatWeeks)
                ?? base.incumbentRetreatWeeks,
            incumbentRetreatReputationGain: try container.decodeIfPresent(
                Double.self, forKey: .incumbentRetreatReputationGain
            ) ?? base.incumbentRetreatReputationGain,
            incumbentRetreatStandingGain: try container.decodeIfPresent(
                Double.self, forKey: .incumbentRetreatStandingGain
            ) ?? base.incumbentRetreatStandingGain
        )
    }
}

// Lets `RivalBalance`'s synthesized decoder read a `"rivals"` object that
// has no `"depth"` block at all — the trick `ProgressionBalance` uses: the
// concrete overload wins over the generic `decode(_:forKey:)`, turning the
// required key into `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.RivalBalance.DepthBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.RivalBalance.DepthBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
