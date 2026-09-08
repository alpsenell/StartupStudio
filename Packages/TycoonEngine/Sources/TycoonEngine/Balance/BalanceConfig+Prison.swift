import Foundation

// Iteration 11, wave two — W4. What a day inside is worth.
//
// Every number here is read from exactly one place: `PrisonSystem`, which
// is reached only from `CrimeSystem.servingTime`, which returns on its
// first line unless a court has handed down a sentence. A run that is
// never sentenced never reads a field in this file, so a balance file that
// turns all of it up is still bit-for-bit the game that ships.
//
// Nothing here is a multiplier on an existing pipeline: every value is
// *added* to a meter or a counter, once, on a day the founder is in a
// cell. There is no identity-at-1.0 to get wrong.

extension BalanceConfig {

    // MARK: - Prison

    public struct PrisonBalance: Codable, Equatable, Sendable {

        // MARK: The day's five choices

        /// Head down: sleep is the only thing on offer, and it is not much.
        public var headDownEnergy: Double
        public var headDownMood: Double

        /// The library: it costs a little to concentrate and pays in
        /// something to think about.
        public var libraryEnergy: Double
        public var libraryMood: Double
        /// Every so many library days, an attribute point on the way out.
        public var librarySkillEveryDays: Int
        public var librarySkillPoints: Double

        /// The yard: air and daylight, and other people.
        public var yardEnergy: Double
        public var yardHealth: Double
        public var yardMood: Double
        public var yardStanding: Double
        public var yardTroubleChance: Double

        /// The phone: the only thing in here that moves a relationship.
        public var callMood: Double
        public var callRelationships: Double
        public var callAffection: Double

        /// The deal: it pays in standing and costs in everything else.
        public var dealEnergy: Double
        public var dealHealth: Double
        public var dealMood: Double
        public var dealStanding: Double
        public var dealTroubleChance: Double
        /// What carrying something for somebody puts in the wallet.
        public var dealPay: Int

        // MARK: What being inside costs anyway

        /// The slide under every day, whatever the founder chose. Affection
        /// is `CrimeSystem`'s (`insideAffectionPerDay`); this is the rest.
        public var dailyEnergy: Double
        public var dailyHealth: Double
        public var dailyMood: Double
        /// What the partner's own affection loses every day of it. Faster
        /// than an absence: this one has a reason attached to it.
        public var dailyAffection: Double
        /// What an infraction takes off the mood on the day it happens.
        public var infractionMood: Double
        public var infractionHealth: Double

        // MARK: The gang

        /// The day of the sentence the wing gets round to asking.
        public var gangOfferDay: Int
        /// The standing joining is worth on the day.
        public var gangJoinStanding: Double
        /// What refusing costs on the day, and what it multiplies the
        /// yard's trouble by afterwards.
        public var refusedStanding: Double
        public var refusedPenalty: Double
        /// What being in multiplies the yard's trouble by.
        public var gangProtection: Double
        /// How much of the trouble a full standing meter takes off (0…1).
        public var standingProtection: Double

        // MARK: The cellmate

        /// The bond a cellmate starts at, what a day in the yard adds, and
        /// what the phone call adds (they hear it too).
        public var cellmateBondStart: Double
        public var cellmateBondPerYardDay: Double
        public var cellmateBondPerDay: Double

        // MARK: The parole board

        /// Where in the sentence the board sits, 0…1.
        public var paroleAtProgress: Double
        /// The opening standing before the record is read.
        public var paroleOpening: Double
        public var paroleInfractionCost: Double
        public var paroleLibraryCredit: Double
        public var paroleCallCredit: Double
        public var paroleDealCost: Double
        public var paroleGangCost: Double
        /// How much of the standing scale the time already served is worth.
        public var paroleServedCredit: Double
        /// What each thing the caretaker held together is worth.
        public var paroleCaretakerCredit: Double
        /// Exchanges the board hears.
        public var paroleExchanges: Int
        /// The base chance one thing said lands, before the attribute.
        public var paroleLandBase: Double
        public var paroleSkillDivisor: Double
        public var paroleLandInfractionPenalty: Double
        public var paroleCourseCredit: Double
        public var paroleFamilyCredit: Double
        /// The standing at which the board lets the founder out.
        public var paroleGrantStanding: Double

