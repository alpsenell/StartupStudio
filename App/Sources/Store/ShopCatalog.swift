import Foundation
import TycoonEngine

// MARK: Iteration 13 — P2 (purchases: StoreKit and the session)

/// The six things the shop sells, beside the one unlock
/// (`UnlockState.productID`). Ids, kinds and which are used once; no
/// prices — the store quotes those (`Product.displayPrice`), the app never
/// hardcodes one. See `docs/product/iteration-13-iap.md` §1 and §4.4.
enum ShopProduct: String, CaseIterable, Sendable, Identifiable {
    case secondChance = "com.alpsenel.startupstudio.secondchance"
    case fourthSlot = "com.alpsenel.startupstudio.slot4"
    case loftPack = "com.alpsenel.startupstudio.decor.loft"
    case cashMonth = "com.alpsenel.startupstudio.cash.month"
    case cashQuarter = "com.alpsenel.startupstudio.cash.quarter"
    case veteran = "com.alpsenel.startupstudio.veteran"

    var id: String { rawValue }

    /// The App Store's product id.
    var productID: String { rawValue }

    /// Used once and never restored: cash, the second chance, the
    /// veteran. The slot and the pack are owned on the Apple ID.
    var isConsumable: Bool {
        switch self {
        case .secondChance, .cashMonth, .cashQuarter, .veteran: true
        case .fourthSlot, .loftPack: false
        }
    }

    /// What a consumable grants in game terms; `nil` for the two owned things.
    var kind: PurchaseKind? {
        switch self {
        case .cashMonth: .cash(weeks: 4)
        case .cashQuarter: .cash(weeks: 13)
        case .secondChance: .secondChance
        case .veteran: .veteran
        case .fourthSlot, .loftPack: nil
        }
    }

    /// The name the store and the game both use (§1).
    var displayName: String {
        switch self {
        case .secondChance: String(localized: "The receiver's call", comment: "Shop item: reverses a bankruptcy ending once")
        case .fourthSlot: String(localized: "A fourth slot", comment: "Shop item: a fourth save slot on the front door")
        case .loftPack: String(localized: "The loft pack", comment: "Shop item: six home decor pieces")
        case .cashMonth: String(localized: "A month of runway", comment: "Shop item: four weeks of the company's burn, in cash")
        case .cashQuarter: String(localized: "A quarter of runway", comment: "Shop item: thirteen weeks of the company's burn, in cash")
        case .veteran: String(localized: "A veteran", comment: "Shop item: one lead-level candidate added to the hiring pool")
        }
    }
}

enum ShopCatalog {
    /// Every product id the shop asks the store about.
    static let productIDs: [String] = ShopProduct.allCases.map(\.productID)

    /// The product behind an id, `nil` for the unlock and for anything an
    /// older or newer build sold.
    static func product(for productID: String) -> ShopProduct? {
        ShopProduct(rawValue: productID)
    }

    /// Whether a transaction for `productID` must wait for the session to
    /// apply it before it is finished. Everything else — the unlock, the
    /// slot, the pack, an id this build does not know — is owned or
    /// nothing, and finishing it is always safe. `Entitlements.updates()`
    /// reads this: a consumable finished before it is applied is money
    /// taken for nothing.
    static func isConsumable(_ productID: String) -> Bool {
        product(for: productID)?.isConsumable ?? false
    }

    /// The name a grant goes by on the Purchases list.
    static func name(of kind: PurchaseKind) -> String {
        switch kind {
        case .cash(4): ShopProduct.cashMonth.displayName
        case .cash(13): ShopProduct.cashQuarter.displayName
        case .cash(let weeks): String(localized: "\(weeks) weeks of runway", comment: "Purchases list: a cash grant of an unusual size")
        case .secondChance: ShopProduct.secondChance.displayName
        case .veteran: ShopProduct.veteran.displayName
        }
    }

    // MARK: The fourth slot

    /// The save store is always built this wide (§4.3); the fourth row is
    /// locked until the slot is owned.
    static let slotCount = 4
    /// The fourth slot's index (`slot3.json`, the `slot3` iCloud key).
    static let fourthSlotIndex = 3
}
