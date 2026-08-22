import Foundation
import TycoonContent
import TycoonEngine

/// Shared helpers for building custom balance configurations in tests.
/// Defaults mirror the shipped `Balance.json` values.
enum TestBalance {
    static func make(
        startingCash: Int = 12_000,
        weeklyOperatingCost: Int = 400,
        bankruptcyGraceDays: Int = 14,
        garageRent: Int = 0,
        bugChanceBase: Double = 0.30,
        bugChanceSkillDivisor: Double = 120.0,
        founderCoding: Double = 40.0,
        shipCodeThreshold: Double = 0.6,
        qualityWeights: BalanceConfig.QualityWeights = BalanceConfig.QualityWeights(
            design: 0.35, code: 0.45, polish: 0.20
        ),
        bugPenaltyCap: Double = 0.4,
        founderDesign: Double = 30.0,
        founderMarketing: Double = 20.0,
        employeeBasePoints: Double = 1.0,
        skillYieldDivisor: Double = 25.0,
        skillGrowthRate: Double = 0.08,
        candidateRefreshDays: Int = 14,
        candidateCountMin: Int = 3,
        candidateCountMax: Int = 6,
        candidateSkillBase: Double = 35.0,
        candidateSkillPerReputation: Double = 0.5,
        candidateSkillTierBonus: [String: Double] = [
            OfficeTier.garage.rawValue: 0,
            OfficeTier.loft.rawValue: 10,
            OfficeTier.studio.rawValue: 20,
            OfficeTier.campus.rawValue: 30,
        ],
        salaryBase: Int = 180,
        salaryPerSkillPoint: Double = 9.0,
        salaryJitter: Double = 0.10,
        researchBasePoints: Double = 0.5,
        researchCodingDivisor: Double = 40.0,
        researchDesignDivisor: Double = 80.0,
        techQualityMultiplierCap: Double = 1.5,
        reviewNoiseSigma: Double = 6.0,
        reviewFloor: Int = 5,
        reviewCeiling: Int = 98,
        reviewOutlets: [String] = ["TechDaily", "AppVerdict", "The Stack Review", "ByteSized"],
        salesBaseFactor: Double = 0.4,
        salesQualityFactor: Double = 0.6,
        salesDecayBase: Double = 0.72,
        salesDecayQualityFactor: Double = 0.20,
        delistFraction: Double = 0.01,
        reputationReviewNudge: Double = 0.1,
        contractOfferRefreshDays: Int = 7,
        contractOfferCount: Int = 3,
        contractPtsMin: Double = 20,
        contractPtsMax: Double = 120,
        contractCodeSplitMin: Double = 0.5,
        contractCodeSplitMax: Double = 0.8,
        contractPayoutPerPoint: Double = 90,
        contractUrgencyPremiumMin: Double = 1.0,
        contractUrgencyPremiumMax: Double = 1.3,
        contractPenaltyFraction: Double = 0.3,
        contractDeadlinePtsPerDay: Double = 3.0,
        contractDeadlineSlackMin: Double = 1.1,
        contractDeadlineSlackMax: Double = 1.6,
        contractYearScale: Double = 0.25,
        contractReputationReward: Double = 1.0,
        contractReputationPenalty: Double = 2.0,
        socialPushDailyCost: Int = 50,
        socialPushDurationDays: Int = 14,
        socialPushDailyHype: Double = 2.0,
        pressReleaseCost: Int = 500,
        pressReleaseHype: Double = 15.0,
        launchEventCost: Int = 5_000,
        launchEventHype: Double = 40.0,
        launchEventMinTier: String = OfficeTier.studio.rawValue,
        hypeDecayRate: Double = 0.02,
        reviewExpectationBase: Double = 30.0,
        reviewExpectationPerYear: Double = 3.0,
        reviewExpectationRepFactor: Double = 0.15,
        reviewShortfallPenalty: Double = 0.5,
        reviewHypeDivisor: Double = 20.0,
        hypeLaunchCarryFraction: Double = 0.5,
        salesHypeDivisor: Double = 150.0,
        eventCheckIntervalDays: Int = 30,
        eventChance: Double = 0.2,
        life: BalanceConfig.LifeBalance = TestBalance.life()
    ) -> BalanceConfig {
        BalanceConfig(
            startingCash: startingCash,
            weeklyOperatingCost: weeklyOperatingCost,
            bankruptcyGraceDays: bankruptcyGraceDays,
            offices: [
                OfficeTier.garage.rawValue: BalanceConfig.OfficeDef(
                    upgradeCost: 0, weeklyRent: garageRent, headcountCap: 3
                ),
                OfficeTier.loft.rawValue: BalanceConfig.OfficeDef(
                    upgradeCost: 15_000, weeklyRent: 150, headcountCap: 6
                ),
                OfficeTier.studio.rawValue: BalanceConfig.OfficeDef(
                    upgradeCost: 90_000, weeklyRent: 900, headcountCap: 14
                ),
                OfficeTier.campus.rawValue: BalanceConfig.OfficeDef(
                    upgradeCost: 750_000, weeklyRent: 6_000, headcountCap: 40
                ),
            ],
            bugChanceBase: bugChanceBase,
            bugChanceSkillDivisor: bugChanceSkillDivisor,
            founderCoding: founderCoding,
            shipCodeThreshold: shipCodeThreshold,
            qualityWeights: qualityWeights,
            bugPenaltyCap: bugPenaltyCap,
            founderDesign: founderDesign,
            founderMarketing: founderMarketing,
            employeeBasePoints: employeeBasePoints,
            skillYieldDivisor: skillYieldDivisor,
            skillGrowthRate: skillGrowthRate,
            candidateRefreshDays: candidateRefreshDays,
            candidateCountMin: candidateCountMin,
            candidateCountMax: candidateCountMax,
            candidateSkillBase: candidateSkillBase,
            candidateSkillPerReputation: candidateSkillPerReputation,
            candidateSkillTierBonus: candidateSkillTierBonus,
            salaryBase: salaryBase,
            salaryPerSkillPoint: salaryPerSkillPoint,
            salaryJitter: salaryJitter,
            researchBasePoints: researchBasePoints,
            researchCodingDivisor: researchCodingDivisor,
            researchDesignDivisor: researchDesignDivisor,
            techQualityMultiplierCap: techQualityMultiplierCap,
            reviewNoiseSigma: reviewNoiseSigma,
            reviewFloor: reviewFloor,
            reviewCeiling: reviewCeiling,
            reviewOutlets: reviewOutlets,
            salesBaseFactor: salesBaseFactor,
            salesQualityFactor: salesQualityFactor,
            salesDecayBase: salesDecayBase,
            salesDecayQualityFactor: salesDecayQualityFactor,
            delistFraction: delistFraction,
            reputationReviewNudge: reputationReviewNudge,
            contractOfferRefreshDays: contractOfferRefreshDays,
            contractOfferCount: contractOfferCount,
            contractPtsMin: contractPtsMin,
            contractPtsMax: contractPtsMax,
            contractCodeSplitMin: contractCodeSplitMin,
            contractCodeSplitMax: contractCodeSplitMax,
            contractPayoutPerPoint: contractPayoutPerPoint,
            contractUrgencyPremiumMin: contractUrgencyPremiumMin,
            contractUrgencyPremiumMax: contractUrgencyPremiumMax,
            contractPenaltyFraction: contractPenaltyFraction,
            contractDeadlinePtsPerDay: contractDeadlinePtsPerDay,
            contractDeadlineSlackMin: contractDeadlineSlackMin,
            contractDeadlineSlackMax: contractDeadlineSlackMax,
            contractYearScale: contractYearScale,
            contractReputationReward: contractReputationReward,
            contractReputationPenalty: contractReputationPenalty,
            socialPushDailyCost: socialPushDailyCost,
            socialPushDurationDays: socialPushDurationDays,
            socialPushDailyHype: socialPushDailyHype,
            pressReleaseCost: pressReleaseCost,
            pressReleaseHype: pressReleaseHype,
            launchEventCost: launchEventCost,
            launchEventHype: launchEventHype,
            launchEventMinTier: launchEventMinTier,
            hypeDecayRate: hypeDecayRate,
            reviewExpectationBase: reviewExpectationBase,
            reviewExpectationPerYear: reviewExpectationPerYear,
            reviewExpectationRepFactor: reviewExpectationRepFactor,
            reviewShortfallPenalty: reviewShortfallPenalty,
            reviewHypeDivisor: reviewHypeDivisor,
            hypeLaunchCarryFraction: hypeLaunchCarryFraction,
            salesHypeDivisor: salesHypeDivisor,
            eventCheckIntervalDays: eventCheckIntervalDays,
            eventChance: eventChance,
            life: life
        )
    }

