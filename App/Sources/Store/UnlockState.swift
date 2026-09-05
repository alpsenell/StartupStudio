import Foundation

// MARK: Iteration 7 — the unlock (R6)

/// What the session knows about the one non-consumable, and what the
/// paywall is doing about it.
struct UnlockState: Equatable {
    /// The product the owner creates in App Store Connect.
    static let productID = "com.alpsenel.startupstudio.fullgame"

    /// Whether the player owns the full game.
    var isEntitled = false
    /// False until StoreKit has answered once this launch. Before that
    /// `isEntitled` is the cached answer from the last launch — enough to
    /// keep the first frame from flickering, never enough to open the gate
    /// past that frame on its own: the paywall waits for a real answer.
    var isKnown = false
    /// True while the paywall sheet is up.
    var isPresentingPaywall = false
    /// Set the first time the paywall is shown this launch, and never
    /// cleared: the review prompt reads it and stays quiet.
    var paywallShownThisSession = false
    /// The price the store quoted, once it has ("$4.99"). `nil` until the
    /// product loads, and after a load that failed.
    var displayPrice: String?
    /// Why the last purchase or restore did not go through, for the
    /// paywall to say in one line. Cleared by the next attempt.
    var lastStoreMessage: String?

    static let unknown = UnlockState()
}
