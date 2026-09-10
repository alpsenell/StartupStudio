import Foundation

// Iteration 16 — S2 (office downgrade). Moving one office tier down the
// ladder: the honest inverse of `upgradeOffice`.
//
// Every number here is read only by `.downgradeOffice`, which no bot sends,
// and by the morale drag it stores (`GameState.officeDowngrade`). A run that
// never moves down reads none of them. `"officeDowngrade"` is appended at
// the end of `Balance.json`; a balance file without it reads these
// defaults.
//
// - The move costs `moveCostBase + moveCostRentWeeks ×` the current tier's
//   listed rent in the office's district: the movers, the broken lease.
// - Everybody's morale target sits `moraleDrag` lower for `moraleDragDays`:
//   people read a smaller office as a company shrinking.
// - Reputation drops `reputationCost` on the day: so does everybody else.

extension BalanceConfig {

    // MARK: - Office downgrade

    public struct OfficeDowngradeBalance: Codable, Equatable, Sendable {
        /// The flat part of a move down: movers, the van, the week lost.
        public var moveCostBase: Int
        /// Weeks of the tier being left's rent (district-scaled) the move
        /// also costs: the lease does not end because you did.
        public var moveCostRentWeeks: Int
        /// Points off every employee's morale target while the drag runs.
        public var moraleDrag: Double
        /// How long the drag runs, in days.
        public var moraleDragDays: Int
        /// Reputation lost on the day of the move.
        public var reputationCost: Double

        public init(
            moveCostBase: Int = 2_000,
            moveCostRentWeeks: Int = 2,
            moraleDrag: Double = 5,
            moraleDragDays: Int = 91,
            reputationCost: Double = 3
        ) {
            self.moveCostBase = moveCostBase
            self.moveCostRentWeeks = moveCostRentWeeks
            self.moraleDrag = moraleDrag
            self.moraleDragDays = moraleDragDays
            self.reputationCost = reputationCost
        }

        /// The shipped numbers.
        public static let `default` = OfficeDowngradeBalance()

        private enum CodingKeys: String, CodingKey {
            case moveCostBase, moveCostRentWeeks, moraleDrag, moraleDragDays, reputationCost
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                moveCostBase: try container.decodeIfPresent(Int.self, forKey: .moveCostBase)
                    ?? fallback.moveCostBase,
                moveCostRentWeeks: try container.decodeIfPresent(Int.self, forKey: .moveCostRentWeeks)
                    ?? fallback.moveCostRentWeeks,
                moraleDrag: try container.decodeIfPresent(Double.self, forKey: .moraleDrag)
                    ?? fallback.moraleDrag,
                moraleDragDays: try container.decodeIfPresent(Int.self, forKey: .moraleDragDays)
                    ?? fallback.moraleDragDays,
                reputationCost: try container.decodeIfPresent(Double.self, forKey: .reputationCost)
                    ?? fallback.reputationCost
            )
        }
    }
}
