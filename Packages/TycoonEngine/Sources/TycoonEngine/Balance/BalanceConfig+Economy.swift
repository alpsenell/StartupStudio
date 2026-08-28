/// The `"economy"` block of `Balance.json`: the quality skill ceiling, the
/// two revenue models, hosting costs, team-size diminishing returns, live
/// ops, work pace, the morale/quit rules, the founder's consequences, the
/// pause budget, and the revenue-linked credit limit.
///
/// Every field has a default, so an older balance file without the block
/// (or with only part of it) still decodes; the shipped `Balance.json`
/// spells all of them out. No other workstream edits this file or the
/// `"economy"` object.
extension BalanceConfig {
    public struct EconomyBalance: Codable, Equatable, Sendable {
        // MARK: Quality ceiling

        /// The share of full quality a crew of complete beginners can reach.
        /// The rest is earned: `ceiling = base + (1 − base) × skillIndex/100`.
        public var qualityCeilingBase: Double
        /// Extra review expectation per point of product-type complexity
        /// above 1.0.
        public var expectationPerComplexity: Double

        // MARK: Revenue models

        /// Weeks over which a subscription product's whole addressable
        /// market would sign up at quality 1 and no churn.
        public var subscriberAcquisitionWeeks: Double
        /// Weekly churn at quality 0; every quality point buys some of it
        /// back through `churnQualityFactor`.
        public var churnBase: Double
        public var churnQualityFactor: Double
        /// A subscription product delists once it drops below this many
        /// paying subscribers.
        public var subscriptionFloorSubscribers: Int
        /// Extra weekly hosting cost per subscriber (on top of the product
        /// type's flat `hostingCostPerWeek`).
        public var hostingCostPerSubscriber: Double

        // MARK: Team size

        /// Brooks's law: `n` people on one job produce
        /// `1 / (1 + brooksPenalty × (n − 1))` each.
        public var brooksPenalty: Double

        // MARK: Live ops

        /// Share of the open bugs at ship that survive into the wild.
        public var liveBugSeedFraction: Double
        /// One live bug is discovered per this many units sold in a week.
        public var liveBugUnitsPerDiscovery: Double
        /// Each live bug shaves this fraction off weekly sales / subscribers.
        public var liveBugSalesPenalty: Double
        /// The most sales a swarm of live bugs can eat.
        public var liveBugPenaltyCap: Double
        /// Live bugs at or above this count raise the alarm (once per run
        /// of trouble).
        public var liveBugAlarmThreshold: Int
        /// A supporter fixes `polish output × this` live bugs per day.
        public var supportBugFixMultiplier: Double
        /// Support also softens churn by this fraction per supporter.
        public var supportChurnRelief: Double
        /// Price / demand trade-off per tier, keyed by `PriceTier.rawValue`.
        public var priceTiers: [String: PriceTierDef]
        /// Premium pricing under this quality doubles churn and drags
        /// one-time sales.
        public var premiumQualityThreshold: Double
        /// What an unjustified premium price multiplies churn by.
        public var premiumChurnPenalty: Double
        /// A patch costs this share of the original point pools.
        public var updatePoolFraction: Double
        /// Quality a finished patch adds (capped at 100).
        /// Days a campaign kind must wait before running again on the
        /// same product. Zero — the default — is the old behaviour, where
        /// a one-shot's duplicate guard lapsed the day after it ran and a
        /// $500 press release could be repeated daily.
        public var campaignCooldownDays: Int
        /// Hype multiplier per previous campaign of the same kind on the
        /// same product. `1` is no decay, and the default.
        public var campaignRepeatHypeDecay: Double
        /// What a premium price costs in sales when the reviews do not
        /// carry it. `1` — the default — is the old behaviour, where
        /// `overpriced` was computed for every product and read only in
        /// the subscription branch, so four of the six product types could
        /// overprice a bad product for free.
        public var premiumOverpricedSalesFactor: Double
        /// What a point of post-launch hype is worth to weekly sales,
        /// through `salesHypeDivisor`. Zero disables the channel, which is
        /// the default and matches a game where post-launch campaigns were
        /// silently refused.
        public var liveHypeSalesFactor: Double
        public var updateQualityBonus: Double
        /// Geometric decay applied to that bonus per patch already
        /// shipped, read off `ReleaseInfo.updateCount`. `1` is the old
        /// flat bonus and the default, so a balance without the key
        /// patches exactly as it did.
        public var updateQualityDecay: Double
        /// Weight of the re-review against the launch reviews.
        public var updateReviewWeight: Double
        /// Sales multiplier for the week a patch lands.
        public var updateSalesBump: Double
        /// Days a patch's sales bump lasts.
        public var updateBumpDays: Int

