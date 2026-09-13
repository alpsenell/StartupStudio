import Foundation
import TycoonContent

// Iteration 15 — K4 (deals and exits).
//
// Three verbs on the company as a thing that can be sold or can buy:
//
// - **The for-sale sign** (meta A2). The founder names a price between
//   `deals.askMin` and `deals.askMax` × today's valuation. Every
//   `bidIntervalDays` the strongest rival the strategic approach would
//   send (the company worth `strategicDominanceFactor ×` them, reputation
//   at `strategicMinReputation`, not weak) bids `valuation × (bidBase +
//   bidStep × n)`, capped at the ask; with no such rival, the strongest
//   rival bids the liquidator's `liquidatorFraction`. A bid lands on the
//   existing `pendingBuyout` path, so accept, decline and the earn-out
//   answer it unchanged; at or above today's valuation it is strategic
//   (`.acquired`), below it a sale (`.soldUp`). While the sign stands the
//   office reads the papers: morale, the poach odds, launch hype, the
//   board.
// - **Sell up before the receiver** (meta A4). From the first day in the
//   red, the strongest rival takes the company at the distress bid's
//   midpoint (no draw), a liquidator at `sellUpLiquidatorFraction` with
//   nobody on the board, falling by `sellUpWeeklyFactor` a week.
// - **Buy them with paper** (company C5). A rival for equity: their price
//   as a share of the company, capped; their founder takes a board seat
//   as a round of `amount 0` and joins the address book.
//
// Every query here is arithmetic on state: no stream is read.

/// The for-sale sign, while it stands.
public struct DealListing: Codable, Equatable, Sendable {
    /// What the founder asked, in dollars, fixed the day the sign went up.
    public var askingPrice: Int
    /// The ask as a multiple of that day's valuation, for the copy.
    public var askMultiple: Double
    public var sinceDay: Int
    /// Bids that actually reached the desk.
    public var bids: Int
    /// The last of them.
    public var lastBid: Int?

    public init(askingPrice: Int, askMultiple: Double, sinceDay: Int, bids: Int = 0, lastBid: Int? = nil) {
        self.askingPrice = askingPrice
        self.askMultiple = askMultiple
        self.sinceDay = sinceDay
        self.bids = bids
        self.lastBid = lastBid
    }
}

/// One bid the sign brings.
public struct DealBid: Equatable, Sendable {
    public var rivalID: UUID
    public var rivalName: String
    public var amount: Int
    /// `amount` over today's valuation.
    public var multiple: Double
    /// At or above today's valuation: a sale that ends as *Acquired*.
    public var isStrategic: Bool
    /// Nobody strategic qualified: the liquidator's number.
    public var isLiquidator: Bool
    /// The day it lands.
    public var day: Int
}

/// What selling up today is worth, and what waiting costs.
public struct DealSellUpOffer: Equatable, Sendable {
    /// The buyer, or `nil` for the liquidator.
    public var rivalID: UUID?
    public var buyerName: String
    public var amount: Int
    /// What the same sale fetches once the next week of debt is on it.
    public var nextWeekAmount: Int
    /// Days until it does.
    public var dropsInDays: Int
    public var daysInDebt: Int
    public var graceDays: Int

    /// Days of grace left before the receiver.
    public var daysLeft: Int { max(0, graceDays - daysInDebt) }
}

/// A stock deal's numbers, or why there is none.
public struct DealStockTerms: Equatable, Sendable {
    /// Points of the company their founder takes.
    public var equity: Double
    /// What the rival is priced at (the cash deal's cost).
    public var price: Int
    /// Their founder, named from the rival's seed.
    public var founderName: String
    /// Why the deal cannot be signed today; `nil` when it can.
    public var blocker: String?

    public var isOpen: Bool { blocker == nil }
}

extension GameState {
    // MARK: - The for-sale sign

    /// Launch hype at ship: ×`launchHypeFactor` while a sign stands,
    /// exactly 1 otherwise.
    public func dealLaunchHypeFactor(balance: BalanceConfig) -> Double {
        rivals.listing == nil ? 1 : balance.deals.launchHypeFactor
    }

    /// What the sign does to everybody's morale target: `moralePerWeek`
    /// for each week it has stood, the first included, to at most
    /// `moraleDragCap`. Exactly 0 with no sign up.
    public func dealMoraleTargetDrag(balance: BalanceConfig) -> Double {
        guard let weeks = dealWeeksListed else { return 0 }
        return min(balance.deals.moraleDragCap, Double(weeks + 1) * balance.deals.moralePerWeek)
    }

    /// The poach chance: ×`poachFactor` while a sign stands, exactly 1
    /// otherwise.
    public func dealPoachFactor(balance: BalanceConfig) -> Double {
        rivals.listing == nil ? 1 : balance.deals.poachFactor
    }

