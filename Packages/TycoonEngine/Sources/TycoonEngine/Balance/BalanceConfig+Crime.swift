import Foundation

// Iteration 11 — N1. Crime, scandal and the courtroom.
//
// Every number here is read from exactly one of two places: the moment
// the player presses an offence button, and the weekly sweep that only
// runs while `state.crime.record` is non-empty. A run that never commits
// an offence never reads a single field in this file, so a balance file
// that turns all of it up is still bit-for-bit the game that ships.
//
// The one shape rule the lane keeps: every gain is *added*, never
// multiplied into an existing pipeline, so there is no "identity at 1.0"
// multiplier to get wrong. `cookBooksValuationFactor` is the exception,
// and it multiplies only the offer that arrives while the books are
// cooked, which is an offer no clean run has.

extension BalanceConfig {

    // MARK: - Crime

    public struct CrimeBalance: Codable, Equatable, Sendable {

        // MARK: The offences

        /// Cook the books: the multiplier on a term sheet that arrives
        /// while the accounts are still warm, and how long they stay warm.
        public var cookBooksValuationFactor: Double
        public var cookBooksWeeks: Int
        public var cookBooksNotoriety: Double

        /// Dodge the tax: what fraction of the quarter's bill stays in the
        /// company, and how the notional bill is derived from trailing
        /// revenue. (The game has never posted a tax bill; see
        /// `FinanceSystem`'s N1 region for why the dodge posts a credit
        /// rather than the bill posting a debit.)
        public var taxRateOnRevenue: Double
        public var taxQuarterWeeks: Int
        public var dodgeFraction: Double
        public var dodgeTaxesNotoriety: Double

        /// The NDA poach: the fee out of the founder's own pocket, the
        /// base chance the target says yes, and the multiplier the breach
        /// of their non-compete buys.
        public var ndaPoachFee: Int
        public var ndaPoachBaseChance: Double
        public var ndaPoachNDAFactor: Double
        /// How much better the poached engineer is than the pool's best.
        public var ndaPoachSkillBonus: Double
        public var ndaPoachNotoriety: Double

        /// The envelope: the fee, and the points one outlet's review moves
        /// on the next launch.
        public var bribeFee: Int
        public var bribeNotchPoints: Int
        public var bribeNotoriety: Double

        /// The fake demo: hype now, and the bug landslide if the build
        /// ships inside the window.
        public var fakeDemoHype: Double
        public var fakeDemoWindowDays: Int
        public var fakeDemoBugMultiplier: Double
        public var fakeDemoNotoriety: Double

        /// The planted story: the fee, what it takes off the rival's
        /// reputation, and what it hands them if it is traced back.
        public var plantStoryFee: Int
        public var plantStoryReputationHit: Double
        public var plantStoryStrengthGift: Double
        public var plantStoryNotoriety: Double

        // MARK: Notoriety and discovery

        /// Points shed a week, once nothing new has happened.
        public var notorietyDecayPerWeek: Double
        /// How much a full notoriety meter multiplies discovery by, on top
        /// of the base (1 + notoriety/100 × this).
        public var notorietyDiscoveryFactor: Double
        /// The Legal department halves it.
        public var legalDepartmentFactor: Double
        /// Weekly base chance per open record entry, per offence.
        public var cookBooksDiscovery: Double
        public var dodgeTaxesDiscovery: Double
        public var ndaPoachDiscovery: Double
        public var bribeDiscovery: Double
        public var fakeDemoDiscovery: Double
        public var plantStoryDiscovery: Double
        /// Paper goes cold over this many weeks, down to `coldCaseFloor`
        /// of the base rate.
        public var coldCaseWeeks: Double
        public var coldCaseFloor: Double
        /// Nothing is ever certain to be found in one week.
        public var discoveryCeiling: Double

        // MARK: The case

        /// A hearing is set this far out.
        public var hearingWeeksMin: Int
        public var hearingWeeksMax: Int
        /// What a settlement costs: a base scaled by the offence's
        /// gravity, plus a slice of what the offence made.
        public var settlementBase: Int
        public var settlementGainFactor: Double
        public var settlementFloor: Int
        /// What the two paid tiers of lawyer cost the founder's wallet.
        public var highStreetFee: Int
        public var silkFee: Int

