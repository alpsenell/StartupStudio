import SwiftUI
import TycoonEngine

// MARK: - Iteration 13 — P3 (purchases: surfaces and copy)

/// The five things the shop sells on the game's own surfaces: the money
/// sheet (two), the post-mortem (one), the hire sheet (one) and the
/// furnish sheet (one). The fourth slot is the front door's and P2's.
///
/// The product ids are written here and in P2's `ShopCatalog`, and
/// nowhere else in the app (spec §8, "the shop nags anyway").
enum ShopSurfaceItem: String, CaseIterable, Sendable {
    case monthOfRunway = "com.alpsenel.startupstudio.cash.month"
    case quarterOfRunway = "com.alpsenel.startupstudio.cash.quarter"
    case receiversCall = "com.alpsenel.startupstudio.secondchance"
    case veteran = "com.alpsenel.startupstudio.veteran"
    case loftPack = "com.alpsenel.startupstudio.decor.loft"

    var productID: String { rawValue }

    /// What the engine grants for it, or `nil` for the pack, which the
    /// engine never hears about.
    var kind: PurchaseKind? {
        switch self {
        case .monthOfRunway: .cash(weeks: 4)
        case .quarterOfRunway: .cash(weeks: 13)
        case .receiversCall: .secondChance
        case .veteran: .veteran
        case .loftPack: nil
        }
    }

    /// Cash, the second chance and the veteran unrank the company; the
    /// pack changes a picture.
    var unranks: Bool { kind != nil }

    var name: String {
        switch self {
        case .monthOfRunway: String(localized: "A month of runway", comment: "Shop item on the money sheet: four weeks of company burn in cash")
        case .quarterOfRunway: String(localized: "A quarter of runway", comment: "Shop item on the money sheet: thirteen weeks of company burn in cash")
        case .receiversCall: String(localized: "The receiver's call", comment: "Shop item on the bankruptcy post-mortem: reverses the bankruptcy once")
        case .veteran: String(localized: "A veteran", comment: "Shop item on the hire sheet: one lead-level candidate, shown before you buy")
        case .loftPack: String(localized: "The loft pack", comment: "Shop item on the furnish sheet: six decor items for the flat")
        }
    }
}

/// What the game's surfaces need from the store, and nothing more: a
/// price per product, what is owned, a way to buy, and why not.
///
/// P2's StoreKit client is adapted to this at merge and injected with
/// `.environment(\.shopSurface, …)`. With nothing injected — every
/// snapshot test, and this branch before P2 lands — the surfaces draw
/// nothing at all, so a screen without a store is the screen it was.
@MainActor
protocol ShopSurfaceModel: AnyObject, Sendable {
    /// The storefront's own `displayPrice`, or `nil` while the App Store
    /// has not answered. The app never writes a price itself.
    func price(_ productID: String) -> String?
    /// Owned non-consumables, by product id.
    var owned: Set<String> { get }
    /// Why the store cannot sell anything right now (purchases turned off
    /// on the device, the App Store unreachable), or `nil`. The game's own
    /// refusals come from `PurchaseRule`, not from here.
    var refusal: String? { get }
    /// Starts a purchase. The session applies the grant and finishes the
    /// transaction; the surface only asks.
    func buy(_ item: ShopSurfaceItem)
}

private struct ShopSurfaceKey: EnvironmentKey {
    static let defaultValue: (any ShopSurfaceModel)? = nil
}

extension EnvironmentValues {
    /// The store, for the four surfaces that sell something. `nil` means
    /// no shop: the surfaces are simply absent.
    var shopSurface: (any ShopSurfaceModel)? {
        get { self[ShopSurfaceKey.self] }
        set { self[ShopSurfaceKey.self] = newValue }
    }
}

/// A fixed store for previews and the headless screenshot pass: the US
/// prices from the spec's table and an owned set, and a `buy` that only
/// records what was asked for.
@MainActor
final class ShopSurfacePreview: ShopSurfaceModel {
    let prices: [String: String]
    var owned: Set<String>
    var refusal: String?
    private(set) var asked: [ShopSurfaceItem] = []

    init(
        prices: [String: String] = ShopSurfacePreview.usPrices,
        owned: Set<String> = [],
        refusal: String? = nil
    ) {
        self.prices = prices
        self.owned = owned
        self.refusal = refusal
    }

    static let usPrices: [String: String] = [
        ShopSurfaceItem.monthOfRunway.productID: "$1.99",
        ShopSurfaceItem.quarterOfRunway.productID: "$4.99",
        ShopSurfaceItem.receiversCall.productID: "$2.99",
        ShopSurfaceItem.veteran.productID: "$2.99",
        ShopSurfaceItem.loftPack.productID: "$1.99",
    ]

    func price(_ productID: String) -> String? { prices[productID] }

    func buy(_ item: ShopSurfaceItem) {
        asked.append(item)
    }
}

/// The store a surface reads: the injected one, or — on a debug pass that
/// asked for a shop surface before P2's client exists — the preview.
enum ShopSurfaceResolver {
    @MainActor
    static func resolve(_ injected: (any ShopSurfaceModel)?) -> (any ShopSurfaceModel)? {
        if let injected { return injected }
        #if DEBUG
        return ShopSurfaceDebug.previewStore
        #else
        return nil
        #endif
    }
}

// MARK: - Copy

/// The spec's §2 and §5 copy, in one place so the four surfaces say the
/// same thing the same way.
enum ShopSurfaceCopy {
    /// Above the two cash rows in a Standard company, always visible.
    static let unrankingLine = String(
        localized: "Bought money makes this company unranked — no leaderboards from here on, like an heirloom. Achievements, the ledger and the Hall of Fame carry on.",
        comment: "Money sheet, App Store card: the rule above the two cash packs, shown in every standard company"
    )

