import Foundation

// Iteration 11, wave two — W1. The three backers, their cheques, their
// strings and what heat costs.
//
// Every number here is read from exactly one place: `DirtyMoneySystem`,
// which returns on its first line while `state.dirtyMoney` is `.empty` —
// which it is until the player opens the Business tab's finances. So a
// balance file that turns all of this up is still bit-for-bit the game
// that ships, and a run that never looks at its own finances never reads
// a field in this file.
//
// No multiplier here sits in an existing pipeline: every figure is a
// cheque, a bill or a degree of heat that only exists once somebody has
// banked money they should not have.

extension BalanceConfig {

    // MARK: - Dirty money

    public struct DirtyMoneyBalance: Codable, Equatable, Sendable {

        // MARK: When the offer comes

        /// The offer is only ever made to a company in trouble: cash below
        /// this many weeks of operating cost, or a term sheet turned down
        /// inside the last quarter.
        public var redCashWeeks: Double
        /// How far back a declined term sheet counts.
        public var declinedWindowDays: Int
        /// The weekly chance an offer arrives once the conditions hold.
        public var offerChance: Double
        /// How long the offer stands.
        public var offerDays: Int
        /// No offer before this day, whatever the balance sheet says: a
        /// garage in its first fortnight is not worth anybody's trouble.
        public var offerNotBeforeDay: Int

        // MARK: The cheques

        public var familyOfficeCheque: Int
        public var frontCheque: Int
        public var sharkCheque: Int
        /// The cheque grows with the weekly payroll, capped, so the money
        /// is always a plausible amount of money for the company it lands
        /// in.
        public var chequePayrollDivisor: Int
        public var chequePayrollCap: Double

        // MARK: The strings

        /// The family office's consultant, in days after the cheque.
        public var consultantAfterDays: Int
        /// The market they name, in days after the cheque.
        public var theirMarketAfterDays: Int
        /// The front's first invoice, and every one after it.
        public var invoiceAfterDays: Int
        public var invoiceEveryDays: Int
        /// The nephew, in days after the first invoice is paid.
        public var nephewAfterDays: Int
        /// How long the founder has to answer a string.
        public var demandRespondDays: Int
        /// What a stall buys.
        public var stallDays: Int

        /// What each string costs, as a fraction of the cheque.
        public var invoiceFractionOfCheque: Double
        public var invoiceFloor: Int
        public var vigFractionOfCheque: Double
        public var vigFloor: Int
        public var consultantFractionOfCheque: Double
        public var nephewFractionOfCheque: Double
        public var passengerFloor: Int

        /// A passenger on the payroll is noticed by the people who are
        /// actually doing the work.
        public var passengerMoralePerWeek: Double

        // MARK: The heat

        public var complyHeatRelief: Double
        public var stallHeat: Double
        public var refuseHeat: Double
        /// A string about money is worth more heat than a favour.
        public var paymentHeatWeight: Double
        /// Heat cools by this much a week, once nothing is outstanding.
        public var heatDecayPerWeek: Double
        /// Below this the heat never pays out.
        public var reprisalHeatFloor: Double
        public var reprisalFactor: Double
        public var reprisalCeiling: Double
        /// Days between two reprisals, so a bad month is not a bad week.
        public var reprisalCooldownDays: Int

        /// What a reprisal costs where it costs something.
        public var windowRepairCost: Int
        public var windowMoraleHit: Double
        public var friendBondHit: Double
        public var rivalStrengthGain: Double
        public var reprisalMoodHit: Double

        // MARK: Laundering

        /// Notoriety a payment through the backer adds, per payment.
        /// (The weekly chance one is *found* is `Crime.launderDiscovery`,
        /// a constant in N1's file: `Crime.discoveryChance` is handed the
        /// crime block alone and cannot reach this one.)
        public var launderNotoriety: Double

        // MARK: The ways out

        /// The payoff: this many times the cheque, plus a surcharge for
        /// the heat.
        public var payoffMultiple: Double
        public var payoffHeatSurcharge: Double
        /// What turning witness does to the heat that is left: it becomes
        /// permanent, and this is what it settles at.
        public var witnessHeatFloor: Double
        /// What they will pay for the company, as a fraction of its
        /// valuation.
        public var sellUpValuationFraction: Double
        /// What the founder walks away with, as a fraction of the price.
        public var sellUpFounderFraction: Double

