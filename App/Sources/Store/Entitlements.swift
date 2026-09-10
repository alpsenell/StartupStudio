import Foundation
import StoreKit

// MARK: Iteration 7 — the unlock (R6)

/// How a purchase attempt ended, in the words the paywall needs.
enum PurchaseOutcome: Equatable, Sendable {
    /// The transaction verified and finished; the gate opens.
    case purchased
    /// The player backed out of the store sheet. Nothing to say.
    case cancelled
    /// Ask to Buy, or a deferred transaction: the answer arrives later
    /// through `updates`, and the paywall says so.
    case pending
    /// The store answered but the transaction did not verify.
    case unverified
}

/// What the session needs from the store, behind a protocol so the
/// session's own tests can stand in a fake and the StoreKit tests can
/// drive the real one through `SKTestSession`.
protocol EntitlementSource: Sendable {
    /// Whether the full game is owned, from the store's own record.
    func isEntitled() async -> Bool
    /// The entitlement after every transaction the store reports — a
    /// purchase on another device, a refund, an Ask to Buy approval.
    /// Runs for the app's life.
    func updates() -> AsyncStream<Bool>
    /// The localized price ("$4.99"), or `nil` while the store is unreachable.
    func displayPrice() async -> String?
    /// Buys the one product.
    func purchase() async throws -> PurchaseOutcome
    /// Restore purchases: asks the App Store for the receipt again, then
    /// re-reads the entitlement.
    func restore() async throws -> Bool
}

/// StoreKit 2, and nothing else: `Transaction.currentEntitlements` (works
/// offline from the local receipt), `Transaction.updates`, `AppStore.sync()`
/// behind Restore, every result through `VerificationResult`. No server,
/// no receipt validation service — the unlock is Apple-ID-scoped, which
/// is what a pay-once game wants.
actor Entitlements: EntitlementSource {
    static let shared = Entitlements()

    let productID: String

    init(productID: String = UnlockState.productID) {
        self.productID = productID
    }

    func isEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if entitles(result) { return true }
        }
        return false
    }

    nonisolated func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result,
                       // Iteration 13 (P2): finish what is owned or
                       // unknown — the unlock, the slot, the pack, an id
                       // this build does not sell — so it is not
                       // redelivered at every launch. A consumable is left
                       // for `ShopClient` and `GameSession.applyGrant`,
                       // which finish it once the grant is in the save:
                       // finished here, it would be money taken for nothing.
                       !ShopCatalog.isConsumable(transaction.productID) {
                        await transaction.finish()
                    }
                    continuation.yield(await self.isEntitled())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func displayPrice() async -> String? {
        (try? await Product.products(for: [productID]))?.first?.displayPrice
    }

    func purchase() async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [productID]).first else {
            throw StoreUnavailable()
        }
        // `Product.purchase` is main-actor bound (it presents the store
        // sheet); the product itself is Sendable.
        let result = try await Task { @MainActor in try await product.purchase() }.value
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                return .purchased
            case .unverified:
                return .unverified
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws -> Bool {
        try await AppStore.sync()
        return await isEntitled()
    }

    /// A verified, unrevoked transaction for our product. `currentEntitlements`
    /// already leaves revoked ones out; the date is checked anyway, so a
    /// refund that reaches `updates` re-locks on the same test.
    private func entitles(_ result: VerificationResult<Transaction>) -> Bool {
        guard case .verified(let transaction) = result else { return false }
        return transaction.productID == productID && transaction.revocationDate == nil
    }

    struct StoreUnavailable: Error {}
}
