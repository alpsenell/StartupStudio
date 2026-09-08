import Foundation

/// Tunable game-balance values, decoded from `Resources/Balance.json`.
public struct BalanceConfig: Codable, Equatable, Sendable {
    public struct OfficeDef: Codable, Equatable, Sendable {
        public var upgradeCost: Int
        public var weeklyRent: Int
        public var headcountCap: Int

        public init(upgradeCost: Int, weeklyRent: Int, headcountCap: Int) {
            self.upgradeCost = upgradeCost
            self.weeklyRent = weeklyRent
            self.headcountCap = headcountCap
        }
    }

    /// Everything that tunes the founder's personal life (`LifeSystem`).
    /// Decoded from the `"life"` block of `Balance.json`.
    public struct LifeBalance: Codable, Equatable, Sendable {
        /// Daily meter deltas.
        public struct MeterDrift: Codable, Equatable, Sendable {
            public var energy: Double
            public var health: Double
            public var mood: Double
            public var relationships: Double

            public init(energy: Double, health: Double, mood: Double, relationships: Double) {
                self.energy = energy
                self.health = health
                self.mood = mood
                self.relationships = relationships
            }

            public static let zero = MeterDrift(energy: 0, health: 0, mood: 0, relationships: 0)
        }

        /// Weights of energy / health / mood in the founder's wellbeing term.
        public struct WellbeingWeights: Codable, Equatable, Sendable {
            public var energy: Double
            public var health: Double
            public var mood: Double

            public init(energy: Double, health: Double, mood: Double) {
                self.energy = energy
                self.health = health
                self.mood = mood
            }
        }

        /// One weekend activity: meter deltas and its wallet cost.
        public struct ActivityDef: Codable, Equatable, Sendable {
            public var energy: Double
            public var health: Double
            public var mood: Double
            public var relationships: Double
            public var cost: Int

            public init(energy: Double, health: Double, mood: Double, relationships: Double, cost: Int) {
                self.energy = energy
                self.health = health
                self.mood = mood
                self.relationships = relationships
                self.cost = cost
            }
        }

        public struct HomeDef: Codable, Equatable, Sendable {
            public var upgradeCost: Int
            public var weeklyRent: Int
            /// Daily mood drift granted by living here.
            public var moodBonus: Double

            public init(upgradeCost: Int, weeklyRent: Int, moodBonus: Double) {
                self.upgradeCost = upgradeCost
                self.weeklyRent = weeklyRent
                self.moodBonus = moodBonus
            }
        }

        // Money
        public var startingWallet: Int
        public var defaultFounderSalary: Int
        public var founderSalaryMax: Int

        // Drift & output
        /// Keyed by `WorkSchedule` raw value.
        public var drift: [String: MeterDrift]
        /// Founder output factor keyed by `WorkSchedule` raw value.
        public var scheduleOutputFactor: [String: Double]
        public var wellbeingWeights: WellbeingWeights
        /// Founder output at zero wellbeing; full wellbeing reaches 1.
        public var minOutputFactor: Double
        /// Extra daily relationships drain keyed by `RelationshipStage` raw
        /// value (a missing key means 0).
        public var stageRelationshipDrain: [String: Double]
        /// Daily drift contributed by each child.
        public var childDrift: MeterDrift
        /// Daily mood loss while the wallet is negative.
        public var debtMoodPenalty: Double

        // Thresholds
        public var burnoutEnergyThreshold: Double
        public var burnoutDays: Int
        public var burnoutRecoveryEnergy: Double
        public var hospitalHealthThreshold: Double
        public var hospitalDays: Int
        public var hospitalBill: Int
        public var hospitalRecoveryHealth: Double
        public var breakupThreshold: Double
        public var breakupStreakDays: Int
        public var breakupMoodPenalty: Double

        // Life events
        public var lifeEventIntervalDays: Int
        public var lifeEventChance: Double

        // Founder condition
        public var coldOutputFactor: Double
        public var lowEnergyBugThreshold: Double
        public var lowEnergyBugDivisor: Double

        // Weekly
        public var childWeeklyCost: Int
        /// Keyed by `WeekendActivity` raw value.
        public var activities: [String: ActivityDef]
        public var vacationDays: Int

        // Relationship & children gates
        public var datingMinRelationships: Double
        public var partnerMinRelationships: Double
        public var partnerMinDaysAtStage: Int
        public var marriedMinRelationships: Double
        public var marriedMinDaysAtStage: Int
        public var weddingCost: Int
        public var childMinRelationships: Double
        public var childStartCost: Int
        /// Minimum `HomeTier` raw value required to have a child.
        public var childMinHome: String
        public var maxChildren: Int
        public var childSpacingDays: Int
        public var childMoodBonus: Double

        /// Keyed by `HomeTier` raw value.
        public var homes: [String: HomeDef]
        /// Evenings the founder has in a week, keyed by `WorkSchedule` raw
        /// value — the Life tab's scarce resource, spent by training, a
        /// partner activity, a hang-out, mentoring or an instant activity.
        ///
        /// An empty map means no budget at all, which is the pre-budget
        /// behaviour: every action back on its own independent cooldown.
        /// A balance file without the key therefore plays exactly as it
        /// did, and so does every test written before this existed.
        public var eveningsPerWeek: [String: Int]

        public init(
            startingWallet: Int,
            defaultFounderSalary: Int,
            founderSalaryMax: Int,
            drift: [String: MeterDrift],
            scheduleOutputFactor: [String: Double],
            wellbeingWeights: WellbeingWeights,
            minOutputFactor: Double,
            stageRelationshipDrain: [String: Double],
            childDrift: MeterDrift,
            debtMoodPenalty: Double,
            burnoutEnergyThreshold: Double,
            burnoutDays: Int,
            burnoutRecoveryEnergy: Double,
            hospitalHealthThreshold: Double,
            hospitalDays: Int,
            hospitalBill: Int,
            hospitalRecoveryHealth: Double,
            breakupThreshold: Double,
            breakupStreakDays: Int,
            breakupMoodPenalty: Double,
            lifeEventIntervalDays: Int,
            lifeEventChance: Double,
            coldOutputFactor: Double,
            lowEnergyBugThreshold: Double,
            lowEnergyBugDivisor: Double,
            childWeeklyCost: Int,
            activities: [String: ActivityDef],
            vacationDays: Int,
            datingMinRelationships: Double,
            partnerMinRelationships: Double,
            partnerMinDaysAtStage: Int,
            marriedMinRelationships: Double,
            marriedMinDaysAtStage: Int,
            weddingCost: Int,
            childMinRelationships: Double,
            childStartCost: Int,
            childMinHome: String,
            maxChildren: Int,
            childSpacingDays: Int,
            childMoodBonus: Double,
            homes: [String: HomeDef],
            // Last, with a default, so every caller written before the
            // evening budget existed still compiles — and gets no budget.
            eveningsPerWeek: [String: Int] = [:]
        ) {
            self.startingWallet = startingWallet
            self.defaultFounderSalary = defaultFounderSalary
            self.founderSalaryMax = founderSalaryMax
            self.drift = drift
            self.scheduleOutputFactor = scheduleOutputFactor
            self.wellbeingWeights = wellbeingWeights
            self.minOutputFactor = minOutputFactor
            self.stageRelationshipDrain = stageRelationshipDrain
            self.childDrift = childDrift
            self.debtMoodPenalty = debtMoodPenalty
            self.burnoutEnergyThreshold = burnoutEnergyThreshold
            self.burnoutDays = burnoutDays
            self.burnoutRecoveryEnergy = burnoutRecoveryEnergy
            self.hospitalHealthThreshold = hospitalHealthThreshold
            self.hospitalDays = hospitalDays
            self.hospitalBill = hospitalBill
            self.hospitalRecoveryHealth = hospitalRecoveryHealth
            self.breakupThreshold = breakupThreshold
            self.breakupStreakDays = breakupStreakDays
            self.breakupMoodPenalty = breakupMoodPenalty
            self.lifeEventIntervalDays = lifeEventIntervalDays
            self.lifeEventChance = lifeEventChance
            self.coldOutputFactor = coldOutputFactor
            self.lowEnergyBugThreshold = lowEnergyBugThreshold
            self.lowEnergyBugDivisor = lowEnergyBugDivisor
            self.childWeeklyCost = childWeeklyCost
            self.activities = activities
            self.vacationDays = vacationDays
            self.datingMinRelationships = datingMinRelationships
            self.partnerMinRelationships = partnerMinRelationships
            self.partnerMinDaysAtStage = partnerMinDaysAtStage
            self.marriedMinRelationships = marriedMinRelationships
            self.marriedMinDaysAtStage = marriedMinDaysAtStage
            self.weddingCost = weddingCost
            self.childMinRelationships = childMinRelationships
            self.childStartCost = childStartCost
            self.childMinHome = childMinHome
            self.maxChildren = maxChildren
            self.childSpacingDays = childSpacingDays
            self.childMoodBonus = childMoodBonus
            self.homes = homes
            self.eveningsPerWeek = eveningsPerWeek
        }

        public func drift(for schedule: WorkSchedule) -> MeterDrift {
            guard let def = drift[schedule.rawValue] else {
                preconditionFailure("BalanceConfig.life is missing drift for schedule '\(schedule.rawValue)'")
            }
            return def
        }

        public func outputFactor(for schedule: WorkSchedule) -> Double {
            guard let factor = scheduleOutputFactor[schedule.rawValue] else {
                preconditionFailure("BalanceConfig.life is missing an output factor for schedule '\(schedule.rawValue)'")
            }
            return factor
        }

        public func relationshipDrain(for stage: RelationshipStage) -> Double {
            stageRelationshipDrain[stage.rawValue] ?? 0
        }

        public func activity(_ activity: WeekendActivity) -> ActivityDef {
            guard let def = activities[activity.rawValue] else {
                preconditionFailure("BalanceConfig.life is missing an activity definition for '\(activity.rawValue)'")
            }
            return def
        }

        public func home(_ tier: HomeTier) -> HomeDef {
            guard let def = homes[tier.rawValue] else {
                preconditionFailure("BalanceConfig.life is missing a home definition for tier '\(tier.rawValue)'")
            }
            return def
        }

        /// Evenings this schedule leaves the founder, or `nil` when the
        /// balance has no budget — the caller then applies only the
        /// per-day caps, as it did before the budget existed.
        public func evenings(for schedule: WorkSchedule) -> Int? {
            eveningsPerWeek[schedule.rawValue]
        }
    }

    /// Tuning for the studio's standing in a topic — the "Hold the
    /// Category" ledger kept by `StandingSystem`, read by the market report
    /// and by the new-product flow's topic step.
    ///
    /// Standing is rent, not a trophy: everything the studio does in a
    /// category pays into it, and every week with nothing on the market
    /// there takes some back. It buys exactly one thing — sight of the
    /// topic's forward book at `forecastThreshold` — so none of these
    /// numbers reaches the economy.
    public struct StandingBalance: Codable, Equatable, Sendable {
        /// Upper clamp; the lower clamp is always 0.
        public var maxStanding: Double
        /// Paid when a product ships into the topic.
        public var shipGain: Double
        /// Paid per launch-review point above `reviewNeutralScore`, and
        /// charged per point below it — a panned launch does less for your
        /// name in a category than a well-received one.
        public var reviewGainPerPoint: Double
        public var reviewNeutralScore: Double
        /// Paid when a patch lands on a product in the topic.
        public var patchGain: Double
        /// Paid when a campaign starts on a product in the topic.
        public var campaignGain: Double
        /// Paid every shift the studio has something on the market there.
        public var presenceWeeklyGain: Double
        /// Charged every shift it does not.
        public var decayWeeklyLoss: Double
        /// Standing at or above this reads the topic's forward book.
        public var forecastThreshold: Double