        // MARK: The wall

        public var escapeBase: Double
        public var escapeStandingCredit: Double
        public var escapeLibraryCredit: Double
        /// The later in the sentence, the less anybody believes you meant
        /// to serve it.
        public var escapeLateCost: Double
        /// A failed attempt multiplies what is left of the sentence.
        public var escapeFailureSentenceFactor: Double
        public var escapeFailureInfractions: Int
        /// Notoriety a successful escape is worth, and the day count the
        /// case that never closes is listed for.
        public var escapeNotoriety: Double

        public init(
            headDownEnergy: Double = 1.2,
            headDownMood: Double = -0.8,
            libraryEnergy: Double = 0.5,
            libraryMood: Double = 1.0,
            librarySkillEveryDays: Int = 7,
            librarySkillPoints: Double = 1.0,
            yardEnergy: Double = 0.6,
            yardHealth: Double = 1.4,
            yardMood: Double = 0.5,
            yardStanding: Double = 3.0,
            yardTroubleChance: Double = 0.10,
            callMood: Double = 0.8,
            callRelationships: Double = 2.2,
            callAffection: Double = 0.9,
            dealEnergy: Double = 1.0,
            dealHealth: Double = 0.6,
            dealMood: Double = 1.4,
            dealStanding: Double = 7.0,
            dealTroubleChance: Double = 0.28,
            dealPay: Int = 120,
            dailyEnergy: Double = -0.3,
            dailyHealth: Double = -0.35,
            dailyMood: Double = -0.9,
            dailyAffection: Double = -0.6,
            infractionMood: Double = -6,
            infractionHealth: Double = -4,
            gangOfferDay: Int = 4,
            gangJoinStanding: Double = 22,
            refusedStanding: Double = -6,
            refusedPenalty: Double = 1.6,
            gangProtection: Double = 0.45,
            standingProtection: Double = 0.6,
            cellmateBondStart: Double = 20,
            cellmateBondPerYardDay: Double = 1.6,
            cellmateBondPerDay: Double = 0.35,
            paroleAtProgress: Double = 0.5,
            paroleOpening: Double = -6,
            paroleInfractionCost: Double = 13,
            paroleLibraryCredit: Double = 3.2,
            paroleCallCredit: Double = 1.6,
            paroleDealCost: Double = 4.0,
            paroleGangCost: Double = 10,
            paroleServedCredit: Double = 40,
            paroleCaretakerCredit: Double = 6,
            paroleExchanges: Int = 3,
            paroleLandBase: Double = 0.46,
            paroleSkillDivisor: Double = 210,
            paroleLandInfractionPenalty: Double = 0.06,
            paroleCourseCredit: Double = 0.02,
            paroleFamilyCredit: Double = 0.03,
            paroleGrantStanding: Double = 28,
            escapeBase: Double = 0.16,
            escapeStandingCredit: Double = 0.22,
            escapeLibraryCredit: Double = 0.008,
            escapeLateCost: Double = 0.12,
            escapeFailureSentenceFactor: Double = 2.0,
            escapeFailureInfractions: Int = 2,
            escapeNotoriety: Double = 20
        ) {
            self.headDownEnergy = headDownEnergy
            self.headDownMood = headDownMood
            self.libraryEnergy = libraryEnergy
            self.libraryMood = libraryMood
            self.librarySkillEveryDays = librarySkillEveryDays
            self.librarySkillPoints = librarySkillPoints
            self.yardEnergy = yardEnergy
            self.yardHealth = yardHealth
            self.yardMood = yardMood
            self.yardStanding = yardStanding
            self.yardTroubleChance = yardTroubleChance
            self.callMood = callMood
            self.callRelationships = callRelationships
            self.callAffection = callAffection
            self.dealEnergy = dealEnergy
            self.dealHealth = dealHealth
            self.dealMood = dealMood
            self.dealStanding = dealStanding
            self.dealTroubleChance = dealTroubleChance
            self.dealPay = dealPay
            self.dailyEnergy = dailyEnergy
            self.dailyHealth = dailyHealth
            self.dailyMood = dailyMood
            self.dailyAffection = dailyAffection
            self.infractionMood = infractionMood
            self.infractionHealth = infractionHealth
            self.gangOfferDay = gangOfferDay
            self.gangJoinStanding = gangJoinStanding
            self.refusedStanding = refusedStanding
            self.refusedPenalty = refusedPenalty
            self.gangProtection = gangProtection
            self.standingProtection = standingProtection
            self.cellmateBondStart = cellmateBondStart
            self.cellmateBondPerYardDay = cellmateBondPerYardDay
            self.cellmateBondPerDay = cellmateBondPerDay
            self.paroleAtProgress = paroleAtProgress
            self.paroleOpening = paroleOpening
            self.paroleInfractionCost = paroleInfractionCost
            self.paroleLibraryCredit = paroleLibraryCredit
            self.paroleCallCredit = paroleCallCredit
            self.paroleDealCost = paroleDealCost
            self.paroleGangCost = paroleGangCost
            self.paroleServedCredit = paroleServedCredit
            self.paroleCaretakerCredit = paroleCaretakerCredit
            self.paroleExchanges = paroleExchanges
            self.paroleLandBase = paroleLandBase
            self.paroleSkillDivisor = paroleSkillDivisor
            self.paroleLandInfractionPenalty = paroleLandInfractionPenalty
            self.paroleCourseCredit = paroleCourseCredit
            self.paroleFamilyCredit = paroleFamilyCredit
            self.paroleGrantStanding = paroleGrantStanding
            self.escapeBase = escapeBase
            self.escapeStandingCredit = escapeStandingCredit
            self.escapeLibraryCredit = escapeLibraryCredit
            self.escapeLateCost = escapeLateCost
            self.escapeFailureSentenceFactor = escapeFailureSentenceFactor
            self.escapeFailureInfractions = escapeFailureInfractions
            self.escapeNotoriety = escapeNotoriety
        }