    static var standard: BalanceConfig { make() }

    /// Builds a life balance. Defaults mirror the shipped `Balance.json`
    /// "life" block.
    static func life(
        startingWallet: Int = 2_000,
        defaultFounderSalary: Int = 0,
        founderSalaryMax: Int = 5_000,
        chillDrift: BalanceConfig.LifeBalance.MeterDrift = BalanceConfig.LifeBalance.MeterDrift(
            energy: 1.5, health: 0.3, mood: 0.5, relationships: 0.3
        ),
        normalDrift: BalanceConfig.LifeBalance.MeterDrift = BalanceConfig.LifeBalance.MeterDrift(
            energy: -0.4, health: -0.2, mood: 0, relationships: -0.3
        ),
        crunchDrift: BalanceConfig.LifeBalance.MeterDrift = BalanceConfig.LifeBalance.MeterDrift(
            energy: -2.0, health: -0.8, mood: -0.6, relationships: -1.2
        ),
        stageRelationshipDrain: [String: Double] = [
            RelationshipStage.single.rawValue: 0,
            RelationshipStage.dating.rawValue: 0.2,
            RelationshipStage.partner.rawValue: 0.3,
            RelationshipStage.married.rawValue: 0.4,
        ],
        childDrift: BalanceConfig.LifeBalance.MeterDrift = BalanceConfig.LifeBalance.MeterDrift(
            energy: -0.3, health: 0, mood: 0.2, relationships: 0.1
        ),
        debtMoodPenalty: Double = 1.0,
        burnoutEnergyThreshold: Double = 15,
        burnoutDays: Int = 7,
        burnoutRecoveryEnergy: Double = 50,
        hospitalHealthThreshold: Double = 10,
        hospitalDays: Int = 14,
        hospitalBill: Int = 5_000,
        hospitalRecoveryHealth: Double = 40,
        breakupThreshold: Double = 15,
        breakupStreakDays: Int = 14,
        breakupMoodPenalty: Double = 25,
        lifeEventIntervalDays: Int = 14,
        lifeEventChance: Double = 0.35,
        coldOutputFactor: Double = 0.6,
        lowEnergyBugThreshold: Double = 30,
        lowEnergyBugDivisor: Double = 60,
        childWeeklyCost: Int = 80,
        vacationDays: Int = 7,
        datingMinRelationships: Double = 40,
        partnerMinRelationships: Double = 60,
        partnerMinDaysAtStage: Int = 56,
        marriedMinRelationships: Double = 75,
        marriedMinDaysAtStage: Int = 84,
        weddingCost: Int = 8_000,
        childMinRelationships: Double = 70,
        childStartCost: Int = 5_000,
        childMinHome: String = HomeTier.apartment.rawValue,
        maxChildren: Int = 3,
        childSpacingDays: Int = 140,
        childMoodBonus: Double = 20,
        studioFlatRent: Int = 120
    ) -> BalanceConfig.LifeBalance {
        typealias Activity = BalanceConfig.LifeBalance.ActivityDef
        typealias Home = BalanceConfig.LifeBalance.HomeDef
        return BalanceConfig.LifeBalance(
            startingWallet: startingWallet,
            defaultFounderSalary: defaultFounderSalary,
            founderSalaryMax: founderSalaryMax,
            drift: [
                WorkSchedule.chill.rawValue: chillDrift,
                WorkSchedule.normal.rawValue: normalDrift,
                WorkSchedule.crunch.rawValue: crunchDrift,
            ],
            scheduleOutputFactor: [
                WorkSchedule.chill.rawValue: 0.8,
                WorkSchedule.normal.rawValue: 1.0,
                WorkSchedule.crunch.rawValue: 1.3,
            ],
            wellbeingWeights: BalanceConfig.LifeBalance.WellbeingWeights(energy: 0.4, health: 0.3, mood: 0.3),
            minOutputFactor: 0.5,
            stageRelationshipDrain: stageRelationshipDrain,
            childDrift: childDrift,
            debtMoodPenalty: debtMoodPenalty,
            burnoutEnergyThreshold: burnoutEnergyThreshold,
            burnoutDays: burnoutDays,
            burnoutRecoveryEnergy: burnoutRecoveryEnergy,
            hospitalHealthThreshold: hospitalHealthThreshold,
            hospitalDays: hospitalDays,
            hospitalBill: hospitalBill,
            hospitalRecoveryHealth: hospitalRecoveryHealth,
            breakupThreshold: breakupThreshold,
            breakupStreakDays: breakupStreakDays,
            breakupMoodPenalty: breakupMoodPenalty,
            lifeEventIntervalDays: lifeEventIntervalDays,
            lifeEventChance: lifeEventChance,
            coldOutputFactor: coldOutputFactor,
            lowEnergyBugThreshold: lowEnergyBugThreshold,
            lowEnergyBugDivisor: lowEnergyBugDivisor,
            childWeeklyCost: childWeeklyCost,
            activities: [
                WeekendActivity.rest.rawValue: Activity(energy: 15, health: 0, mood: 5, relationships: 0, cost: 0),
                WeekendActivity.gym.rawValue: Activity(energy: -3, health: 12, mood: 0, relationships: 0, cost: 60),
                WeekendActivity.dateNight.rawValue: Activity(energy: 0, health: 0, mood: 8, relationships: 15, cost: 120),
                WeekendActivity.friends.rawValue: Activity(energy: 0, health: 0, mood: 10, relationships: 8, cost: 80),
                WeekendActivity.hobby.rawValue: Activity(energy: 0, health: 0, mood: 15, relationships: 0, cost: 50),
                WeekendActivity.familyTime.rawValue: Activity(energy: 0, health: 0, mood: 6, relationships: 12, cost: 40),
                WeekendActivity.vacation.rawValue: Activity(energy: 40, health: 10, mood: 20, relationships: 10, cost: 1_500),
                WeekendActivity.doctor.rawValue: Activity(energy: 0, health: 15, mood: 0, relationships: 0, cost: 200),
            ],
            vacationDays: vacationDays,
            datingMinRelationships: datingMinRelationships,
            partnerMinRelationships: partnerMinRelationships,
            partnerMinDaysAtStage: partnerMinDaysAtStage,
            marriedMinRelationships: marriedMinRelationships,
            marriedMinDaysAtStage: marriedMinDaysAtStage,
            weddingCost: weddingCost,
            childMinRelationships: childMinRelationships,
            childStartCost: childStartCost,
            childMinHome: childMinHome,
            maxChildren: maxChildren,
            childSpacingDays: childSpacingDays,
            childMoodBonus: childMoodBonus,
            homes: [
                HomeTier.studioFlat.rawValue: Home(upgradeCost: 0, weeklyRent: studioFlatRent, moodBonus: 0),
                HomeTier.apartment.rawValue: Home(upgradeCost: 6_000, weeklyRent: 300, moodBonus: 0),
                HomeTier.house.rawValue: Home(upgradeCost: 40_000, weeklyRent: 700, moodBonus: 0.2),
                HomeTier.penthouse.rawValue: Home(upgradeCost: 250_000, weeklyRent: 2_500, moodBonus: 0.5),
            ]
        )
    }

