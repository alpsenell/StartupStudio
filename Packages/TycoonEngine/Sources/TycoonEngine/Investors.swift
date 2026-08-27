import Foundation
import TycoonContent

/// What an investor watches once they have a board seat. Miss it for long
/// enough and the pressure climbs; at 100 the board replaces the founder.
public enum BoardExpectation: String, Codable, Equatable, Sendable, CaseIterable {
    /// Revenue has to keep climbing quarter on quarter.
    case mrrGrowth
    /// Something has to ship, regularly.
    case shipCadence
    /// The team has to keep getting bigger.
    case headcount
    /// The company has to actually make money.
    case profitability

    public var displayName: String {
        switch self {
        case .mrrGrowth: "Revenue growth"
        case .shipCadence: "Shipping cadence"
        case .headcount: "Headcount growth"
        case .profitability: "Profitability"
        }
    }

    /// What the board says it wants, in the founder's words.
    public var demand: String {
        switch self {
        case .mrrGrowth: "Revenue up every quarter. No excuses about the market."
        case .shipCadence: "Something has to ship every quarter. Anything."
        case .headcount: "Hire. A company that isn't growing is dying."
        case .profitability: "Stop burning our money. Get to profitable."
        }
    }
}

extension InvestorDef {
    /// The persona's board expectation, resolved from the content
    /// catalog's raw string. An unknown value reads as shipping cadence,
    /// the mildest of the four.
    public var expectation: BoardExpectation {
        BoardExpectation(rawValue: expects) ?? .shipCadence
    }
}

/// A funding offer sitting on the table. Answered with `.acceptInvestment`
/// or `.declineInvestment`; ignored past `respondByDay` and withdrawn.
public struct InvestmentOffer: Codable, Equatable, Sendable {
    /// `InvestorDef.id` of the persona making the offer.
    public var investorID: String
    public var investorName: String
    /// Cash on the table.
    public var amount: Int
    /// Percentage points of equity they want (0...100).
    public var equity: Double
    /// The valuation the offer implies.
    public var valuation: Int
    /// Whether taking it puts them on the board.
    public var takesBoardSeat: Bool
    public var expects: BoardExpectation
    /// Last day the player can answer.
    public var respondByDay: Int

    public init(
        investorID: String,
        investorName: String,
        amount: Int,
        equity: Double,
        valuation: Int,
        takesBoardSeat: Bool,
        expects: BoardExpectation,
        respondByDay: Int
    ) {
        self.investorID = investorID
        self.investorName = investorName
        self.amount = amount
        self.equity = equity
        self.valuation = valuation
        self.takesBoardSeat = takesBoardSeat
        self.expects = expects
        self.respondByDay = respondByDay
    }
}

/// A round the founder actually closed.
public struct RaisedRound: Codable, Equatable, Sendable, Identifiable {
    public var investorID: String
    public var investorName: String
    public var amount: Int
    public var equity: Double
    public var valuation: Int
    public var day: Int
    public var takesBoardSeat: Bool
    public var expects: BoardExpectation

    /// Stable across a save: one investor closes at most one round.
    public var id: String { investorID }

    public init(
        investorID: String,
        investorName: String,
        amount: Int,
        equity: Double,
        valuation: Int,
        day: Int,
        takesBoardSeat: Bool,
        expects: BoardExpectation
    ) {
        self.investorID = investorID
        self.investorName = investorName
        self.amount = amount
        self.equity = equity
        self.valuation = valuation
        self.day = day
        self.takesBoardSeat = takesBoardSeat
        self.expects = expects
    }
}

/// One quarterly board review, kept so the board room can show a history
/// rather than a single number.
public struct BoardReview: Codable, Equatable, Sendable {
    public var day: Int
    public var expectation: BoardExpectation
    /// Whether the company met it.
    public var met: Bool
    /// Board pressure after this review (0...100).
    public var pressure: Double
    /// One line the board room shows.
    public var note: String

    public init(day: Int, expectation: BoardExpectation, met: Bool, pressure: Double, note: String) {
        self.day = day
        self.expectation = expectation
        self.met = met
        self.pressure = pressure
        self.note = note
    }
}

