import Foundation
import TycoonEngine

/// The seam between this branch's UI and WS-A's post-launch actions.
///
/// `ReleaseInfo` already carries the live-ops *state* (`liveBugs`,
/// `priceTier`, `subscribers`, `isSubscription`), so everything the UI
/// **reads** works today. The three actions that write it —
/// `.setPriceTier`, `.startUpdate` and the `.support` assignment — live in
/// WS-A's reserved region of `GameAction`, which does not exist on this
/// branch; a call site for a case that isn't in the enum will not compile.
///
/// So the controls that need them are built, laid out and accessible, and
/// this one type decides whether they are shown. When WS-A merges (it
/// merges before WS-E), flip `isAvailable` to `true` and return the real
/// actions from the three factories — the call sites do not change.
///
/// ```swift
/// static let isAvailable = true
/// static func setPriceTier(productID: UUID, tier: PriceTier) -> GameAction? {
///     .setPriceTier(productID: productID, tier: tier)
/// }
/// static func startUpdate(productID: UUID) -> GameAction? { .startUpdate(productID: productID) }
/// static func supportAssignment(productID: UUID) -> Assignment? { .support(productID) }
/// ```
enum LiveOps {
    /// Whether the engine on this branch accepts post-launch actions.
    static let isAvailable = false

    /// Re-prices a released product.
    static func setPriceTier(productID: UUID, tier: PriceTier) -> GameAction? {
        nil
    }

    /// Puts a released product back into a short update cycle.
    static func startUpdate(productID: UUID) -> GameAction? {
        nil
    }

    /// The assignment that puts an employee on a live product's bug queue.
    static func supportAssignment(productID: UUID) -> Assignment? {
        nil
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