        // MARK: Work pace

        /// Per-pace effects, keyed by `WorkPace.rawValue`.
        public var pace: [String: PaceDef]

        // MARK: Morale & quits

        /// Days without a raise, promotion or training before an employee
        /// feels stuck.
        public var stagnationDays: Int
        public var stagnationMoralePenalty: Double
        /// Morale hit while the office is at its headcount cap.
        public var overcrowdingMoralePenalty: Double
        /// Morale hit per contract past its deadline.
        public var overdueContractMoralePenalty: Double
        /// The founder being away longer than this many days costs morale.
        public var founderAwayDays: Int
        public var founderAwayMoralePenalty: Double
        /// The founder mood below which the room starts to notice. Only
        /// the downside is modelled — see `founderMoraleDelta`.
        public var founderMoodMoraleFloor: Double
        /// Morale-target points per point of founder mood below that
        /// floor. Zero disables the hook, which is the default.
        public var founderMoodMoraleFactor: Double
        /// Morale-target points taken from a team on crunch when the
        /// founder has put themselves on chill. A founder on `normal`
        /// pays half of it; one crunching alongside them pays none.
        public var paceMismatchMoralePenalty: Double
        /// The multiple of the team's *median* weekly salary the founder
        /// can pay themselves before anybody minds. A multiple, not a
        /// number, so the band moves with the roster: a garage founder on
        /// a grand a week is fine and a fourteen-person studio founder on
        /// the same is invisible, while the reverse is a problem.
        public var founderPayFairRatio: Double
        /// Morale-target points per whole multiple of median pay above the
        /// band. A slope, not a cliff, so the player cannot park exactly
        /// on the threshold and forget it. Zero disables it.
        public var founderPayMoralePerRatioPoint: Double
        /// The most the pay gap can cost morale, however greedy.
        public var founderPayMoraleCap: Double
        /// Extra board pressure per quarter, per whole multiple above the
        /// band, once a board is seated. Zero disables it.
        public var founderPayBoardPressure: Double
        /// The share of the bank's ceiling the company can draw on its own
        /// name. The rest needs the founder's signature. `1.0` — the
        /// default — means all of it, which is how borrowing worked before
        /// a guarantee existed.
        public var unsecuredCreditFraction: Double
        /// What a home is worth as collateral, as a multiple of its
        /// `upgradeCost`. Zero disables guarantees, and a studio flat
        /// (upgrade cost 0) can never secure anything whatever this is.
        public var guaranteeHomeFactor: Double
        /// Days of company debt before the bank calls a guarantee in.
        public var guaranteeCallDays: Int
        /// How long a resignation notice stays open for a counter-offer.
        public var resignationNoticeDays: Int
        /// A counter-offer has to beat the salary at notice by this factor.
        public var counterOfferRaiseFactor: Double
        /// Morale a successful counter-offer restores.
        public var counterOfferMoraleBoost: Double

        // MARK: Founder consequences

        /// Weekly interest charged on an overdrawn personal wallet.
        public var walletInterestWeeklyRate: Double
        /// The wallet balance at which the landlord loses patience.
        public var evictionWalletThreshold: Int
        /// Days after a warning before the forced downgrade lands.
        public var evictionGraceDays: Int
        /// Weeks the company's rescue salary is sized to clear the
        /// founder's overdraft over, once the landlord has written.
        public var evictionRecoveryWeeks: Int
        /// Days signed off after a hospital stay ends. The schedule is
        /// pinned to `.chill` and a request to crunch is refused.
        public var convalescenceDays: Int
        /// The share of a hospital bill a company with a People & HR
        /// department carries for the founder.
        public var hospitalInsuredFraction: Double
        /// Two hospital stays inside this window become a chronic condition.
        public var chronicWindowDays: Int
        /// Energy ceiling while chronically ill.
        public var chronicMaxEnergy: Double
        /// Output multiplier while chronically ill.
        public var chronicOutputFactor: Double
        /// Consecutive restorative weekends that cure it.
        public var chronicCureWeeks: Int
        /// Days alone at rock-bottom relationships before loneliness sets in.
        public var lonelinessDays: Int
        /// Daily mood drift while lonely.
        public var lonelinessMoodDrift: Double
        /// Relationships at or below this while single start the clock.
        public var lonelinessRelationshipThreshold: Double
        /// Two burnouts inside this window make the news.
        public var burnoutWindowDays: Int
        /// Reputation lost when they do.
        public var burnoutReputationPenalty: Double