    /// A life balance where nothing moves on its own: no schedule, stage,
    /// or child drift, and life events never roll. Combined with
    /// `TestLife.pinPeak`, the founder's output multiplier is exactly the
    /// schedule factor (1.0 on `.normal`), so hand-computed output
    /// expectations hold.
    static var quietLife: BalanceConfig.LifeBalance {
        life(
            chillDrift: .zero,
            normalDrift: .zero,
            crunchDrift: .zero,
            stageRelationshipDrain: [:],
            childDrift: .zero,
            lifeEventIntervalDays: 10_000
        )
    }
}

/// Shared helpers for the founder's personal life in tests.
enum TestLife {
    /// Pins energy, health, and mood to 100 so the wellbeing term of the
    /// founder output multiplier is exactly 1.
    static func pinPeak(_ state: inout GameState) {
        state.life.meters = LifeMeters(energy: 100, health: 100, mood: 100, relationships: 50)
    }

    /// Puts the founder at `stage` with a partner on record (no children).
    static func setPartner(_ state: inout GameState, stage: RelationshipStage, sinceDay: Int = 0) {
        state.life.family.stage = stage
        state.life.family.stageSinceDay = sinceDay
        state.life.family.partnerName = stage == .single ? nil : "Sam"
        state.life.family.partnerAppearanceSeed = stage == .single ? nil : 7
    }