        public init(
            redCashWeeks: Double = 4,
            declinedWindowDays: Int = 90,
            offerChance: Double = 0.35,
            offerDays: Int = 7,
            offerNotBeforeDay: Int = 30,
            familyOfficeCheque: Int = 240_000,
            frontCheque: Int = 90_000,
            sharkCheque: Int = 30_000,
            chequePayrollDivisor: Int = 4_000,
            chequePayrollCap: Double = 2.0,
            consultantAfterDays: Int = 56,
            theirMarketAfterDays: Int = 168,
            invoiceAfterDays: Int = 45,
            invoiceEveryDays: Int = 90,
            nephewAfterDays: Int = 30,
            demandRespondDays: Int = 10,
            stallDays: Int = 14,
            invoiceFractionOfCheque: Double = 0.12,
            invoiceFloor: Int = 4_000,
            vigFractionOfCheque: Double = 0.035,
            vigFloor: Int = 500,
            consultantFractionOfCheque: Double = 0.008,
            nephewFractionOfCheque: Double = 0.005,
            passengerFloor: Int = 400,
            passengerMoralePerWeek: Double = 0.6,
            complyHeatRelief: Double = 6,
            stallHeat: Double = 9,
            refuseHeat: Double = 26,
            paymentHeatWeight: Double = 1.25,
            heatDecayPerWeek: Double = 1.5,
            reprisalHeatFloor: Double = 25,
            reprisalFactor: Double = 0.55,
            reprisalCeiling: Double = 0.4,
            reprisalCooldownDays: Int = 21,
            windowRepairCost: Int = 3_500,
            windowMoraleHit: Double = 7,
            friendBondHit: Double = 22,
            rivalStrengthGain: Double = 6,
            reprisalMoodHit: Double = 12,
            launderNotoriety: Double = 7,
            payoffMultiple: Double = 2.2,
            payoffHeatSurcharge: Double = 1.4,
            witnessHeatFloor: Double = 55,
            sellUpValuationFraction: Double = 0.45,
            sellUpFounderFraction: Double = 0.35
        ) {
            self.redCashWeeks = redCashWeeks
            self.declinedWindowDays = declinedWindowDays
            self.offerChance = offerChance
            self.offerDays = offerDays
            self.offerNotBeforeDay = offerNotBeforeDay
            self.familyOfficeCheque = familyOfficeCheque
            self.frontCheque = frontCheque
            self.sharkCheque = sharkCheque
            self.chequePayrollDivisor = chequePayrollDivisor
            self.chequePayrollCap = chequePayrollCap
            self.consultantAfterDays = consultantAfterDays
            self.theirMarketAfterDays = theirMarketAfterDays
            self.invoiceAfterDays = invoiceAfterDays
            self.invoiceEveryDays = invoiceEveryDays
            self.nephewAfterDays = nephewAfterDays
            self.demandRespondDays = demandRespondDays
            self.stallDays = stallDays
            self.invoiceFractionOfCheque = invoiceFractionOfCheque
            self.invoiceFloor = invoiceFloor
            self.vigFractionOfCheque = vigFractionOfCheque
            self.vigFloor = vigFloor
            self.consultantFractionOfCheque = consultantFractionOfCheque
            self.nephewFractionOfCheque = nephewFractionOfCheque
            self.passengerFloor = passengerFloor
            self.passengerMoralePerWeek = passengerMoralePerWeek
            self.complyHeatRelief = complyHeatRelief
            self.stallHeat = stallHeat
            self.refuseHeat = refuseHeat
            self.paymentHeatWeight = paymentHeatWeight
            self.heatDecayPerWeek = heatDecayPerWeek
            self.reprisalHeatFloor = reprisalHeatFloor
            self.reprisalFactor = reprisalFactor
            self.reprisalCeiling = reprisalCeiling
            self.reprisalCooldownDays = reprisalCooldownDays
            self.windowRepairCost = windowRepairCost
            self.windowMoraleHit = windowMoraleHit
            self.friendBondHit = friendBondHit
            self.rivalStrengthGain = rivalStrengthGain
            self.reprisalMoodHit = reprisalMoodHit
            self.launderNotoriety = launderNotoriety
            self.payoffMultiple = payoffMultiple
            self.payoffHeatSurcharge = payoffHeatSurcharge
            self.witnessHeatFloor = witnessHeatFloor
            self.sellUpValuationFraction = sellUpValuationFraction
            self.sellUpFounderFraction = sellUpFounderFraction
        }

        /// The shipped rules. Like the crime block, the default is not
        /// "switched off" — there is nothing to switch off until the
        /// player opens the finances — so a balance file with no
        /// `"dirtyMoney"` object still gets the game that ships.
        public static let `default` = DirtyMoneyBalance()

        /// The base cheque a backer writes.
        public func cheque(for backer: DirtyMoneyBacker) -> Int {
            switch backer {
            case .familyOffice: familyOfficeCheque
            case .theFront: frontCheque
            case .theShark: sharkCheque
            }
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"dirtyMoney"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.DirtyMoneyBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.DirtyMoneyBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
