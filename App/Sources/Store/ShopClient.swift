import Foundation
import StoreKit

// MARK: Iteration 13 — P2 (purchases: StoreKit and the session)

/// One verified transaction, in the few facts the session needs. The
/// StoreKit `Transaction` itself stays inside the actor, so the session —
/// and a fake — never touch StoreKit types.
struct ShopTransaction: Sendable, Equatable, Codable {
    /// `Transaction.id`, the key the engine refuses a second grant on.
    var id: UInt64
    var productID: String
    /// A refund or a revoked Family purchase. A consumable is never clawed
    /// back (§6); an owned thing stops being owned.
    var isRevoked: Bool = false
}

/// How a purchase ended.
enum ShopPurchaseResult: Sendable, Equatable {
    /// Verified and *not yet finished*: the session applies it first.
    case verified(ShopTransaction)
    /// Ask to Buy: the answer arrives through `updates()`.
    case pending
    case cancelled
    /// The store answered but the transaction did not verify.
    case unverified
}

/// The store, as the session sees it. `ShopClient` in the app; a fake in
/// a check. Nothing here finishes a consumable by itself — the session
/// calls `finish` once the grant is on disk.
protocol ShopSource: Sendable {
    /// Product id → the storefront's price string ("$1.99"). Empty while
    /// the store is unreachable.
    func displayPrices() async -> [String: String]
    /// Buys one product. A verified consumable comes back unfinished.
    func purchase(_ productID: String) async throws -> ShopPurchaseResult
    /// Finishes a transaction this source handed out. Idempotent.
    func finish(_ transactionID: UInt64) async
    /// Every verified consumable of ours still unfinished — the ones a
    /// killed app never finished. Called once per launch.
    func unfinished() async -> [ShopTransaction]
    /// The owned, unrevoked non-consumables of the catalog.
    func ownedProductIDs() async -> Set<String>
    /// Every verified transaction the store reports for the app's life:
    /// Ask to Buy approvals, purchases on another device, refunds.
    func updates() -> AsyncStream<ShopTransaction>
}

/// StoreKit 2 behind `ShopSource`. The verified `Transaction`s it hands
/// out are held here by id until the session says `finish`, so a grant is
/// always applied (and autosaved) before the store is told it was
/// delivered.
///
/// Swift 6: an actor, and it never calls into the session — the session
/// awaits it from the main actor and reads the answers.
actor ShopClient: ShopSource {
    static let shared = ShopClient()

    /// Verified transactions handed out and not yet finished.
    private var held: [UInt64: Transaction] = [:]

    func displayPrices() async -> [String: String] {
        guard let products = try? await Product.products(for: ShopCatalog.productIDs) else { return [:] }
        return Dictionary(products.map { ($0.id, $0.displayPrice) }, uniquingKeysWith: { first, _ in first })
    }

    func purchase(_ productID: String) async throws -> ShopPurchaseResult {
        guard let product = try await Product.products(for: [productID]).first else {
            throw Entitlements.StoreUnavailable()
        }
        // `Product.purchase` presents the store sheet; main-actor bound,
        // as in `Entitlements.purchase`.
        let result = try await Task { @MainActor in try await product.purchase() }.value
        switch result {
        case .success(.verified(let transaction)):
            return .verified(hold(transaction))
        case .success(.unverified):
            return .unverified
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    func finish(_ transactionID: UInt64) async {
        if let transaction = held.removeValue(forKey: transactionID) {
            await transaction.finish()
            return
        }
        // Handed out by a previous launch: find it again.
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result, transaction.id == transactionID {
                await transaction.finish()
                return
            }
        }
    }

    func unfinished() async -> [ShopTransaction] {
        var out: [ShopTransaction] = []
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            if ShopCatalog.isConsumable(transaction.productID) {
                out.append(hold(transaction))
            } else {
                // Owned things and ids this build does not sell: finishing
                // is always safe, and stops the redelivery.
                await transaction.finish()
            }
        }
        return out
    }

    func ownedProductIDs() async -> Set<String> {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let product = ShopCatalog.product(for: transaction.productID),
                  !product.isConsumable
            else { continue }
            owned.insert(product.productID)
        }
        return owned
    }

    nonisolated func updates() -> AsyncStream<ShopTransaction> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    // Unverified answers grant nothing and are left alone.
                    guard case .verified(let transaction) = result else { continue }
                    continuation.yield(await self.hold(transaction))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Keeps a consumable until the session finishes it; owned things are
    /// finished by `Entitlements.updates()` and by `unfinished()`.
    private func hold(_ transaction: Transaction) -> ShopTransaction {
        if ShopCatalog.isConsumable(transaction.productID) {
            held[transaction.id] = transaction
        }
        return ShopTransaction(
            id: transaction.id,
            productID: transaction.productID,
            isRevoked: transaction.revocationDate != nil
        )
    }
}