    static func child(name: String = "Kit", bornDay: Int = 0) -> Child {
        Child(id: UUID(), name: name, bornDay: bornDay, appearanceSeed: 3)
    }
}

/// Shared helpers for hand-building employees and candidates in tests.
enum TestPeople {
    static func employee(
        id: UUID = UUID(),
        name: String = "Worker",
        coding: Double = 50,
        design: Double = 25,
        marketing: Double = 10,
        weeklySalary: Int = 500,
        assignment: Assignment = .idle
    ) -> Employee {
        Employee(
            id: id,
            name: name,
            skills: SkillSet(coding: coding, design: design, marketing: marketing),
            weeklySalary: weeklySalary,
            assignment: assignment,
            isFounder: false,
            hiredDay: 0,
            appearanceSeed: 1
        )
    }

    static func candidate(
        id: UUID = UUID(),
        name: String = "Ada Lovelace",
        coding: Double = 30,
        design: Double = 20,
        marketing: Double = 10,
        weeklySalary: Int = 500
    ) -> Candidate {
        Candidate(
            id: id,
            name: name,
            skills: SkillSet(coding: coding, design: design, marketing: marketing),
            weeklySalary: weeklySalary,
            appearanceSeed: 2
        )
    }
}

/// Shared content catalogs for tests.
enum TestContent {
    /// The real shipped catalog from TycoonContent.
    static let bundled: ContentCatalog = {
        do {
            return try ContentCatalog.loadBundled()
        } catch {
            fatalError("Tests require the bundled TycoonContent catalog: \(error)")
        }
    }()