/// Everything the investor and board layer persists: the cap table, the
/// offer on the table, board pressure, and the profitability record that
/// gates an IPO.
public struct InvestorState: Codable, Equatable, Sendable {
    /// Percentage of the company the founder still owns (starts at 100).
    public var equityRemaining: Double
    /// Rounds closed, oldest first.
    public var rounds: [RaisedRound]
    /// The offer awaiting an answer, if any.
    public var pendingOffer: InvestmentOffer?
    /// Investor ids that have already made an offer, so a persona never
    /// approaches twice. Encoded sorted.
    public var approachedInvestorIDs: Set<String>
    /// 0...100. At `boardWarningPressure` the board demands a plan; at 100
    /// the founder is replaced.
    public var boardPressure: Double
    /// Quarterly reviews, oldest first, capped.
    public var reviews: [BoardReview]
    /// The last day a quarterly review ran.
    public var lastReviewDay: Int?
    /// The last day an offer check ran (global cadence).
    public var lastOfferDay: Int?
    /// Consecutive quarters the company finished in profit — one of the
    /// three IPO gates.
    public var profitableQuarters: Int
    /// Company cash at the last quarter boundary, so the next one can tell
    /// whether the quarter was profitable.
    public var lastQuarterCash: Int
    /// Revenue booked in the last quarter, for the growth expectation.
    public var lastQuarterRevenue: Int
    /// Products shipped as of the last quarter, for the cadence
    /// expectation.
    public var lastQuarterShipped: Int
    /// Headcount at the last quarter, for the headcount expectation.
    public var lastQuarterHeadcount: Int
    /// Set the day the player files to go public, so the ending screen can
    /// say when.
    public var ipoDay: Int?

    /// How many reviews the board room keeps.
    static let maxReviews = 24

    public init(
        equityRemaining: Double = 100,
        rounds: [RaisedRound] = [],
        pendingOffer: InvestmentOffer? = nil,
        approachedInvestorIDs: Set<String> = [],
        boardPressure: Double = 0,
        reviews: [BoardReview] = [],
        lastReviewDay: Int? = nil,
        lastOfferDay: Int? = nil,
        profitableQuarters: Int = 0,
        lastQuarterCash: Int = 0,
        lastQuarterRevenue: Int = 0,
        lastQuarterShipped: Int = 0,
        lastQuarterHeadcount: Int = 0,
        ipoDay: Int? = nil
    ) {
        self.equityRemaining = equityRemaining
        self.rounds = rounds
        self.pendingOffer = pendingOffer
        self.approachedInvestorIDs = approachedInvestorIDs
        self.boardPressure = boardPressure
        self.reviews = reviews
        self.lastReviewDay = lastReviewDay
        self.lastOfferDay = lastOfferDay
        self.profitableQuarters = profitableQuarters
        self.lastQuarterCash = lastQuarterCash
        self.lastQuarterRevenue = lastQuarterRevenue
        self.lastQuarterShipped = lastQuarterShipped
        self.lastQuarterHeadcount = lastQuarterHeadcount
        self.ipoDay = ipoDay
    }

    /// A fresh company: the founder owns all of it and nobody is watching.
    public static let initial = InvestorState()

    /// Whether anyone the founder answers to has a board seat.
    public var hasBoard: Bool {
        rounds.contains { $0.takesBoardSeat }
    }

    /// Total raised across every round.
    public var totalRaised: Int {
        rounds.reduce(0) { $0 + $1.amount }
    }

    /// Equity sold so far, in percentage points.
    public var equitySold: Double {
        max(0, 100 - equityRemaining)
    }

    /// What the board is watching, if anyone is: the expectation of the
    /// most recent round that took a seat.
    public var boardExpectation: BoardExpectation? {
        rounds.last { $0.takesBoardSeat }?.expects
    }

    /// The most recent quarterly review.
    public var latestReview: BoardReview? { reviews.last }

    /// Appends a review, dropping the oldest beyond the cap.
    mutating func record(_ review: BoardReview) {
        reviews.append(review)
        if reviews.count > Self.maxReviews {
            reviews.removeFirst(reviews.count - Self.maxReviews)
        }
    }
}

// MARK: - Codable

// Hand-written so `approachedInvestorIDs` encodes in sorted order (set
// iteration order is not stable, and the determinism tests compare bytes)
// and every field decodes with a default — an absent key reads as
// `.initial`, so a save written before investors existed still loads.