        /// Every field decodes if present, so `"prison"` may be a partial
        /// object — or absent altogether.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = PrisonBalance()
            func value(_ key: CodingKeys, _ fallbackValue: Double) throws -> Double {
                try container.decodeIfPresent(Double.self, forKey: key) ?? fallbackValue
            }
            func count(_ key: CodingKeys, _ fallbackValue: Int) throws -> Int {
                try container.decodeIfPresent(Int.self, forKey: key) ?? fallbackValue
            }
            self.init(
                headDownEnergy: try value(.headDownEnergy, fallback.headDownEnergy),
                headDownMood: try value(.headDownMood, fallback.headDownMood),
                libraryEnergy: try value(.libraryEnergy, fallback.libraryEnergy),
                libraryMood: try value(.libraryMood, fallback.libraryMood),
                librarySkillEveryDays: try count(.librarySkillEveryDays, fallback.librarySkillEveryDays),
                librarySkillPoints: try value(.librarySkillPoints, fallback.librarySkillPoints),
                yardEnergy: try value(.yardEnergy, fallback.yardEnergy),
                yardHealth: try value(.yardHealth, fallback.yardHealth),
                yardMood: try value(.yardMood, fallback.yardMood),
                yardStanding: try value(.yardStanding, fallback.yardStanding),
                yardTroubleChance: try value(.yardTroubleChance, fallback.yardTroubleChance),
                callMood: try value(.callMood, fallback.callMood),
                callRelationships: try value(.callRelationships, fallback.callRelationships),
                callAffection: try value(.callAffection, fallback.callAffection),
                dealEnergy: try value(.dealEnergy, fallback.dealEnergy),
                dealHealth: try value(.dealHealth, fallback.dealHealth),
                dealMood: try value(.dealMood, fallback.dealMood),
                dealStanding: try value(.dealStanding, fallback.dealStanding),
                dealTroubleChance: try value(.dealTroubleChance, fallback.dealTroubleChance),
                dealPay: try count(.dealPay, fallback.dealPay),
                dailyEnergy: try value(.dailyEnergy, fallback.dailyEnergy),
                dailyHealth: try value(.dailyHealth, fallback.dailyHealth),
                dailyMood: try value(.dailyMood, fallback.dailyMood),
                dailyAffection: try value(.dailyAffection, fallback.dailyAffection),
                infractionMood: try value(.infractionMood, fallback.infractionMood),
                infractionHealth: try value(.infractionHealth, fallback.infractionHealth),
                gangOfferDay: try count(.gangOfferDay, fallback.gangOfferDay),
                gangJoinStanding: try value(.gangJoinStanding, fallback.gangJoinStanding),
                refusedStanding: try value(.refusedStanding, fallback.refusedStanding),
                refusedPenalty: try value(.refusedPenalty, fallback.refusedPenalty),
                gangProtection: try value(.gangProtection, fallback.gangProtection),
                standingProtection: try value(.standingProtection, fallback.standingProtection),
                cellmateBondStart: try value(.cellmateBondStart, fallback.cellmateBondStart),
                cellmateBondPerYardDay: try value(.cellmateBondPerYardDay, fallback.cellmateBondPerYardDay),
                cellmateBondPerDay: try value(.cellmateBondPerDay, fallback.cellmateBondPerDay),
                paroleAtProgress: try value(.paroleAtProgress, fallback.paroleAtProgress),
                paroleOpening: try value(.paroleOpening, fallback.paroleOpening),
                paroleInfractionCost: try value(.paroleInfractionCost, fallback.paroleInfractionCost),
                paroleLibraryCredit: try value(.paroleLibraryCredit, fallback.paroleLibraryCredit),
                paroleCallCredit: try value(.paroleCallCredit, fallback.paroleCallCredit),
                paroleDealCost: try value(.paroleDealCost, fallback.paroleDealCost),
                paroleGangCost: try value(.paroleGangCost, fallback.paroleGangCost),
                paroleServedCredit: try value(.paroleServedCredit, fallback.paroleServedCredit),
                paroleCaretakerCredit: try value(.paroleCaretakerCredit, fallback.paroleCaretakerCredit),
                paroleExchanges: try count(.paroleExchanges, fallback.paroleExchanges),
                paroleLandBase: try value(.paroleLandBase, fallback.paroleLandBase),
                paroleSkillDivisor: try value(.paroleSkillDivisor, fallback.paroleSkillDivisor),
                paroleLandInfractionPenalty: try value(
                    .paroleLandInfractionPenalty, fallback.paroleLandInfractionPenalty
                ),
                paroleCourseCredit: try value(.paroleCourseCredit, fallback.paroleCourseCredit),
                paroleFamilyCredit: try value(.paroleFamilyCredit, fallback.paroleFamilyCredit),
                paroleGrantStanding: try value(.paroleGrantStanding, fallback.paroleGrantStanding),
                escapeBase: try value(.escapeBase, fallback.escapeBase),
                escapeStandingCredit: try value(.escapeStandingCredit, fallback.escapeStandingCredit),
                escapeLibraryCredit: try value(.escapeLibraryCredit, fallback.escapeLibraryCredit),
                escapeLateCost: try value(.escapeLateCost, fallback.escapeLateCost),
                escapeFailureSentenceFactor: try value(
                    .escapeFailureSentenceFactor, fallback.escapeFailureSentenceFactor
                ),
                escapeFailureInfractions: try count(
                    .escapeFailureInfractions, fallback.escapeFailureInfractions
                ),
                escapeNotoriety: try value(.escapeNotoriety, fallback.escapeNotoriety)
            )
        }

        public static let `default` = PrisonBalance()
    }
}
