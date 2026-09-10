import PixelKit
import SwiftUI
import TycoonEngine

// MARK: - Iteration 9 — L7: furnishing the home

/// The seam between the engine's decor (ids, slots, rules) and PixelKit's
/// (sprites, anchors). Both sides key on the same strings, so this is a
/// lookup and a couple of small policies, never a second catalog.
enum DecorPresentation {
    /// The sprite for a decor id, or `nil` when the id is not a thing
    /// PixelKit can draw.
    static func sprite(for itemID: String) -> SpriteLibrary.HomeDecorName? {
        SpriteLibrary.HomeDecorName(rawValue: itemID)
    }

    /// What the home scene should draw: what is actually placed, or — on a
    /// headless screenshot pass with `-autoDecor` — one of everything.
    static func sceneDecor(life: LifeState, tier: HomeTier) -> [String: SpriteLibrary.HomeDecorName] {
        #if DEBUG
        if DebugLaunch.fillsDecor { return showroom(tier: tier) }
        #endif
        var out: [String: SpriteLibrary.HomeDecorName] = [:]
        for placed in life.decor.placed(in: tier) {
            if let name = sprite(for: placed.itemID) { out[placed.slot] = name }
        }
        return out
    }

    /// Every decor id the player may place right now: the possessions they
    /// bought, plus whatever the ledger has earned them.
    ///
    /// Iteration 13 (P2): `owned` is the App Store's owned product ids
    /// (`GameSession.shop.owned`); the loft pack's items are offered only
    /// while it is owned. A refund stops new placements — what is already
    /// placed stays, because the scene draws `life.decor`, not this list.
    static func available(life: LifeState, ledger: LegacyLedger, owned: Set<String> = []) -> [DecorItem] {
        let earned = ledger.availableDecor
        return HomeDecor.catalog.filter { item in
            switch item.source {
            case .shop: life.possessions.contains(item.id)
            // MARK: P2 (purchases: StoreKit and the session)
            case .purchased: owned.contains(ShopProduct.loftPack.productID)
            // MARK: end P2
            default: earned.contains(item.id)
            }
        }
    }

    /// The line under an item in the shelf: where it came from, and where
    /// it goes.
    static func caption(for item: DecorItem) -> String {
        "\(item.source.caption) · \(item.kind.placementPhrase)"
    }

    /// What VoiceOver calls one slot: what is in it, or that it is empty.
    static func spokenSlot(_ slotID: String, life: LifeState, tier: HomeTier) -> String {
        guard let slot = HomeDecor.slot(slotID) else { return "A place for something" }
        guard let itemID = life.decor.item(in: slotID, tier: tier),
              let item = HomeDecor.item(itemID)
        else { return "\(slot.name): \(slot.kind.emptyName.lowercased())" }
        return "\(slot.name): \(item.name)"
    }

    #if DEBUG
    /// One of everything, for the screenshot pass: the bought things
    /// first, then the earned ones, in slot order.
    static func showroom(tier: HomeTier) -> [String: SpriteLibrary.HomeDecorName] {
        var out: [String: SpriteLibrary.HomeDecorName] = [:]
        var pools: [DecorSlotKind: [DecorItem]] = [:]
        // MARK: P3 (purchases: surfaces and copy)
        // The loft pack is never in the showroom: a debug pass that never
        // bought it photographs the room it always did.
        for item in HomeDecor.catalog where sprite(for: item.id) != nil && item.source != .purchased {
        // MARK: end P3
            pools[item.kind, default: []].append(item)
        }
        var used: [DecorSlotKind: Int] = [:]
        for slot in HomeDecor.slots(for: tier) {
            let pool = pools[slot.kind] ?? []
            guard !pool.isEmpty else { continue }
            let index = (used[slot.kind] ?? 0) % pool.count
            used[slot.kind] = index + 1
            if let name = sprite(for: pool[index].id) { out[slot.id] = name }
        }
        return out
    }
    #endif
}

// MARK: - The ledger's side

/// Earning decor. The ending trophies are derived from `endingsReached`
/// in `LegacyLedger.availableDecor`, so only the season posters, the
/// pennant and the record player are written here.
extension GameSession {
    /// Adds a decor id to the ledger and writes it, once.
    func unlockDecor(_ id: String) {
        guard !ledger.unlockedDecor.contains(id) else { return }
        ledger.unlockedDecor.insert(id)
        saveLedger()
    }

    /// A season that was seen out leaves its poster on the wall.
    func unlockSeasonPoster(twist: SeasonTwist) {
        unlockDecor(HomeDecor.posterID(for: twist))
    }

    /// A night the company won something leaves the pennant.
    func unlockAwardsPennant() {
        unlockDecor("pennant")
    }
}
