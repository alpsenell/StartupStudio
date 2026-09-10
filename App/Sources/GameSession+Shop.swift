import Foundation
import TycoonContent
import TycoonEngine
import TycoonSave

// MARK: Iteration 13 — P2 (purchases: StoreKit and the session)

/// The session's side of the shop (`iteration-13-iap.md` §4): buying,
/// applying a consumable exactly once, parking one no company can take
/// yet, what a killed app left unfinished, the owned slot and pack, and
/// restore. StoreKit is behind `ShopSource`; the actor never touches the
/// session — every call here is on the main actor, awaiting the source.
///
/// Idempotence is two-layered (§4.1): the engine refuses a transaction id
/// it has already granted, and the session finishes on "already granted"
/// so an unfinished duplicate stops being redelivered. A third, local
/// layer — the ids this device applied, in `UserDefaults` — keeps a
/// redelivered transaction from landing in a *different* company than the
/// one it was applied to.
extension GameSession {
    /// The listener on the store's updates, alive for the app's life.
    @MainActor private static var shopListener: Task<Void, Never>?
    /// The store the session was installed with.
    @MainActor private static var shopSource: (any ShopSource)?
    /// Where the parked ids, the owned cache and the applied ids live.
    @MainActor private static var shopDefaults: UserDefaults = .standard
    /// A retry of the parked grants is under way.
    @MainActor private static var retryingParked = false

    private static let appliedKey = "shop.applied"
    /// The applied-ids list keeps the most recent this many.
    private static let appliedCap = 200

    /// Seeds the shop from the last launch, asks the store for prices and
    /// ownership, applies whatever a killed app left unfinished, and
    /// listens for the app's life. Called once from the root view.
    func installShop(source: any ShopSource = ShopClient.shared, defaults: UserDefaults = .standard) {
        Self.shopSource = source
        Self.shopDefaults = defaults
        shop.owned = ShopState.loadOwnedCache(from: defaults)
        shop.isOwnedKnown = false
        shop.parked = ShopState.loadParked(from: defaults)
        refreshSlots()

        Self.shopListener?.cancel()
        // Subscribe before the first question, so nothing that lands while
        // the store is answering is missed. StoreKit also redelivers every
        // unfinished transaction here at launch; `applyGrant` is idempotent.
        let updates = source.updates()
        Self.shopListener = Task { [weak self] in
            let prices = await source.displayPrices()
            let owned = await source.ownedProductIDs()
            guard !Task.isCancelled, let self else { return }
            if !prices.isEmpty { self.shop.prices = prices }
            self.applyOwned(owned)

            // §4.1 step 4: the store's list is the truth; the mirror in
            // `UserDefaults` is only what the front door counted.
            let unfinished = await source.unfinished()
            guard !Task.isCancelled else { return }
            self.shop.parked.removeAll { parked in !unfinished.contains { $0.id == parked.id } }
            self.saveParked()
            for transaction in unfinished {
                await self.applyGrant(transaction)
            }
            self.applyShopDebugLaunchArguments()

            for await transaction in updates {
                guard !Task.isCancelled else { return }
                await self.applyGrant(transaction)
            }
        }
    }

    // MARK: - Buying

    /// A shop button was tapped: straight to the store. "Leave the
    /// boards?" is the surface's to ask before it calls this (P3's
    /// `ShopPurchaseFlow.tap`), so the session never asks it a second time.
    func requestShopPurchase(_ product: ShopProduct) {
        shop.lastMessage = nil
        Task { await buyFromShop(product) }
    }

    /// Why `product` cannot be bought right now, in one line, or `nil`.
    /// Checked before the store sheet opens, so money is never taken for
    /// a grant the reducer would refuse on the spot.
    func shopRefusal(_ product: ShopProduct) -> String? {
        guard let kind = product.kind else {
            return shop.owns(product)
                ? String(localized: "Already yours on this Apple ID.", comment: "Shop: the owned item was tapped again")
                : nil
        }
        guard hasCurrentGame else {
            return String(localized: "Open a company first.", comment: "Shop: a consumable was tapped with no company open")
        }
        return PurchaseRule.refusal(kind, state: engine.state)
    }

