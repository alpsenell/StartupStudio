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

    /// What each price tier does to price and demand, for the picker's
    /// caption. Mirrors WS-A's documented multipliers.
    static func priceCaption(for tier: PriceTier) -> String {
        switch tier {
        case .budget: "60% of list price, half again as many buyers"
        case .standard: "List price"
        case .premium: "60% more per sale, far fewer buyers — and it needs the quality to justify it"
        }
    }
}
