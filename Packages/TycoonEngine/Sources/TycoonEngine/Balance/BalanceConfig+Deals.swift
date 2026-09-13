import Foundation

// Iteration 15 — K4 (deals and exits). The for-sale sign, selling up
// before the receiver, and buying a rival with paper
// (docs/product/iteration-15-pm/meta.md §2, §4; company.md §5).
//
// Every number here is read only behind a verb the player chose — a sign
// hung, a sell-up taken, a stock deal signed — or on a bankrupt run's
// ledger record, which no simulation reads back. `"deals"` is an optional
// key: a balance file without it reads these defaults.

extension BalanceConfig {

    // MARK: - Deals

    public struct DealsBalance: Codable, Equatable, Sendable {
        // The for-sale sign (A2).
        /// The asking price, as a multiple of today's valuation.
        public var askMin: Double
        public var askMax: Double
        /// A bid every this many days the sign stands.
        public var bidIntervalDays: Int
        /// Bid n (1, 2, 3 …) is `valuation × (bidBase + bidStep × n)`,
        /// capped at the ask.
        public var bidBase: Double
        public var bidStep: Double
        /// A rival worth at least this multiple of the company can afford
        /// it, and bids beside the ones the strategic approach would send.
        public var buyerSizeFactor: Double
        /// With no buyer at all, the liquidator's fraction of valuation.
        public var liquidatorFraction: Double
        /// The morale target falls this much for each week the sign stands…
        public var moralePerWeek: Double
        /// …to at most this.
        public var moraleDragCap: Double
        /// The poach chance while listed.
        public var poachFactor: Double
        /// Launch hype at ship while listed.
        public var launchHypeFactor: Double
        /// Board pressure when the sign goes up, and again with each bid.
        public var boardPressure: Double

        // Sell up before the receiver (A4).
        /// The sell-up price's fraction of valuation before any week of
        /// debt: the midpoint of the distress bid (`offerFractionMin…Max`,
        /// 0.9) when nil, the number itself when set. Shipped at 0.5: over
        /// the ten pacing seeds one bankrupt bot in ten took a cash event
        /// in its last 21 days (lane K4's measurement), so waiting must be
        /// the only way to a better number.
        public var sellUpFraction: Double?
        /// With no rival on the board, the liquidator's fraction.
        public var sellUpLiquidatorFraction: Double
        /// The price keeps this share of itself per whole week of debt.
        public var sellUpWeeklyFactor: Double
        /// Rapport the ledger's people lose when the company went bankrupt.
        public var bankruptcyRapportHaircut: Double

        // Buy them with paper (C5).
        /// The stock deal prices the rival as the cash deal does.
        public var stockPremium: Double
        /// The most equity one stock deal hands over, in points.
        public var stockMaxEquity: Double
        /// The founder keeps at least this much after the deal.
        public var stockMinKept: Double
        /// Their founder's rapport on arrival in the address book.
        public var stockFounderRapport: Double
        /// Their founder's patience on the board.
        public var stockPatienceWeeks: Int

        public init(
            askMin: Double = 0.8,
            // T4 (O1): 1.6 → 2.0. With unsolicited offers capped at the ask
            // while the sign stands, and the ≥1.5× approach measured under
            // eight weeks away on the studio and the campus, a patient sign
            // has to be able to reach the market's own number.
            askMax: Double = 2.0,
            bidIntervalDays: Int = 28,
            bidBase: Double = 0.9,
            bidStep: Double = 0.1,
            buyerSizeFactor: Double = 1.5,
            liquidatorFraction: Double = 0.5,
            moralePerWeek: Double = 1,
            moraleDragCap: Double = 12,
            poachFactor: Double = 1.5,
            launchHypeFactor: Double = 0.9,
            boardPressure: Double = 5,
            sellUpFraction: Double? = 0.5,
            sellUpLiquidatorFraction: Double = 0.4,
            sellUpWeeklyFactor: Double = 0.9,
            bankruptcyRapportHaircut: Double = 20,
            stockPremium: Double = 1.3,
            stockMaxEquity: Double = 25,
            stockMinKept: Double = 20,
            stockFounderRapport: Double = 60,
            stockPatienceWeeks: Int = 26
        ) {
            self.askMin = askMin
            self.askMax = askMax
            self.bidIntervalDays = bidIntervalDays
            self.bidBase = bidBase
            self.bidStep = bidStep
            self.buyerSizeFactor = buyerSizeFactor
            self.liquidatorFraction = liquidatorFraction
            self.moralePerWeek = moralePerWeek
            self.moraleDragCap = moraleDragCap
            self.poachFactor = poachFactor
            self.launchHypeFactor = launchHypeFactor
            self.boardPressure = boardPressure
            self.sellUpFraction = sellUpFraction
            self.sellUpLiquidatorFraction = sellUpLiquidatorFraction
            self.sellUpWeeklyFactor = sellUpWeeklyFactor
            self.bankruptcyRapportHaircut = bankruptcyRapportHaircut
            self.stockPremium = stockPremium
            self.stockMaxEquity = stockMaxEquity
            self.stockMinKept = stockMinKept
            self.stockFounderRapport = stockFounderRapport
            self.stockPatienceWeeks = stockPatienceWeeks
        }

        /// The shipped numbers.
        public static let `default` = DealsBalance()

        private enum CodingKeys: String, CodingKey {
            case askMin, askMax, bidIntervalDays, bidBase, bidStep, buyerSizeFactor, liquidatorFraction
            case moralePerWeek, moraleDragCap, poachFactor, launchHypeFactor, boardPressure
            case sellUpFraction, sellUpLiquidatorFraction, sellUpWeeklyFactor
            case bankruptcyRapportHaircut
            case stockPremium, stockMaxEquity, stockMinKept, stockFounderRapport, stockPatienceWeeks
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
                askMin: try double(.askMin, d.askMin),
                askMax: try double(.askMax, d.askMax),
                bidIntervalDays: try int(.bidIntervalDays, d.bidIntervalDays),
                bidBase: try double(.bidBase, d.bidBase),
                bidStep: try double(.bidStep, d.bidStep),
                buyerSizeFactor: try double(.buyerSizeFactor, d.buyerSizeFactor),
                liquidatorFraction: try double(.liquidatorFraction, d.liquidatorFraction),
                moralePerWeek: try double(.moralePerWeek, d.moralePerWeek),
                moraleDragCap: try double(.moraleDragCap, d.moraleDragCap),
                poachFactor: try double(.poachFactor, d.poachFactor),
                launchHypeFactor: try double(.launchHypeFactor, d.launchHypeFactor),
                boardPressure: try double(.boardPressure, d.boardPressure),
                sellUpFraction: try container.decodeIfPresent(Double.self, forKey: .sellUpFraction)
                    ?? d.sellUpFraction,
                sellUpLiquidatorFraction: try double(.sellUpLiquidatorFraction, d.sellUpLiquidatorFraction),
                sellUpWeeklyFactor: try double(.sellUpWeeklyFactor, d.sellUpWeeklyFactor),
                bankruptcyRapportHaircut: try double(.bankruptcyRapportHaircut, d.bankruptcyRapportHaircut),
                stockPremium: try double(.stockPremium, d.stockPremium),
                stockMaxEquity: try double(.stockMaxEquity, d.stockMaxEquity),
                stockMinKept: try double(.stockMinKept, d.stockMinKept),
                stockFounderRapport: try double(.stockFounderRapport, d.stockFounderRapport),
                stockPatienceWeeks: try int(.stockPatienceWeeks, d.stockPatienceWeeks)
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"deals"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.DealsBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.DealsBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
