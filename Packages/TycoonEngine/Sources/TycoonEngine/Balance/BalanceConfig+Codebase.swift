import Foundation

/// The `"codebase"` block of `Balance.json`: what a product leaves behind,
/// what building on it is worth, what the debt costs, and how fast people
/// taken off production work can pay it down.
///
/// Every field has a default, so an older balance file without the block
/// still decodes — and every default here is the *shipped* value, not a
/// neutral one, because the neutral case is reached by having no codebase
/// at all rather than by zeroing the table.
///
/// **The one invariant this file exists to protect.** A greenfield build
/// carries no codebase, so `debt` is exactly 0, `debtCeiling(0)` is exactly
/// 1.0 and `bugRateMultiplier(0)` is exactly 1.0 — the arithmetic in
/// `ProductSystem.ship` is bit-for-bit what it was before this block
/// existed. Nothing in here can move the pacing bots, which never build on
/// a codebase; see `CodebaseSystem` for why the debt a build *accrues* is
/// also inert until ship.
extension BalanceConfig {
    public struct CodebaseBalance: Codable, Equatable, Sendable {
        // MARK: The head start

        /// The share of a shipped product's filled pools that carries into
        /// the codebase — and so into the next product built on it. The
        /// whole visible upside of the trade.
        public var carryFraction: Double

        // MARK: What debt costs

        /// Ceiling lost per point of debt: the quality ceiling is
        /// multiplied by `1 − debt × this`, floored at `ceilingFloor`.
        /// Exactly 1.0 at debt 0.
        ///
        /// At 0.004 a codebase carrying 55 points of debt caps a crew that
        /// could reach 78 at 61 — the sentence the ship sheet was built to
        /// be able to say — and the hard debt cap works out to a ceiling
        /// of 0.60, hard but not hopeless. Halving it to 0.002 leaves the
        /// worst codebase in the game costing three review points, which
        /// nobody would refactor for.
        public var debtCeilingPenaltyPerPoint: Double
        /// The worst a codebase can cap you at, however bad it gets. A
        /// floor rather than an asymptote so the number on the ship sheet
        /// stays a number the player can plan against. Deliberately below
        /// what `debtCap × debtCeilingPenaltyPerPoint` can reach (0.60), so
        /// it is a safety net for a retune rather than the operating
        /// point of the shipped balance.
        public var ceilingFloor: Double
        /// Added to the bug-chance multiplier per point of debt: bugs you
        /// did not write. Exactly 1.0 at debt 0.
        public var debtBugRatePerPoint: Double
        /// The hard cap on a codebase's debt. Past it, more crunch costs
        /// nothing extra — the codebase is already the worst it can be,
        /// and the player needs a reason to refactor rather than a reason
        /// to give up.
        public var debtCap: Double

        // MARK: Where debt comes from

        /// Debt added per day the whole company is on `.crunch` while a
        /// build is running. Charged once per crunching build per day, not
        /// once per person: shortcuts are taken by the schedule, not by
        /// the headcount.
        ///
        /// 0.15 was measured, not guessed. A bot crunching every single
        /// day for two years and never refactoring finishes on a debt of
        /// 75 out of a cap of 100 — still a slope with somewhere left to
        /// fall, which is the point. At 0.25 the same run saturates the
        /// cap inside the window and the dial stops being a dial; at 0.10
        /// a whole crunched year costs a ceiling multiplier of 0.90 and
        /// reads as rounding. See `CodebaseProbeTests.codebaseTable`.
        public var crunchDebtPerDay: Double
        /// Debt added per bug still open when the product ships. Shipping
        /// a bug list is a decision, and this is the half of its price
        /// that outlives the launch.
        public var shipBugDebt: Double
        /// Debt added by each completed patch cycle. Small — a patch is
        /// mostly bug fixes — but a product walked to the review ceiling
        /// on twelve patches leaves a codebase nobody wants.
        public var patchDebt: Double

        // MARK: Paying it down

        /// Debt cleared per refactoring day, before the skill term. The
        /// shape mirrors `researchBasePoints`: the other assignment that
        /// produces nothing anyone can see.
        ///
        /// Sized so refactoring is measured in weeks and not days: one
        /// mid-level developer (coding 60) clears 0.65 a day, so digging a
        /// studio out of the 75 points two years of crunch leaves takes
        /// one person about four months, or three people about six weeks.
        /// It has to be long enough that taking people off production
        /// work is the decision — if it were a fortnight nobody would
        /// think about it.
        public var refactorBasePoints: Double
        /// Coding skill is divided by this and added to the daily cut.
        public var refactorCodingDivisor: Double

        public init(
            carryFraction: Double = 0.35,
            debtCeilingPenaltyPerPoint: Double = 0.004,
            ceilingFloor: Double = 0.55,
            debtBugRatePerPoint: Double = 0.010,
            debtCap: Double = 100,
            crunchDebtPerDay: Double = 0.15,
            shipBugDebt: Double = 0.5,
            patchDebt: Double = 2,
            refactorBasePoints: Double = 0.35,
            refactorCodingDivisor: Double = 200
        ) {
            self.carryFraction = carryFraction
            self.debtCeilingPenaltyPerPoint = debtCeilingPenaltyPerPoint
            self.ceilingFloor = ceilingFloor
            self.debtBugRatePerPoint = debtBugRatePerPoint
            self.debtCap = debtCap
            self.crunchDebtPerDay = crunchDebtPerDay
            self.shipBugDebt = shipBugDebt
            self.patchDebt = patchDebt
            self.refactorBasePoints = refactorBasePoints
            self.refactorCodingDivisor = refactorCodingDivisor
        }

        public static let `default` = CodebaseBalance()

        /// A block that changes nothing: no head start, free debt, and a
        /// refactor that does nothing. For tests that want the codebase
        /// plumbing without its arithmetic.
        public static let neutral = CodebaseBalance(
            carryFraction: 0,
            debtCeilingPenaltyPerPoint: 0,
            ceilingFloor: 1,
            debtBugRatePerPoint: 0,
            crunchDebtPerDay: 0,
            shipBugDebt: 0,
            patchDebt: 0,
            refactorBasePoints: 0,
            refactorCodingDivisor: 1_000_000
        )

        /// The share of full quality a codebase carrying `debt` still
        /// allows. **Exactly 1.0 at debt 0** — the hard repo rule that
        /// keeps a greenfield build identical to the shipped balance.
        public func debtCeiling(_ debt: Double) -> Double {
            guard debt > 0 else { return 1 }
            return max(ceilingFloor, 1 - debt * debtCeilingPenaltyPerPoint)
        }

        /// The multiplier this much debt puts on the chance a completed
        /// code point ships a bug. **Exactly 1.0 at debt 0.**
        public func bugRateMultiplier(_ debt: Double) -> Double {
            guard debt > 0 else { return 1 }
            return 1 + debt * debtBugRatePerPoint
        }

        /// `debt` clamped into the legal range.
        public func clampDebt(_ debt: Double) -> Double {
            min(debtCap, max(0, debt))
        }
    }
}
