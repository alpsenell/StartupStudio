import Foundation

// Iteration 9 — L6. The sabbatical: what it costs to walk away for a
// summer, who is allowed to mind the shop, and what the caretaker does
// with it.
//
// Every knob here is read *only* while `state.life.sabbatical?.isActive`
// is true, which is only ever true because the player pressed a button.
// The two dials that reach other systems (`boardPatienceFactor`,
// `poachChanceFactor`) are asked for through `SabbaticalEffects`, which
// answers "unchanged" and "×1" whenever nobody is away — so a run that
// never takes a sabbatical is bit-for-bit the run it was before this file
// existed, whatever the numbers below say.

extension BalanceConfig {

    // MARK: - Sabbatical

    public struct SabbaticalBalance: Codable, Equatable, Sendable {
        // MARK: Gates

        /// Weeks on the payroll before somebody can be handed the company.
        public var minTenureWeeks: Int
        /// Founder bond they need. A caretaker is a relationship, not an
        /// org-chart position: the best engineer in the room cannot have
        /// the keys if the founder has never bought them a coffee.
        public var minBond: Double
        /// Nobody minds an empty office.
        public var minHeadcount: Int
        public var minWeeks: Int
        public var maxWeeks: Int
        /// A build landing inside this many days keeps the founder home.
        public var shipLockoutDays: Int
        /// Wallet money per week away — flights, the rented house, the
        /// months of not being paid to be somewhere.
        public var weeklyCost: Int

        // MARK: Being away

        /// What a week off the treadmill gives back, per day.
        public var healthPerDay: Double
        public var energyPerDay: Double
        public var moodPerDay: Double
        /// The partner gets the founder back, which is the point.
        public var affectionPerDay: Double

        /// Days between the caretaker's calls. One a week, at most.
        public var decisionIntervalDays: Int
        /// How finished a build has to be before a caretaker ships it,
        /// as a multiple of the founder's own ship gate. A Speedster uses
        /// `speedsterShipFactor` instead and gets it out of the door.
        public var shipFactor: Double
        public var speedsterShipFactor: Double
        /// Chance, per decision, that the caretaker spends money on a hire
        /// instead of taking the ladder's next rung.
        public var hireChance: Double
        /// Weeks of runway a caretaker insists on before hiring anybody.
        public var hireRunwayWeeks: Int
        /// A Grumbler in charge is a room that stops being tidied: morale
        /// target drift per day, applied to everybody but them.
        public var grumblerMoralePerDay: Double
        /// A Mentor in charge teaches instead of shipping: extra skill a
        /// week of their care is worth to the weakest person on the team.
        public var mentorSkillGain: Double
        /// Chance per decision that a Flight Risk caretaker takes the call
        /// they have been half-listening to and leaves — which ends the
        /// sabbatical on the spot.
        public var flightRiskLeaveChance: Double

        // MARK: What it costs the company

        /// The board's patience, multiplied, while the founder is away.
        /// 0.5 = a fund that gave you six months gives the caretaker three.
        public var boardPatienceFactor: Double
        /// Rivals' poach odds, multiplied, while the founder is away.
        public var poachChanceFactor: Double
        /// Bond the caretaker loses if the founder flies home early.
        public var earlyEndBondPenalty: Double

        public init(
            minTenureWeeks: Int = 26,
            minBond: Double = 50,
            minHeadcount: Int = 2,
            minWeeks: Int = 4,
            maxWeeks: Int = 12,
            shipLockoutDays: Int = 14,
            weeklyCost: Int = 500,
            healthPerDay: Double = 0.7,
            energyPerDay: Double = 1.0,
            moodPerDay: Double = 0.5,
            affectionPerDay: Double = 0.4,
            decisionIntervalDays: Int = 7,
            shipFactor: Double = 1.15,
            speedsterShipFactor: Double = 1.0,
            hireChance: Double = 0.2,
            hireRunwayWeeks: Int = 26,
            grumblerMoralePerDay: Double = -0.15,
            mentorSkillGain: Double = 2.5,
            flightRiskLeaveChance: Double = 0.12,
            boardPatienceFactor: Double = 0.5,
            poachChanceFactor: Double = 1.5,
            earlyEndBondPenalty: Double = 25
        ) {
            self.minTenureWeeks = minTenureWeeks
            self.minBond = minBond
            self.minHeadcount = minHeadcount
            self.minWeeks = minWeeks
            self.maxWeeks = maxWeeks
            self.shipLockoutDays = shipLockoutDays
            self.weeklyCost = weeklyCost
            self.healthPerDay = healthPerDay
            self.energyPerDay = energyPerDay
            self.moodPerDay = moodPerDay
            self.affectionPerDay = affectionPerDay
            self.decisionIntervalDays = decisionIntervalDays
            self.shipFactor = shipFactor
            self.speedsterShipFactor = speedsterShipFactor
            self.hireChance = hireChance
            self.hireRunwayWeeks = hireRunwayWeeks
            self.grumblerMoralePerDay = grumblerMoralePerDay
            self.mentorSkillGain = mentorSkillGain
            self.flightRiskLeaveChance = flightRiskLeaveChance
            self.boardPatienceFactor = boardPatienceFactor
            self.poachChanceFactor = poachChanceFactor
            self.earlyEndBondPenalty = earlyEndBondPenalty
        }

        /// The shipped sabbatical. Unlike most blocks in this folder the
        /// default is not "switched off": there is nothing to switch off
        /// until the player hands somebody the keys, and a balance file
        /// with no `"sabbatical"` object should still be able to offer
        /// one. Identity is kept by the gate, not by the numbers.
        public static let `default` = SabbaticalBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"sabbatical"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.SabbaticalBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.SabbaticalBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
