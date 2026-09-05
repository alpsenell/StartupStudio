import Foundation
import TycoonContent
import TycoonEngine
import TycoonSave

// MARK: Iteration 7 — the unlock (R6)

/// The session's side of the one non-consumable: the gate on the clock,
/// the store's answer kept current for the app's life, and the paywall's
/// state. Everything StoreKit is behind `EntitlementSource`, so the
/// session's tests run on a fake and the StoreKit tests drive the real
/// actor through `SKTestSession`.
extension GameSession {
    /// The cached answer from the last launch. Read once, before StoreKit
    /// has spoken, so an entitled player's first frame is not a lock; it
    /// is never trusted past that — `unlock.isKnown` is what the paywall
    /// waits for.
    static let entitledCacheKey = "store.entitledCache"

    /// The listener on `Transaction.updates`, alive for the app's life.
    @MainActor private static var unlockListener: Task<Void, Never>?
    /// The store the session was installed with, for purchase and restore.
    @MainActor private static var unlockSource: (any EntitlementSource)?
    /// Where the cached answer lives; the tests hand in their own.
    @MainActor private static var unlockDefaults: UserDefaults = .standard

    /// Installs the gate, seeds the entitlement from the cache, asks the
    /// store, and listens for changes. Called once from the root view's
    /// `.task`; the gate follows the engine across every swap by itself.
    func installUnlock(
        source: any EntitlementSource = Entitlements.shared,
        defaults: UserDefaults = .standard
    ) {
        Self.unlockSource = source
        Self.unlockDefaults = defaults
        unlock.isEntitled = defaults.bool(forKey: Self.entitledCacheKey)
        unlock.isKnown = false
        installGate(UnlockGate { [weak self] in self?.unlock.isEntitled ?? false })

        Self.unlockListener?.cancel()
        // Subscribe before the first question, so a transaction that
        // lands while the store is still answering is not missed.
        let updates = source.updates()
        Self.unlockListener = Task { [weak self] in
            let entitled = await source.isEntitled()
            guard !Task.isCancelled else { return }
            self?.apply(entitled: entitled)
            for await entitled in updates {
                guard !Task.isCancelled else { return }
                self?.apply(entitled: entitled)
            }
        }
        applyUnlockDebugLaunchArguments()
    }

    /// The store's answer, whenever it comes: launch, a purchase here or
    /// on another device, a refund. A refund re-locks the *clock* — the
    /// next tick stops and the paywall comes back; the save is untouched.
    func apply(entitled: Bool) {
        unlock.isEntitled = entitled
        unlock.isKnown = true
        Self.unlockDefaults.set(entitled, forKey: Self.entitledCacheKey)
        if entitled, unlock.isPresentingPaywall {
            // Bought or restored, here or elsewhere: the sheet has done
            // its job, and the clock the gate stopped runs again.
            dismissPaywall()
            resumeAfterUnlock()
        } else {
            reconsiderPaywall()
        }
    }

    // MARK: - The gate, read back

    /// Whether the unlock gate is refusing `state` right now.
    func unlockGateRefuses(_ state: GameState) -> Bool {
        guard let gate = gates.first(where: { $0.id == UnlockGate.gateID }) else { return false }
        return !gate.allows(state)
    }

    /// The current game, gated: chapter 2 or later, not entitled, not a daily.
    var isCurrentGameGated: Bool {
        hasCurrentGame && unlockGateRefuses(engine.state)
    }

    // MARK: - The paywall

    /// Opens the paywall by itself when — and only when — the policy says
    /// so: the game view calls it on appear (Continue on a gated save) and
    /// after every stop of the clock (the gate refusing a tick).
    func reconsiderPaywall() {
        guard !unlock.isPresentingPaywall else { return }
        #if DEBUG
        // `-noPaywall`: the lock on the speed control, photographed alone.
        if ProcessInfo.processInfo.arguments.contains("-noPaywall") { return }
        #endif
        let presents = PaywallPresentation.autoPresents(
            gated: isCurrentGameGated,
            known: unlock.isKnown,
            inGame: !isAtFrontDoor && hasCurrentGame,
            ended: engine.state.gameOver != nil,
            paused: engine.state.speed == .paused,
            pauseReasonUp: !engine.lastPauseEvents.isEmpty
        )
        if presents {
            presentPaywall()
        }
    }