        // MARK: Pause budget

        /// At most one non-critical pause per this many days; the rest are
        /// downgraded to a log line.
        public var pauseBudgetDays: Int

        // MARK: Loans

        public var creditLimitBase: Int
        /// Share of trailing revenue the bank will lend against.
        public var creditLimitRevenueFactor: Double
        public var creditLimitPerReputation: Double
        /// Weeks of revenue the credit limit looks back over.
        public var creditRevenueWeeks: Int

        /// One price tier's trade-off: what the player charges, and how much
        /// demand that costs.
        public struct PriceTierDef: Codable, Equatable, Sendable {
            public var priceFactor: Double
            public var demandFactor: Double
            /// Weight this tier carries in the fight for a topic's share
            /// (`RivalSystem.recomputeShare`). `1` is neutral, and the
            /// default.
            ///
            /// Without it the tier was revenue and nothing else — and the
            /// shipped numbers multiply out to 0.90 / 1.00 / 0.96, so
            /// standard was strictly best for every product type in the
            /// game and the picker was a three-way control with one
            /// answer. Undercutting has to buy something, and what it buys
            /// is customers taken off somebody else.
            public var shareWeight: Double

            public init(priceFactor: Double, demandFactor: Double, shareWeight: Double = 1) {
                self.priceFactor = priceFactor
                self.demandFactor = demandFactor
                self.shareWeight = shareWeight
            }
        }

        /// One work pace's effects.
        public struct PaceDef: Codable, Equatable, Sendable {
            /// Multiplier on every producer's daily output.
            public var outputFactor: Double
            /// Added to (crunch: subtracted from) the daily morale target.
            public var moraleTargetDelta: Double
            /// Multiplier on skill growth.
            public var skillGrowthFactor: Double
            /// Multiplier on the chance a code point ships a bug.
            public var bugFactor: Double

            public init(
                outputFactor: Double,
                moraleTargetDelta: Double,
                skillGrowthFactor: Double,
                bugFactor: Double
            ) {
                self.outputFactor = outputFactor
                self.moraleTargetDelta = moraleTargetDelta
                self.skillGrowthFactor = skillGrowthFactor
                self.bugFactor = bugFactor
            }

            /// A pace that changes nothing.
            public static let neutral = PaceDef(
                outputFactor: 1, moraleTargetDelta: 0, skillGrowthFactor: 1, bugFactor: 1
            )
        }

