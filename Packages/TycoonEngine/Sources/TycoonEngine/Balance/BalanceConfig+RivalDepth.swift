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
        ///
        /// Designed at 1.0 (six months of being out-sold reaches the fold
        /// line from a mid-range founding) and shipped at 0.5: measured
        /// at 1.0 the investor suite, which runs with rivals on, lost
        /// three of its nine gates — rivals the funded bots out-sell
        /// launch worse products, share and revenue rise, and the coasting
        /// founder meets the board's number too often to be voted out.
        /// At 0.5 all nine hold and a rival out-sold for a year folds.
        public var strengthPerWeekBeaten: Double
        /// …and an out-sold player loses this much standing there.
        public var standingPerWeekBeaten: Double

        // MARK: The incumbent

        /// Master switch. Off, no incumbent is ever founded.
        public var incumbentEnabled: Bool
        /// The company valuation that first brings one…
        ///
        /// Designed at $750k and shipped at $1M. Measured on the merged
        /// iteration-5 tree with the owned-topics trigger off, $750k
        /// brought the giant to the independent player (`GoalIndependentBot`,
        /// four years) at days 602–889 on six seeds and left it at *Still
        /// yours* on 2 of 10, under the ladder's 3–7; at $1M it arrives
        /// five weeks later (days 637–959) and the count is 4. The funded
        /// studio still meets it on 7 of 10 inside two years (days
        /// 546–644); at $1.5M that is 3, and at $2M none. A strength-95
        /// incumbent is worth $610k–680k, so at the $1M line it is also
        /// the buyer the strategic buyout can name once the company
        /// outgrows it by the 2× the exit asks for.
        public var incumbentValuationFloor: Int
        /// …or this many dominated topics, whichever comes first; 0 turns
        /// the second trigger off.
        ///
        /// Designed at 2 and shipped at 0. Measured on the merged
        /// iteration-5 tree, two owned topics is not a size: a topic is
        /// "dominated" at 65% share against whatever a minnow launched
        /// into it, and a garage founder who has stopped growing owns two
        /// inside seven months. The trigger brought the giant to the
        /// coasting founder (day 217–441) and the independent player
        /// (day 224–546) in year one, and three investor gates moved —
        /// the coaster was never under warning, never recovered, and the
        /// independent ladder's last chapter went from 6 seeds to 3. On
        /// the valuation line alone the coaster never meets a company it
        /// is not worth, the independent player meets one in year 2–3 on
        /// 6 seeds and still finishes, and the funded studio meets it on 8
        /// inside two years; raising the floor instead changed nothing,
        /// because this trigger fired first.
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

        // MARK: Acquisition

        /// Whether buying a rival brings the product that was beating you
        /// in each of your categories. Off, an acquisition is the
        /// reputation bump and the hires it always was.
        public var acquisitionAbsorbsShelf: Bool

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
            strengthPerWeekBeaten: Double = 0.5,
            standingPerWeekBeaten: Double = 1.0,
            incumbentEnabled: Bool = true,
            incumbentValuationFloor: Int = 1_000_000,
            incumbentDominatedTopics: Int = 0,
            incumbentStrengthFactor: Double = 0.6,
            incumbentStrengthMin: Double = 70,
            incumbentStrengthMax: Double = 95,
            incumbentReputationMin: Double = 60,
            incumbentReputationMax: Double = 80,
            incumbentRetreatWeeks: Int = 26,
            incumbentRetreatReputationGain: Double = 5,
            incumbentRetreatStandingGain: Double = 15,
            acquisitionAbsorbsShelf: Bool = true
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
            self.acquisitionAbsorbsShelf = acquisitionAbsorbsShelf
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
            incumbentEnabled: false,
            acquisitionAbsorbsShelf: false
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
        case acquisitionAbsorbsShelf
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
            ) ?? base.incumbentRetreatStandingGain,
            acquisitionAbsorbsShelf: try container.decodeIfPresent(Bool.self, forKey: .acquisitionAbsorbsShelf)
                ?? base.acquisitionAbsorbsShelf
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