        public init(
            maxStanding: Double, shipGain: Double,
            reviewGainPerPoint: Double, reviewNeutralScore: Double,
            patchGain: Double, campaignGain: Double,
            presenceWeeklyGain: Double, decayWeeklyLoss: Double,
            forecastThreshold: Double
        ) {
            self.maxStanding = maxStanding
            self.shipGain = shipGain
            self.reviewGainPerPoint = reviewGainPerPoint
            self.reviewNeutralScore = reviewNeutralScore
            self.patchGain = patchGain
            self.campaignGain = campaignGain
            self.presenceWeeklyGain = presenceWeeklyGain
            self.decayWeeklyLoss = decayWeeklyLoss
            self.forecastThreshold = forecastThreshold
        }

        public static let standard = StandingBalance(
            maxStanding: 100, shipGain: 12,
            reviewGainPerPoint: 0.4, reviewNeutralScore: 60,
            patchGain: 4, campaignGain: 3,
            presenceWeeklyGain: 0.5, decayWeeklyLoss: 1.5,
            forecastThreshold: 50
        )

        /// The standing a launch is worth: the flat ship fee plus what the
        /// press made of it. A disaster can be worth less than nothing;
        /// the caller clamps to `0...maxStanding`.
        public func launchGain(averageReviewScore: Int) -> Double {
            shipGain + reviewGainPerPoint * (Double(averageReviewScore) - reviewNeutralScore)
        }
    }

    /// Tuning for the per-topic market simulation (`MarketSystem`).
    public struct MarketBalance: Codable, Equatable, Sendable {
        /// Multipliers take a random-walk step every this many days.
        public var shiftIntervalDays: Int
        /// Sigma of the gaussian drift step.
        public var driftSigma: Double
        /// Clamp bounds on a topic's demand multiplier.
        public var multiplierMin: Double
        public var multiplierMax: Double
        /// Chance per shift that a topic booms, and the jump it adds.
        public var boomChance: Double
        public var boomJump: Double
        /// Chance per shift that a topic crashes, and the drop it applies.
        public var crashChance: Double
        public var crashJump: Double
        /// How many shifts ahead `MarketForecast` projects a topic for a
        /// studio that holds the category. Read-only: nothing in the sim
        /// consults it, so it costs the walk nothing.
        public var forecastHorizonWeeks: Int
        /// The standing ledger.
        public var standing: StandingBalance

        public init(
            shiftIntervalDays: Int, driftSigma: Double,
            multiplierMin: Double, multiplierMax: Double,
            boomChance: Double, boomJump: Double,
            crashChance: Double, crashJump: Double,
            forecastHorizonWeeks: Int = MarketBalance.defaultForecastHorizonWeeks,
            standing: StandingBalance = .standard
        ) {
            self.shiftIntervalDays = shiftIntervalDays
            self.driftSigma = driftSigma
            self.multiplierMin = multiplierMin
            self.multiplierMax = multiplierMax
            self.boomChance = boomChance
            self.boomJump = boomJump
            self.crashChance = crashChance
            self.crashJump = crashJump
            self.forecastHorizonWeeks = forecastHorizonWeeks
            self.standing = standing
        }

        /// Decoded leniently for the two fields "Hold the Category" added,
        /// so a `Balance.json` written before them still loads.
        private enum CodingKeys: String, CodingKey {
            case shiftIntervalDays, driftSigma, multiplierMin, multiplierMax
            case boomChance, boomJump, crashChance, crashJump
            case forecastHorizonWeeks, standing
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                shiftIntervalDays: try container.decode(Int.self, forKey: .shiftIntervalDays),
                driftSigma: try container.decode(Double.self, forKey: .driftSigma),
                multiplierMin: try container.decode(Double.self, forKey: .multiplierMin),
                multiplierMax: try container.decode(Double.self, forKey: .multiplierMax),
                boomChance: try container.decode(Double.self, forKey: .boomChance),
                boomJump: try container.decode(Double.self, forKey: .boomJump),
                crashChance: try container.decode(Double.self, forKey: .crashChance),
                crashJump: try container.decode(Double.self, forKey: .crashJump),
                forecastHorizonWeeks: try container.decodeIfPresent(
                    Int.self, forKey: .forecastHorizonWeeks
                ) ?? MarketBalance.defaultForecastHorizonWeeks,
                standing: try container.decodeIfPresent(
                    StandingBalance.self, forKey: .standing
                ) ?? .standard
            )
        }

        /// The shipped projection depth, and the default the memberwise
        /// initializer and the lenient decoder agree on.
        ///
        /// Three weeks, and it is free because `MarketForecast` reads the
        /// walk rather than pre-rolling it. The pre-rolled version was
        /// built first and measured: committing a boom two or three shifts
        /// early consumes the RNG stream word for word as before, but it
        /// *reshuffles* which run meets which week, and the pacing table
        /// notices. At horizons 0/1/2/4 the gates held and at 3 the
        /// bankruptcy rate in `growthOnProductRevenueIsACoinFlip` read 67%
        /// against a 55% baseline — no trend across the sweep, so a
        /// reshuffle rather than a dose, but a red gate either way, and
        /// picking the horizon that happened to land green would have been
        /// tuning to noise. A projection moves nothing, so the horizon is
        /// free to be the number the design asked for.
        public static let defaultForecastHorizonWeeks = 3