    /// The purchase itself (§4.1). A verified consumable is applied and
    /// only then finished; every other outcome is a line in
    /// `shop.lastMessage`.
    ///
    /// - Parameter checked: `false` skips the pre-check — `-autoShop`
    ///   only, so the parked path can be driven on a build whose engine
    ///   refuses everything.
    func buyFromShop(_ product: ShopProduct, checked: Bool = true) async {
        guard let source = Self.shopSource, !shop.isBuying(product) else { return }
        if checked, let refusal = shopRefusal(product) {
            shop.lastMessage = refusal
            return
        }
        shop.lastMessage = nil
        shop.inFlight.insert(product.productID)
        defer { shop.inFlight.remove(product.productID) }
        do {
            switch try await source.purchase(product.productID) {
            case .verified(let transaction):
                await applyGrant(transaction)
                if shop.parked.contains(where: { $0.id == transaction.id }) {
                    shop.lastMessage = String(localized: "Bought. No company open can take it right now, so it waits and goes to the next one that can.", comment: "Shop: a consumable was paid for but parked")
                }
            case .pending:
                shop.lastMessage = String(localized: "Waiting for approval. It arrives by itself when it comes through.", comment: "Shop: Ask to Buy is pending")
            case .cancelled:
                break
            case .unverified:
                shop.lastMessage = String(localized: "The App Store's answer couldn't be verified. Nothing was granted; try again in a moment.", comment: "Shop: the transaction did not verify")
            }
        } catch {
            shop.lastMessage = String(localized: "The App Store couldn't be reached. Try again in a moment.", comment: "Shop: the store did not answer")
        }
    }

    // MARK: - Applying a grant

    /// What happened to a consumable's grant.
    private enum ShopGrantOutcome {
        /// The engine applied it just now.
        case applied
        /// It was applied before — here, or before a kill.
        case alreadyGranted
        /// No open company can take it; it waits.
        case parked
    }

    /// Every verified transaction comes through here: a purchase, a launch's
    /// unfinished list, the store's updates, a parked retry.
    ///
    /// Consumables are applied to the open company when `PurchaseRule`
    /// allows, and finished only once the grant is in the save (the engine
    /// autosaves on a non-empty return). Refused, they stay unfinished and
    /// are parked for the next company that can take them.
    func applyGrant(_ transaction: ShopTransaction) async {
        guard let source = Self.shopSource else { return }
        guard let product = ShopCatalog.product(for: transaction.productID) else {
            // The unlock (its own actor sees to it) or an id this build
            // does not sell: nothing to grant, and finishing is safe.
            await source.finish(transaction.id)
            return
        }
        guard product.isConsumable, let kind = product.kind else {
            // The slot or the pack: bought, restored, or refunded.
            if !transaction.isRevoked { shop.owned.insert(product.productID) }
            await source.finish(transaction.id)
            await refreshOwnedProducts(keeping: transaction.isRevoked ? nil : product.productID)
            return
        }
        guard !transaction.isRevoked else {
            // A refunded consumable is not clawed back (§6), and one that
            // was never applied is not applied now.
            unpark(transaction.id)
            await source.finish(transaction.id)
            return
        }
        switch grant(kind, transactionID: transaction.id) {
        case .applied, .alreadyGranted:
            if kind == .secondChance { settleReceiversCall() }
            rememberApplied(transaction.id)
            unpark(transaction.id)
            await source.finish(transaction.id)
        case .parked:
            park(transaction)
        }
    }

    private func grant(_ kind: PurchaseKind, transactionID: UInt64) -> ShopGrantOutcome {
        if engine.state.purchases.contains(transactionID) || hasApplied(transactionID) {
            return .alreadyGranted
        }
        guard shopCanTakeGrants, PurchaseRule.allows(kind, state: engine.state) else { return .parked }
        let events = engine.send(.applyPurchase(kind: kind, transactionID: transactionID))
        if !events.isEmpty || engine.state.purchases.contains(transactionID) {
            return .applied
        }
        return .parked
    }

    /// A real company is live — never the placeholder behind an empty
    /// slot, never a locked fourth slot. Shared companies and ended ones
    /// are `PurchaseRule`'s to refuse.
    private var shopCanTakeGrants: Bool {
        hasCurrentGame && (isDetached || !isShopLockedSlot(currentSlot))
    }

    /// §3.4 step 2: the ledger forgets the bankruptcy the receiver's call
    /// reversed. `endingsReached` keeps it — you did go bankrupt, and the
    /// receiver's letter stays on the shelf — and the hall keeps what the
    /// products earned. Idempotent, so a grant applied before a kill is
    /// settled by the redelivery.
    private func settleReceiversCall() {
        let state = engine.state
        guard let day = state.purchases.secondChanceDay else { return }
        let before = ledger.runs.count
        ledger.runs.removeAll {
            $0.seed == state.seed && $0.day == day && $0.companyName == state.company.name
                && $0.ending == .bankruptcy
        }
        if ledger.runs.count != before { saveLedger() }
    }

    // MARK: - Parked grants

    /// Tries every parked grant against the live company. Idempotent.
    func applyParkedGrants() async {
        guard !shop.parked.isEmpty, !Self.retryingParked else { return }
        Self.retryingParked = true
        defer { Self.retryingParked = false }
        for transaction in shop.parked {
            await applyGrant(transaction)
        }
    }

    /// Called on every engine swap (`GameSession.wireEngineHooks`): a
    /// parked grant goes to the next company that can take it.
    func shopEngineDidChange() {
        guard !shop.parked.isEmpty, Self.shopSource != nil else { return }
        Task { await applyParkedGrants() }
    }