extension InvestorState {
    private enum CodingKeys: String, CodingKey {
        case equityRemaining, rounds, pendingOffer, approachedInvestorIDs, boardPressure
        case reviews, lastReviewDay, lastOfferDay, profitableQuarters
        case lastQuarterCash, lastQuarterRevenue, lastQuarterShipped, lastQuarterHeadcount
        case ipoDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            equityRemaining: try container.decodeIfPresent(Double.self, forKey: .equityRemaining) ?? 100,
            rounds: try container.decodeIfPresent([RaisedRound].self, forKey: .rounds) ?? [],
            pendingOffer: try container.decodeIfPresent(InvestmentOffer.self, forKey: .pendingOffer),
            approachedInvestorIDs: Set(
                try container.decodeIfPresent([String].self, forKey: .approachedInvestorIDs) ?? []
            ),
            boardPressure: try container.decodeIfPresent(Double.self, forKey: .boardPressure) ?? 0,
            reviews: try container.decodeIfPresent([BoardReview].self, forKey: .reviews) ?? [],
            lastReviewDay: try container.decodeIfPresent(Int.self, forKey: .lastReviewDay),
            lastOfferDay: try container.decodeIfPresent(Int.self, forKey: .lastOfferDay),
            profitableQuarters: try container.decodeIfPresent(Int.self, forKey: .profitableQuarters) ?? 0,
            lastQuarterCash: try container.decodeIfPresent(Int.self, forKey: .lastQuarterCash) ?? 0,
            lastQuarterRevenue: try container.decodeIfPresent(Int.self, forKey: .lastQuarterRevenue) ?? 0,
            lastQuarterShipped: try container.decodeIfPresent(Int.self, forKey: .lastQuarterShipped) ?? 0,
            lastQuarterHeadcount: try container.decodeIfPresent(
                Int.self, forKey: .lastQuarterHeadcount
            ) ?? 0,
            ipoDay: try container.decodeIfPresent(Int.self, forKey: .ipoDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(equityRemaining, forKey: .equityRemaining)
        try container.encode(rounds, forKey: .rounds)
        try container.encodeIfPresent(pendingOffer, forKey: .pendingOffer)
        try container.encode(approachedInvestorIDs.sorted(), forKey: .approachedInvestorIDs)
        try container.encode(boardPressure, forKey: .boardPressure)
        try container.encode(reviews, forKey: .reviews)
        try container.encodeIfPresent(lastReviewDay, forKey: .lastReviewDay)
        try container.encodeIfPresent(lastOfferDay, forKey: .lastOfferDay)
        try container.encode(profitableQuarters, forKey: .profitableQuarters)
        try container.encode(lastQuarterCash, forKey: .lastQuarterCash)
        try container.encode(lastQuarterRevenue, forKey: .lastQuarterRevenue)
        try container.encode(lastQuarterShipped, forKey: .lastQuarterShipped)
        try container.encode(lastQuarterHeadcount, forKey: .lastQuarterHeadcount)
        try container.encodeIfPresent(ipoDay, forKey: .ipoDay)
    }
}

// MARK: - Derived company facts

extension GameState {
    /// What the founder is personally worth: their wallet plus their
    /// remaining slice of what the company is worth.
    public func founderNetWorth(balance: BalanceConfig) -> Int {
        let slice = Double(companyValuation(balance: balance)) * investors.equityRemaining / 100
        return life.wallet + Int(slice.rounded())
    }

    /// Products currently on the market that bill monthly — the third IPO
    /// gate. Reads WS-A's `ReleaseInfo.isSubscription`, which is `false`
    /// for every product until their live-ops work lands, so the gate is
    /// simply unmet until then rather than wrong.
    public var hasSubscriptionProduct: Bool {
        products.contains { product in
            guard case .released(let info) = product.stage else { return false }
            return info.isSubscription && !info.offMarket
        }
    }

    /// Whether the company could file to go public today: a big enough
    /// valuation, a run of profitable quarters, and recurring revenue.
    public func canFileIPO(balance: BalanceConfig) -> Bool {
        guard gameOver == nil, investors.ipoDay == nil else { return false }
        let config = balance.investors
        return companyValuation(balance: balance) >= config.ipoValuationFloor
            && investors.profitableQuarters >= config.ipoProfitableQuarters
            && (hasSubscriptionProduct || !config.ipoRequiresSubscription)
    }

    /// Why the company can't file yet, in one line, or `nil` when it can.
    public func ipoBlocker(balance: BalanceConfig) -> String? {
        guard investors.ipoDay == nil else { return "You've already filed." }
        let config = balance.investors
        let valuation = companyValuation(balance: balance)
        if valuation < config.ipoValuationFloor {
            let short = config.ipoValuationFloor - valuation
            return "The bankers want a $\(config.ipoValuationFloor / 1_000_000)M valuation — $\(short) short."
        }
        if investors.profitableQuarters < config.ipoProfitableQuarters {
            let short = config.ipoProfitableQuarters - investors.profitableQuarters
            return "\(short) more profitable quarter\(short == 1 ? "" : "s") on the books."
        }
        if config.ipoRequiresSubscription, !hasSubscriptionProduct {
            return "Nothing on the market bills monthly. They want recurring revenue."
        }
        return nil
    }
}
