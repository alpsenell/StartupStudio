import Foundation

// Iteration 15 — K1 (founder money): the director's loan, the dividend and
// the rescue as a choice. Every number here is read behind an action only
// the app sends (`lendToCompany`, `repayDirectorLoan`, `declareDividend`,
// `answerRescue`) or behind `doors.armed`, which no bot ever raises — so
// the Swift default carries the shipped numbers and a balance file with no
// `"founderMoney"` object plays exactly the game it always played.

extension BalanceConfig {

    // MARK: - Founder money

    public struct FounderMoneyBalance: Codable, Equatable, Sendable {
        /// Weeks of burn the company must still hold after a dividend
        /// (life F1 and company C2 agree on 8).
        public var dividendRunwayWeeks: Int
        /// Days between two dividends: once a quarter (C2's 91, F1's 13
        /// weeks — the same number).
        public var dividendIntervalDays: Int
        /// What a seated board adds to its pressure when a dividend is paid
        /// out of a quarter that lost money (C2).
        public var dividendBoardPressure: Double
        /// For how many weeks the founder's take reads as founder pay: the
        /// team and the board's pay line see `take / dividendPayWeeks` a
        /// week on top of the salary (F1).
        public var dividendPayWeeks: Int
        /// Points on the founder's name (`FounderStanding.name`) for a
        /// rescue the founder chose to take (F9).
        public var rescueStandingName: Double
        /// For how long the chosen rescue stays on the name.
        public var rescueStandingDays: Int

        public init(
            dividendRunwayWeeks: Int = 8,
            dividendIntervalDays: Int = 91,
            dividendBoardPressure: Double = 10,
            dividendPayWeeks: Int = 13,
            rescueStandingName: Double = 4,
            rescueStandingDays: Int = 364
        ) {
            self.dividendRunwayWeeks = dividendRunwayWeeks
            self.dividendIntervalDays = dividendIntervalDays
            self.dividendBoardPressure = dividendBoardPressure
            self.dividendPayWeeks = dividendPayWeeks
            self.rescueStandingName = rescueStandingName
            self.rescueStandingDays = rescueStandingDays
        }

        /// The shipped numbers.
        public static let `default` = FounderMoneyBalance()

        private enum CodingKeys: String, CodingKey {
            case dividendRunwayWeeks, dividendIntervalDays, dividendBoardPressure
            case dividendPayWeeks, rescueStandingName, rescueStandingDays
        }

        /// Every key optional, falling back to the shipped default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                dividendRunwayWeeks: try container.decodeIfPresent(
                    Int.self, forKey: .dividendRunwayWeeks
                ) ?? fallback.dividendRunwayWeeks,
                dividendIntervalDays: try container.decodeIfPresent(
                    Int.self, forKey: .dividendIntervalDays
                ) ?? fallback.dividendIntervalDays,
                dividendBoardPressure: try container.decodeIfPresent(
                    Double.self, forKey: .dividendBoardPressure
                ) ?? fallback.dividendBoardPressure,
                dividendPayWeeks: try container.decodeIfPresent(
                    Int.self, forKey: .dividendPayWeeks
                ) ?? fallback.dividendPayWeeks,
                rescueStandingName: try container.decodeIfPresent(
                    Double.self, forKey: .rescueStandingName
                ) ?? fallback.rescueStandingName,
                rescueStandingDays: try container.decodeIfPresent(
                    Int.self, forKey: .rescueStandingDays
                ) ?? fallback.rescueStandingDays
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"founderMoney"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.FounderMoneyBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.FounderMoneyBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