    private func park(_ transaction: ShopTransaction) {
        guard !shop.parked.contains(where: { $0.id == transaction.id }) else { return }
        shop.parked.append(transaction)
        saveParked()
    }

    private func unpark(_ id: UInt64) {
        guard shop.parked.contains(where: { $0.id == id }) else { return }
        shop.parked.removeAll { $0.id == id }
        saveParked()
    }

    private func saveParked() {
        ShopState.saveParked(shop.parked, to: Self.shopDefaults)
    }

    private func hasApplied(_ id: UInt64) -> Bool {
        (Self.shopDefaults.array(forKey: Self.appliedKey) as? [String] ?? []).contains(String(id))
    }

    private func rememberApplied(_ id: UInt64) {
        var applied = Self.shopDefaults.array(forKey: Self.appliedKey) as? [String] ?? []
        guard !applied.contains(String(id)) else { return }
        applied.append(String(id))
        Self.shopDefaults.set(Array(applied.suffix(Self.appliedCap)), forKey: Self.appliedKey)
    }

    // MARK: - Owned things

    /// The store's answer about the slot and the pack.
    func applyOwned(_ owned: Set<String>) {
        let changed = owned != shop.owned
        shop.owned = owned
        shop.isOwnedKnown = true
        ShopState.saveOwnedCache(owned, to: Self.shopDefaults)
        if changed { refreshSlots() }
    }

    /// Re-reads `currentEntitlements`. `keeping` is a product just bought,
    /// kept even if the store's list has not caught up yet.
    func refreshOwnedProducts(keeping productID: String? = nil) async {
        guard let source = Self.shopSource else { return }
        var owned = await source.ownedProductIDs()
        if let productID { owned.insert(productID) }
        applyOwned(owned)
    }

    /// The fourth slot while it is not owned: its row is locked, its save
    /// (if a refund left one) is kept and not opened (§4.2).
    func isShopLockedSlot(_ slot: Int) -> Bool {
        slot == ShopCatalog.fourthSlotIndex && !shop.owns(.fourthSlot)
    }

    /// The picker's rows without a locked fourth slot, so New company and
    /// the replace dialog never offer it; the locked row is kept in
    /// `shop.lockedSlot` for the front door. Called from `refreshSlots`.
    func shopFilterSlots(_ rows: [SlotSummary]) -> [SlotSummary] {
        shop.lockedSlot = rows.first { isShopLockedSlot($0.slot) }
        return rows.filter { !isShopLockedSlot($0.slot) }
    }

    // MARK: - Restore

    /// Settings' Restore: `AppStore.sync()` (through the unlock's restore),
    /// then ownership re-read. The answer names what came back and says
    /// that consumables do not (§5).
    func restoreShopPurchases() async -> String {
        let entitled = await restorePurchases()
        let unreachable = String(localized: "The App Store couldn't be reached. Try again in a moment.", comment: "Shop: the store did not answer")
        if unlock.lastStoreMessage == "The App Store couldn't be reached. Try again in a moment." {
            return unreachable
        }
        await refreshOwnedProducts()
        var names: [String] = []
        if entitled { names.append(String(localized: "the full company", comment: "Restore alert: the unlock, inside a list")) }
        if shop.owns(.fourthSlot) { names.append(String(localized: "a fourth slot", comment: "Restore alert: the slot, inside a list")) }
        if shop.owns(.loftPack) { names.append(String(localized: "the loft pack", comment: "Restore alert: the pack, inside a list")) }
        let consumables = String(localized: "Cash, second chances and veterans don't restore — each is used once.", comment: "Restore alert: consumables are one-use")
        guard !names.isEmpty else {
            return String(localized: "No purchase to restore on this Apple ID.", comment: "Restore alert: nothing owned") + " " + consumables
        }
        var list = names.formatted(.list(type: .and))
        list = list.prefix(1).uppercased() + list.dropFirst()
        let owned = names.count == 1
            ? String(localized: "\(list) is yours on this Apple ID.", comment: "Restore alert: one owned thing")
            : String(localized: "\(list) are yours on this Apple ID.", comment: "Restore alert: several owned things")
        return owned + " " + consumables
    }

    // MARK: - Debug launch

    /// `-autoShop <productID>` (DEBUG only): drives one purchase through
    /// the store the scheme is attached to — the local `.storekit` file on
    /// the simulator. The id may be the full one or its suffix
    /// (`cash.month`). Skips the pre-check, so on a build whose engine
    /// refuses the grant the transaction parks, which is the point.
    private func applyShopDebugLaunchArguments() {
        #if DEBUG
        guard let word = DebugLaunch.autoShopProductID else { return }
        let product = ShopCatalog.product(for: word)
            ?? ShopCatalog.product(for: "com.alpsenel.startupstudio.\(word)")
        guard let product else { return }
        Task { await buyFromShop(product, checked: false) }
        #endif
    }
}
