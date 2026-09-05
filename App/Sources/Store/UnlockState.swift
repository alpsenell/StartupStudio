import Foundation

// MARK: Iteration 7 — the unlock (R6)

/// What the session knows about the one non-consumable.
struct UnlockState: Equatable {
    /// The product the owner creates in App Store Connect.
    static let productID = "com.alpsenel.startupstudio.fullgame"

    /// Whether the player owns the full game.
    var isEntitled = false
    /// False until StoreKit has answered once this launch.
    var isKnown = false

    static let unknown = UnlockState()
}
