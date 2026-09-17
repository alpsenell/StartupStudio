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

        // MARK: A3 (IPO day)
        //
        // The pricing decision and the day-one pop (`IPO.swift`). Every key
        // here is read only by `fileIPO` and the sheet that prices it, and
        // `.fair`'s proceeds multiple is exactly 1.0 — so a run that files
        // the old way lands on the old dollar.

        /// What a conservative book pays against the fair price.
        public var ipoConservativeProceeds: Double
        /// What an aggressive book pays against the fair price.
        public var ipoAggressiveProceeds: Double
        /// The day-one pop a neutral book gets, in percent.
        public var ipoPopBase: Double
        /// Points of pop per point of average review over neutral.
        public var ipoPopPerReviewPoint: Double
        /// The review score the pop reads as neutral.
        public var ipoPopReviewNeutral: Double
        /// Points of pop per point of average live hype behind the shelf.
        public var ipoPopPerHypePoint: Double
        /// Points of pop per point of market multiplier over 1.0 (a
        /// multiplier of 1.10 is ten points into this coefficient).
        public var ipoPopPerMarketPoint: Double
        /// Points added to the pop for pricing conservatively.
        public var ipoPopConservative: Double
        /// Points taken off the pop for pricing aggressively — the number
        /// that decides whether a book is strong enough to afford greed.
        public var ipoPopAggressive: Double
        /// The worst first day the street hands out.
        public var ipoPopFloor: Double
        /// The best first day the street hands out.
        public var ipoPopCeiling: Double
        /// Reputation lost when the stock closes under its price.
        public var ipoBrokenOpenReputation: Double
        /// Standing every review outlet gains when the founder left money
        /// on the table for them to write about.
        public var ipoConservativeStanding: Double
        // MARK: end A3

        public init(
            lapsedNamePenalty: Double = 2,
            lapsedEarnOutMisses: Int = 1,
            partnerFiredAffection: Double = 25,
            partnerFiredWithCauseAffection: Double = 40,
            partnerFiringStayAffection: Double = 10,
            partnerFiringRespondDays: Int = 3,
            holderDividendMorale: Double = 6,
            holderDividendLoyalty: Double = 5,
            holderDividendCauseDays: Int = 7,
            // MARK: A3 (IPO day)
            ipoConservativeProceeds: Double = 0.85,
            ipoAggressiveProceeds: Double = 1.25,
            ipoPopBase: Double = 18,
            ipoPopPerReviewPoint: Double = 0.8,
            ipoPopReviewNeutral: Double = 70,
            ipoPopPerHypePoint: Double = 0.25,
            ipoPopPerMarketPoint: Double = 0.6,
            ipoPopConservative: Double = 10,
            ipoPopAggressive: Double = 20,
            ipoPopFloor: Double = -40,
            ipoPopCeiling: Double = 120,
            ipoBrokenOpenReputation: Double = 5,
            ipoConservativeStanding: Double = 2
            // MARK: end A3
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
            // MARK: A3 (IPO day)
            self.ipoConservativeProceeds = ipoConservativeProceeds
            self.ipoAggressiveProceeds = ipoAggressiveProceeds
            self.ipoPopBase = ipoPopBase
            self.ipoPopPerReviewPoint = ipoPopPerReviewPoint
            self.ipoPopReviewNeutral = ipoPopReviewNeutral
            self.ipoPopPerHypePoint = ipoPopPerHypePoint
            self.ipoPopPerMarketPoint = ipoPopPerMarketPoint
            self.ipoPopConservative = ipoPopConservative
            self.ipoPopAggressive = ipoPopAggressive
            self.ipoPopFloor = ipoPopFloor
            self.ipoPopCeiling = ipoPopCeiling
            self.ipoBrokenOpenReputation = ipoBrokenOpenReputation
            self.ipoConservativeStanding = ipoConservativeStanding
            // MARK: end A3
        }

        /// The shipped numbers.
        public static let `default` = ExitsBalance()

        private enum CodingKeys: String, CodingKey {
            case lapsedNamePenalty, lapsedEarnOutMisses
            case partnerFiredAffection, partnerFiredWithCauseAffection
            case partnerFiringStayAffection, partnerFiringRespondDays
            case holderDividendMorale, holderDividendLoyalty, holderDividendCauseDays
            // MARK: A3 (IPO day)
            case ipoConservativeProceeds, ipoAggressiveProceeds
            case ipoPopBase, ipoPopPerReviewPoint, ipoPopReviewNeutral
            case ipoPopPerHypePoint, ipoPopPerMarketPoint
            case ipoPopConservative, ipoPopAggressive
            case ipoPopFloor, ipoPopCeiling
            case ipoBrokenOpenReputation, ipoConservativeStanding
            // MARK: end A3
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
                holderDividendCauseDays: try int(.holderDividendCauseDays, d.holderDividendCauseDays),
                // MARK: A3 (IPO day)
                ipoConservativeProceeds: try double(.ipoConservativeProceeds, d.ipoConservativeProceeds),
                ipoAggressiveProceeds: try double(.ipoAggressiveProceeds, d.ipoAggressiveProceeds),
                ipoPopBase: try double(.ipoPopBase, d.ipoPopBase),
                ipoPopPerReviewPoint: try double(.ipoPopPerReviewPoint, d.ipoPopPerReviewPoint),
                ipoPopReviewNeutral: try double(.ipoPopReviewNeutral, d.ipoPopReviewNeutral),
                ipoPopPerHypePoint: try double(.ipoPopPerHypePoint, d.ipoPopPerHypePoint),
                ipoPopPerMarketPoint: try double(.ipoPopPerMarketPoint, d.ipoPopPerMarketPoint),
                ipoPopConservative: try double(.ipoPopConservative, d.ipoPopConservative),
                ipoPopAggressive: try double(.ipoPopAggressive, d.ipoPopAggressive),
                ipoPopFloor: try double(.ipoPopFloor, d.ipoPopFloor),
                ipoPopCeiling: try double(.ipoPopCeiling, d.ipoPopCeiling),
                ipoBrokenOpenReputation: try double(.ipoBrokenOpenReputation, d.ipoBrokenOpenReputation),
                ipoConservativeStanding: try double(.ipoConservativeStanding, d.ipoConservativeStanding)
                // MARK: end A3
            )
        }
    }
}