    /// The lock on the speed control was tapped: the gate that is refusing
    /// gets to answer. The unlock's answer is the paywall; the daily's
    /// (R3) is its result card.
    func clockLockTapped() {
        guard let refusing = gates.first(where: { !$0.allows(engine.state) }) else { return }
        switch refusing.id {
        case UnlockGate.gateID:
            presentPaywall()
        default:
            break
        }
    }

    func presentPaywall() {
        unlock.lastStoreMessage = nil
        unlock.isPresentingPaywall = true
        unlock.paywallShownThisSession = true
    }

    /// "Not now": back to the paused game. Nothing else changes.
    func dismissPaywall() {
        unlock.isPresentingPaywall = false
    }

    /// The price, once; the paywall asks on appear.
    func loadPriceIfNeeded() async {
        guard unlock.displayPrice == nil, let source = Self.unlockSource else { return }
        let price = await source.displayPrice()
        unlock.displayPrice = price
    }

    /// Buys the game. On success the gate opens on the next read, the
    /// sheet closes and the clock runs; every other outcome is a line on
    /// the sheet, which stays up.
    func purchaseUnlock() async {
        guard let source = Self.unlockSource else { return }
        unlock.lastStoreMessage = nil
        do {
            switch try await source.purchase() {
            case .purchased:
                apply(entitled: true)
            case .cancelled:
                break
            case .pending:
                unlock.lastStoreMessage = "Waiting for approval. The game unlocks itself when it comes through."
            case .unverified:
                unlock.lastStoreMessage = "The App Store's answer couldn't be verified. Try again in a moment."
            }
        } catch {
            unlock.lastStoreMessage = "The App Store couldn't be reached. Try again in a moment."
        }
    }

    /// Restore purchases (the paywall's link and the Settings row). Returns
    /// whether the game is owned afterwards.
    @discardableResult
    func restorePurchases() async -> Bool {
        guard let source = Self.unlockSource else { return unlock.isEntitled }
        unlock.lastStoreMessage = nil
        do {
            let entitled = try await source.restore()
            apply(entitled: entitled)
            if !entitled {
                unlock.lastStoreMessage = "No purchase to restore on this Apple ID."
            }
            return entitled
        } catch {
            unlock.lastStoreMessage = "The App Store couldn't be reached. Try again in a moment."
            return unlock.isEntitled
        }
    }

    /// The clock the gate stopped, running again after the purchase.
    private func resumeAfterUnlock() {
        guard hasCurrentGame, !isAtFrontDoor, engine.state.gameOver == nil,
              engine.state.speed == .paused, engine.mayAdvance
        else { return }
        engine.setSpeed(.x1)
    }

    // MARK: - Debug launch

    /// `-autoChapter <n>` (DEBUG only): a generated company at chapter `n`
    /// in slot 3, opened, with the paywall up — so the paywall and the
    /// locked speed control can be photographed from the command line.
    /// `-noPaywall` alongside it leaves the sheet down, for the lock.
    private func applyUnlockDebugLaunchArguments() {
        #if DEBUG
        guard let word = DebugLaunch.value(after: "-autoChapter"), let chapter = Int(word) else { return }
        let engine = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = engine.state
        for _ in 0..<90 { _ = Reducer.tick(&state, balance: engine.balance, content: engine.content) }
        state.progression.chapter = chapter
        state.progression.chapterTitle = ChapterDef.title(for: chapter)
        state.progression.chapterLog = (1...max(1, chapter)).map { ChapterEntry(chapter: $0, day: ($0 - 1) * 45) }
        state.speed = .paused
        let store = SaveStore<GameState>(directory: nil, currentFormatVersion: 1)
        let slot = store.slotCount - 1
        try? store.save(state, appVersion: "debug", summary: SaveSummary(state: state), slot: slot)
        openSlot(slot)
        if isCurrentGameGated, !ProcessInfo.processInfo.arguments.contains("-noPaywall") {
            presentPaywall()
        }
        #endif
    }
}
