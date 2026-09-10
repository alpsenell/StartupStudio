import Foundation
import TycoonSave

// MARK: Iteration 13 — P2 (purchases: StoreKit and the session)

/// What the session knows about the shop: the prices the store quoted,
/// what this Apple ID owns, the purchases waiting for a company, and the
/// last thing worth saying about a purchase.
struct ShopState: Equatable {
    /// Product id → "$1.99". Empty until the store answers.
    var prices: [String: String] = [:]
    /// The owned non-consumables' product ids (`slot4`, `decor.loft`).
    var owned: Set<String> = []
    /// False until StoreKit has answered once this launch; before that
    /// `owned` is the last launch's answer, so the first frame does not
    /// flicker a lock onto an owned slot.
    var isOwnedKnown = false
    /// Verified consumables that no open company could take yet (§4.1
    /// step 3). Unfinished at the store, so they are redelivered at every
    /// launch; mirrored in `UserDefaults` for the front door's line.
    var parked: [ShopTransaction] = []
    /// Why the last purchase did not go through, or what it is waiting
    /// for, in one line. Cleared by the next attempt.
    var lastMessage: String?
    /// Products with a purchase in flight, so a button cannot be tapped twice.
    var inFlight: Set<String> = []
    /// The fourth slot's row while it is locked — empty, or a save a
    /// refund left behind — for the front door. `nil` once owned.
    var lockedSlot: SlotSummary?

    static let parkedKey = "shop.parked"
    static let ownedCacheKey = "shop.ownedCache"

    func price(_ product: ShopProduct) -> String? { prices[product.productID] }

    func owns(_ product: ShopProduct) -> Bool { owned.contains(product.productID) }

    func isBuying(_ product: ShopProduct) -> Bool { inFlight.contains(product.productID) }

    // MARK: Persistence of the small things

    static func loadParked(from defaults: UserDefaults) -> [ShopTransaction] {
        guard let data = defaults.data(forKey: parkedKey),
              let decoded = try? JSONDecoder().decode([ShopTransaction].self, from: data)
        else { return [] }
        return decoded
    }

    static func saveParked(_ parked: [ShopTransaction], to defaults: UserDefaults) {
        if parked.isEmpty {
            defaults.removeObject(forKey: parkedKey)
        } else if let data = try? JSONEncoder().encode(parked) {
            defaults.set(data, forKey: parkedKey)
        }
    }

    static func loadOwnedCache(from defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: ownedCacheKey) ?? [])
    }

    static func saveOwnedCache(_ owned: Set<String>, to defaults: UserDefaults) {
        defaults.set(owned.sorted(), forKey: ownedCacheKey)
    }
}
