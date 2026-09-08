import Foundation

// Iteration 11, wave two — W2. Every number the family drama reads: the
// odds an affair surfaces, what a settlement owes, what a childhood is
// worth in a family court, what a care home costs, and what a sibling
// asks for.
//
// All of it is read only from `FamilyDramaSystem`, and `FamilyDramaSystem`
// returns on its first line while the founder has neither opened the room
// nor started an affair. So a balance file with no `"familyDrama"` object,
// and a run that never touches any of this, are both exactly the game that
// shipped, whatever these numbers say.

extension BalanceConfig {

    public struct FamilyDramaBalance: Codable, Equatable, Sendable {

        // MARK: Discovery

        /// The weekly chance a fresh affair surfaces, before anything
        /// makes it worse.
        public var discoveryWeekly: Double
        /// Added per week the affair has been running, as a multiple of
        /// `discoveryWeekly`. A fortnight is a secret; a year is a habit.
        public var discoveryAgeFactor: Double
        /// Added flat while somebody has already sat the founder down
        /// about a vice (N3's `intervened`): the same person is already
        /// counting the evenings.
        public var interventionDiscoveryBonus: Double
        /// Added at full fame (N4). Photographed at lunch.
        public var fameDiscoveryBonus: Double
        /// No single week is ever worse than this.
        public var discoveryCeiling: Double
        /// Affection lost the day it surfaces.
        public var discoveryAffectionHit: Double

        // MARK: The confrontation

        public var confessAffection: Double
        public var denyAffection: Double
        public var endItAffection: Double
        /// Mood, whichever way it goes. It is not a good evening.
        public var confrontationMood: Double

        // MARK: The settlement

        /// How far a tier of lawyer moves the share, per point of
        /// `CrimeLawyer.weight` difference.
        public var lawyerSwing: Double
        /// Taken off the founder's share when the affair is on the record.
        public var affairSharePenalty: Double
        /// Nobody walks away with more than this, or less.
        public var shareCeiling: Double
        public var shareFloor: Double
        /// A marriage this long pulls the share back towards half…
        public var longMarriageYears: Double
        /// …by this much of the remaining distance.
        public var longMarriagePull: Double
        /// The two paid tiers of family solicitor.
        public var highStreetFee: Int
        public var silkFee: Int
        /// Married at least this long and a slice of the company goes.
        public var equityMarriedDays: Int
        public var equityBasePoints: Double
        public var equityPointsPerYear: Double
        public var equityMaxPoints: Double
        /// Mood the day the estate is divided.
        public var divorceMood: Double

        // MARK: Custody

        /// Weeks out the custody hearing is listed for.
        public var custodyHearingWeeksMin: Int
        public var custodyHearingWeeksMax: Int
        /// The filing fee, out of the wallet.
        public var custodyFilingFee: Int
        /// Every point of bond above the default is worth this much
        /// evidence.
        public var bondEvidenceFactor: Double
        /// The memory ledger's points, scaled into the −100…100 standing.
        public var evidenceScale: Double
        /// What the lawyer's tier is worth in the family court.
        public var custodyLawyerFactor: Double
        /// Taken off the standing when the affair is on the record.
        public var custodyAffairPenalty: Double
        /// The verdict bands.
        public var fullCustodyStanding: Double
        public var sharedCustodyStanding: Double
        public var weekendsStanding: Double

        // MARK: The parents

        /// A parent is this old before the care question can be asked.
        public var careAge: Int
        /// The earliest game year a care bill can land.
        public var careMinYear: Int
        /// What a home costs the wallet every week.
        public var careWeeklyBill: Int
        /// Mood a week while a parent is in care and nobody is paying.
        public var neglectMood: Double
        /// The weekly chance a parent in their eighties dies. Only rolled
        /// once the founder has a record for them, which means only once
        /// they have engaged with any of this.
        public var deathWeekly: Double
        /// Nothing before this age.
        public var deathAge: Int
        /// Mood the week a parent dies.
        public var bereavementMood: Double
        /// Days away for the funeral.
        public var funeralAwayDays: Int
        /// What the estate leaves in the wallet.
        public var inheritance: Int

        // MARK: The sibling

        /// The weekly chance the sibling escalates, once they have asked
        /// at all. The first ask needs the founder to have opened the room
        /// and the company to have money.
        public var askWeekly: Double
        /// Cash the company must hold before the sibling notices.
        public var askMinCash: Int
        /// Days between one ask and the next.
        public var askCooldownDays: Int
        /// The slice they want.
        public var siblingStakePoints: Double
        /// The cheque they want.
        public var siblingLoan: Int
        /// The salary the job costs, weekly.
        public var siblingSalary: Int
        /// Bond moved by a yes and by a no.
        public var askYesBond: Double
        public var askNoBond: Double

        // MARK: The in-laws

        /// Weekly rent the spare room saves, and the mood it costs.
        public var inLawsWeeklySaving: Int
        public var inLawsMoodDrift: Double
        /// Affection the spare room buys, per week.
        public var inLawsAffectionDrift: Double

        // MARK: An evening with a relative

        /// Bond an evening buys.
        public var visitBond: Double
        /// Mood an evening buys.
        public var visitMood: Double
        /// Days before the same relative can be visited again.
        public var visitCooldownDays: Int
        /// Bond lost a week of silence.
        public var silenceDecay: Double

