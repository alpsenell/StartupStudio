import Foundation

// Iteration 13 — P1. What the shop's items are worth, in game terms
// (docs/product/iteration-13-iap.md §1, §3).
//
// Read only when a purchase is applied or priced on a surface, so the
// defaults are the shipped numbers and nothing here can move a run that
// bought nothing. `"purchase"` is an optional key: a balance file without
// it reads these defaults.
//
// - Cash is `weeks × max(weeklyBurn, cashFloorPerWeek)`, capped at
//   `cashCapMonth` for a month (≤ 4 weeks) and `cashCapQuarter` beyond.
// - The veteran rolls at the office tier's candidate ceiling plus
//   `veteranSkillBonus`, capped at `veteranSkillCap`, each skill within
//   `veteranSkillSpread` of its ceiling, and asks `veteranSalaryFactor`
//   times the pool's salary formula for those skills.

extension BalanceConfig {

    // MARK: - Purchases

    public struct PurchaseBalance: Codable, Equatable, Sendable {
        /// The least a week of runway is worth: a garage's honest week is
        /// ~$450, which is not a product.
        public var cashFloorPerWeek: Int
        /// The most a month of runway posts.
        public var cashCapMonth: Int
        /// The most a quarter of runway posts.
        public var cashCapQuarter: Int
        /// Added to the tier's candidate ceiling for the veteran.
        public var veteranSkillBonus: Double
        /// No skill of the veteran's rolls above this.
        public var veteranSkillCap: Double
        /// How far under its ceiling a veteran's skill can roll.
        public var veteranSkillSpread: Double
        /// The veteran's ask over the pool's formula for the same skills.
        public var veteranSalaryFactor: Double
        /// What the trade press takes off the reputation when the receiver
        /// calls (§8: −10 if the call becomes the meta).
        public var secondChanceReputationCost: Double

        public init(
            cashFloorPerWeek: Int = 2_000,
            cashCapMonth: Int = 250_000,
            cashCapQuarter: Int = 1_000_000,
            veteranSkillBonus: Double = 15,
            veteranSkillCap: Double = 95,
            veteranSkillSpread: Double = 10,
            veteranSalaryFactor: Double = 1.4,
            secondChanceReputationCost: Double = 5
        ) {
            self.cashFloorPerWeek = cashFloorPerWeek
            self.cashCapMonth = cashCapMonth
            self.cashCapQuarter = cashCapQuarter
            self.veteranSkillBonus = veteranSkillBonus
            self.veteranSkillCap = veteranSkillCap
            self.veteranSkillSpread = veteranSkillSpread
            self.veteranSalaryFactor = veteranSalaryFactor
            self.secondChanceReputationCost = secondChanceReputationCost
        }

        /// The shipped numbers.
        public static let `default` = PurchaseBalance()

        private enum CodingKeys: String, CodingKey {
            case cashFloorPerWeek, cashCapMonth, cashCapQuarter
            case veteranSkillBonus, veteranSkillCap, veteranSkillSpread, veteranSalaryFactor
            case secondChanceReputationCost
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                cashFloorPerWeek: try container.decodeIfPresent(Int.self, forKey: .cashFloorPerWeek)
                    ?? fallback.cashFloorPerWeek,
                cashCapMonth: try container.decodeIfPresent(Int.self, forKey: .cashCapMonth)
                    ?? fallback.cashCapMonth,
                cashCapQuarter: try container.decodeIfPresent(Int.self, forKey: .cashCapQuarter)
                    ?? fallback.cashCapQuarter,
                veteranSkillBonus: try container.decodeIfPresent(Double.self, forKey: .veteranSkillBonus)
                    ?? fallback.veteranSkillBonus,
                veteranSkillCap: try container.decodeIfPresent(Double.self, forKey: .veteranSkillCap)
                    ?? fallback.veteranSkillCap,
                veteranSkillSpread: try container.decodeIfPresent(Double.self, forKey: .veteranSkillSpread)
                    ?? fallback.veteranSkillSpread,
                veteranSalaryFactor: try container.decodeIfPresent(Double.self, forKey: .veteranSalaryFactor)
                    ?? fallback.veteranSalaryFactor,
                secondChanceReputationCost: try container.decodeIfPresent(
                    Double.self, forKey: .secondChanceReputationCost
                ) ?? fallback.secondChanceReputationCost
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"purchase"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.PurchaseBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.PurchaseBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
