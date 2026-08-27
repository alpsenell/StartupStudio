import SwiftUI
import TycoonContent
import TycoonEngine

/// One row per product type: baseline market size and unit price, whether
/// it is unlocked, your lifetime revenue in that type, and an estimated
/// launch-week peak right now (quality 100) across the coldest and hottest
/// topics. The estimate is `marketSize × topic multiplier` only — it leaves
/// out fit, hype, and the adoption ramp, and says so.
struct ProductTypeMarketsCard: View {
    let engine: GameEngine

    private var snapshots: [TopicSnapshot] {
        MarketAnalysis.byDemand(content: engine.content, market: engine.state.market)
    }

    var body: some View {
        let hottest = snapshots.first
        let coldest = snapshots.last
        CardView("Product-type markets", systemImage: "square.grid.2x2.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(engine.content.productTypes.enumerated()), id: \.element.id) { index, type in
                        ProductTypeMarketRow(
                            type: type,
                            unlocked: engine.state.isProductTypeUnlocked(type.id, content: engine.content),
                            revenue: revenue(in: type.id),
                            hottest: hottest,
                            coldest: coldest
                        )
                        if index < engine.content.productTypes.count - 1 {
                            Divider()
                        }
                    }
                }
                Text("Launch peak is an estimate: market size × today's topic multiplier for a quality-100 launch, before fit, hype, and the adoption ramp.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Lifetime revenue across every released product of this type.
    private func revenue(in typeID: String) -> Int {
        engine.state.products.reduce(0) { total, product in
            guard product.typeID == typeID, case .released(let info) = product.stage else { return total }
            return total + info.totalRevenue
        }
    }
}

private struct ProductTypeMarketRow: View {
    let type: ProductTypeDef
    let unlocked: Bool
    let revenue: Int
    let hottest: TopicSnapshot?
    let coldest: TopicSnapshot?

    private var peakLow: Double { type.marketSize * (coldest?.multiplier ?? 1) }
    private var peakHigh: Double { type.marketSize * (hottest?.multiplier ?? 1) }

    private var peakRangeLabel: String {
        let low = MarketFormat.units(peakLow)
        let high = MarketFormat.units(peakHigh)
        return low == high ? "\(high) units/wk" : "\(low)–\(high) units/wk"
    }

    private var peakRevenueLabel: String {
        let low = Int((peakLow * type.unitPrice).rounded()).money
        let high = Int((peakHigh * type.unitPrice).rounded()).money
        return low == high ? high : "\(low)–\(high)"
    }

    private var rangeTopicsLabel: String? {
        guard let hottest, let coldest, hottest.id != coldest.id else { return nil }
        return "\(coldest.topic.name) → \(hottest.topic.name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: type.iconSystemName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(unlocked ? Theme.accent : .secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Theme.chipBackground,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(type.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(unlocked ? .primary : .secondary)
                            .lineLimit(1)
                        if !unlocked {
                            lockTag
                        }
                    }
                    Text("\(MarketFormat.units(type.marketSize)) units/wk · \(MarketFormat.price(type.unitPrice)) each")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(revenue.money)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(revenue > 0 ? Theme.positiveCash : .secondary)
                        .contentTransition(.numericText())
                    Text("your revenue")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text("Est. peak now")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(peakRangeLabel)
                    .font(.caption)
                    .monospacedDigit()
                Text("(\(peakRevenueLabel))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.leading, 30 + Theme.Spacing.md)

            if let rangeTopicsLabel {
                Text(rangeTopicsLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 30 + Theme.Spacing.md)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var lockTag: some View {
        HStack(spacing: 2) {
            Image(systemName: "lock.fill")
            Text("LOCKED")
                .kerning(0.4)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.Spacing.xs + 2)
        .padding(.vertical, 2)
        .background(Theme.chipBackground, in: Capsule())
    }

    private var rowAccessibilityLabel: String {
        var parts = [
            "\(type.name)\(unlocked ? "" : ", locked")",
            "market size \(MarketFormat.units(type.marketSize)) units per week at \(MarketFormat.price(type.unitPrice))",
            "your revenue \(revenue.money)",
            "estimated launch peak now \(peakRangeLabel), \(peakRevenueLabel)",
        ]
        if let rangeTopicsLabel {
            parts.append("from \(rangeTopicsLabel.replacingOccurrences(of: "→", with: "to"))")
        }
        return parts.joined(separator: ", ")
    }
}
