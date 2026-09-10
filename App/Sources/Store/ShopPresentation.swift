import Foundation

// MARK: Iteration 13 — P2 (purchases: StoreKit and the session)

/// Every place in the app something could be sold, the six where it is
/// and the rest where it never is. The table is `ShopPresentation.offers`.
enum ShopSurface: String, CaseIterable, Sendable {
    // Where the shop lives (§5): each item next to the thing it buys.
    case moneySheet, postMortem, hireSheet, furnishSheet, frontDoor
    /// Lists what is owned and bought; sells nothing.
    case settings
    // Where it never is (the anti-nag rules, §5 1–6).
    case noticeRail, pause, coachTip, weeklyReport, tour, morningDesk
    case journal, toast, pushNotification, hud, paywall, endingCover
}

/// The anti-nag rules of `iteration-13-iap.md` §5 as pure functions, like
/// `PaywallPresentation`, so a surface asks rather than decides:
///
/// 1. Never on the notice rail. 2. Never a pause. 3. Never a coach tip.
/// 4. Never self-presenting. 5. Never in the weekly report, the tour, the
/// morning desk, the journal, a toast or a push. 6. No badges, counters,
/// countdowns, "limited", "offer", "best value", sale marks, or a price
/// where the HUD is drawn. 7. One price per item, in the storefront's own
/// string, next to the thing it buys, the thing said in dollars first.
///
/// The surfaces' own copy (§2's refusals, the unranking line, "Leave the
/// boards?") is P3's, in `ShopSurfaceCopy`; the confirmation is asked by
/// the surface, never by the session.
enum ShopPresentation {
    /// The table: each product on exactly one surface.
    static func offers(_ product: ShopProduct, on surface: ShopSurface) -> Bool {
        switch (product, surface) {
        case (.cashMonth, .moneySheet), (.cashQuarter, .moneySheet): true
        case (.secondChance, .postMortem): true
        case (.veteran, .hireSheet): true
        case (.loftPack, .furnishSheet): true
        case (.fourthSlot, .frontDoor): true
        default: false
        }
    }

    /// A price is drawn only where the item is offered (rule 7).
    static func showsPrice(_ product: ShopProduct, on surface: ShopSurface) -> Bool {
        offers(product, on: surface)
    }

    /// Rule 4: no shop sheet ever opens by itself — not at a bankruptcy
    /// warning, not at low runway, not on an ending, not on launch.
    static func autoPresents(on surface: ShopSurface) -> Bool { false }

    /// Rule 6, for copy: none of these may appear in a shop string.
    static let forbiddenPhrases = [
        "limited", "offer", "best value", "sale", "% off", "today only",
        "hurry", "last chance", "don't miss", "exclusive", "free",
    ]

    /// Whether a line of shop copy keeps rule 6.
    static func isPlain(_ copy: String) -> Bool {
        let lowered = copy.lowercased()
        return !forbiddenPhrases.contains { lowered.contains($0) }
    }

    /// "A fourth slot · $0.99": the thing, the grant in dollars when
    /// there is one, then the one price; the price is left out while the
    /// store is quiet.
    static func label(_ product: ShopProduct, amount: Int? = nil, price: String?) -> String {
        var parts = [product.displayName]
        if let amount, amount > 0 { parts.append("+\(amount.money)") }
        if let price { parts.append(price) }
        return parts.joined(separator: " · ")
    }
}
