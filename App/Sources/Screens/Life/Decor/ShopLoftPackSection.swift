import SwiftUI
import TycoonEngine

// MARK: - Iteration 13 — P3 (purchases: surfaces and copy)

/// The loft pack, on the furnish sheet under the things the founder
/// already has: six items shown greyed with one price on the header while
/// the pack is not owned. Once it is, the six are on the shelf above like
/// everything else, captioned "Bought from the App Store", and this
/// section is gone.
struct ShopLoftPackSection: View {
    @Environment(\.shopSurface) private var injected

    var body: some View {
        if let shop = ShopSurfaceResolver.resolve(injected),
           !shop.owned.contains(ShopSurfaceItem.loftPack.productID) {
            section(shop)
        }
    }

    private func section(_ shop: any ShopSurfaceModel) -> some View {
        let item = ShopSurfaceItem.loftPack
        let price = shop.price(item.productID)
        let enabled = shop.refusal == nil && price != nil
        let header = price.map {
            String(localized: "The loft pack · \($0)", comment: "Furnish sheet: the heading of the decor pack sold through the App Store, with its price")
        } ?? item.name

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(header)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            Text("Six things for the flat: two for the wall, two for a shelf, two for the floor. They change the picture and nothing else.", comment: "Furnish sheet: what the loft pack is")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(HomeDecor.loftPackItems) { decor in
                HStack(spacing: Theme.Spacing.md) {
                    DecorSwatch(itemID: decor.id)
                        .frame(width: 44, height: 40)
                        .saturation(0)
                        .opacity(0.45)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(decor.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(decor.kind.placementPhrase.capitalizedFirst)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }

            Button {
                Haptics.tap()
                shop.buy(item)
            } label: {
                Text("Buy the pack", comment: "Furnish sheet: the button under the loft pack; its price is on the heading above")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .buttonStyle(PixelButtonStyle(fill: enabled ? Theme.pixelAccent : Theme.pixelPaper))
            .disabled(!enabled)
            .accessibilityLabel(
                price.map {
                    String(localized: "Buy the loft pack, six things for the flat, \($0), from the App Store", comment: "VoiceOver: the loft pack's buy button, with its price")
                } ?? String(localized: "Buy the loft pack, asking the App Store for the price", comment: "VoiceOver: the loft pack's buy button before its price arrives")
            )

            if let refusal = shop.refusal {
                Text(refusal)
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The pack on the shelf once it is owned. `DecorPresentation.available`
/// gains an `owned:` parameter in P2; until then — and harmlessly after,
/// because the list is de-duplicated — the owned pack is added here.
enum ShopLoftPack {
    static func shelf(_ base: [DecorItem], owned: Set<String>) -> [DecorItem] {
        guard owned.contains(ShopSurfaceItem.loftPack.productID) else { return base }
        let have = Set(base.map(\.id))
        return base + HomeDecor.loftPackItems.filter { !have.contains($0.id) }
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
