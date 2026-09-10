import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: K2 (product lifecycle)

/// Iteration 15 — K2 (C6). The price change, priced: the old segmented
/// picker became this sheet. A price list on pixel paper says what a rise
/// and a cut do to *this* product, then one row per other tier carries its
/// own cost — the subscribers a rise loses, the sale a cut buys or the day
/// the next one is due — and the tap on the row is the confirmation. Every
/// number is the engine's (`GameState.lifecyclePriceChange`).
///
/// Shared by the product page's live-ops card and the storefront's buy
/// button, so the price has one sheet wherever it is changed from.
struct LifecyclePriceSheet: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// presented content before the environment is installed.
    private var shell: GameShell { injectedShell ?? .shared }

    private var state: GameState { engine.state }
    private var product: Product? { state.product(id: productID) }
    private var type: ProductTypeDef? { product.flatMap { engine.content.productType($0.typeID) } }
    private var topicName: String {
        product.flatMap { engine.content.topic($0.topicID)?.name } ?? "the topic"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let product, let info = product.releaseInfo {
                        priceList(product, info)
                        choices(product, info)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Change the price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep it") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - The price list

    private func priceList(_ product: Product, _ info: ReleaseInfo) -> some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Price list")
                PixelText(text: product.name, scale: 3, color: Theme.pixelInk, shadow: true)
                Text("Now \(price(info.priceTier, info)) · \(info.priceTier.displayName)")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(Theme.pixelInk)
                Divider().overlay(Theme.pixelInk.opacity(0.3))
                ForEach(tradeLines(product, info), id: \.text) { line in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Image(systemName: line.icon)
                            .font(.caption)
                            .foregroundStyle(line.tint)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(line.text)
                            .font(.footnote)
                            .foregroundStyle(Theme.pixelInk.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct TradeLine {
        let icon: String
        let text: String
        let tint: Color
    }

    private func tradeLines(_ product: Product, _ info: ReleaseInfo) -> [TradeLine] {
        let config = engine.balance.lifecycle
        let churn = Int((config.riseChurn * 100).rounded())
        let dent = Int(((1 - config.riseUnitsFactor) * 100).rounded())
        let bump = Int(((config.saleBump - 1) * 100).rounded())
        var lines = [
            TradeLine(
                icon: "arrow.up.right",
                text: info.isSubscription
                    ? "A rise costs \(churn)% of the book the day it lands. People notice a bill."
                    : "A rise costs \(dent)% of sales for \(config.riseWeeks) weeks. People wait for the sale.",
                tint: Theme.warning
            ),
            TradeLine(
                icon: "tag.fill",
                text: "A cut is a sale once every \(config.saleIntervalDays / 7) weeks: +\(bump)% for a week, +\(Int(config.saleStanding.rounded())) \(topicName) standing, and the paper prints it.",
                tint: Theme.pixelAccent
            ),
            TradeLine(
                icon: "calendar",
                text: "Changes are \(config.changeCooldownDays) days apart. Premium at launch is a bet you cannot quietly unwind.",
                tint: Theme.pixelAccent
            ),
        ]
        if state.rivals.challenges.contains(where: { $0.topicID == product.topicID }) {
            lines.append(TradeLine(
                icon: "flag.fill",
                text: "A rival is contesting \(topicName): a cut to budget counts as the budget defence.",
                tint: Theme.warning
            ))
        }
        return lines
    }

    // MARK: - The choices

    @ViewBuilder
    private func choices(_ product: Product, _ info: ReleaseInfo) -> some View {
        let other = PriceTier.allCases.first { $0 != info.priceTier } ?? .standard
        let cooldown = state.lifecycleRepriceRefusal(productID: productID, tier: other, balance: engine.balance)
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if case .cooldown(let until)? = cooldown {
                Text("Customers are still reading the last change. The next can come on day \(until), \(until - state.day) day\(until - state.day == 1 ? "" : "s") from now.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(PriceTier.allCases.filter { $0 != info.priceTier }, id: \.self) { tier in
                if let change = state.lifecyclePriceChange(productID: productID, to: tier, balance: engine.balance) {
                    Button { reprice(product, to: tier) } label: {
                        row(
                            title: "\(change.isRise ? "Raise" : "Cut") to \(tier.displayName) · \(price(tier, info))",
                            cost: LiveOps.lifecycleConsequence(change, topicName: topicName),
                            caption: LiveOps.priceCaption(
                                for: tier, balance: engine.balance, reviewScore: info.averageReviewScore
                            ),
                            tint: change.isRise ? Theme.warning : Theme.positiveCash
                        )
                    }
                    .buttonStyle(.pressableRow)
                    .disabled(cooldown != nil)
                    .opacity(cooldown != nil ? 0.5 : 1)
                    .accessibilityLabel("\(change.isRise ? "Raise" : "Cut") \(product.name) to \(tier.displayName)")
                    .accessibilityHint(LiveOps.lifecycleConsequence(change, topicName: topicName))
                }
            }
            Button { dismiss() } label: {
                row(
                    title: "Keep it at \(info.priceTier.displayName)",
                    cost: "Nothing changes. " + LiveOps.priceCaption(
                        for: info.priceTier, balance: engine.balance, reviewScore: info.averageReviewScore
                    ),
                    caption: nil,
                    tint: .primary
                )
            }
            .buttonStyle(.pressableRow)
        }
    }

    private func row(title: String, cost: String, caption: String?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text(cost)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func reprice(_ product: Product, to tier: PriceTier) {
        let refusal = state.lifecycleRepriceRefusal(productID: productID, tier: tier, balance: engine.balance)
        shell.toasts.send(
            LiveOps.reprice(productID: productID, tier: tier),
            to: engine,
            rejected: refusal?.sentence ?? "The price did not change."
        )
        dismiss()
    }

    /// "$14" or "$9 / mo": the type's list price times the tier's factor,
    /// the arithmetic the economy charges.
    private func price(_ tier: PriceTier, _ info: ReleaseInfo) -> String {
        guard let type else { return tier.displayName }
        let amount = Int((type.unitPrice * engine.balance.economy.priceTier(tier).priceFactor).rounded())
        return info.isSubscription ? "\(amount.money) / mo" : amount.money
    }
}

// MARK: end K2