    /// An ask snapped to tenths inside `askMin…askMax`.
    public static func dealClampedAsk(_ multiple: Double, balance: BalanceConfig) -> Double {
        let snapped = (multiple * 10).rounded() / 10
        return min(balance.deals.askMax, max(balance.deals.askMin, snapped))
    }

    /// Why the sign cannot go up today, or `nil` when it can.
    public func dealListingBlocker(balance: BalanceConfig) -> String? {
        if gameOver != nil || epilogue != nil { return "This company already had its ending." }
        if rivals.listing != nil { return "The sign is already up." }
        if investors.earnOut != nil { return "It is sold already: the earn-out is running." }
        if companyValuation(balance: balance) <= 0 { return "Nobody lists a company worth nothing." }
        return nil
    }

    /// Whole weeks the sign has stood, while it stands.
    public var dealWeeksListed: Int? {
        rivals.listing.map { max(0, (day - $0.sinceDay) / Self.daysPerWeek) }
    }

    /// The day the next bid lands, while the sign stands.
    public func dealNextBidDay(balance: BalanceConfig) -> Int? {
        guard let listing = rivals.listing else { return nil }
        let interval = max(1, balance.deals.bidIntervalDays)
        let elapsed = max(0, day - listing.sinceDay)
        return listing.sinceDay + (elapsed / interval + 1) * interval
    }

    /// The `number`th bid (1, 2, 3 …), on today's numbers.
    public func dealListingBid(number: Int, balance: BalanceConfig) -> DealBid? {
        guard let listing = rivals.listing, number >= 1 else { return nil }
        let deals = balance.deals
        let config = balance.rivals
        let exits = balance.investors
        let valuation = companyValuation(balance: balance)
        let landsOn = listing.sinceDay + number * max(1, deals.bidIntervalDays)
        // Who bids: every rival the strategic approach would send (the
        // company worth `strategicDominanceFactor ×` them, reputation at
        // `strategicMinReputation`) and every rival big enough to afford
        // it (worth `buyerSizeFactor ×` the company). Nobody pays full
        // price for a weak company, as `buyoutCheck` reads weak.
        let weak = company.daysInDebt > 0
            || company.cash < config.weakCashThreshold
            || company.reputation < config.weakRepThreshold
        let buyers = weak ? [] : rivals.rivals.filter { rival in
            let theirs = Double(rival.valuation(balance: balance))
            let courted = company.reputation >= exits.strategicMinReputation
                && Double(valuation) >= theirs * exits.strategicDominanceFactor
            let canAfford = theirs >= Double(valuation) * deals.buyerSizeFactor
            return courted || canAfford
        }
        if let buyer = Self.dealStrongest(buyers) {
            let raw = Double(valuation) * (deals.bidBase + deals.bidStep * Double(number))
            let amount = max(1000, Int(min(Double(listing.askingPrice), raw).rounded()))
            return DealBid(
                rivalID: buyer.id, rivalName: buyer.name, amount: amount,
                multiple: valuation > 0 ? Double(amount) / Double(valuation) : 0,
                isStrategic: amount >= valuation, isLiquidator: false, day: landsOn
            )
        }
        guard let buyer = Self.dealStrongest(rivals.rivals) else { return nil }
        let raw = Double(valuation) * deals.liquidatorFraction
        let amount = max(1000, Int(min(Double(listing.askingPrice), raw).rounded()))
        return DealBid(
            rivalID: buyer.id, rivalName: buyer.name, amount: amount,
            multiple: valuation > 0 ? Double(amount) / Double(valuation) : 0,
            isStrategic: false, isLiquidator: true, day: landsOn
        )
    }

    /// The next bid as the sign stands today.
    public func dealNextBid(balance: BalanceConfig) -> DealBid? {
        guard let listing = rivals.listing, let next = dealNextBidDay(balance: balance) else { return nil }
        return dealListingBid(
            number: (next - listing.sinceDay) / max(1, balance.deals.bidIntervalDays),
            balance: balance
        )
    }

    // MARK: - Sell up before the receiver

    /// Today's sell-up, from the first day in the red; `nil` otherwise.
    public func dealSellUpOffer(balance: BalanceConfig) -> DealSellUpOffer? {
        guard gameOver == nil, epilogue == nil, company.daysInDebt > 0 else { return nil }
        let deals = balance.deals
        let valuation = Double(companyValuation(balance: balance))
        let buyer = Self.dealStrongest(rivals.rivals)
        let base = buyer == nil
            ? deals.sellUpLiquidatorFraction
            : (deals.sellUpFraction ?? RivalSystem.distressFraction(balance.rivals, uniform: 0.5))
        let weeks = company.daysInDebt / Self.daysPerWeek
        func price(_ weeks: Int) -> Int {
            max(1000, Int((valuation * base * pow(deals.sellUpWeeklyFactor, Double(weeks))).rounded()))
        }
        return DealSellUpOffer(
            rivalID: buyer?.id,
            buyerName: buyer?.name ?? "The liquidator",
            amount: price(weeks),
            nextWeekAmount: price(weeks + 1),
            dropsInDays: Self.daysPerWeek - company.daysInDebt % Self.daysPerWeek,
            daysInDebt: company.daysInDebt,
            graceDays: balance.bankruptcyGraceDays
        )
    }

