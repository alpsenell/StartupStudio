import Foundation
import TycoonEngine

/// The app's window onto WS-A's post-launch actions.
///
/// `ReleaseInfo` carries the live-ops *state* (`liveBugs`, `priceTier`,
/// `subscribers`, `isSubscription`) and WS-A's reducer carries the three
/// actions that write it. This type was the merge seam: WS-E built the
/// price picker, the support assignment and "Ship an update" against an
/// engine that did not have those cases yet, and hid them behind
/// `isAvailable`. WS-A has merged, so they are live and the call sites
/// never changed.
enum LiveOps {
    /// Whether the engine accepts post-launch actions.
    static let isAvailable = true

    /// Re-prices a released product.
    static func setPriceTier(productID: UUID, tier: PriceTier) -> GameAction? {
        .setPriceTier(productID: productID, tier: tier)
    }

    /// Puts a released product back into a short update cycle.
    static func startUpdate(productID: UUID) -> GameAction? {
        .startUpdate(productID: productID)
    }

    /// The assignment that puts an employee on a live product's bug queue.
    static func supportAssignment(productID: UUID) -> Assignment? {
        .support(productID)
    }

    /// What each price tier is actually for, read off the balance rather
    /// than restated here.
    ///
    /// The caption used to give price and demand separately — "60% of list
    /// price, half again as many buyers" — which reads like a trade and
    /// hides the product: 0.6 × 1.5 is 0.90 against standard's 1.00 and
    /// premium's 0.96, so on revenue alone standard won every time and the
    /// picker had one answer. Now the revenue effect is stated as one
    /// number and each tier names the thing it buys that revenue does not.
    static func priceCaption(for tier: PriceTier, balance: BalanceConfig) -> String {
        let def = balance.economy.priceTier(tier)
        let revenue = def.priceFactor * def.demandFactor
        let percent = Int(((revenue - 1) * 100).rounded())
        let revenueLine = percent == 0
            ? String(localized: "List price", comment: "Price tier caption: this tier earns exactly the list price per buyer")
            : String(localized: "\(percent > 0 ? "+" : "")\(percent)% revenue per buyer reached", comment: "Price tier caption: how much more or less each buyer is worth at this price")

        switch tier {
        case .budget:
            return revenueLine + String(localized: " · undercuts rivals for share of the topic", comment: "Budget price tier: what it buys beyond revenue. Appended to the revenue line")
        case .standard:
            return revenueLine + String(localized: " · no edge either way", comment: "Standard price tier: what it buys beyond revenue. Appended to the revenue line")
        case .premium:
            return revenueLine
                + String(localized: " · needs reviews of \(Int(balance.economy.premiumQualityThreshold)) or it drives buyers away", comment: "Premium price tier: what it costs beyond revenue. Appended to the revenue line")
        }
    }
}