        public static let standard = MarketBalance(
            shiftIntervalDays: 7, driftSigma: 0.06,
            multiplierMin: 0.4, multiplierMax: 1.8,
            boomChance: 0.05, boomJump: 0.4,
            crashChance: 0.05, crashJump: 0.4
        )
    }

    /// Tuning for the post-launch adoption ramp: sales start slow and reach
    /// the full peak only after `adoptionWeeks`, which shrinks with the
    /// team's marketing skill at launch and with launch hype.
    public struct AdoptionBalance: Codable, Equatable, Sendable {
        /// Ramp length with zero marketing skill and zero hype.
        public var rampWeeksMax: Double
        /// The ramp can never get shorter than this.
        public var rampWeeksMin: Double
        /// Average marketing skill removes `skill / marketingDivisor` weeks.
        public var marketingDivisor: Double
        /// Launch hype removes `hype / hypeDivisor` weeks.
        public var hypeDivisor: Double

        public init(
            rampWeeksMax: Double, rampWeeksMin: Double,
            marketingDivisor: Double, hypeDivisor: Double
        ) {
            self.rampWeeksMax = rampWeeksMax
            self.rampWeeksMin = rampWeeksMin
            self.marketingDivisor = marketingDivisor
            self.hypeDivisor = hypeDivisor
        }

        public static let standard = AdoptionBalance(
            rampWeeksMax: 8, rampWeeksMin: 1, marketingDivisor: 16, hypeDivisor: 25
        )
    }

    /// Tuning for employee morale, performance, seniority, and training.
    public struct StaffBalance: Codable, Equatable, Sendable {
        /// Morale a fresh hire starts with.
        public var startingMorale: Double
        /// Daily fraction morale moves toward its target.
        public var moraleAdaptRate: Double
        /// Morale target before pay and office adjustments.
        public var baselineMorale: Double
        /// Paid under `underpaidThreshold ×` fair pay drags the target down
        /// by `underpaidTargetPenalty`; over `wellPaidThreshold ×` lifts it
        /// by `wellPaidTargetBonus`. Fair pay is the hiring-market rate for
        /// the employee's skills, raised `levelPayExpectation` per level.
        public var underpaidThreshold: Double
        public var underpaidTargetPenalty: Double
        public var wellPaidThreshold: Double
        public var wellPaidTargetBonus: Double
        public var levelPayExpectation: Double
        /// Morale target bonus keyed by `OfficeTier` raw value.
        public var officeMoraleBonus: [String: Double]
        /// Morale below the threshold for more than the streak quits.
        public var quitMoraleThreshold: Double
        public var quitStreakDays: Int
        /// Praise: instant morale boost, at most once per cooldown.
        public var praiseMoraleBoost: Double
        public var praiseCooldownDays: Int
        /// A salary change of fraction f moves morale by `f × raiseFactor`
        /// (raises) or `f × cutFactor` (cuts, f negative so morale drops).
        public var raiseMoraleFactor: Double
        public var cutMoraleFactor: Double
        /// Promotion / demotion: salary change fraction and morale delta.
        public var promotionSalaryBump: Double
        public var promotionMoraleBoost: Double
        public var demotionSalaryCut: Double
        public var demotionMoralePenalty: Double
        /// Morale at which output is exactly 1×; each point above/below
        /// moves output by `performancePerMoralePoint`, clamped to
        /// `performanceMin...performanceMax`.
        public var moraleNeutral: Double
        public var performancePerMoralePoint: Double
        public var performanceMin: Double
        public var performanceMax: Double
        /// Extra output per seniority level above junior.
        public var levelOutputBonus: Double
        /// Training: cash cost, instant boost to the chosen skill, morale
        /// boost, and per-employee cooldown.
        public var trainingCost: Int
        public var trainingSkillBoost: Double
        public var trainingMoraleBoost: Double
        public var trainingCooldownDays: Int

        // MARK: Iteration 5 (WS-D — the answer becomes the policy)

        // Every knob below is gated on a rule or a flag only a founder's
        // own answer can set. The pacing bots never answer a staff moment
        // — the deadline picks strict, which sets neither — so none of
        // these numbers is ever read in a pacing run.

        /// Morale every hired employee loses when a generous rule is
        /// publicly reversed.
        public var policyReversalMoralePenalty: Double
        /// Loyalty the people the rule answered for lose on top of that.
        public var policyReversalLoyaltyPenalty: Double
        /// What every candidate's ask is multiplied by while
        /// `good_leave_policy` is set (a studio with a leave policy is a
        /// cheaper place to say yes to). 1.0 without the flag.
        public var leavePolicyAskFactor: Double
        /// What `teamConflict`'s pick weight is multiplied by while
        /// `remote_friendly` is set. 1 without the flag.
        public var remoteConflictWeightFactor: Double
        /// What weekly bond growth is multiplied by for a friendship with
        /// someone the remote rule answered for — people who never share
        /// a room. 1.0 without the rule.
        public var remoteBondGrowthFactor: Double

        public init(
            startingMorale: Double, moraleAdaptRate: Double, baselineMorale: Double,
            underpaidThreshold: Double, underpaidTargetPenalty: Double,
            wellPaidThreshold: Double, wellPaidTargetBonus: Double,
            levelPayExpectation: Double, officeMoraleBonus: [String: Double],
            quitMoraleThreshold: Double, quitStreakDays: Int,
            praiseMoraleBoost: Double, praiseCooldownDays: Int,
            raiseMoraleFactor: Double, cutMoraleFactor: Double,
            promotionSalaryBump: Double, promotionMoraleBoost: Double,
            demotionSalaryCut: Double, demotionMoralePenalty: Double,
            moraleNeutral: Double, performancePerMoralePoint: Double,
            performanceMin: Double, performanceMax: Double, levelOutputBonus: Double,
            trainingCost: Int, trainingSkillBoost: Double,
            trainingMoraleBoost: Double, trainingCooldownDays: Int,
            policyReversalMoralePenalty: Double = 10,
            policyReversalLoyaltyPenalty: Double = 15,
            leavePolicyAskFactor: Double = 0.95,
            remoteConflictWeightFactor: Double = 2,
            remoteBondGrowthFactor: Double = 0.5
        ) {
            self.startingMorale = startingMorale
            self.moraleAdaptRate = moraleAdaptRate
            self.baselineMorale = baselineMorale
            self.underpaidThreshold = underpaidThreshold
            self.underpaidTargetPenalty = underpaidTargetPenalty
            self.wellPaidThreshold = wellPaidThreshold
            self.wellPaidTargetBonus = wellPaidTargetBonus
            self.levelPayExpectation = levelPayExpectation
            self.officeMoraleBonus = officeMoraleBonus
            self.quitMoraleThreshold = quitMoraleThreshold
            self.quitStreakDays = quitStreakDays
            self.praiseMoraleBoost = praiseMoraleBoost
            self.praiseCooldownDays = praiseCooldownDays
            self.raiseMoraleFactor = raiseMoraleFactor
            self.cutMoraleFactor = cutMoraleFactor
            self.promotionSalaryBump = promotionSalaryBump
            self.promotionMoraleBoost = promotionMoraleBoost
            self.demotionSalaryCut = demotionSalaryCut
            self.demotionMoralePenalty = demotionMoralePenalty
            self.moraleNeutral = moraleNeutral
            self.performancePerMoralePoint = performancePerMoralePoint
            self.performanceMin = performanceMin
            self.performanceMax = performanceMax
            self.levelOutputBonus = levelOutputBonus
            self.trainingCost = trainingCost
            self.trainingSkillBoost = trainingSkillBoost
            self.trainingMoraleBoost = trainingMoraleBoost
            self.trainingCooldownDays = trainingCooldownDays
            self.policyReversalMoralePenalty = policyReversalMoralePenalty
            self.policyReversalLoyaltyPenalty = policyReversalLoyaltyPenalty
            self.leavePolicyAskFactor = leavePolicyAskFactor
            self.remoteConflictWeightFactor = remoteConflictWeightFactor
            self.remoteBondGrowthFactor = remoteBondGrowthFactor
        }

        public static let standard = StaffBalance(
            startingMorale: 70, moraleAdaptRate: 0.04, baselineMorale: 60,
            underpaidThreshold: 0.85, underpaidTargetPenalty: 25,
            wellPaidThreshold: 1.15, wellPaidTargetBonus: 10,
            levelPayExpectation: 0.12,
            officeMoraleBonus: ["garage": 0, "loft": 3, "studio": 6, "campus": 10],
            quitMoraleThreshold: 20, quitStreakDays: 14,
            praiseMoraleBoost: 8, praiseCooldownDays: 7,
            raiseMoraleFactor: 40, cutMoraleFactor: 80,
            promotionSalaryBump: 0.15, promotionMoraleBoost: 15,
            demotionSalaryCut: 0.10, demotionMoralePenalty: 20,
            moraleNeutral: 70, performancePerMoralePoint: 0.005,
            performanceMin: 0.5, performanceMax: 1.15, levelOutputBonus: 0.06,
            trainingCost: 800, trainingSkillBoost: 6,
            trainingMoraleBoost: 4, trainingCooldownDays: 14
        )
    }

    /// Tuning for contract quality: what skill level the client expects and
    /// what a shortfall costs on delivery.
    public struct ContractQualityBalance: Codable, Equatable, Sendable {
        /// Bounds on the uniform required-skill roll before year scaling.
        public var skillMin: Double
        public var skillMax: Double
        /// Required skill rises this much per elapsed year, capped.
        public var skillYearBump: Double
        public var skillCap: Double
        /// Delivery quality score bands (0...100): at or above `great` the
        /// client is delighted, `okay..<great` grumbles (reduced payout),
        /// below `okay` the client rejects the quality (reduced payout and
        /// a reputation hit).
        public var okayThreshold: Int
        public var greatThreshold: Int
        public var okayPayoutFraction: Double
        public var poorPayoutFraction: Double
        public var poorReputationPenalty: Double

        public init(
            skillMin: Double, skillMax: Double, skillYearBump: Double, skillCap: Double,
            okayThreshold: Int, greatThreshold: Int,
            okayPayoutFraction: Double, poorPayoutFraction: Double,
            poorReputationPenalty: Double
        ) {
            self.skillMin = skillMin
            self.skillMax = skillMax
            self.skillYearBump = skillYearBump
            self.skillCap = skillCap
            self.okayThreshold = okayThreshold
            self.greatThreshold = greatThreshold
            self.okayPayoutFraction = okayPayoutFraction
            self.poorPayoutFraction = poorPayoutFraction
            self.poorReputationPenalty = poorReputationPenalty
        }

        public static let standard = ContractQualityBalance(
            skillMin: 25, skillMax: 65, skillYearBump: 5, skillCap: 90,
            okayThreshold: 60, greatThreshold: 80,
            okayPayoutFraction: 0.85, poorPayoutFraction: 0.5,
            poorReputationPenalty: 2.0
        )
    }

    /// Tuning for company loans.
    ///
    /// The ceiling itself is *not* here: it is
    /// `economy.creditLimitBase / creditLimitRevenueFactor /
    /// creditLimitPerReputation`, split into an unsecured share and a share
    /// the founder's home secures. This block used to carry a second,
    /// unused `baseLimit + reputation × perReputation` that only the
    /// Business tab read, so the screen and the bank quietly disagreed
    /// about what could be borrowed; both now go through
    /// `GameState.creditLimit(balance:)`.
    public struct LoanBalance: Codable, Equatable, Sendable {
        /// Interest charged weekly on the outstanding balance.
        public var weeklyInterestRate: Double

        public init(weeklyInterestRate: Double) {
            self.weeklyInterestRate = weeklyInterestRate
        }

        public static let standard = LoanBalance(weeklyInterestRate: 0.01)
    }

    /// Tuning for company depth: how employee roles route build output,
    /// how candidates roll a role, what departments grant, and what office
    /// amenities cost and do. Decoded from the `"company"` block.
    public struct CompanyBalance: Codable, Equatable, Sendable {
        /// Multipliers a role applies to its code / design / polish output
        /// on products (and code / design on contracts).
        public struct RoleYield: Codable, Equatable, Sendable {
            public var code: Double
            public var design: Double
            public var polish: Double

            public init(code: Double, design: Double, polish: Double) {
                self.code = code
                self.design = design
                self.polish = polish
            }

            public static let neutral = RoleYield(code: 1, design: 1, polish: 1)
        }

        public struct AmenityDef: Codable, Equatable, Sendable {
            public var upgradeCost: Int
            public var weeklyCost: Int
            /// The office tier needed to build it.
            public var minTier: OfficeTier
            /// Added to every hired employee's morale target while owned.
            public var moraleBonus: Double
            /// Daily founder health drift while owned.
            public var founderHealthBonus: Double
            /// Extra sub-threshold days before an employee quits.
            public var quitStreakBonusDays: Int

            public init(
                upgradeCost: Int, weeklyCost: Int, minTier: OfficeTier,
                moraleBonus: Double, founderHealthBonus: Double = 0, quitStreakBonusDays: Int = 0
            ) {
                self.upgradeCost = upgradeCost
                self.weeklyCost = weeklyCost
                self.minTier = minTier
                self.moraleBonus = moraleBonus
                self.founderHealthBonus = founderHealthBonus
                self.quitStreakBonusDays = quitStreakBonusDays
            }
        }

        // Roles
        /// Keyed by `EmployeeRole` raw value; a missing role yields 1×.
        public var roleYields: [String: RoleYield]
        /// Bugs fixed per polish point a QA engineer contributes (others
        /// fix one per point).
        public var qaBugFixMultiplier: Double
        /// Hype a marketer assigned to an in-development product adds per
        /// day, scaled by `1 + marketing / 100`.
        public var marketerDailyHype: Double

        // Candidates
        /// Weighted pick at refresh, keyed by `EmployeeRole` raw value
        /// (missing or non-positive: never rolled).
        public var candidateRoleWeights: [String: Int]
        /// Minimum office tier a role appears at, keyed by raw value
        /// (missing: garage).
        public var candidateRoleMinTier: [String: OfficeTier]
        /// Builder roles add this to the roll ceiling of their primary skill.
        public var builderPrimarySkillBonus: Double
        /// Marketers add this to their marketing roll ceiling.
        public var marketerSkillBonus: Double
        /// Salary multiplier for lawyers, HR, and ops.
        public var supportSalaryFactor: Double

        // Departments
        public var legalPenaltyFactor: Double
        public var legalPayoutBonus: Double
        public var legalExtraOffers: Int
        public var hrMoraleBonus: Double
        public var hrRefreshDaysReduction: Int
        public var hrQuitStreakBonus: Int
        public var hrTrainingCostFactor: Double
        public var opsUpkeepFactor: Double
        public var opsRentFactor: Double

        /// Keyed by `Amenity` raw value.
        public var amenities: [String: AmenityDef]

        public init(
            roleYields: [String: RoleYield],
            qaBugFixMultiplier: Double,
            marketerDailyHype: Double,
            candidateRoleWeights: [String: Int],
            candidateRoleMinTier: [String: OfficeTier],
            builderPrimarySkillBonus: Double,
            marketerSkillBonus: Double,
            supportSalaryFactor: Double,
            legalPenaltyFactor: Double,
            legalPayoutBonus: Double,
            legalExtraOffers: Int,
            hrMoraleBonus: Double,
            hrRefreshDaysReduction: Int,
            hrQuitStreakBonus: Int,
            hrTrainingCostFactor: Double,
            opsUpkeepFactor: Double,
            opsRentFactor: Double,
            amenities: [String: AmenityDef]
        ) {
            self.roleYields = roleYields
            self.qaBugFixMultiplier = qaBugFixMultiplier
            self.marketerDailyHype = marketerDailyHype
            self.candidateRoleWeights = candidateRoleWeights
            self.candidateRoleMinTier = candidateRoleMinTier
            self.builderPrimarySkillBonus = builderPrimarySkillBonus
            self.marketerSkillBonus = marketerSkillBonus
            self.supportSalaryFactor = supportSalaryFactor
            self.legalPenaltyFactor = legalPenaltyFactor
            self.legalPayoutBonus = legalPayoutBonus
            self.legalExtraOffers = legalExtraOffers
            self.hrMoraleBonus = hrMoraleBonus
            self.hrRefreshDaysReduction = hrRefreshDaysReduction
            self.hrQuitStreakBonus = hrQuitStreakBonus
            self.hrTrainingCostFactor = hrTrainingCostFactor
            self.opsUpkeepFactor = opsUpkeepFactor
            self.opsRentFactor = opsRentFactor
            self.amenities = amenities
        }

        public func roleYield(_ role: EmployeeRole) -> RoleYield {
            roleYields[role.rawValue] ?? .neutral
        }

        public func candidateMinTier(_ role: EmployeeRole) -> OfficeTier {
            candidateRoleMinTier[role.rawValue] ?? .garage
        }

        public func amenity(_ amenity: Amenity) -> AmenityDef {
            guard let def = amenities[amenity.rawValue] else {
                preconditionFailure("BalanceConfig.company is missing an amenity definition for '\(amenity.rawValue)'")
            }
            return def
        }

        public static let standard = CompanyBalance(
            roleYields: [
                "founder": RoleYield(code: 1.0, design: 1.0, polish: 1.0),
                "frontend": RoleYield(code: 1.1, design: 1.1, polish: 0.9),
                "backend": RoleYield(code: 1.4, design: 0.5, polish: 1.0),
                "designer": RoleYield(code: 0.5, design: 1.5, polish: 1.0),
                "qa": RoleYield(code: 0.6, design: 0.6, polish: 1.6),
                "marketer": RoleYield(code: 0.3, design: 0.3, polish: 0.3),
                "lawyer": RoleYield(code: 0.3, design: 0.3, polish: 0.3),
                "hr": RoleYield(code: 0.3, design: 0.3, polish: 0.3),
                "ops": RoleYield(code: 0.3, design: 0.3, polish: 0.3),
            ],
            qaBugFixMultiplier: 2.0,
            marketerDailyHype: 0.4,
            candidateRoleWeights: [
                "frontend": 22, "backend": 25, "designer": 18, "qa": 12,
                "marketer": 10, "lawyer": 5, "hr": 5, "ops": 3,
            ],
            candidateRoleMinTier: ["lawyer": .loft, "hr": .loft, "ops": .studio],
            builderPrimarySkillBonus: 15,
            marketerSkillBonus: 20,
            supportSalaryFactor: 0.9,
            legalPenaltyFactor: 0.5,
            legalPayoutBonus: 1.10,
            legalExtraOffers: 1,
            hrMoraleBonus: 5,
            hrRefreshDaysReduction: 4,
            hrQuitStreakBonus: 7,
            hrTrainingCostFactor: 0.7,
            opsUpkeepFactor: 0.7,
            opsRentFactor: 0.9,
            amenities: [
                "gameRoom": AmenityDef(
                    upgradeCost: 10_000, weeklyCost: 150, minTier: .loft, moraleBonus: 4
                ),
                "cafeteria": AmenityDef(
                    upgradeCost: 25_000, weeklyCost: 400, minTier: .studio, moraleBonus: 6
                ),
                "shuttle": AmenityDef(
                    upgradeCost: 15_000, weeklyCost: 300, minTier: .studio, moraleBonus: 4,
                    quitStreakBonusDays: 7
                ),
                "gym": AmenityDef(
                    upgradeCost: 30_000, weeklyCost: 350, minTier: .studio, moraleBonus: 5,
                    founderHealthBonus: 0.2
                ),
            ]
        )
    }

    /// How one `Difficulty` rescales the balance. Factors multiply, bonuses
    /// and deltas add; `identity` (all 1× / +0) is what Normal ships with.
    /// Decoded from the `"difficulty"` block, keyed by `Difficulty` raw value.
    public struct RivalBalance: Codable, Equatable, Sendable {
        /// How many rival studios exist at once (folded rivals are
        /// replaced; acquired rivals are not).
        public var rivalCount: Int
        /// Days between evolution steps (strength drift + ship/stumble roll).
        public var evolveIntervalDays: Int
        /// Sigma of the weekly strength random-walk step.
        public var strengthDriftSigma: Double
        /// Chance an evolution step ships a product (dents that topic's
        /// market multiplier by `competitionDent`).
        public var shipChance: Double
        public var competitionDent: Double
        /// Reputation a rival gains when it ships.
        public var shipReputationGain: Double
        /// Chance an evolution step stumbles instead (strength and
        /// reputation drop).
        public var stumbleChance: Double
        public var stumbleStrengthDrop: Double
        public var stumbleReputationDrop: Double
        /// A rival below this strength folds and is replaced.
        public var foldThreshold: Double
        /// Founding rolls: strength and reputation ranges.
        public var foundingStrengthMin: Double
        public var foundingStrengthMax: Double
        public var foundingReputationMin: Double
        public var foundingReputationMax: Double

        /// Poach checks fire on days where `day % poachIntervalDays ==
        /// poachOffsetDays`, at most once per `poachCooldownDays`.
        public var poachIntervalDays: Int
        public var poachOffsetDays: Int
        public var poachCooldownDays: Int
        /// Base chance a check produces an offer, scaled down by the
        /// target's loyalty (`1 - loyalty / loyaltyResistDivisor`).
        public var poachChance: Double
        public var loyaltyResistDivisor: Double
        /// Targeting weights over skill total, underpayment, and low morale.
        public var poachSkillWeight: Double
        public var poachUnderpaidWeight: Double
        public var poachMoraleWeight: Double
        /// Offered salary = fair pay × uniform(premiumMin...premiumMax).
        public var poachPremiumMin: Double
        public var poachPremiumMax: Double
        /// Days the player has to respond before the offer auto-resolves.
        public var poachResponseDays: Int
        /// Loyalty gained when the player matches the offer.
        public var matchLoyaltyBoost: Double

        /// Buyout checks fire on days where `day % buyoutIntervalDays ==
        /// buyoutOffsetDays`, at most once per `buyoutCooldownDays`, and
        /// only while the company looks weak.
        public var buyoutIntervalDays: Int
        public var buyoutOffsetDays: Int
        /// No buyout offer before this day.
        ///
        /// Reputation starts at 10 and `weakRepThreshold` is 20, so without
        /// this a brand-new garage looks "weak" from day one and gets a
        /// distress offer inside its first month — a critical pause, with a
        /// deadline, before the player has shipped anything. Optional so an
        /// older Balance.json still decodes; `nil` means the old behaviour.
        public var buyoutEarliestDay: Int?
        public var buyoutCooldownDays: Int
        public var buyoutChance: Double
        public var weakCashThreshold: Int
        public var weakRepThreshold: Double
        /// Offer = company valuation × uniform(offerFractionMin...Max).
        public var offerFractionMin: Double
        public var offerFractionMax: Double
        public var buyoutResponseDays: Int

        /// Valuation inputs (rival: per strength point; player: revenue
        /// multiple over recent weekly sales plus per reputation point).
        public var valuationPerStrength: Double
        public var valuationRevenueMultiple: Double
        public var valuationPerReputation: Double

        /// Acquiring a rival costs `valuation × acquirePremium` and needs
        /// player valuation ≥ rival valuation × `acquireDominanceFactor`.
        public var acquirePremium: Double
        public var acquireDominanceFactor: Double
        public var acquireRepBonus: Double
        /// Absorbed hires = `strength / absorbDivisor` (capped by headroom).
        public var absorbDivisor: Double

        /// The Category Fight and the Incumbent (WS-A, iteration 5).
        /// Declared with an inline default and read through the
        /// `KeyedDecodingContainer` overload in `BalanceConfig+RivalDepth`,
        /// so a `"rivals"` object without a `"depth"` block still decodes.
        public var depth: DepthBalance = .default

        public init(
            rivalCount: Int,
            evolveIntervalDays: Int,
            strengthDriftSigma: Double,
            shipChance: Double,
            competitionDent: Double,
            shipReputationGain: Double,
            stumbleChance: Double,
            stumbleStrengthDrop: Double,
            stumbleReputationDrop: Double,
            foldThreshold: Double,
            foundingStrengthMin: Double,
            foundingStrengthMax: Double,
            foundingReputationMin: Double,
            foundingReputationMax: Double,
            poachIntervalDays: Int,
            poachOffsetDays: Int,
            poachCooldownDays: Int,
            poachChance: Double,
            loyaltyResistDivisor: Double,
            poachSkillWeight: Double,
            poachUnderpaidWeight: Double,
            poachMoraleWeight: Double,
            poachPremiumMin: Double,
            poachPremiumMax: Double,
            poachResponseDays: Int,
            matchLoyaltyBoost: Double,
            buyoutIntervalDays: Int,
            buyoutOffsetDays: Int,
            buyoutEarliestDay: Int? = nil,
            buyoutCooldownDays: Int,
            buyoutChance: Double,
            weakCashThreshold: Int,
            weakRepThreshold: Double,
            offerFractionMin: Double,
            offerFractionMax: Double,
            buyoutResponseDays: Int,
            valuationPerStrength: Double,
            valuationRevenueMultiple: Double,
            valuationPerReputation: Double,
            acquirePremium: Double,
            acquireDominanceFactor: Double,
            acquireRepBonus: Double,
            absorbDivisor: Double
        ) {
            self.rivalCount = rivalCount
            self.evolveIntervalDays = evolveIntervalDays
            self.strengthDriftSigma = strengthDriftSigma
            self.shipChance = shipChance
            self.competitionDent = competitionDent
            self.shipReputationGain = shipReputationGain
            self.stumbleChance = stumbleChance
            self.stumbleStrengthDrop = stumbleStrengthDrop
            self.stumbleReputationDrop = stumbleReputationDrop
            self.foldThreshold = foldThreshold
            self.foundingStrengthMin = foundingStrengthMin
            self.foundingStrengthMax = foundingStrengthMax
            self.foundingReputationMin = foundingReputationMin
            self.foundingReputationMax = foundingReputationMax
            self.poachIntervalDays = poachIntervalDays
            self.poachOffsetDays = poachOffsetDays
            self.poachCooldownDays = poachCooldownDays
            self.poachChance = poachChance
            self.loyaltyResistDivisor = loyaltyResistDivisor
            self.poachSkillWeight = poachSkillWeight
            self.poachUnderpaidWeight = poachUnderpaidWeight
            self.poachMoraleWeight = poachMoraleWeight
            self.poachPremiumMin = poachPremiumMin
            self.poachPremiumMax = poachPremiumMax
            self.poachResponseDays = poachResponseDays
            self.matchLoyaltyBoost = matchLoyaltyBoost
            self.buyoutIntervalDays = buyoutIntervalDays
            self.buyoutOffsetDays = buyoutOffsetDays
            self.buyoutEarliestDay = buyoutEarliestDay
            self.buyoutCooldownDays = buyoutCooldownDays
            self.buyoutChance = buyoutChance
            self.weakCashThreshold = weakCashThreshold
            self.weakRepThreshold = weakRepThreshold
            self.offerFractionMin = offerFractionMin
            self.offerFractionMax = offerFractionMax
            self.buyoutResponseDays = buyoutResponseDays
            self.valuationPerStrength = valuationPerStrength
            self.valuationRevenueMultiple = valuationRevenueMultiple
            self.valuationPerReputation = valuationPerReputation
            self.acquirePremium = acquirePremium
            self.acquireDominanceFactor = acquireDominanceFactor
            self.acquireRepBonus = acquireRepBonus
            self.absorbDivisor = absorbDivisor
        }

        public static let standard = RivalBalance(
            rivalCount: 4,
            evolveIntervalDays: 7,
            strengthDriftSigma: 2.0,
            shipChance: 0.10,
            competitionDent: 0.08,
            shipReputationGain: 1.5,
            stumbleChance: 0.06,
            stumbleStrengthDrop: 6,
            stumbleReputationDrop: 4,
            foldThreshold: 8,
            foundingStrengthMin: 15,
            foundingStrengthMax: 55,
            foundingReputationMin: 10,
            foundingReputationMax: 50,
            poachIntervalDays: 7,
            poachOffsetDays: 3,
            poachCooldownDays: 21,
            poachChance: 0.35,
            loyaltyResistDivisor: 130,
            poachSkillWeight: 1.0,
            poachUnderpaidWeight: 120,
            poachMoraleWeight: 90,
            poachPremiumMin: 1.15,
            poachPremiumMax: 1.45,
            poachResponseDays: 5,
            matchLoyaltyBoost: 12,
            buyoutIntervalDays: 7,
            buyoutOffsetDays: 5,
            buyoutCooldownDays: 28,
            buyoutChance: 0.4,
            weakCashThreshold: 5000,
            weakRepThreshold: 20,
            offerFractionMin: 0.7,
            offerFractionMax: 1.1,
            buyoutResponseDays: 5,
            valuationPerStrength: 4000,
            valuationRevenueMultiple: 6,
            valuationPerReputation: 1500,
            acquirePremium: 1.3,
            acquireDominanceFactor: 1.5,
            acquireRepBonus: 5,
            absorbDivisor: 25
        )
    }

    public struct CityBalance: Codable, Equatable, Sendable {
        /// One district's costs and perks.
        public struct DistrictDef: Codable, Equatable, Sendable {
            /// Multiplies the office tier's weekly rent.
            public var rentMultiplier: Double
            /// Multiplies purchase and relocation costs.
            public var priceMultiplier: Double
            /// Added to the candidate-refresh skill ceiling.
            public var candidateSkillBonus: Double
            /// Extra weekly contract offers (like `legalExtraOffers`).
            public var extraContractOffers: Int
            /// Weekly reputation drift from the address's prestige.
            public var weeklyReputationDrift: Double
            /// Added to every hired employee's morale target.
            public var moraleBonus: Double

            public init(
                rentMultiplier: Double,
                priceMultiplier: Double,
                candidateSkillBonus: Double,
                extraContractOffers: Int,
                weeklyReputationDrift: Double,
                moraleBonus: Double
            ) {
                self.rentMultiplier = rentMultiplier
                self.priceMultiplier = priceMultiplier
                self.candidateSkillBonus = candidateSkillBonus
                self.extraContractOffers = extraContractOffers
                self.weeklyReputationDrift = weeklyReputationDrift
                self.moraleBonus = moraleBonus
            }

            /// Old Town: the pre-city baseline (multipliers 1, no perks).
            public static let neutral = DistrictDef(
                rentMultiplier: 1, priceMultiplier: 1, candidateSkillBonus: 0,
                extraContractOffers: 0, weeklyReputationDrift: 0, moraleBonus: 0
            )
        }

        /// Keyed by `DistrictID` raw value; a missing key reads as neutral.
        public var districts: [String: DistrictDef]
        /// Buy price = this many weeks of the district-scaled weekly rent.
        public var buyPriceFactor: Double
        /// Weekly tax posted while owned: `propertyValue × rate`.
        public var weeklyPropertyTaxRate: Double
        /// Sigma of the monthly relative property-value step.
        public var propertyDriftSigma: Double
        /// Property value stays within `purchase × min...max` factors.
        public var propertyValueMinFactor: Double
        public var propertyValueMaxFactor: Double
        /// Relocation cost = base × destination price multiplier.
        public var relocationCostBase: Int
        /// Morale hit every hired employee takes on a move.
        public var relocationMoralePenalty: Double

        public init(
            districts: [String: DistrictDef],
            buyPriceFactor: Double,
            weeklyPropertyTaxRate: Double,
            propertyDriftSigma: Double,
            propertyValueMinFactor: Double,
            propertyValueMaxFactor: Double,
            relocationCostBase: Int,
            relocationMoralePenalty: Double
        ) {
            self.districts = districts
            self.buyPriceFactor = buyPriceFactor
            self.weeklyPropertyTaxRate = weeklyPropertyTaxRate
            self.propertyDriftSigma = propertyDriftSigma
            self.propertyValueMinFactor = propertyValueMinFactor
            self.propertyValueMaxFactor = propertyValueMaxFactor
            self.relocationCostBase = relocationCostBase
            self.relocationMoralePenalty = relocationMoralePenalty
        }

        public func district(_ id: DistrictID) -> DistrictDef {
            districts[id.rawValue] ?? .neutral
        }

        public static let standard = CityBalance(
            districts: [
                DistrictID.oldTown.rawValue: DistrictDef(
                    rentMultiplier: 1.0, priceMultiplier: 1.0, candidateSkillBonus: 0,
                    extraContractOffers: 0, weeklyReputationDrift: 0, moraleBonus: 0
                ),
                DistrictID.suburbs.rawValue: DistrictDef(
                    rentMultiplier: 0.7, priceMultiplier: 0.7, candidateSkillBonus: -5,
                    extraContractOffers: 0, weeklyReputationDrift: -0.1, moraleBonus: -2
                ),
                DistrictID.midtown.rawValue: DistrictDef(
                    rentMultiplier: 1.3, priceMultiplier: 1.4, candidateSkillBonus: 5,
                    extraContractOffers: 1, weeklyReputationDrift: 0.1, moraleBonus: 2
                ),
                DistrictID.techPark.rawValue: DistrictDef(
                    rentMultiplier: 1.6, priceMultiplier: 1.8, candidateSkillBonus: 12,
                    extraContractOffers: 1, weeklyReputationDrift: 0.15, moraleBonus: 3
                ),
                DistrictID.downtown.rawValue: DistrictDef(
                    rentMultiplier: 2.2, priceMultiplier: 2.6, candidateSkillBonus: 8,
                    extraContractOffers: 2, weeklyReputationDrift: 0.3, moraleBonus: 5
                ),
            ],
            buyPriceFactor: 150,
            weeklyPropertyTaxRate: 0.002,
            propertyDriftSigma: 0.03,
            propertyValueMinFactor: 0.5,
            propertyValueMaxFactor: 2.0,
            relocationCostBase: 8000,
            relocationMoralePenalty: 5
        )
    }

    public struct InstantLifeBalance: Codable, Equatable, Sendable {
        /// One instant activity's effects: `LifeBalance.ActivityDef` deltas
        /// plus a per-activity cooldown.
        public struct InstantActivityDef: Codable, Equatable, Sendable {
            public var energy: Double
            public var health: Double
            public var mood: Double
            public var relationships: Double
            public var cost: Int
            public var cooldownDays: Int

            public init(
                energy: Double, health: Double, mood: Double,
                relationships: Double, cost: Int, cooldownDays: Int
            ) {
                self.energy = energy
                self.health = health
                self.mood = mood
                self.relationships = relationships
                self.cost = cost
                self.cooldownDays = cooldownDays
            }
        }

        /// A buyable possession: one-time mood pop, then a small daily
        /// mood drift and a prestige term feeding the relationships drift.
        public struct ItemDef: Codable, Equatable, Sendable {
            public var name: String
            public var cost: Int
            public var moodPop: Double
            public var dailyMoodDrift: Double
            public var prestige: Double

            public init(name: String, cost: Int, moodPop: Double, dailyMoodDrift: Double, prestige: Double) {
                self.name = name
                self.cost = cost
                self.moodPop = moodPop
                self.dailyMoodDrift = dailyMoodDrift
                self.prestige = prestige
            }
        }

        /// Instant activities allowed per day (shared cap).
        public var maxPerDay: Int
        /// Keyed by `InstantActivity` raw value.
        public var activities: [String: InstantActivityDef]
        /// The shop catalog, keyed by item id.
        public var items: [String: ItemDef]
        /// Prestige sum × this joins the daily relationships drift.
        public var prestigeRelationshipFactor: Double

        public init(
            maxPerDay: Int,
            activities: [String: InstantActivityDef],
            items: [String: ItemDef],
            prestigeRelationshipFactor: Double
        ) {
            self.maxPerDay = maxPerDay
            self.activities = activities
            self.items = items
            self.prestigeRelationshipFactor = prestigeRelationshipFactor
        }

        public func activity(_ activity: InstantActivity) -> InstantActivityDef? {
            activities[activity.rawValue]
        }

        public static let standard = InstantLifeBalance(
            maxPerDay: 2,
            activities: [
                InstantActivity.gymSession.rawValue: InstantActivityDef(
                    energy: -8, health: 6, mood: 3, relationships: 0, cost: 30, cooldownDays: 1
                ),
                InstantActivity.walk.rawValue: InstantActivityDef(
                    energy: -2, health: 2, mood: 4, relationships: 0, cost: 0, cooldownDays: 1
                ),
                InstantActivity.cinema.rawValue: InstantActivityDef(
                    energy: -3, health: 0, mood: 8, relationships: 2, cost: 40, cooldownDays: 2
                ),
                InstantActivity.restaurant.rawValue: InstantActivityDef(
                    energy: 2, health: -1, mood: 6, relationships: 4, cost: 90, cooldownDays: 2
                ),
            ],
            items: [
                "espressoMachine": ItemDef(
                    name: "Espresso machine", cost: 600, moodPop: 5, dailyMoodDrift: 0.1, prestige: 0
                ),
                "gamingConsole": ItemDef(
                    name: "Gaming console", cost: 900, moodPop: 8, dailyMoodDrift: 0.15, prestige: 0
                ),
                "roadBike": ItemDef(
                    name: "Road bike", cost: 1800, moodPop: 6, dailyMoodDrift: 0.1, prestige: 1
                ),
                "designerWatch": ItemDef(
                    name: "Designer watch", cost: 4000, moodPop: 6, dailyMoodDrift: 0.05, prestige: 2
                ),
                "sportsCar": ItemDef(
                    name: "Sports car", cost: 60000, moodPop: 15, dailyMoodDrift: 0.2, prestige: 6
                ),
            ],
            prestigeRelationshipFactor: 0.02
        )
    }

    public struct SocialBalance: Codable, Equatable, Sendable {
        /// Loyalty drifts toward `50 + (morale − 70) / 2` at this rate.
        public var loyaltyAdaptRate: Double
        /// The quit streak extends by `loyalty / this` days.
        public var loyaltyQuitDivisor: Double
        /// Per-employee cooldown shared by coffee / 1-on-1 / gift.
        public var socialCooldownDays: Int
        public var coffeeCost: Int
        public var coffeeMorale: Double
        public var coffeeLoyalty: Double
        public var oneOnOneLoyalty: Double
        public var giftCost: Int
        public var giftMorale: Double
        public var giftLoyalty: Double
        public var dinnerCostPerHead: Int
        public var dinnerMorale: Double
        public var dinnerLoyalty: Double
        public var teamDinnerCooldownDays: Int
        /// Weekly chance a co-assigned pair without a bond forms one.
        public var bondChance: Double
        public var bondGrowthPerWeek: Double
        public var bondDecayPerWeek: Double
        /// Output factor per point of the strongest co-assigned bond:
        /// `1 + bonus × strength / 100`.
        public var friendshipOutputBonus: Double
        /// Morale a surviving friend loses when their friend is fired or
        /// poached, scaled by bond strength / 100.
        public var friendFiredMoralePenalty: Double
        public var staffEventIntervalDays: Int
        public var staffEventChance: Double
        public var birthdayMoraleBoost: Double
        public var birthdayCakeCost: Int
        public var supportCost: Int
        public var supportMorale: Double
        public var supportLoyalty: Double
        public var strictLoyaltyPenalty: Double
        public var staffEventResponseDays: Int

        public init(
            loyaltyAdaptRate: Double,
            loyaltyQuitDivisor: Double,
            socialCooldownDays: Int,
            coffeeCost: Int,
            coffeeMorale: Double,
            coffeeLoyalty: Double,
            oneOnOneLoyalty: Double,
            giftCost: Int,
            giftMorale: Double,
            giftLoyalty: Double,
            dinnerCostPerHead: Int,
            dinnerMorale: Double,
            dinnerLoyalty: Double,
            teamDinnerCooldownDays: Int,
            bondChance: Double,
            bondGrowthPerWeek: Double,
            bondDecayPerWeek: Double,
            friendshipOutputBonus: Double,
            friendFiredMoralePenalty: Double,
            staffEventIntervalDays: Int,
            staffEventChance: Double,
            birthdayMoraleBoost: Double,
            birthdayCakeCost: Int,
            supportCost: Int,
            supportMorale: Double,
            supportLoyalty: Double,
            strictLoyaltyPenalty: Double,
            staffEventResponseDays: Int
        ) {
            self.loyaltyAdaptRate = loyaltyAdaptRate
            self.loyaltyQuitDivisor = loyaltyQuitDivisor
            self.socialCooldownDays = socialCooldownDays
            self.coffeeCost = coffeeCost
            self.coffeeMorale = coffeeMorale
            self.coffeeLoyalty = coffeeLoyalty
            self.oneOnOneLoyalty = oneOnOneLoyalty
            self.giftCost = giftCost
            self.giftMorale = giftMorale
            self.giftLoyalty = giftLoyalty
            self.dinnerCostPerHead = dinnerCostPerHead
            self.dinnerMorale = dinnerMorale
            self.dinnerLoyalty = dinnerLoyalty
            self.teamDinnerCooldownDays = teamDinnerCooldownDays
            self.bondChance = bondChance
            self.bondGrowthPerWeek = bondGrowthPerWeek
            self.bondDecayPerWeek = bondDecayPerWeek
            self.friendshipOutputBonus = friendshipOutputBonus
            self.friendFiredMoralePenalty = friendFiredMoralePenalty
            self.staffEventIntervalDays = staffEventIntervalDays
            self.staffEventChance = staffEventChance
            self.birthdayMoraleBoost = birthdayMoraleBoost
            self.birthdayCakeCost = birthdayCakeCost
            self.supportCost = supportCost
            self.supportMorale = supportMorale
            self.supportLoyalty = supportLoyalty
            self.strictLoyaltyPenalty = strictLoyaltyPenalty
            self.staffEventResponseDays = staffEventResponseDays
        }

        public static let standard = SocialBalance(
            loyaltyAdaptRate: 0.03,
            loyaltyQuitDivisor: 10,
            socialCooldownDays: 7,
            coffeeCost: 20,
            coffeeMorale: 3,
            coffeeLoyalty: 3,
            oneOnOneLoyalty: 8,
            giftCost: 250,
            giftMorale: 8,
            giftLoyalty: 10,
            dinnerCostPerHead: 60,
            dinnerMorale: 6,
            dinnerLoyalty: 4,
            teamDinnerCooldownDays: 14,
            bondChance: 0.15,
            bondGrowthPerWeek: 4,
            bondDecayPerWeek: 2,
            friendshipOutputBonus: 0.08,
            friendFiredMoralePenalty: 18,
            staffEventIntervalDays: 21,
            staffEventChance: 0.5,
            birthdayMoraleBoost: 6,
            birthdayCakeCost: 100,
            supportCost: 500,
            supportMorale: 6,
            supportLoyalty: 12,
            strictLoyaltyPenalty: 10,
            staffEventResponseDays: 5
        )
    }

    public struct DifficultyBalance: Codable, Equatable, Sendable {
        /// × `startingCash`.
        public var startingCashFactor: Double
        /// × `weeklyOperatingCost`.
        public var operatingCostFactor: Double
        /// × every office tier's `weeklyRent` and `upgradeCost`.
        public var officeCostFactor: Double
        /// × `salaryBase` and `salaryPerSkillPoint` (so fair-pay
        /// expectations move with the hiring market).
        public var salaryFactor: Double
        /// × `marketSizeScale` (sales) and `contractPayoutPerPoint`.
        public var revenueFactor: Double
        /// + `reviewExpectationBase`.
        public var reviewExpectationBonus: Double
        /// + `bankruptcyGraceDays`.
        public var bankruptcyGraceDaysDelta: Int
        /// + `candidateSkillBase`.
        public var candidateSkillBonus: Double
        /// × `life.hospitalBill` and every home tier's `weeklyRent`.
        public var lifeCostFactor: Double

        public init(
            startingCashFactor: Double, operatingCostFactor: Double, officeCostFactor: Double,
            salaryFactor: Double, revenueFactor: Double, reviewExpectationBonus: Double,
            bankruptcyGraceDaysDelta: Int, candidateSkillBonus: Double, lifeCostFactor: Double
        ) {
            self.startingCashFactor = startingCashFactor
            self.operatingCostFactor = operatingCostFactor
            self.officeCostFactor = officeCostFactor
            self.salaryFactor = salaryFactor
            self.revenueFactor = revenueFactor
            self.reviewExpectationBonus = reviewExpectationBonus
            self.bankruptcyGraceDaysDelta = bankruptcyGraceDaysDelta
            self.candidateSkillBonus = candidateSkillBonus
            self.lifeCostFactor = lifeCostFactor
        }

        /// Changes nothing — Normal.
        public static let identity = DifficultyBalance(
            startingCashFactor: 1, operatingCostFactor: 1, officeCostFactor: 1,
            salaryFactor: 1, revenueFactor: 1, reviewExpectationBonus: 0,
            bankruptcyGraceDaysDelta: 0, candidateSkillBonus: 0, lifeCostFactor: 1
        )

        /// The shipped easy / normal / hard table.
        public static let standardTable: [String: DifficultyBalance] = [
            Difficulty.easy.rawValue: DifficultyBalance(
                startingCashFactor: 1.5, operatingCostFactor: 0.8, officeCostFactor: 0.8,
                salaryFactor: 0.9, revenueFactor: 1.25, reviewExpectationBonus: -5,
                bankruptcyGraceDaysDelta: 7, candidateSkillBonus: 10, lifeCostFactor: 0.8
            ),
            Difficulty.normal.rawValue: .identity,
            Difficulty.hard.rawValue: DifficultyBalance(
                startingCashFactor: 0.7, operatingCostFactor: 1.3, officeCostFactor: 1.25,
                salaryFactor: 1.15, revenueFactor: 0.8, reviewExpectationBonus: 6,
                bankruptcyGraceDaysDelta: -4, candidateSkillBonus: -5, lifeCostFactor: 1.2
            ),
        ]
    }

    /// Weights of the three point pools in the ship-quality formula.
    public struct QualityWeights: Codable, Equatable, Sendable {
        public var design: Double
        public var code: Double
        public var polish: Double

        public init(design: Double, code: Double, polish: Double) {
            self.design = design
            self.code = code
            self.polish = polish
        }
    }

    // MARK: - Finance

    public var startingCash: Int
    public var weeklyOperatingCost: Int
    public var bankruptcyGraceDays: Int
    /// Keyed by `OfficeTier` raw value.
    public var offices: [String: OfficeDef]

    // MARK: - Product development

    /// Base probability that a completed code point introduces a bug.
    public var bugChanceBase: Double
    /// Divisor applied to coding skill in the bug-chance formula.
    public var bugChanceSkillDivisor: Double
    /// The founder's starting coding skill (also the bug-roll fallback when
    /// no employees are assigned to a product).
    public var founderCoding: Double
    /// Fraction of the type's required code points needed before shipping.
    public var shipCodeThreshold: Double
    public var qualityWeights: QualityWeights
    /// Maximum fraction of quality that open bugs can destroy.
    public var bugPenaltyCap: Double

    // MARK: - Employees & hiring

    /// The founder's starting design skill.
    public var founderDesign: Double
    /// The founder's starting marketing skill.
    public var founderMarketing: Double
    /// Skill-independent daily points every assigned employee produces.
    public var employeeBasePoints: Double
    /// Divisor turning the relevant skill into extra daily points.
    public var skillYieldDivisor: Double
    /// Daily growth applied to each skill that fed a pool, scaled by
    /// `1 - skill/100` and capped at 100.
    public var skillGrowthRate: Double
    /// The candidate pool is replaced every this many days.
    public var candidateRefreshDays: Int
    /// Bounds on how many candidates each refresh rolls.
    public var candidateCountMin: Int
    public var candidateCountMax: Int
    /// Skill roll ceiling before reputation and office-tier bonuses.
    public var candidateSkillBase: Double
    /// Ceiling gained per point of company reputation.
    public var candidateSkillPerReputation: Double
    /// Ceiling bonus keyed by `OfficeTier` raw value.
    public var candidateSkillTierBonus: [String: Double]
    /// Weekly salary floor before the per-skill component.
    public var salaryBase: Int
    /// Weekly salary added per total skill point.
    public var salaryPerSkillPoint: Double
    /// Uniform relative jitter (+/-) applied to a rolled salary.
    public var salaryJitter: Double

    // MARK: - Research

    /// Skill-independent daily research points every researcher generates.
    public var researchBasePoints: Double
    /// Divisor turning coding skill into extra daily research points.
    public var researchCodingDivisor: Double
    /// Divisor turning design skill into extra daily research points.
    public var researchDesignDivisor: Double
    /// Upper bound on the tech quality multiplier (1 + summed bonuses).
    public var techQualityMultiplierCap: Double

    // MARK: - Reviews

    public var reviewNoiseSigma: Double
    public var reviewFloor: Int
    public var reviewCeiling: Int
    public var reviewOutlets: [String]

    // MARK: - Sales

    public var salesBaseFactor: Double
    public var salesQualityFactor: Double
    public var salesDecayBase: Double
    public var salesDecayQualityFactor: Double
    /// A released product delists once weekly units fall below this fraction of peak.
    public var delistFraction: Double
    /// Fraction by which reputation moves toward the average review score per launch.
    public var reputationReviewNudge: Double
    /// Engine-side multiplier on every product type's `marketSize` (the
    /// content package is read-only, so the economy is scaled here).
    public var marketSizeScale: Double

    // MARK: - Launch saturation & genre fatigue

    /// Each of the studio's own releases in the same topic within
    /// `saturationWindowDays` multiplies the next launch's sales peak by
    /// this factor, never below `saturationFloor`.
    public var saturationPerRelease: Double
    public var saturationFloor: Double
    public var saturationWindowDays: Int
    /// Each release of the same product type within
    /// `genreFatigueWindowDays` multiplies the next launch's peak by this
    /// factor (same floor).
    public var genreFatigueFactor: Double
    public var genreFatigueWindowDays: Int

    // MARK: - Contracts

    /// The offer sheet is replaced (and un-accepted offers expire) every this many days.
    public var contractOfferRefreshDays: Int
    /// Offers rolled per refresh.
    public var contractOfferCount: Int
    /// Bounds on an offer's total point roll before year scaling.
    public var contractPtsMin: Double
    public var contractPtsMax: Double
    /// Bounds on the uniform fraction of total points that lands in code.
    public var contractCodeSplitMin: Double
    public var contractCodeSplitMax: Double
    /// Dollars per total point before the urgency premium.
    public var contractPayoutPerPoint: Double
    /// Bounds on the uniform urgency premium multiplying the payout.
    public var contractUrgencyPremiumMin: Double
    public var contractUrgencyPremiumMax: Double
    /// Fraction of the payout owed when a deadline is missed.
    public var contractPenaltyFraction: Double
    /// Points per day the deadline budget assumes.
    public var contractDeadlinePtsPerDay: Double
    /// Bounds on the uniform slack multiplying the deadline budget.
    public var contractDeadlineSlackMin: Double
    public var contractDeadlineSlackMax: Double
    /// The point-roll range grows by this fraction per elapsed year.
    public var contractYearScale: Double
    /// Reputation gained on completion / lost on a missed deadline.
    public var contractReputationReward: Double
    public var contractReputationPenalty: Double

    // MARK: - Marketing & hype

    /// Social pushes have no upfront cost; they bill this much per active day…
    public var socialPushDailyCost: Int
    /// …for this many days…
    public var socialPushDurationDays: Int
    /// …adding this much hype each of those days.
    public var socialPushDailyHype: Double
    /// Press releases: one-shot cost and immediate hype.
    public var pressReleaseCost: Int
    public var pressReleaseHype: Double
    /// Launch events: one-shot cost and immediate hype.
    public var launchEventCost: Int
    public var launchEventHype: Double
    /// Minimum `OfficeTier` raw value required to throw a launch event.
    public var launchEventMinTier: String
    /// Daily multiplicative hype decay on in-development products,
    /// applied before the day's campaign additions.
    public var hypeDecayRate: Double

    // MARK: - Review expectations

    /// The press grades against `base + perYear * (year - 1) + repFactor * reputation`.
    public var reviewExpectationBase: Double
    public var reviewExpectationPerYear: Double
    public var reviewExpectationRepFactor: Double
    /// Fraction of the expectation shortfall subtracted from the score.
    public var reviewShortfallPenalty: Double
    /// Launch hype adds `hypeAtLaunch / reviewHypeDivisor` review points.
    public var reviewHypeDivisor: Double

    // MARK: - Hype-driven sales

    /// The sales peak gains `1 + hypeAtLaunch * carry / salesHypeDivisor`.
    public var hypeLaunchCarryFraction: Double
    public var salesHypeDivisor: Double

    // MARK: - Random events

    /// The event system rolls every this many days (`day % interval == 0`).
    public var eventCheckIntervalDays: Int
    /// Probability that an interval day's roll fires an event.
    public var eventChance: Double

    // MARK: - Founder life

    public var life: LifeBalance

    // MARK: - Dynamics (market, adoption, staff, contract quality, loans)

    public var market: MarketBalance
    public var adoption: AdoptionBalance
    public var staff: StaffBalance
    public var contractQuality: ContractQualityBalance
    public var loans: LoanBalance

    // MARK: - Company depth (roles, departments, amenities)

    public var company: CompanyBalance

    // MARK: - Rivals

    public var rivals: RivalBalance

    // MARK: - City

    public var city: CityBalance

    // MARK: - Instant life

    public var instantLife: InstantLifeBalance

    // MARK: - Social

    public var social: SocialBalance

    // MARK: - Market history

    /// Weeks of per-topic multiplier history `MarketState.history` keeps.
    public var marketHistoryWeeks: Int
    /// Booms and crashes `MarketState.recentEvents` keeps.
    public var marketEventLogCap: Int

    // MARK: - Difficulty

    /// Per-difficulty rescaling, keyed by `Difficulty` raw value. A missing
    /// key reads as `DifficultyBalance.identity`.
    public var difficulty: [String: DifficultyBalance]

    // MARK: - Workstream blocks

    // One block per workstream, each defined in its own
    // `BalanceConfig+X.swift` and tuned in its own `Balance.json` object,
    // so six branches never edit the same balance line. An absent block
    // decodes as `.default`.

    /// Economy, live ops and pacing (WS-A).
    public var economy: EconomyBalance
    /// Narrative cadences and choice deadlines (WS-B).
    public var narrative: NarrativeBalance
    /// Chapters, goals and archetypes (WS-F).
    public var progression: ProgressionBalance
    /// Rounds, board pressure and the IPO gate (WS-F).
    public var investors: InvestorBalance
    /// Employee trait strengths (WS-F).
    public var traits: TraitBalance
    /// The founder's own attributes and what training them costs.
    public var founder: FounderBalance
    /// The networking floor: who is in the room and what a deal costs.
    public var networking: NetworkingBalance
    /// A partner who needs tending, and a team that can become friends.
    public var relationships: RelationshipBalance
    /// What a shipped product leaves behind: the head start, the debt, and
    /// what refactoring buys back.
    ///
    /// Declared with an inline default rather than as an `init` parameter,
    /// which is what makes the `"codebase"` key genuinely optional in the
    /// synthesized decode (every other block above is required by
    /// `Balance.json` whatever its `init` default says). Construct a
    /// custom one by assigning to the property.
    public var codebase: CodebaseBalance = .default

    // MARK: Iteration 5 blocks

    // Same rule as `codebase`: an inline default keeps the key optional.
    // Lanes whose knobs belong to an existing block (rivals, investors,
    // staff, narrative, relationships) add them there instead.

    /// Rival-sponsored white-label contracts (WS-C).
    public var sponsoredContracts: SponsoredContractBalance = .default
    /// The four founding origins' day-0 deltas (WS-H).
    public var origins: OriginBalance = .default

    // MARK: Iteration 9 blocks

    // MARK: L5 (side project)
    /// The five side-project tracks and their chapters. Inline default,
    /// like `codebase` above, so `"sideProject"` stays an optional key —
    /// and behind `.startSideProject`, so a run that never starts one
    /// never reads it.
    public var sideProject: SideProjectBalance = .default
    // MARK: end L5 (side project)
    // MARK: Iteration 9 — the Life tab

    // Same rule again: an inline default keeps each key optional, and
    // each lane owns the type behind its own property (see the
    // `BalanceConfig+<lane>.swift` file named for it).

    // MARK: L2 (life score)

    /// What the founder's life is graded out of, and the gates on the
    /// *Walked away* ending (`BalanceConfig+LifeScore.swift`). Read only
    /// by `LifeScore`, which nothing in the simulation calls.
    public var lifeScore: LifeScoreBalance = .default

    // MARK: end of Iteration 9
    // MARK: Iteration 9 — L6 (sabbatical)

    /// Handing the company to somebody else for a summer. Inline default,
    /// like `codebase` above, so `"sabbatical"` is an optional key.
    public var sabbatical: SabbaticalBalance = .default

    // MARK: end Iteration 9 — L6

    // MARK: Iteration 10 blocks

    // MARK: M1 (feature board)

    /// What a placed feature card is worth
    /// (`BalanceConfig+FeatureBoard.swift`). Inline default, so
    /// `"featureBoard"` is an optional key; and the multiplier it feeds is
    /// exactly 1.0 for an empty board, so a run that places no card never
    /// reads a number that matters.
    public var featureBoard: FeatureBoardBalance = .default

    // MARK: end M1 (feature board)
    // MARK: Iteration 10 — one property per lane; the type behind it lives
    // in the `BalanceConfig+<lane>.swift` file named for it.

    // MARK: M2 (pitch room)

    /// What a conversation with an investor, a client, a journalist or
    /// the board can move (`BalanceConfig+Pitch.swift`). Every span is a
    /// swing around zero warmth, so this block cannot change a run that
    /// never opens the room. Inline default, so `"pitch"` is optional.
    public var pitch: PitchBalance = .default

    // MARK: end of Iteration 10
    // MARK: Iteration 10 — M3 (incident room)

    /// When a live product breaks, and what the room can do about it
    /// (`BalanceConfig+Incidents.swift`). Inline default, like `codebase`
    /// above, so `"incidents"` is an optional key — and behind a gate only
    /// the app opens, so a run that never opens the Products tab never
    /// reads a value from it.
    public var incidents: IncidentBalance = .default

    // MARK: end Iteration 10 — M3
    // MARK: Iteration 10 — M6 (bug hunt)

    /// The thumb on the bug: how many a day, and how many crawl at once
    /// (`BalanceConfig+BugHunt.swift`). Inline default, so `"bugHunt"` is
    /// an optional key; read only when the player taps one.
    public var bugHunt: BugHuntBalance = .default

    // MARK: end Iteration 10 — M6

    // MARK: Iteration 11 — N5 (office secrets)

    /// What the office keeps from the founder: when a thread starts, how
    /// fast it burns, and what each answer costs
    /// (`BalanceConfig+OfficeSecrets.swift`). Inline default, so
    /// `"officeSecrets"` is an optional key — and behind a gate only the
    /// Team tab opens, so a run that never looks at the team never reads a
    /// value from it.
    public var officeSecrets: OfficeSecretsBalance = .default

    // MARK: end Iteration 11 — N5
    // MARK: Iteration 11 — N4 (fame and the feed)

    /// What a post reaches, what reach is worth, and what fame buys
    /// (`BalanceConfig+Fame.swift`). Inline default, so `"fame"` is an
    /// optional key; every number in it is read only once the founder has
    /// posted at least once.
    public var fame: FameBalance = .default

    // MARK: end Iteration 11 — N4
    // MARK: Iteration 11 — N1 (crime and the courtroom)

    /// What the six offences are worth, how likely they are to be found,
    /// and how a courtroom grades three exchanges
    /// (`BalanceConfig+Crime.swift`). Inline default, so `"crime"` is an
    /// optional key; every field is read only from behind a button no bot
    /// presses.
    public var crime: CrimeBalance = .default

    // MARK: end Iteration 11 — N1
    // MARK: Iteration 11 — N3 (assets, vices and the doctor)

    /// The catalog of everything the founder can own, catch, treat or
    /// become dependent on (`BalanceConfig+Assets.swift`). Inline default,
    /// so `"assets"` is an optional key — and read only from
    /// `AssetsSystem`, which stands down entirely until the player opens
    /// the Assets screen.
    public var assets: AssetsBalance = .default

    // MARK: end Iteration 11 — N3

    // MARK: Iteration 11, wave two — W3 (espionage)

    /// What it costs to have something done to a rival, how likely it is
    /// to land and how likely it is to come back
    /// (`BalanceConfig+Espionage.swift`). Inline default, so `"espionage"`
    /// is an optional key; every field is read from behind a button on a
    /// rival's page, or from behind the Team tab's own gate.
    public var espionage: EspionageBalance = .default

    // MARK: end Iteration 11, wave two — W3

    public init(
        startingCash: Int,
        weeklyOperatingCost: Int,
        bankruptcyGraceDays: Int,
        offices: [String: OfficeDef],
        bugChanceBase: Double,
        bugChanceSkillDivisor: Double,
        founderCoding: Double,
        shipCodeThreshold: Double,
        qualityWeights: QualityWeights,
        bugPenaltyCap: Double,
        founderDesign: Double,
        founderMarketing: Double,
        employeeBasePoints: Double,
        skillYieldDivisor: Double,
        skillGrowthRate: Double,
        candidateRefreshDays: Int,
        candidateCountMin: Int,
        candidateCountMax: Int,
        candidateSkillBase: Double,
        candidateSkillPerReputation: Double,
        candidateSkillTierBonus: [String: Double],
        salaryBase: Int,
        salaryPerSkillPoint: Double,
        salaryJitter: Double,
        researchBasePoints: Double,
        researchCodingDivisor: Double,
        researchDesignDivisor: Double,
        techQualityMultiplierCap: Double,
        reviewNoiseSigma: Double,
        reviewFloor: Int,
        reviewCeiling: Int,
        reviewOutlets: [String],
        salesBaseFactor: Double,
        salesQualityFactor: Double,
        salesDecayBase: Double,
        salesDecayQualityFactor: Double,
        delistFraction: Double,
        reputationReviewNudge: Double,
        contractOfferRefreshDays: Int,
        contractOfferCount: Int,
        contractPtsMin: Double,
        contractPtsMax: Double,
        contractCodeSplitMin: Double,
        contractCodeSplitMax: Double,
        contractPayoutPerPoint: Double,
        contractUrgencyPremiumMin: Double,
        contractUrgencyPremiumMax: Double,
        contractPenaltyFraction: Double,
        contractDeadlinePtsPerDay: Double,
        contractDeadlineSlackMin: Double,
        contractDeadlineSlackMax: Double,
        contractYearScale: Double,
        contractReputationReward: Double,
        contractReputationPenalty: Double,
        socialPushDailyCost: Int,
        socialPushDurationDays: Int,
        socialPushDailyHype: Double,
        pressReleaseCost: Int,
        pressReleaseHype: Double,
        launchEventCost: Int,
        launchEventHype: Double,
        launchEventMinTier: String,
        hypeDecayRate: Double,
        reviewExpectationBase: Double,
        reviewExpectationPerYear: Double,
        reviewExpectationRepFactor: Double,
        reviewShortfallPenalty: Double,
        reviewHypeDivisor: Double,
        hypeLaunchCarryFraction: Double,
        salesHypeDivisor: Double,
        eventCheckIntervalDays: Int,
        eventChance: Double,
        life: LifeBalance,
        market: MarketBalance = .standard,
        adoption: AdoptionBalance = .standard,
        staff: StaffBalance = .standard,
        contractQuality: ContractQualityBalance = .standard,
        loans: LoanBalance = .standard,
        company: CompanyBalance = .standard,
        rivals: RivalBalance = .standard,
        city: CityBalance = .standard,
        instantLife: InstantLifeBalance = .standard,
        social: SocialBalance = .standard,
        marketSizeScale: Double = 1,
        saturationPerRelease: Double = 1,
        saturationFloor: Double = 0.3,
        saturationWindowDays: Int = 182,
        genreFatigueFactor: Double = 1,
        genreFatigueWindowDays: Int = 84,
        marketHistoryWeeks: Int = 26,
        marketEventLogCap: Int = 30,
        difficulty: [String: DifficultyBalance] = DifficultyBalance.standardTable,
        economy: EconomyBalance = .default,
        narrative: NarrativeBalance = .default,
        progression: ProgressionBalance = .default,
        investors: InvestorBalance = .default,
        traits: TraitBalance = .default,
        founder: FounderBalance = .default,
        networking: NetworkingBalance = .default,
        relationships: RelationshipBalance = .default
    ) {
        self.startingCash = startingCash
        self.weeklyOperatingCost = weeklyOperatingCost
        self.bankruptcyGraceDays = bankruptcyGraceDays
        self.offices = offices
        self.bugChanceBase = bugChanceBase
        self.bugChanceSkillDivisor = bugChanceSkillDivisor
        self.founderCoding = founderCoding
        self.shipCodeThreshold = shipCodeThreshold
        self.qualityWeights = qualityWeights
        self.bugPenaltyCap = bugPenaltyCap
        self.founderDesign = founderDesign
        self.founderMarketing = founderMarketing
        self.employeeBasePoints = employeeBasePoints
        self.skillYieldDivisor = skillYieldDivisor
        self.skillGrowthRate = skillGrowthRate
        self.candidateRefreshDays = candidateRefreshDays
        self.candidateCountMin = candidateCountMin
        self.candidateCountMax = candidateCountMax
        self.candidateSkillBase = candidateSkillBase
        self.candidateSkillPerReputation = candidateSkillPerReputation
        self.candidateSkillTierBonus = candidateSkillTierBonus
        self.salaryBase = salaryBase
        self.salaryPerSkillPoint = salaryPerSkillPoint
        self.salaryJitter = salaryJitter
        self.researchBasePoints = researchBasePoints
        self.researchCodingDivisor = researchCodingDivisor
        self.researchDesignDivisor = researchDesignDivisor
        self.techQualityMultiplierCap = techQualityMultiplierCap
        self.reviewNoiseSigma = reviewNoiseSigma
        self.reviewFloor = reviewFloor
        self.reviewCeiling = reviewCeiling
        self.reviewOutlets = reviewOutlets
        self.salesBaseFactor = salesBaseFactor
        self.salesQualityFactor = salesQualityFactor
        self.salesDecayBase = salesDecayBase
        self.salesDecayQualityFactor = salesDecayQualityFactor
        self.delistFraction = delistFraction
        self.reputationReviewNudge = reputationReviewNudge
        self.contractOfferRefreshDays = contractOfferRefreshDays
        self.contractOfferCount = contractOfferCount
        self.contractPtsMin = contractPtsMin
        self.contractPtsMax = contractPtsMax
        self.contractCodeSplitMin = contractCodeSplitMin
        self.contractCodeSplitMax = contractCodeSplitMax
        self.contractPayoutPerPoint = contractPayoutPerPoint
        self.contractUrgencyPremiumMin = contractUrgencyPremiumMin
        self.contractUrgencyPremiumMax = contractUrgencyPremiumMax
        self.contractPenaltyFraction = contractPenaltyFraction
        self.contractDeadlinePtsPerDay = contractDeadlinePtsPerDay
        self.contractDeadlineSlackMin = contractDeadlineSlackMin
        self.contractDeadlineSlackMax = contractDeadlineSlackMax
        self.contractYearScale = contractYearScale
        self.contractReputationReward = contractReputationReward
        self.contractReputationPenalty = contractReputationPenalty
        self.socialPushDailyCost = socialPushDailyCost
        self.socialPushDurationDays = socialPushDurationDays
        self.socialPushDailyHype = socialPushDailyHype
        self.pressReleaseCost = pressReleaseCost
        self.pressReleaseHype = pressReleaseHype
        self.launchEventCost = launchEventCost
        self.launchEventHype = launchEventHype
        self.launchEventMinTier = launchEventMinTier
        self.hypeDecayRate = hypeDecayRate
        self.reviewExpectationBase = reviewExpectationBase
        self.reviewExpectationPerYear = reviewExpectationPerYear
        self.reviewExpectationRepFactor = reviewExpectationRepFactor
        self.reviewShortfallPenalty = reviewShortfallPenalty
        self.reviewHypeDivisor = reviewHypeDivisor
        self.hypeLaunchCarryFraction = hypeLaunchCarryFraction
        self.salesHypeDivisor = salesHypeDivisor
        self.eventCheckIntervalDays = eventCheckIntervalDays
        self.eventChance = eventChance
        self.life = life
        self.market = market
        self.adoption = adoption
        self.staff = staff
        self.contractQuality = contractQuality
        self.loans = loans
        self.company = company
        self.rivals = rivals
        self.city = city
        self.instantLife = instantLife
        self.social = social
        self.marketSizeScale = marketSizeScale
        self.saturationPerRelease = saturationPerRelease
        self.saturationFloor = saturationFloor
        self.saturationWindowDays = saturationWindowDays
        self.genreFatigueFactor = genreFatigueFactor
        self.genreFatigueWindowDays = genreFatigueWindowDays
        self.marketHistoryWeeks = marketHistoryWeeks
        self.marketEventLogCap = marketEventLogCap
        self.difficulty = difficulty
        self.economy = economy
        self.narrative = narrative
        self.progression = progression
        self.investors = investors
        self.traits = traits
        self.founder = founder
        self.networking = networking
        self.relationships = relationships
    }

    public func office(_ tier: OfficeTier) -> OfficeDef {
        guard let def = offices[tier.rawValue] else {
            preconditionFailure("BalanceConfig is missing an office definition for tier '\(tier.rawValue)'")
        }
        return def
    }

    /// Shorthand for `life.home(tier)`.
    public func home(_ tier: HomeTier) -> LifeBalance.HomeDef {
        life.home(tier)
    }

    /// A copy rescaled for `difficulty` per its `difficulty` block (an
    /// absent block reads as identity, so Normal — and any balance without
    /// the block — comes back equal to `self`). Pure: the receiver is never
    /// mutated, and the RNG-facing cadences (refresh intervals, roll counts,
    /// ranges that decide whether a word is drawn) are deliberately not on
    /// the list, so a seed walks the same random path on every difficulty.
    public func adjusted(for difficulty: Difficulty) -> BalanceConfig {
        let scale = self.difficulty[difficulty.rawValue] ?? .identity
        func scaled(_ value: Int, by factor: Double) -> Int {
            Int((Double(value) * factor).rounded())
        }

        var copy = self
        copy.startingCash = scaled(startingCash, by: scale.startingCashFactor)
        copy.weeklyOperatingCost = scaled(weeklyOperatingCost, by: scale.operatingCostFactor)
        copy.bankruptcyGraceDays = bankruptcyGraceDays + scale.bankruptcyGraceDaysDelta
        for (tier, office) in offices {
            copy.offices[tier] = OfficeDef(
                upgradeCost: scaled(office.upgradeCost, by: scale.officeCostFactor),
                weeklyRent: scaled(office.weeklyRent, by: scale.officeCostFactor),
                headcountCap: office.headcountCap
            )
        }
        copy.salaryBase = scaled(salaryBase, by: scale.salaryFactor)
        copy.salaryPerSkillPoint = salaryPerSkillPoint * scale.salaryFactor
        copy.marketSizeScale = marketSizeScale * scale.revenueFactor
        copy.contractPayoutPerPoint = contractPayoutPerPoint * scale.revenueFactor
        copy.reviewExpectationBase = reviewExpectationBase + scale.reviewExpectationBonus
        copy.candidateSkillBase = candidateSkillBase + scale.candidateSkillBonus
        // Rival money values track the revenue economy; cadences and
        // chances deliberately stay so the world stream walks the same
        // path on every difficulty.
        copy.rivals.valuationPerStrength = rivals.valuationPerStrength * scale.revenueFactor
        copy.rivals.valuationPerReputation = rivals.valuationPerReputation * scale.revenueFactor
        copy.rivals.weakCashThreshold = scaled(rivals.weakCashThreshold, by: scale.startingCashFactor)
        // City money values track office costs; multipliers are ratios and
        // stay put.
        copy.city.relocationCostBase = scaled(city.relocationCostBase, by: scale.officeCostFactor)
        // Instant-life prices track the founder's cost of living.
        for (id, activity) in instantLife.activities {
            copy.instantLife.activities[id]?.cost = scaled(activity.cost, by: scale.lifeCostFactor)
        }
        for (id, item) in instantLife.items {
            copy.instantLife.items[id]?.cost = scaled(item.cost, by: scale.lifeCostFactor)
        }
        // Social costs are company money; track operating costs.
        copy.social.coffeeCost = scaled(social.coffeeCost, by: scale.operatingCostFactor)
        copy.social.giftCost = scaled(social.giftCost, by: scale.operatingCostFactor)
        copy.social.dinnerCostPerHead = scaled(social.dinnerCostPerHead, by: scale.operatingCostFactor)
        copy.social.birthdayCakeCost = scaled(social.birthdayCakeCost, by: scale.operatingCostFactor)
        copy.social.supportCost = scaled(social.supportCost, by: scale.operatingCostFactor)
        copy.life.hospitalBill = scaled(life.hospitalBill, by: scale.lifeCostFactor)
        for (tier, home) in life.homes {
            copy.life.homes[tier] = LifeBalance.HomeDef(
                upgradeCost: home.upgradeCost,
                weeklyRent: scaled(home.weeklyRent, by: scale.lifeCostFactor),
                moodBonus: home.moodBonus
            )
        }
        return copy
    }

    /// The weekly pay an employee considers fair: the candidate-market
    /// rate for their skills, raised by `staff.levelPayExpectation` per
    /// seniority level. Pay below `staff.underpaidThreshold` of it drags
    /// morale toward the door; above `staff.wellPaidThreshold` lifts it.
    public func fairWeeklyPay(for employee: Employee) -> Double {
        (Double(salaryBase) + salaryPerSkillPoint * employee.skills.total)
            * (1 + staff.levelPayExpectation * Double(employee.level.rank))
    }

    /// Decodes the bundled `Balance.json` via `Bundle.module`.
    public static func loadBundled() throws -> BalanceConfig {
        guard let url = Bundle.module.url(forResource: "Balance", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "Balance.json is missing from the TycoonEngine bundle"
            ])
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    // MARK: Decoding on a wide stack (iteration 11)

    /// Decodes a `BalanceConfig` from JSON on a thread with a 64 MB stack.
    ///
    /// The synthesized decoder for a struct with close to four hundred
    /// stored properties builds, in a debug build, a frame far larger
    /// than a cooperative thread's 512 KB stack and within reach of iOS's
    /// 1 MB main thread — and it grows with every balance block a lane
    /// adds. The four-lane merge of iteration 11 was the one that crossed
    /// the line (`swiftpm-testing-helper` died with a bus error inside
    /// `BalanceConfig.init(from:)`). Running the decode on its own thread
    /// makes the frame size irrelevant, whoever calls it and from where.
    public static func decode(_ data: Data) throws -> BalanceConfig {
        final class Box: @unchecked Sendable {
            var result: Result<BalanceConfig, any Error>?
        }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            box.result = Result { try JSONDecoder().decode(BalanceConfig.self, from: data) }
            done.signal()
        }
        thread.stackSize = 64 << 20
        thread.start()
        done.wait()
        guard let result = box.result else {
            throw CocoaError(.coderReadCorrupt, userInfo: [
                NSLocalizedDescriptionKey: "Balance decoding produced no result"
            ])
        }
        return try result.get()
    }
}