    // MARK: - Buy them with paper

    /// A stock deal for `rival`, priced as the cash deal is.
    public func dealStockTerms(for rival: Rival, balance: BalanceConfig, content: ContentCatalog) -> DealStockTerms {
        let deals = balance.deals
        let theirs = rival.valuation(balance: balance)
        let price = Int((Double(theirs) * deals.stockPremium).rounded())
        let ours = companyValuation(balance: balance)
        // Up to the next tenth, so the seller is never short.
        let equity = ours > 0 ? (Double(price) / Double(ours) * 1000).rounded(.up) / 10 : Double.infinity
        let blocker: String? = if epilogue != nil || gameOver != nil {
            "This company already had its ending; nobody takes its paper."
        } else if Double(ours) < Double(theirs) * balance.rivals.acquireDominanceFactor {
            "You're not big enough yet — grow your valuation first"
        } else if equity > deals.stockMaxEquity {
            "Their price is \(Self.dealPercent(equity)) of the company. Paper stops at \(Self.dealPercent(deals.stockMaxEquity))."
        } else if investors.equityRemaining - equity < deals.stockMinKept {
            "You would keep \(Self.dealPercent(investors.equityRemaining - equity)). Paper stops at \(Self.dealPercent(deals.stockMinKept)) kept."
        } else {
            nil
        }
        return DealStockTerms(
            equity: equity, price: price, founderName: rival.dealFounderName(content: content), blocker: blocker
        )
    }

    // MARK: T4 (publisher) — O1: the sign caps the market

    /// An unsolicited approach while the sign stands pays no more than the
    /// ask (`RivalSystem.buyoutCheck`, after its draws). `amount` itself
    /// with no sign up.
    public func dealCappedApproach(_ amount: Int) -> Int {
        guard let listing = rivals.listing else { return amount }
        return min(amount, listing.askingPrice)
    }

    /// The studio that would come on its own today at the strategic
    /// premium, as `buyoutCheck` reads it: the strongest rival, when the
    /// company is not weak, has the reputation and is worth
    /// `strategicDominanceFactor ×` it. `nil` when nobody would.
    public func dealStrategicSuitor(balance: BalanceConfig) -> Rival? {
        let config = balance.rivals
        let exits = balance.investors
        guard let buyer = Self.dealStrongest(rivals.rivals),
              company.daysInDebt == 0,
              company.cash >= config.weakCashThreshold,
              company.reputation >= config.weakRepThreshold,
              company.reputation >= exits.strategicMinReputation,
              Double(companyValuation(balance: balance))
                >= Double(buyer.valuation(balance: balance)) * exits.strategicDominanceFactor
        else { return nil }
        return buyer
    }

    // MARK: end T4

    // MARK: - Helpers

    /// The strongest of `pool`; ties break on the id string, as
    /// `RivalSystem` breaks them.
    static func dealStrongest(_ pool: [Rival]) -> Rival? {
        pool.max { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// "19%", "2.5%".
    public static func dealPercent(_ points: Double) -> String {
        let tenths = (points * 10).rounded() / 10
        return tenths == tenths.rounded() ? "\(Int(tenths))%" : String(format: "%.1f%%", tenths)
    }
}

extension RaisedRound {
    /// The id prefix of a seat paid for in stock (`acquireRivalForStock`).
    public static let dealPaperPrefix = "deal-paper-"

    /// Whether this seat came with a studio bought in stock, not cash.
    public var isDealPaper: Bool { investorID.hasPrefix(Self.dealPaperPrefix) }
}

extension Rival {
    /// The studio's founder, named from its appearance seed: the same
    /// name every time, and no stream read.
    public func dealFounderName(content: ContentCatalog) -> String {
        let first = content.names.firstNames
        let last = content.names.lastNames
        guard !first.isEmpty, !last.isEmpty else { return "\(name)'s founder" }
        return first[Int(appearanceSeed % UInt64(first.count))] + " "
            + last[Int((appearanceSeed / 7_919) % UInt64(last.count))]
    }
}

extension LegacyRun {
    /// A bankrupt company's people remember how it ended: every one the
    /// ledger carries loses `points` of rapport, and arrives in the next
    /// company that much cooler (`applyHeirloom`).
    mutating func dealBankruptcyHaircut(_ points: Double) {
        guard points > 0 else { return }
        people = people.map { person in
            var person = person
            person.rapport = max(0, person.rapport - points)
            person.carriedHaircut = points
            return person
        }
        if var longest = longestServing {
            longest.rapport = max(0, longest.rapport - points)
            longest.carriedHaircut = points
            longestServing = longest
        }
    }
}
