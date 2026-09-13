import Foundation
import TycoonContent

// Iteration 17 — T7 (press and stakes): a stake in a rival.
//
// On a rival's profile, beside *Acquire*: buy 5, 10 or 25% of them for
// `valuation × stakes.premium × percent` from company cash. A quarter of the
// price becomes their strength. While you hold it: a weekly dividend of
// `percent × Σ(weeklyUnits × unitPrice)` over their products on the market,
// posted to the ledger; from 10% their next topic is on the profile; their
// poaching odds against you ×0.5; no price war from them. Sell any time at
// `valuation × stakes.sellBack × percent`. If they fold it is gone; if you
// acquire them the stake is part of the price.
//
// (Not `Stakes.swift`: that file is the networking floor's holdings.)
//
// Identity: no bot sends `.buyRivalStake`, so `RivalsState.stakes` stays
// empty and is never encoded; every read below returns its neutral value
// (factor 1, the full price, no dividend) and draws nothing.

/// One minority stake the company holds in a rival studio.
public struct RivalStake: Codable, Equatable, Sendable {
    public var rivalID: UUID
    /// Fraction of the rival held: 0.05, 0.10 or 0.25.
    public var percent: Double
    /// What it cost.
    public var paid: Int
    public var sinceDay: Int
    /// Dividends received so far.
    public var dividends: Int

    public init(rivalID: UUID, percent: Double, paid: Int, sinceDay: Int, dividends: Int = 0) {
        self.rivalID = rivalID
        self.percent = percent
        self.paid = paid
        self.sinceDay = sinceDay
        self.dividends = dividends
    }

    private enum CodingKeys: String, CodingKey {
        case rivalID, percent, paid, sinceDay, dividends
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            rivalID: try container.decode(UUID.self, forKey: .rivalID),
            percent: try container.decode(Double.self, forKey: .percent),
            paid: try container.decode(Int.self, forKey: .paid),
            sinceDay: try container.decode(Int.self, forKey: .sinceDay),
            dividends: try container.decodeIfPresent(Int.self, forKey: .dividends) ?? 0
        )
    }

    /// "25%".
    public var percentLabel: String { "\(Int((percent * 100).rounded()))%" }
}

/// What buying a stake of one size would cost and do, and why it cannot
/// happen today when it cannot.
public struct RivalStakeQuote: Equatable, Sendable {
    public var percent: Double
    public var price: Int
    /// Strength the rival gains from the money.
    public var strengthGain: Double
    /// Why it cannot be bought today; `nil` when it can.
    public var blocker: String?
}

extension GameState {
    /// The stake held in `rivalID`, if any.
    public func rivalStake(in rivalID: UUID) -> RivalStake? {
        rivals.stakes.first { $0.rivalID == rivalID }
    }

    /// Why no stake can change hands today, whatever its size; `nil` when
    /// one can.
    public func rivalStakeBlocker(balance: BalanceConfig) -> String? {
        if gameOver != nil || epilogue != nil { return "This company already had its ending." }
        if investors.earnOut != nil { return "Not while the acquirer's earn-out runs." }
        if rivals.listing != nil { return "Not with the for-sale sign up." }
        return nil
    }

    /// The price and the gates of a `percent` stake in `rivalID`.
    public func rivalStakeQuote(rivalID: UUID, percent: Double, balance: BalanceConfig) -> RivalStakeQuote? {
        guard let rival = rivals.rival(id: rivalID) else { return nil }
        let stakes = balance.stakes
        let price = Int((Double(rival.valuation(balance: balance)) * stakes.premium * percent).rounded())
        let perPoint = max(1, balance.rivals.valuationPerStrength)
        let gain = Double(price) * stakes.strengthShare / perPoint
        let blocker: String? = if let general = rivalStakeBlocker(balance: balance) {
            general
        } else if let held = rivalStake(in: rivalID) {
            "You hold \(held.percentLabel) — sell it to change it."
        } else if !stakes.percents.contains(where: { abs($0 - percent) < 0.0001 }) {
            "Stakes come in \(stakes.percents.map { "\(Int(($0 * 100).rounded()))%" }.joined(separator: ", "))."
        } else if price <= 0 {
            "They are worth nothing to own."
        } else if company.cash < price {
            "Need \((price - company.cash).dollars) more cash"
        } else {
            nil
        }
        return RivalStakeQuote(percent: percent, price: price, strengthGain: gain, blocker: blocker)
    }

    /// What the stake sells back for today; 0 once the rival is gone.
    public func rivalStakeSaleValue(_ stake: RivalStake, balance: BalanceConfig) -> Int {
        guard let rival = rivals.rival(id: stake.rivalID) else { return 0 }
        return Int((Double(rival.valuation(balance: balance)) * balance.stakes.sellBack * stake.percent).rounded())
    }

    /// The stake marked to market: their valuation × the percent held.
    public func rivalStakeMarkValue(_ stake: RivalStake, balance: BalanceConfig) -> Int {
        guard let rival = rivals.rival(id: stake.rivalID) else { return 0 }
        return Int((Double(rival.valuation(balance: balance)) * stake.percent).rounded())
    }

    /// This week's dividend: the percent held of the `stakes.dividendPayout`
    /// share of what their products take a week, `weeklyUnits × unitPrice`,
    /// over the products on the market (or every product, with
    /// `stakes.countOffMarket`).
    public func rivalStakeWeeklyDividend(
        _ stake: RivalStake, balance: BalanceConfig, content: ContentCatalog
    ) -> Int {
        guard let rival = rivals.rival(id: stake.rivalID) else { return 0 }
        let products = balance.stakes.countOffMarket ? rival.products : rival.competingProducts(on: day)
        let revenue = products.reduce(0.0) { total, product in
            total + Double(product.weeklyUnits) * (content.productType(product.typeID)?.unitPrice ?? 0)
        }
        return Int((revenue * balance.stakes.dividendPayout * stake.percent).rounded())
    }

    /// Their next topic, printed on the profile from `stakes.roadmapFrom`
    /// up — the line the mole's report gives, without the crime.
    public func rivalStakeRoadmapTopic(rivalID: UUID, balance: BalanceConfig) -> String? {
        guard let stake = rivalStake(in: rivalID),
              stake.percent + 0.0001 >= balance.stakes.roadmapFrom,
              let rival = rivals.rival(id: rivalID)
        else { return nil }
        return rival.focusTopicIDs.first
    }

    /// A poacher that you partly own tries half as hard. Exactly 1 with no
    /// stake in them.
    public func rivalStakePoachFactor(rivalID: UUID, balance: BalanceConfig) -> Double {
        rivalStake(in: rivalID) == nil ? 1 : balance.stakes.poachFactor
    }

    /// Whether a rival holds off a price war because you own part of it.
    public func rivalStakeHoldsFire(rivalID: UUID) -> Bool {
        rivalStake(in: rivalID) != nil
    }

    /// The acquisition price once the stake you already hold is counted:
    /// `(1 − percent) ×` the full price. The full price unchanged with no
    /// stake.
    public func rivalStakeAcquirePrice(rivalID: UUID, fullPrice: Int) -> Int {
        guard let stake = rivalStake(in: rivalID) else { return fullPrice }
        return Int((Double(fullPrice) * (1 - stake.percent)).rounded())
    }
}
