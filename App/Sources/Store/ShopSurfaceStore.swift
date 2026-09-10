import Foundation
import StoreKit

// MARK: Iteration 13 — P2 (purchases: StoreKit and the session)

/// The session's shop, in the shape P3's surfaces read
/// (`ShopSurfaceModel`, `App/Sources/Store/ShopSurfaceModel.swift` on
/// `p3-surfaces`): a price per product id, the owned set, why the store
/// cannot sell right now, and a way to buy.
///
/// Every requirement of that protocol is here except `buy(_:)`, which
/// takes P3's `ShopSurfaceItem`. That type does not exist on this branch,
/// so the conformance is three lines the merge adds once P3 is in:
///
///     extension ShopSurfaceStore: ShopSurfaceModel {
///         func buy(_ item: ShopSurfaceItem) { buy(productID: item.productID) }
///     }
///
/// plus the root injection, written out in `AppRootView`'s P2 markers.
///
/// It reads through the session, so a view that reads `owned` or a price
/// is observing `session.shop` and redraws when the store answers.
@MainActor
final class ShopSurfaceStore {
    private weak var session: GameSession?

    init(session: GameSession) {
        self.session = session
    }

    /// The storefront's own `displayPrice`, `nil` until the store answers.
    func price(_ productID: String) -> String? {
        session?.shop.prices[productID]
    }

    /// Owned non-consumables, by product id.
    var owned: Set<String> {
        session?.shop.owned ?? []
    }

    /// Why the store cannot sell anything right now, or `nil`. The game's
    /// own refusals are `PurchaseRule`'s, not this.
    var refusal: String? {
        if !AppStore.canMakePayments {
            return String(localized: "Purchases are turned off on this device.", comment: "Shop: in-app purchases are restricted on the device")
        }
        if session?.shop.prices.isEmpty ?? true {
            return String(localized: "The App Store isn't answering. Try again later.", comment: "Shop: the store's prices did not load")
        }
        return nil
    }

    /// Starts a purchase: the session buys, applies the grant and finishes
    /// the transaction. No confirmation here — the surface asked it.
    func buy(productID: String) {
        guard let product = ShopCatalog.product(for: productID) else { return }
        session?.requestShopPurchase(product)
    }
}

// Iteration 13 merge — P2's store meets P3's surface protocol.
extension ShopSurfaceStore: ShopSurfaceModel {
    func buy(_ item: ShopSurfaceItem) { buy(productID: item.productID) }
}