        public init(
            qualityCeilingBase: Double = 0.35,
            expectationPerComplexity: Double = 8,
            subscriberAcquisitionWeeks: Double = 42,
            churnBase: Double = 0.06,
            churnQualityFactor: Double = 0.03,
            subscriptionFloorSubscribers: Int = 8,
            hostingCostPerSubscriber: Double = 0.05,
            brooksPenalty: Double = 0.10,
            liveBugSeedFraction: Double = 0.5,
            liveBugUnitsPerDiscovery: Double = 2_000,
            liveBugSalesPenalty: Double = 0.015,
            liveBugPenaltyCap: Double = 0.6,
            liveBugAlarmThreshold: Int = 12,
            supportBugFixMultiplier: Double = 1.5,
            supportChurnRelief: Double = 0.15,
            priceTiers: [String: PriceTierDef] = PriceTierDef.standardTable,
            premiumQualityThreshold: Double = 70,
            premiumChurnPenalty: Double = 2.0,
            updatePoolFraction: Double = 0.30,
            campaignCooldownDays: Int = 0,
            campaignRepeatHypeDecay: Double = 1,
            liveHypeSalesFactor: Double = 0,
            premiumOverpricedSalesFactor: Double = 1,
            updateQualityBonus: Double = 8,
            updateQualityDecay: Double = 1,
            updateReviewWeight: Double = 0.5,
            updateSalesBump: Double = 1.5,
            updateBumpDays: Int = 7,
            pace: [String: PaceDef] = PaceDef.standardTable,
            stagnationDays: Int = 364,
            stagnationMoralePenalty: Double = 10,
            overcrowdingMoralePenalty: Double = 6,
            overdueContractMoralePenalty: Double = 4,
            founderAwayDays: Int = 7,
            founderAwayMoralePenalty: Double = 5,
            founderMoodMoraleFloor: Double = 50,
            founderMoodMoraleFactor: Double = 0,
            paceMismatchMoralePenalty: Double = 0,
            founderPayFairRatio: Double = 1.5,
            founderPayMoralePerRatioPoint: Double = 0,
            founderPayMoraleCap: Double = 10,
            founderPayBoardPressure: Double = 0,
            unsecuredCreditFraction: Double = 1,
            guaranteeHomeFactor: Double = 0,
            guaranteeCallDays: Int = 7,
            resignationNoticeDays: Int = 7,
            counterOfferRaiseFactor: Double = 1.12,
            counterOfferMoraleBoost: Double = 30,
            walletInterestWeeklyRate: Double = 0.015,
            evictionWalletThreshold: Int = -3_000,
            evictionGraceDays: Int = 14,
            evictionRecoveryWeeks: Int = 26,
            convalescenceDays: Int = 14,
            hospitalInsuredFraction: Double = 0.6,
            chronicWindowDays: Int = 364,
            chronicMaxEnergy: Double = 80,
            chronicOutputFactor: Double = 0.9,
            chronicCureWeeks: Int = 3,
            lonelinessDays: Int = 60,
            lonelinessMoodDrift: Double = 0.5,
            lonelinessRelationshipThreshold: Double = 1,
            burnoutWindowDays: Int = 364,
            burnoutReputationPenalty: Double = 3,
            pauseBudgetDays: Int = 5,
            creditLimitBase: Int = 20_000,
            creditLimitRevenueFactor: Double = 0.5,
            creditLimitPerReputation: Double = 300,
            creditRevenueWeeks: Int = 12
        ) {
            self.qualityCeilingBase = qualityCeilingBase
            self.expectationPerComplexity = expectationPerComplexity
            self.subscriberAcquisitionWeeks = subscriberAcquisitionWeeks
            self.churnBase = churnBase
            self.churnQualityFactor = churnQualityFactor
            self.subscriptionFloorSubscribers = subscriptionFloorSubscribers
            self.hostingCostPerSubscriber = hostingCostPerSubscriber
            self.brooksPenalty = brooksPenalty
            self.liveBugSeedFraction = liveBugSeedFraction
            self.liveBugUnitsPerDiscovery = liveBugUnitsPerDiscovery
            self.liveBugSalesPenalty = liveBugSalesPenalty
            self.liveBugPenaltyCap = liveBugPenaltyCap
            self.liveBugAlarmThreshold = liveBugAlarmThreshold
            self.supportBugFixMultiplier = supportBugFixMultiplier
            self.supportChurnRelief = supportChurnRelief
            self.priceTiers = priceTiers
            self.premiumQualityThreshold = premiumQualityThreshold
            self.premiumChurnPenalty = premiumChurnPenalty
            self.updatePoolFraction = updatePoolFraction
            self.campaignCooldownDays = campaignCooldownDays
            self.campaignRepeatHypeDecay = campaignRepeatHypeDecay
            self.liveHypeSalesFactor = liveHypeSalesFactor
            self.premiumOverpricedSalesFactor = premiumOverpricedSalesFactor
            self.updateQualityBonus = updateQualityBonus
            self.updateQualityDecay = updateQualityDecay
            self.updateReviewWeight = updateReviewWeight
            self.updateSalesBump = updateSalesBump
            self.updateBumpDays = updateBumpDays
            self.pace = pace
            self.stagnationDays = stagnationDays
            self.stagnationMoralePenalty = stagnationMoralePenalty
            self.overcrowdingMoralePenalty = overcrowdingMoralePenalty
            self.overdueContractMoralePenalty = overdueContractMoralePenalty
            self.founderAwayDays = founderAwayDays
            self.founderAwayMoralePenalty = founderAwayMoralePenalty
            self.founderMoodMoraleFloor = founderMoodMoraleFloor
            self.founderMoodMoraleFactor = founderMoodMoraleFactor
            self.paceMismatchMoralePenalty = paceMismatchMoralePenalty
            self.founderPayFairRatio = founderPayFairRatio
            self.founderPayMoralePerRatioPoint = founderPayMoralePerRatioPoint
            self.founderPayMoraleCap = founderPayMoraleCap
            self.founderPayBoardPressure = founderPayBoardPressure
            self.unsecuredCreditFraction = unsecuredCreditFraction
            self.guaranteeHomeFactor = guaranteeHomeFactor
            self.guaranteeCallDays = guaranteeCallDays
            self.resignationNoticeDays = resignationNoticeDays
            self.counterOfferRaiseFactor = counterOfferRaiseFactor
            self.counterOfferMoraleBoost = counterOfferMoraleBoost
            self.walletInterestWeeklyRate = walletInterestWeeklyRate
            self.evictionWalletThreshold = evictionWalletThreshold
            self.evictionGraceDays = evictionGraceDays
            self.evictionRecoveryWeeks = evictionRecoveryWeeks
            self.convalescenceDays = convalescenceDays
            self.hospitalInsuredFraction = hospitalInsuredFraction
            self.chronicWindowDays = chronicWindowDays
            self.chronicMaxEnergy = chronicMaxEnergy
            self.chronicOutputFactor = chronicOutputFactor
            self.chronicCureWeeks = chronicCureWeeks
            self.lonelinessDays = lonelinessDays
            self.lonelinessMoodDrift = lonelinessMoodDrift
            self.lonelinessRelationshipThreshold = lonelinessRelationshipThreshold
            self.burnoutWindowDays = burnoutWindowDays
            self.burnoutReputationPenalty = burnoutReputationPenalty
            self.pauseBudgetDays = pauseBudgetDays
            self.creditLimitBase = creditLimitBase
            self.creditLimitRevenueFactor = creditLimitRevenueFactor
            self.creditLimitPerReputation = creditLimitPerReputation
            self.creditRevenueWeeks = creditRevenueWeeks
        }

