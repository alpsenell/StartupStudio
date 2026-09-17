import Foundation

// Iteration 18 — A3 (IPO day). Going public stops being a button.
//
// The player prices the offering — conservative, fair or aggressive — and
// the bell scene plays the first day out. Everything here is a pure
// function of the state that is already on the board:
//
// - **The price moves the money.** Conservative prints the book at
//   `exits.ipoConservativeProceeds` of the fair price, aggressive at
//   `exits.ipoAggressiveProceeds`. The whole company is sold at that
//   price, so the exit split (T1) reads the same number the founder does.
// - **The pop is derived, never drawn.** `IPOQuote.pop` reads the average
//   review of what is on sale, the live hype behind it, the market's
//   multiplier under it and the aggression the player chose. There is no
//   new RNG anywhere in this file, so a run that files at the same price
//   on the same day pops the same amount every time.
// - **Aggressive can break open.** A negative pop is a *broken open*: the
//   reputation cost lands on the way out (`exits.ipoBrokenOpenReputation`),
//   the paper leads with it, and the biography records it forever.
// - **The ticker is derived from the name.** No state, no draw — see
//   `IPOTicker.derive(from:)`.
//
// Identity: `.fileIPO` with no price is `.fair`, whose proceeds multiple is
// exactly 1.0, so every old caller (the bots, the tests, the old save's
// replayed action) lands on the same dollar it always did.

/// How the founder priced the offering.
public enum IPOPrice: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// Leaves money on the table for a near-certain pop.
    case conservative
    /// The bankers' number. The old, defaulted behaviour.
    case fair
    /// Prices for every dollar the book will bear — and the open can break.
    case aggressive

    /// What the offering pays against the fair price.
    public func proceedsMultiple(_ balance: BalanceConfig.ExitsBalance) -> Double {
        switch self {
        case .conservative: balance.ipoConservativeProceeds
        case .fair: 1.0
        case .aggressive: balance.ipoAggressiveProceeds
        }
    }

    /// Points added to the day-one pop for pricing this way.
    public func popOffset(_ balance: BalanceConfig.ExitsBalance) -> Double {
        switch self {
        case .conservative: balance.ipoPopConservative
        case .fair: 0
        case .aggressive: -balance.ipoPopAggressive
        }
    }

    /// The word the sheet and the bell scene print.
    public var displayName: String {
        switch self {
        case .conservative: "Conservative"
        case .fair: "Fair"
        case .aggressive: "Aggressive"
        }
    }
}

/// What the first day did, kept for the ending card, the biography and —
/// when the founder keeps running it — the street that comes after.
public struct IPOResult: Codable, Equatable, Sendable {
    public var price: IPOPrice
    /// Three or four letters, derived from the company name.
    public var ticker: String
    /// What the whole company was priced at on the morning.
    public var offerValuation: Int
    /// What the founder's slice paid into the wallet.
    public var proceeds: Int
    /// The day-one move, in percent. Negative is a broken open.
    public var pop: Double
    /// What the company was worth at the close of the first day.
    public var dayOneClose: Int
    /// The day the bell rang.
    public var day: Int

    public init(
        price: IPOPrice,
        ticker: String,
        offerValuation: Int,
        proceeds: Int,
        pop: Double,
        dayOneClose: Int,
        day: Int
    ) {
        self.price = price
        self.ticker = ticker
        self.offerValuation = offerValuation
        self.proceeds = proceeds
        self.pop = pop
        self.dayOneClose = dayOneClose
        self.day = day
    }

    /// The open broke: the stock closed its first day under the price the
    /// founder sold it at.
    public var brokeOpen: Bool { pop < 0 }

    /// "+38%" / "-12%", the way every surface prints it.
    public var popLabel: String {
        let rounded = Int(pop.rounded())
        return "\(rounded >= 0 ? "+" : "")\(rounded)%"
    }
}

/// One row of the pricing sheet: what this price pays, what it is expected
/// to do on the day, and what it costs if it goes wrong. Pure — the sheet
/// prints it, the reducer recomputes it.
public struct IPOQuote: Equatable, Sendable {
    public var price: IPOPrice
    /// The whole company at this price.
    public var offerValuation: Int
    /// What lands in the founder's wallet.
    public var proceeds: Int
    /// The derived day-one move, in percent.
    public var pop: Double
    /// The company at the close of the first day.
    public var dayOneClose: Int
    public var ticker: String

    public var brokeOpen: Bool { pop < 0 }

    public var popLabel: String {
        let rounded = Int(pop.rounded())
        return "\(rounded >= 0 ? "+" : "")\(rounded)%"
    }

    /// The odds line the sheet prints beside the money. The pop is
    /// derived, so these are not odds so much as the house's read of the
    /// book as it stands — which is what a banker says out loud anyway.
    public var oddsLine: String {
        switch pop {
        case 25...: "Prices to pop hard — \(popLabel) on the day"
        case 8..<25: "Prices to pop — \(popLabel) on the day"
        case 0..<8: "Prices to open flat — \(popLabel) on the day"
        default: "Prices to break open — \(popLabel) on the day"
        }
    }
}

// MARK: - The ticker

