import Foundation

// Iteration 17 — T3 (people). What letting somebody go costs.
//
// Every number here is read only behind the player's own taps: the plain
// firing's new `payNotice` argument (defaulted off, so the resignation
// sheet, the move-down debug seed and every test keep the old free
// path), the with-cause interaction (which no bot sends), and
// `.layOff`, which no bot sends. A run that never fires anybody reads
// none of them. `"severance"` is appended at the end of `Balance.json`;
// a balance file without it reads these defaults.
//
// - Plain firing pays notice: `weeksPerQuarterTenure` weeks of salary for
//   every full quarter (13 weeks) served, capped at `maxWeeks`.
// - With cause is free, and the room sees it: `causeMoraleAll` on everyone
//   who stays, and when the person's morale was over `claimMoraleOver` a
//   wrongful-dismissal claim lands with `claimChance` (one `socialRNG`
//   word, on the tap), for `claimWeeksPay` weeks of their pay to settle,
//   or `claimLostFactor` of that if the court finds for them.
// - Several at once is a layoff: the notice totalled, `layoffMoralePerHead`
//   a head on everyone who stays (capped at `layoffMoraleCap`), reputation
//   −`layoffReputationPerThree` for every three people, and a seated board
//   that watches headcount reads it as a miss.
//
// The measured check (T3 report): the studio fixture's eleven people cost
// $14,368 of notice plain; with cause the expected claim at the spec's 20%
// was $27,802, more than the notice, so the chance is halved to 10%.

extension BalanceConfig {

    // MARK: - Severance

    public struct SeveranceBalance: Codable, Equatable, Sendable {
        /// The notice cap, in weeks of salary.
        public var maxWeeks: Int
        /// Weeks of notice per full quarter (13 weeks) served.
        public var weeksPerQuarterTenure: Int
        /// Morale on everyone who stays when somebody is fired for cause.
        public var causeMoraleAll: Double
        /// The chance of a wrongful-dismissal claim, drawn only when the
        /// person's morale was over `claimMoraleOver`.
        public var claimChance: Double
        public var claimMoraleOver: Double
        /// The claim's settlement price, in weeks of the person's pay.
        public var claimWeeksPay: Int
        /// What losing the claim in court costs, as a multiple of the
        /// settlement price.
        public var claimLostFactor: Double
        /// Morale on everyone who stays, per head let go in one layoff.
        public var layoffMoralePerHead: Double
        /// The floor of that hit, however many go.
        public var layoffMoraleCap: Double
        /// Reputation lost for every three people in one layoff.
        public var layoffReputationPerThree: Double

        public init(
            maxWeeks: Int = 4,
            weeksPerQuarterTenure: Int = 1,
            causeMoraleAll: Double = -4,
            claimChance: Double = 0.1,
            claimMoraleOver: Double = 50,
            claimWeeksPay: Int = 8,
            claimLostFactor: Double = 1.5,
            layoffMoralePerHead: Double = -2,
            layoffMoraleCap: Double = -10,
            layoffReputationPerThree: Double = 1
        ) {
            self.maxWeeks = maxWeeks
            self.weeksPerQuarterTenure = weeksPerQuarterTenure
            self.causeMoraleAll = causeMoraleAll
            self.claimChance = claimChance
            self.claimMoraleOver = claimMoraleOver
            self.claimWeeksPay = claimWeeksPay
            self.claimLostFactor = claimLostFactor
            self.layoffMoralePerHead = layoffMoralePerHead
            self.layoffMoraleCap = layoffMoraleCap
            self.layoffReputationPerThree = layoffReputationPerThree
        }

        /// The shipped numbers.
        public static let `default` = SeveranceBalance()

        private enum CodingKeys: String, CodingKey {
            case maxWeeks, weeksPerQuarterTenure, causeMoraleAll, claimChance, claimMoraleOver
            case claimWeeksPay, claimLostFactor, layoffMoralePerHead, layoffMoraleCap
            case layoffReputationPerThree
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                maxWeeks: try container.decodeIfPresent(Int.self, forKey: .maxWeeks)
                    ?? fallback.maxWeeks,
                weeksPerQuarterTenure: try container.decodeIfPresent(Int.self, forKey: .weeksPerQuarterTenure)
                    ?? fallback.weeksPerQuarterTenure,
                causeMoraleAll: try container.decodeIfPresent(Double.self, forKey: .causeMoraleAll)
                    ?? fallback.causeMoraleAll,
                claimChance: try container.decodeIfPresent(Double.self, forKey: .claimChance)
                    ?? fallback.claimChance,
                claimMoraleOver: try container.decodeIfPresent(Double.self, forKey: .claimMoraleOver)
                    ?? fallback.claimMoraleOver,
                claimWeeksPay: try container.decodeIfPresent(Int.self, forKey: .claimWeeksPay)
                    ?? fallback.claimWeeksPay,
                claimLostFactor: try container.decodeIfPresent(Double.self, forKey: .claimLostFactor)
                    ?? fallback.claimLostFactor,
                layoffMoralePerHead: try container.decodeIfPresent(Double.self, forKey: .layoffMoralePerHead)
                    ?? fallback.layoffMoralePerHead,
                layoffMoraleCap: try container.decodeIfPresent(Double.self, forKey: .layoffMoraleCap)
                    ?? fallback.layoffMoraleCap,
                layoffReputationPerThree: try container.decodeIfPresent(Double.self, forKey: .layoffReputationPerThree)
                    ?? fallback.layoffReputationPerThree
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"severance"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.SeveranceBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.SeveranceBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
