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
            homes: [String: HomeDef]
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
        life: LifeBalance
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

    /// Decodes the bundled `Balance.json` via `Bundle.module`.
    public static func loadBundled() throws -> BalanceConfig {
        guard let url = Bundle.module.url(forResource: "Balance", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "Balance.json is missing from the TycoonEngine bundle"
            ])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BalanceConfig.self, from: data)
    }
}
