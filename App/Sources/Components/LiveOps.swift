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
    ///
    /// Iteration 12 (J5, I1): with `reviewScore` and the premium review
    /// curve on, premium's number is the one *this* product earns at its
    /// score — and the other two tiers say so when premium would beat them.
    static func priceCaption(for tier: PriceTier, balance: BalanceConfig, reviewScore: Int? = nil) -> String {
        // MARK: J5 (announce)
        if let reviewScore, balance.economy.premiumReviewCurve.slope != 0 {
            return announcePriceCaption(for: tier, balance: balance, reviewScore: reviewScore)
        }
        // MARK: end J5
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

    // MARK: J5 (announce)

    /// I1: the caption at this product's review score. Premium states the
    /// revenue it actually earns here (0.6 + 0.02 × (review − 75) of the
    /// buyers, capped, at ×1.6 the price); the other two add premium's
    /// number when it would beat them.
    private static func announcePriceCaption(
        for tier: PriceTier, balance: BalanceConfig, reviewScore: Int
    ) -> String {
        let economy = balance.economy
        let percent = Int(((economy.revenueFactor(for: tier, reviewScore: reviewScore) - 1) * 100).rounded())
        let premiumPercent = Int(((economy.revenueFactor(for: .premium, reviewScore: reviewScore) - 1) * 100).rounded())
        let revenueLine = percent == 0
            ? String(localized: "List price", comment: "Price tier caption: this tier earns exactly the list price per buyer")
            : String(localized: "\(percent > 0 ? "+" : "")\(percent)% revenue per buyer reached", comment: "Price tier caption: how much more or less each buyer is worth at this price")
        let premiumWouldWin = premiumPercent > max(0, percent)
        let premiumHint = premiumWouldWin
            ? String(localized: " · premium would earn +\(premiumPercent)% at a review of \(reviewScore)", comment: "Price tier caption: what premium would earn at this product's review score, when it beats the current tier. Appended")
            : ""

        switch tier {
        case .budget:
            return revenueLine
                + String(localized: " · undercuts rivals for share of the topic", comment: "Budget price tier: what it buys beyond revenue. Appended to the revenue line")
                + premiumHint
        case .standard:
            return revenueLine
                + String(localized: " · no edge either way", comment: "Standard price tier: what it buys beyond revenue. Appended to the revenue line")
                + premiumHint
        case .premium:
            let threshold = Int(economy.premiumQualityThreshold)
            let bugFactor = economy.premiumReviewCurve.liveBugFactor
            let costLine = Double(reviewScore) < economy.premiumQualityThreshold
                ? String(localized: " · under \(threshold) it drives buyers away", comment: "Premium price tier at a review below the quality threshold: the penalty. Appended")
                : bugFactor == 2
                    ? String(localized: " · each live bug costs twice as much", comment: "Premium price tier: live bugs cost premium twice the usual sales penalty. Appended")
                    : String(localized: " · needs reviews of \(threshold)", comment: "Premium price tier: the review score it needs. Appended")
            return String(localized: "\(percent > 0 ? "+" : "")\(percent)% revenue per buyer at a review of \(reviewScore)", comment: "Premium price tier caption: the revenue per buyer this product earns at its own review score")
                + costLine
        }
    }

    // MARK: end J5
}