        // MARK: The courtroom

        public var exchanges: Int
        public var landBase: Double
        public var landSkillDivisor: Double
        public var landCeiling: Double
        public var landFloor: Double
        /// Saying the thing your defence is built on.
        public var onDefenceBonus: Double
        /// How much the other side's paper argues back, per exchange and
        /// at the opening.
        public var evidenceLandPenalty: Double
        public var evidenceOpeningWeight: Double
        /// The verdict bands, in standing.
        public var acquittalStanding: Double
        public var fineStanding: Double
        public var settlementStanding: Double
        /// The fine's base, before the offence's gravity.
        public var fineBase: Int
        public var sentenceWeeksMin: Int
        public var sentenceWeeksMax: Int
        /// The reputation a guilty verdict costs the company, and the
        /// reputation an acquittal hands back.
        public var guiltyReputationHit: Double
        public var acquittalReputationGain: Double
        /// While the founder is inside: how much faster affection slides,
        /// and what the board's patience is multiplied by.
        public var insideAffectionPerDay: Double
        public var insideBoardPressurePerWeek: Double

        // MARK: Suing a rival

        /// What filing costs the company, and what winning takes off them.
        public var suitFilingFee: Int
        public var suitDamagesPerStrength: Double
        /// A won suit takes a product off the rival's shelf.
        public var suitTakesProduct: Bool

