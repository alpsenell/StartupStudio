import SwiftUI
import TycoonEngine

// MARK: - Iteration 13 — P3 (purchases: surfaces and copy)

/// The money sheet's fourth card: the two cash packs, each with the grant
/// in dollars and the storefront's price, the unranking rule above them,
/// and why not when the rule says no.
///
/// Nothing on it moves: no badge, no count, no pulse. It is drawn only
/// when a store is present (`\.shopSurface`), so a sheet without one is
/// the sheet it was.
struct ShopAppStoreCard: View {
    let engine: GameEngine

    @Environment(\.shopSurface) private var injected
    @State private var pending: ShopSurfaceItem?

    private static let items: [ShopSurfaceItem] = [.monthOfRunway, .quarterOfRunway]

    var body: some View {
        if let shop = ShopSurfaceResolver.resolve(injected) {
            card(shop)
                .shopDebugScrollTarget("shop")
                .shopLeaveBoardsDialog(pending: $pending, companyName: engine.state.company.name) { item in
                    shop.buy(item)
                }
        }
    }

    private func card(_ shop: any ShopSurfaceModel) -> some View {
        let state = engine.state
        // Both packs share every rule today; the footnotes are gathered
        // and said once.
        let refusals = Self.items.compactMap { item in
            item.kind.flatMap { ShopSurfaceCopy.refusal($0, state: state) }
        }
        let footnotes = Array(NSOrderedSet(array: refusals.map(\.footnote) + [shop.refusal].compactMap { $0 })) as? [String] ?? []

        return CardView(String(localized: "The App Store", comment: "Money sheet card: the two cash packs sold through the App Store"), systemImage: "bag") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if state.mode == .standard {
                    Text(ShopSurfaceCopy.unrankingLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Self.items, id: \.self) { item in
                    row(item, shop: shop, state: state)
                }
                ForEach(footnotes, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func row(_ item: ShopSurfaceItem, shop: any ShopSurfaceModel, state: GameState) -> some View {
        let weeks = if case .cash(let weeks) = item.kind { weeks } else { 0 }
        let amount = PurchaseRule.cashAmount(weeks: weeks, state: state, balance: engine.balance)
        let refusal = item.kind.flatMap { ShopSurfaceCopy.refusal($0, state: state) }
        let price = shop.price(item.productID)
        let enabled = refusal == nil && shop.refusal == nil && price != nil
        let spokenGrant = amount > 0
            ? String(localized: "\(ShopSurfaceCopy.grant(amount)) into company cash", comment: "What a cash pack puts in the company, said before the tap. The argument is a dollar figure with a plus sign")
            : nil
        let button = ShopPriceButton(
            item: item,
            price: price,
            refusedWord: refusal?.button,
            enabled: enabled,
            spokenGrant: spokenGrant
        ) {
            ShopPurchaseFlow.tap(item, state: state, shop: shop, pending: &pending)
        }

        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                info(item, amount: amount)
                Spacer(minLength: Theme.Spacing.sm)
                button.frame(width: 124)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                info(item, amount: amount)
                button
            }
        }
    }

    /// The name and the grant, silent: the button says both to VoiceOver.
    private func info(_ item: ShopSurfaceItem, amount: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if amount > 0 {
                Text("\(ShopSurfaceCopy.grant(amount)) into company cash", comment: "What a cash pack puts in the company, said before the tap. The argument is a dollar figure with a plus sign")
                    .font(Theme.Typography.number(.caption, weight: .semibold))
                    .foregroundStyle(Theme.positiveCash)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityHidden(true)
    }
}