        public init(
            discoveryWeekly: Double = 0.07,
            discoveryAgeFactor: Double = 0.06,
            interventionDiscoveryBonus: Double = 0.05,
            fameDiscoveryBonus: Double = 0.12,
            discoveryCeiling: Double = 0.42,
            discoveryAffectionHit: Double = 30,
            confessAffection: Double = -22,
            denyAffection: Double = -38,
            endItAffection: Double = -14,
            confrontationMood: Double = -12,
            lawyerSwing: Double = 0.55,
            affairSharePenalty: Double = 0.1,
            shareCeiling: Double = 0.72,
            shareFloor: Double = 0.28,
            longMarriageYears: Double = 8,
            longMarriagePull: Double = 0.5,
            highStreetFee: Int = 4_000,
            silkFee: Int = 18_000,
            equityMarriedDays: Int = 728,
            equityBasePoints: Double = 3,
            equityPointsPerYear: Double = 1.5,
            equityMaxPoints: Double = 12,
            divorceMood: Double = -18,
            custodyHearingWeeksMin: Int = 4,
            custodyHearingWeeksMax: Int = 8,
            custodyFilingFee: Int = 2_500,
            bondEvidenceFactor: Double = 0.3,
            evidenceScale: Double = 4,
            custodyLawyerFactor: Double = 40,
            custodyAffairPenalty: Double = 18,
            fullCustodyStanding: Double = 34,
            sharedCustodyStanding: Double = -6,
            weekendsStanding: Double = -34,
            careAge: Int = 78,
            careMinYear: Int = 3,
            careWeeklyBill: Int = 900,
            neglectMood: Double = -3,
            deathWeekly: Double = 0.012,
            deathAge: Int = 82,
            bereavementMood: Double = -22,
            funeralAwayDays: Int = 3,
            inheritance: Int = 12_000,
            askWeekly: Double = 0.05,
            askMinCash: Int = 60_000,
            askCooldownDays: Int = 84,
            siblingStakePoints: Double = 4,
            siblingLoan: Int = 15_000,
            siblingSalary: Int = 900,
            askYesBond: Double = 14,
            askNoBond: Double = -16,
            inLawsWeeklySaving: Int = 350,
            inLawsMoodDrift: Double = -1.2,
            inLawsAffectionDrift: Double = 1.2,
            visitBond: Double = 9,
            visitMood: Double = 5,
            visitCooldownDays: Int = 14,
            silenceDecay: Double = 1.2
        ) {
            self.discoveryWeekly = discoveryWeekly
            self.discoveryAgeFactor = discoveryAgeFactor
            self.interventionDiscoveryBonus = interventionDiscoveryBonus
            self.fameDiscoveryBonus = fameDiscoveryBonus
            self.discoveryCeiling = discoveryCeiling
            self.discoveryAffectionHit = discoveryAffectionHit
            self.confessAffection = confessAffection
            self.denyAffection = denyAffection
            self.endItAffection = endItAffection
            self.confrontationMood = confrontationMood
            self.lawyerSwing = lawyerSwing
            self.affairSharePenalty = affairSharePenalty
            self.shareCeiling = shareCeiling
            self.shareFloor = shareFloor
            self.longMarriageYears = longMarriageYears
            self.longMarriagePull = longMarriagePull
            self.highStreetFee = highStreetFee
            self.silkFee = silkFee
            self.equityMarriedDays = equityMarriedDays
            self.equityBasePoints = equityBasePoints
            self.equityPointsPerYear = equityPointsPerYear
            self.equityMaxPoints = equityMaxPoints
            self.divorceMood = divorceMood
            self.custodyHearingWeeksMin = custodyHearingWeeksMin
            self.custodyHearingWeeksMax = custodyHearingWeeksMax
            self.custodyFilingFee = custodyFilingFee
            self.bondEvidenceFactor = bondEvidenceFactor
            self.evidenceScale = evidenceScale
            self.custodyLawyerFactor = custodyLawyerFactor
            self.custodyAffairPenalty = custodyAffairPenalty
            self.fullCustodyStanding = fullCustodyStanding
            self.sharedCustodyStanding = sharedCustodyStanding
            self.weekendsStanding = weekendsStanding
            self.careAge = careAge
            self.careMinYear = careMinYear
            self.careWeeklyBill = careWeeklyBill
            self.neglectMood = neglectMood
            self.deathWeekly = deathWeekly
            self.deathAge = deathAge
            self.bereavementMood = bereavementMood
            self.funeralAwayDays = funeralAwayDays
            self.inheritance = inheritance
            self.askWeekly = askWeekly
            self.askMinCash = askMinCash
            self.askCooldownDays = askCooldownDays
            self.siblingStakePoints = siblingStakePoints
            self.siblingLoan = siblingLoan
            self.siblingSalary = siblingSalary
            self.askYesBond = askYesBond
            self.askNoBond = askNoBond
            self.inLawsWeeklySaving = inLawsWeeklySaving
            self.inLawsMoodDrift = inLawsMoodDrift
            self.inLawsAffectionDrift = inLawsAffectionDrift
            self.visitBond = visitBond
            self.visitMood = visitMood
            self.visitCooldownDays = visitCooldownDays
            self.silenceDecay = silenceDecay
        }

        public static let `default` = FamilyDramaBalance()
    }
}
