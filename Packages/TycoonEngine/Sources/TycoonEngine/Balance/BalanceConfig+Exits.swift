import Foundation

// Iteration 17 — T1 (exits and joins). The numbers behind four joins:
//
// - **The exit reads the options** (`ExitSystem.settle`): a lapsed holder
//   is `lapsedNamePenalty` on the founder's name for good, the same read
//   as a firing with cause; during an earn-out each lapsed holder reads as
//   `lapsedEarnOutMisses` missed reviews on the acquirer's patience, capped
//   one short of the ousting (the lane's measurement, `t1.md`: on the
//   studio the acceleration is 5% of the founder's cheque at three points
//   out and 3.3% at two, so the lapse had to cost something).
// - **Firing the partner is a fight** (`RelationshipSystem.partnerFired`):
//   `partnerFiredAffection` off on the day; with cause, the rest of
//   `partnerFiredWithCauseAffection` the next morning and the question;
//   staying costs `partnerFiringStayAffection` more; unanswered for
//   `partnerFiringRespondDays`, staying is the answer.
// - **The dividend reaches the holders' desks** (`FounderMoneySystem`):
//   a holder on payroll who got a line gains `holderDividendMorale` and
//   `holderDividendLoyalty` on the day, and the manage sheet can say so for
//   `holderDividendCauseDays`.
//
// Every number is read only behind a grant, a director's loan, a partner on
// payroll or a dividend with a holder in it — none of which any bot or
// fixture has — so the default path reads none of them. `"exits"` is
// appended at the end of `Balance.json`; a file without it reads these.

extension BalanceConfig {

    // MARK: - Exits and joins

    public struct ExitsBalance: Codable, Equatable, Sendable {
        /// Name points per holder whose unvested options lapsed at an exit.
        public var lapsedNamePenalty: Double
        /// Missed earn-out reviews each lapsed holder reads as (capped one
        /// short of `investors.earnOutMissesToOust`).
        public var lapsedEarnOutMisses: Int
        /// Affection lost the day the founder fires their partner.
        public var partnerFiredAffection: Double
        /// Affection lost in all when the firing had a cause (the rest of it
        /// lands the next morning).
        public var partnerFiredWithCauseAffection: Double
        /// Affection lost again when the founder stays after it.
        public var partnerFiringStayAffection: Double
        /// Days the morning question waits before staying is the answer.
        public var partnerFiringRespondDays: Int
        /// Morale a holder on payroll gains the day a dividend pays them.
        public var holderDividendMorale: Double
        /// Loyalty a holder on payroll gains the day a dividend pays them.
        public var holderDividendLoyalty: Double
        /// Days the manage sheet names the dividend as a morale cause.
        public var holderDividendCauseDays: Int

        public init(
            lapsedNamePenalty: Double = 2,
            lapsedEarnOutMisses: Int = 1,
            partnerFiredAffection: Double = 25,
            partnerFiredWithCauseAffection: Double = 40,
            partnerFiringStayAffection: Double = 10,
            partnerFiringRespondDays: Int = 3,
            holderDividendMorale: Double = 6,
            holderDividendLoyalty: Double = 5,
            holderDividendCauseDays: Int = 7
        ) {
            self.lapsedNamePenalty = lapsedNamePenalty
            self.lapsedEarnOutMisses = lapsedEarnOutMisses
            self.partnerFiredAffection = partnerFiredAffection
            self.partnerFiredWithCauseAffection = partnerFiredWithCauseAffection
            self.partnerFiringStayAffection = partnerFiringStayAffection
            self.partnerFiringRespondDays = partnerFiringRespondDays
            self.holderDividendMorale = holderDividendMorale
            self.holderDividendLoyalty = holderDividendLoyalty
            self.holderDividendCauseDays = holderDividendCauseDays
        }

        /// The shipped numbers.
        public static let `default` = ExitsBalance()

        private enum CodingKeys: String, CodingKey {
            case lapsedNamePenalty, lapsedEarnOutMisses
            case partnerFiredAffection, partnerFiredWithCauseAffection
            case partnerFiringStayAffection, partnerFiringRespondDays
            case holderDividendMorale, holderDividendLoyalty, holderDividendCauseDays
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let d = Self.default
            func double(_ key: CodingKeys, _ fallback: Double) throws -> Double {
                try container.decodeIfPresent(Double.self, forKey: key) ?? fallback
            }
            func int(_ key: CodingKeys, _ fallback: Int) throws -> Int {
                try container.decodeIfPresent(Int.self, forKey: key) ?? fallback
            }
            self.init(
                lapsedNamePenalty: try double(.lapsedNamePenalty, d.lapsedNamePenalty),
                lapsedEarnOutMisses: try int(.lapsedEarnOutMisses, d.lapsedEarnOutMisses),
                partnerFiredAffection: try double(.partnerFiredAffection, d.partnerFiredAffection),
                partnerFiredWithCauseAffection: try double(
                    .partnerFiredWithCauseAffection, d.partnerFiredWithCauseAffection
                ),
                partnerFiringStayAffection: try double(.partnerFiringStayAffection, d.partnerFiringStayAffection),
                partnerFiringRespondDays: try int(.partnerFiringRespondDays, d.partnerFiringRespondDays),
                holderDividendMorale: try double(.holderDividendMorale, d.holderDividendMorale),
                holderDividendLoyalty: try double(.holderDividendLoyalty, d.holderDividendLoyalty),
                holderDividendCauseDays: try int(.holderDividendCauseDays, d.holderDividendCauseDays)
            )
        }
    }
}