    /// Under the veteran's card in a ranked company.
    static let veteranUnrankingLine = String(
        localized: "A bought hire makes this company unranked, like an heirloom. Achievements still count.",
        comment: "Hire sheet, the veteran card: what buying the veteran does to the leaderboards"
    )

    /// The receiver's call, under its button (§5).
    static let receiversCallBody = String(
        localized: "The overdraft is written off and a month of cash goes in. The loan is still yours, so is whatever the bank already took, and the trade press will remember. From here the company is unranked.",
        comment: "Bankruptcy post-mortem: what the receiver's call does, above its button"
    )

    /// A refused purchase: the button's short word and the footnote under
    /// it. `nil` when the rule allows it.
    ///
    /// The rule decides; this only chooses the words. A shared company and
    /// a stake have the spec's own copy; anything else prints the rule's
    /// one line.
    static func refusal(_ kind: PurchaseKind, state: GameState) -> (button: String?, footnote: String)? {
        guard let line = PurchaseRule.refusal(kind, state: state) else { return nil }
        let mode = state.mode
        if mode.isDaily || mode.isSeason || mode.isLeague {
            return (
                String(localized: "Not in a shared company", comment: "Disabled shop button in a daily, season or league company"),
                String(localized: "Today's company is the same for everyone, and your year leaves a ghost for the next player. Money from outside it would be a different game. The shop opens in a company of your own.", comment: "Footnote under a disabled shop button in a daily, season or league company")
            )
        }
        if state.rules.stake >= 2, kind != .veteran {
            return (
                String(localized: "Not at this stake", comment: "Disabled shop button at stake 2 or higher, No credit"),
                String(localized: "Stake 2, No credit: the bank won't lend, and neither will we.", comment: "Footnote under a disabled shop button at stake 2, No credit")
            )
        }
        return (nil, line)
    }

    /// "+$78,400" — the grant before the tap.
    static func grant(_ amount: Int) -> String {
        "+\(amount.money)"
    }
}

// MARK: - The first ranked purchase

/// The one confirmation the spec adds (§2): the first economy purchase in
/// a ranked company asks once, before StoreKit's own sheet. After it the
/// company is unranked and the question never comes again, because
/// `isRanked` is false.
struct ShopLeaveBoardsDialog: ViewModifier {
    @Binding var pending: ShopSurfaceItem?
    let companyName: String
    let buy: (ShopSurfaceItem) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            String(localized: "Leave the boards?", comment: "Title of the one confirmation before the first bought money in a ranked company"),
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending
        ) { item in
            Button(String(localized: "Buy and leave the boards", comment: "Confirms the first bought money in a ranked company")) {
                pending = nil
                buy(item)
            }
            Button(String(localized: "Cancel", comment: "Cancels the first bought money in a ranked company"), role: .cancel) {
                pending = nil
            }
        } message: { _ in
            Text("\(companyName) stops posting to leaderboards from today. Achievements still count.", comment: "Message of the one confirmation before the first bought money in a ranked company. The argument is the company name")
        }
    }
}

extension View {
    func shopLeaveBoardsDialog(
        pending: Binding<ShopSurfaceItem?>,
        companyName: String,
        buy: @escaping (ShopSurfaceItem) -> Void
    ) -> some View {
        modifier(ShopLeaveBoardsDialog(pending: pending, companyName: companyName, buy: buy))
    }
}

/// Buys through the one door: an economy item in a ranked company asks
/// first, everything else goes straight to the store.
@MainActor
enum ShopPurchaseFlow {
    static func tap(
        _ item: ShopSurfaceItem,
        state: GameState,
        shop: any ShopSurfaceModel,
        pending: inout ShopSurfaceItem?
    ) {
        Haptics.tap()
        if item.unranks && state.isRanked {
            pending = item
        } else {
            shop.buy(item)
        }
    }
}

// MARK: - The price button

/// One price, in the storefront's own string, on a button in the game's
/// own hand. Disabled with nothing to say while the App Store has not
/// answered; the refusal's short word in place of the price when the
/// rule says no.
struct ShopPriceButton: View {
    let item: ShopSurfaceItem
    /// "Take the receiver's call" — or `nil` for the price alone.
    var title: String?
    let price: String?
    /// The refusal's short word ("Not in a shared company"), shown instead
    /// of the price.
    var refusedWord: String?
    let enabled: Bool
    /// What VoiceOver hears after the name: "+$78,400 company cash".
    var spokenGrant: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Typography.number(.subheadline, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(PixelButtonStyle(fill: enabled ? Theme.pixelAccent : Theme.pixelPaper))
        .disabled(!enabled)
        .accessibilityLabel(spoken)
    }

    private var label: String {
        if let refusedWord { return refusedWord }
        let price = price ?? "…"
        guard let title else { return price }
        return "\(title) · \(price)"
    }

    private var spoken: String {
        var parts = [item.name]
        if let spokenGrant { parts.append(spokenGrant) }
        if let refusedWord {
            parts.append(refusedWord)
        } else if let price {
            parts.append(String(localized: "\(price), from the App Store", comment: "VoiceOver: the price of a shop item. The argument is the storefront price"))
        } else {
            parts.append(String(localized: "asking the App Store for the price", comment: "VoiceOver: a shop item whose price has not arrived yet"))
        }
        return parts.joined(separator: ", ")
    }
}