        public static let `default` = EconomyBalance()

        /// The trade-off for a price tier (`.standard` when unknown).
        public func priceTier(_ tier: PriceTier) -> PriceTierDef {
            priceTiers[tier.rawValue] ?? PriceTierDef(priceFactor: 1, demandFactor: 1)
        }

        /// The effects of a work pace (neutral when unknown).
        public func pace(_ workPace: WorkPace) -> PaceDef {
            pace[workPace.rawValue] ?? .neutral
        }
    }
}

extension BalanceConfig.EconomyBalance.PriceTierDef {
    /// Budget undercuts on price and wins volume; premium is the reverse.
    public static let standardTable: [String: BalanceConfig.EconomyBalance.PriceTierDef] = [
        PriceTier.budget.rawValue: .init(priceFactor: 0.6, demandFactor: 1.5),
        PriceTier.standard.rawValue: .init(priceFactor: 1.0, demandFactor: 1.0),
        PriceTier.premium.rawValue: .init(priceFactor: 1.6, demandFactor: 0.6),
    ]
}

extension BalanceConfig.EconomyBalance.PaceDef {
    public static let standardTable: [String: BalanceConfig.EconomyBalance.PaceDef] = [
        WorkPace.relaxed.rawValue: .init(
            outputFactor: 0.85, moraleTargetDelta: 6, skillGrowthFactor: 1, bugFactor: 0.9
        ),
        WorkPace.normal.rawValue: .neutral,
        WorkPace.crunch.rawValue: .init(
            outputFactor: 1.25, moraleTargetDelta: -18, skillGrowthFactor: 1.2, bugFactor: 1.3
        ),
    ]
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"economy"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.EconomyBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.EconomyBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