    /// A tiny hand-built catalog with round numbers for exact assertions.
    /// One product type ("tool", unlocked) and one topic ("testing");
    /// research tests add known tech nodes and extra (usually locked)
    /// product types on top.
    static func tiny(
        designPts: Double = 10,
        codePts: Double = 10,
        polishPts: Double = 10,
        unitPrice: Double = 2.0,
        marketSize: Double = 1000,
        topicFit: Double = 1.0,
        techTree: [TechNode] = [],
        extraProductTypes: [ProductTypeDef] = [],
        events: [EventDef] = [],
        lifeEvents: [LifeEventDef] = []
    ) -> ContentCatalog {
        ContentCatalog(
            productTypes: [
                ProductTypeDef(
                    id: "tool",
                    name: "Tool",
                    iconSystemName: "hammer",
                    designPts: designPts,
                    codePts: codePts,
                    polishPts: polishPts,
                    unitPrice: unitPrice,
                    marketSize: marketSize,
                    unlockedFromStart: true,
                    blurb: "A test tool."
                )
            ] + extraProductTypes,
            topics: [
                TopicDef(
                    id: "testing",
                    name: "Testing",
                    iconSystemName: "checkmark",
                    fitByType: topicFit == 1.0 ? [:] : ["tool": topicFit]
                )
            ],
            techTree: techTree,
            events: events,
            names: NamePools(
                firstNames: ["Ada"], lastNames: ["Lovelace"], clientCompanies: ["TestCo"],
                partnerNames: ["Sam", "Noor", "Luca"], childNames: ["Kit", "Juno", "Remy"]
            ),
            lifeEvents: lifeEvents
        )
    }
}

/// Shared helper for hand-building tech nodes in tests.
enum TestTech {
    static func node(
        id: String,
        name: String? = nil,
        tier: Int = 1,
        researchCost: Double,
        cashCost: Int = 0,
        prerequisites: [String] = [],
        effect: TechNode.Effect
    ) -> TechNode {
        TechNode(
            id: id,
            name: name ?? "Tech \(id)",
            tier: tier,
            researchCost: researchCost,
            cashCost: cashCost,
            prerequisites: prerequisites,
            effect: effect,
            blurb: "A test tech node."
        )
    }
}