        public init(
            cookBooksValuationFactor: Double = 1.35,
            cookBooksWeeks: Int = 13,
            cookBooksNotoriety: Double = 14,
            taxRateOnRevenue: Double = 0.19,
            taxQuarterWeeks: Int = 13,
            dodgeFraction: Double = 0.5,
            dodgeTaxesNotoriety: Double = 12,
            ndaPoachFee: Int = 2_500,
            ndaPoachBaseChance: Double = 0.45,
            ndaPoachNDAFactor: Double = 1.5,
            ndaPoachSkillBonus: Double = 14,
            ndaPoachNotoriety: Double = 10,
            bribeFee: Int = 4_000,
            bribeNotchPoints: Int = 12,
            bribeNotoriety: Double = 9,
            fakeDemoHype: Double = 30,
            fakeDemoWindowDays: Int = 14,
            fakeDemoBugMultiplier: Double = 2.2,
            fakeDemoNotoriety: Double = 11,
            plantStoryFee: Int = 1_500,
            plantStoryReputationHit: Double = 12,
            plantStoryStrengthGift: Double = 8,
            plantStoryNotoriety: Double = 13,
            notorietyDecayPerWeek: Double = 1,
            notorietyDiscoveryFactor: Double = 1.2,
            legalDepartmentFactor: Double = 0.5,
            cookBooksDiscovery: Double = 0.030,
            dodgeTaxesDiscovery: Double = 0.035,
            ndaPoachDiscovery: Double = 0.040,
            bribeDiscovery: Double = 0.025,
            fakeDemoDiscovery: Double = 0.028,
            plantStoryDiscovery: Double = 0.045,
            coldCaseWeeks: Double = 40,
            coldCaseFloor: Double = 0.25,
            discoveryCeiling: Double = 0.35,
            hearingWeeksMin: Int = 4,
            hearingWeeksMax: Int = 8,
            settlementBase: Int = 9_000,
            settlementGainFactor: Double = 0.6,
            settlementFloor: Int = 1_200,
            highStreetFee: Int = 3_500,
            silkFee: Int = 12_000,
            exchanges: Int = 3,
            landBase: Double = 0.44,
            landSkillDivisor: Double = 220,
            landCeiling: Double = 0.9,
            landFloor: Double = 0.1,
            onDefenceBonus: Double = 0.18,
            evidenceLandPenalty: Double = 0.3,
            evidenceOpeningWeight: Double = 34,
            acquittalStanding: Double = 42,
            fineStanding: Double = 4,
            settlementStanding: Double = -34,
            fineBase: Int = 14_000,
            sentenceWeeksMin: Int = 3,
            sentenceWeeksMax: Int = 16,
            guiltyReputationHit: Double = 9,
            acquittalReputationGain: Double = 3,
            insideAffectionPerDay: Double = 0.55,
            insideBoardPressurePerWeek: Double = 4,
            suitFilingFee: Int = 8_000,
            suitDamagesPerStrength: Double = 900,
            suitTakesProduct: Bool = true
        ) {
            self.cookBooksValuationFactor = cookBooksValuationFactor
            self.cookBooksWeeks = cookBooksWeeks
            self.cookBooksNotoriety = cookBooksNotoriety
            self.taxRateOnRevenue = taxRateOnRevenue
            self.taxQuarterWeeks = taxQuarterWeeks
            self.dodgeFraction = dodgeFraction
            self.dodgeTaxesNotoriety = dodgeTaxesNotoriety
            self.ndaPoachFee = ndaPoachFee
            self.ndaPoachBaseChance = ndaPoachBaseChance
            self.ndaPoachNDAFactor = ndaPoachNDAFactor
            self.ndaPoachSkillBonus = ndaPoachSkillBonus
            self.ndaPoachNotoriety = ndaPoachNotoriety
            self.bribeFee = bribeFee
            self.bribeNotchPoints = bribeNotchPoints
            self.bribeNotoriety = bribeNotoriety
            self.fakeDemoHype = fakeDemoHype
            self.fakeDemoWindowDays = fakeDemoWindowDays
            self.fakeDemoBugMultiplier = fakeDemoBugMultiplier
            self.fakeDemoNotoriety = fakeDemoNotoriety
            self.plantStoryFee = plantStoryFee
            self.plantStoryReputationHit = plantStoryReputationHit
            self.plantStoryStrengthGift = plantStoryStrengthGift
            self.plantStoryNotoriety = plantStoryNotoriety
            self.notorietyDecayPerWeek = notorietyDecayPerWeek
            self.notorietyDiscoveryFactor = notorietyDiscoveryFactor
            self.legalDepartmentFactor = legalDepartmentFactor
            self.cookBooksDiscovery = cookBooksDiscovery
            self.dodgeTaxesDiscovery = dodgeTaxesDiscovery
            self.ndaPoachDiscovery = ndaPoachDiscovery
            self.bribeDiscovery = bribeDiscovery
            self.fakeDemoDiscovery = fakeDemoDiscovery
            self.plantStoryDiscovery = plantStoryDiscovery
            self.coldCaseWeeks = coldCaseWeeks
            self.coldCaseFloor = coldCaseFloor
            self.discoveryCeiling = discoveryCeiling
            self.hearingWeeksMin = hearingWeeksMin
            self.hearingWeeksMax = hearingWeeksMax
            self.settlementBase = settlementBase
            self.settlementGainFactor = settlementGainFactor
            self.settlementFloor = settlementFloor
            self.highStreetFee = highStreetFee
            self.silkFee = silkFee
            self.exchanges = exchanges
            self.landBase = landBase
            self.landSkillDivisor = landSkillDivisor
            self.landCeiling = landCeiling
            self.landFloor = landFloor
            self.onDefenceBonus = onDefenceBonus
            self.evidenceLandPenalty = evidenceLandPenalty
            self.evidenceOpeningWeight = evidenceOpeningWeight
            self.acquittalStanding = acquittalStanding
            self.fineStanding = fineStanding
            self.settlementStanding = settlementStanding
            self.fineBase = fineBase
            self.sentenceWeeksMin = sentenceWeeksMin
            self.sentenceWeeksMax = sentenceWeeksMax
            self.guiltyReputationHit = guiltyReputationHit
            self.acquittalReputationGain = acquittalReputationGain
            self.insideAffectionPerDay = insideAffectionPerDay
            self.insideBoardPressurePerWeek = insideBoardPressurePerWeek
            self.suitFilingFee = suitFilingFee
            self.suitDamagesPerStrength = suitDamagesPerStrength
            self.suitTakesProduct = suitTakesProduct
        }

        /// The shipped rules. Like the sabbatical and the bug hunt, the
        /// default is not "switched off" — there is nothing to switch off
        /// until the player presses a button — so a balance file with no
        /// `"crime"` object still gets the game that ships.
        public static let `default` = CrimeBalance()

        /// The fee for a tier of representation.
        public func fee(for lawyer: CrimeLawyer) -> Int {
            switch lawyer {
            case .dutySolicitor: 0
            case .highStreet: highStreetFee
            case .silk: silkFee
            }
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"crime"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.CrimeBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.CrimeBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
