import SwiftUI
import TycoonEngine

// MARK: - Iteration 13 — P3 (purchases: surfaces and copy)

/// The post-mortem's one purchase: after a bankruptcy, and only when the
/// rule would take it (not already taken, not a scenario, not a shared
/// company, not at a stake). Everything it does is said above the button,
/// in dollars, before the tap — including what it cannot undo.
///
/// Never self-presenting: it is a row on a screen the player is already
/// reading, under the three facts, and it opens nothing on its own.
struct ShopReceiverCall: View {
    let engine: GameEngine
    let info: GameOverInfo

    @Environment(\.shopSurface) private var injected
    @State private var pending: ShopSurfaceItem?

    var body: some View {
        if info.kind == .bankruptcy,
           PurchaseRule.refusal(.secondChance, state: engine.state) == nil,
           let shop = ShopSurfaceResolver.resolve(injected) {
            panel(shop)
                .shopDebugScrollTarget("receiver", when: !DebugLaunch.autoShopGrants)
                .shopLeaveBoardsDialog(pending: $pending, companyName: engine.state.company.name) { item in
                    shop.buy(item)
                }
        }
    }

    private func panel(_ shop: any ShopSurfaceModel) -> some View {
        let state = engine.state
        let item = ShopSurfaceItem.receiversCall
        let overdraft = max(0, -state.company.cash)
        let cashIn = PurchaseRule.cashAmount(weeks: 4, state: state, balance: engine.balance)
        let price = shop.price(item.productID)
        let enabled = shop.refusal == nil && price != nil

        return PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(ShopSurfaceCopy.receiversCallBody)
                    .font(.subheadline)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 2) {
                    if overdraft > 0 {
                        Text("Overdraft written off: \(overdraft.money)", comment: "Receiver's call: the negative cash the purchase clears. The argument is a dollar figure")
                    }
                    Text("A month of cash: \(ShopSurfaceCopy.grant(cashIn))", comment: "Receiver's call: the cash it puts in after clearing the overdraft. The argument is a dollar figure with a plus sign")
                }
                .font(Theme.Typography.number(.caption, weight: .semibold))
                .foregroundStyle(Theme.pixelInk.opacity(0.8))
                .accessibilityElement(children: .combine)

                ShopPriceButton(
                    item: item,
                    title: String(localized: "Take the receiver's call", comment: "Button on the bankruptcy post-mortem; the price follows it after a middle dot"),
                    price: price,
                    enabled: enabled,
                    spokenGrant: spokenGrant(overdraft: overdraft, cashIn: cashIn)
                ) {
                    ShopPurchaseFlow.tap(item, state: state, shop: shop, pending: &pending)
                }

                if let refusal = shop.refusal {
                    Text(refusal)
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func spokenGrant(overdraft: Int, cashIn: Int) -> String {
        overdraft > 0
            ? String(localized: "writes off \(overdraft.money) and puts in \(cashIn.money)", comment: "VoiceOver: what the receiver's call does, before its price. Arguments are dollar figures")
            : String(localized: "puts in \(cashIn.money)", comment: "VoiceOver: what the receiver's call does when cash was not negative. The argument is a dollar figure")
    }
}

/// The biography's money card, when the run bought anything: "Bought in:
/// $332,400 over 2 purchases." The record says what happened.
enum ShopBoughtLine {
    static func text(_ purchases: PurchaseLog) -> String? {
        guard !purchases.grants.isEmpty else { return nil }
        let total = purchases.grants.reduce(0) { $0 + $1.amount }
        let count = purchases.grants.count
        return count == 1
            ? String(localized: "Bought in: \(total.money) over 1 purchase.", comment: "Founder biography, money card: what the run bought from the App Store, one purchase. The argument is a dollar figure")
            : String(localized: "Bought in: \(total.money) over \(count) purchases.", comment: "Founder biography, money card: what the run bought from the App Store. Arguments are a dollar figure and a count")
    }
}