/// Three or four letters on the board, derived from the company name and
/// nothing else: no state, no draw, and the same name always reads the
/// same way.
public enum IPOTicker {
    /// The letters `PixelText` can actually draw.
    private static let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let vowels = Set("AEIOU")

    /// The board's letters for a company name.
    ///
    /// - Several words: the initials, up to four (`Blue Harbour Games` →
    ///   `BHG`).
    /// - Two words: three of the first and one of the second
    ///   (`Pixel Forge` → `PIXF`).
    /// - One word: its first letter and the consonants after it
    ///   (`Northwind` → `NRTH`), padded from the word's own letters.
    /// - Nothing usable: four letters folded out of the name's hash, so
    ///   every company has a board to stand under.
    public static func derive(from name: String) -> String {
        let words = name.uppercased()
            .split(whereSeparator: { !alphabet.contains($0) })
            .map(String.init)
            .filter { !$0.isEmpty }

        var ticker = ""
        switch words.count {
        case 0:
            ticker = ""
        case 1:
            let letters = Array(words[0])
            var squeezed = [letters[0]]
            for letter in letters.dropFirst() where !vowels.contains(letter) {
                squeezed.append(letter)
                if squeezed.count == 4 { break }
            }
            // A word with no consonants after the first letter (`AIOLI`)
            // takes what it has, in order.
            if squeezed.count < 3 {
                squeezed = Array(letters.prefix(4))
            }
            ticker = String(squeezed.prefix(4))
        case 2:
            ticker = String(words[0].prefix(3)) + String(words[1].prefix(1))
        default:
            ticker = words.prefix(4).map { String($0.prefix(1)) }.joined()
        }

        if ticker.count < 3 { ticker = pad(ticker, from: name) }
        return String(ticker.prefix(4))
    }

    /// A name with too few letters in it borrows the rest from its own
    /// hash — stable across runs and processes (`FNV-1a`, not `hashValue`,
    /// which is seeded per process).
    private static func pad(_ ticker: String, from name: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(name.utf8) {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var out = ticker
        while out.count < 3 {
            out.append(letters[Int(hash % 26)])
            hash /= 26
        }
        return out
    }
}

// MARK: - The quote

extension GameState {
    /// The three rows of the pricing sheet, in the order they are shown.
    public func ipoQuotes(balance: BalanceConfig) -> [IPOQuote] {
        IPOPrice.allCases.map { ipoQuote(price: $0, balance: balance) }
    }

    /// What filing at `price` today pays, and what the first day does.
    /// Pure: reads the board, draws nothing.
    public func ipoQuote(price: IPOPrice, balance: BalanceConfig) -> IPOQuote {
        let exits = balance.exits
        let fair = Double(companyValuation(balance: balance)) * balance.investors.ipoValuationMultiple
        let valuation = fair * price.proceedsMultiple(exits)
        // The exit split reads the same price the founder is paid at (T1):
        // the loan comes back first, the unvested lapse and come home.
        let split = ladderExitSplit(price: Int(valuation.rounded()), balance: balance)
        let proceeds = Int(
            (valuation * (investors.equityRemaining + split.unvestedPoints) / 100).rounded()
        )
        let pop = ipoPop(price: price, balance: balance)
        return IPOQuote(
            price: price,
            offerValuation: Int(valuation.rounded()),
            proceeds: proceeds,
            pop: pop,
            dayOneClose: Int((valuation * (1 + pop / 100)).rounded()),
            ticker: IPOTicker.derive(from: company.name)
        )
    }

    /// The day-one move, in percent: the book's read of what is on sale
    /// (average review), what the street has heard about it (live hype),
    /// what the market under it is doing, and how hard the founder priced
    /// it. No draws — the same board pops the same way every time.
    public func ipoPop(price: IPOPrice, balance: BalanceConfig) -> Double {
        let exits = balance.exits
        let book = ipoBook(balance: balance)
        var pop = exits.ipoPopBase
        pop += exits.ipoPopPerReviewPoint * (book.averageReview - exits.ipoPopReviewNeutral)
        pop += exits.ipoPopPerHypePoint * book.hype
        pop += exits.ipoPopPerMarketPoint * (book.market - 1) * 100
        pop += price.popOffset(exits)
        return min(exits.ipoPopCeiling, max(exits.ipoPopFloor, pop))
    }

    /// What the bankers have to sell: the average review, live hype and
    /// market multiplier across everything still on sale. An empty shelf
    /// reads as a neutral book, which `canFileIPO` will not let you take
    /// public anyway.
    public func ipoBook(
        balance: BalanceConfig
    ) -> (averageReview: Double, hype: Double, market: Double) {
        var reviews: [Double] = []
        var hype: [Double] = []
        var market: [Double] = []
        for product in products {
            guard case .released(let info) = product.stage, !info.offMarket else { continue }
            reviews.append(Double(info.averageReviewScore))
            hype.append(info.liveHype)
            market.append(self.market.multiplier(for: product.topicID))
        }
        guard !reviews.isEmpty else {
            return (balance.exits.ipoPopReviewNeutral, 0, 1)
        }
        func mean(_ values: [Double]) -> Double {
            values.reduce(0, +) / Double(values.count)
        }
        return (mean(reviews), mean(hype), mean(market))
    }
}
