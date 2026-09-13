import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: T2 (the build)

/// Iteration 17 — T2 (player P1, systems J4). The ship confirmation, as a
/// sheet: what the build is and what the press will read, the price named
/// at launch, and every way to ship it — plain, or as the replacement of a
/// live product of its kind — each with what it costs printed on it.
///
/// The tier rows are the price sheet's (`LifecyclePriceSheet`) at the
/// forecast's score, with the live-ops caption (`LiveOps.priceCaption`).
/// Choosing is free; a launch off standard starts K2's 28-day clock. The
/// plain ship with a v2's parent still live prints what running both costs
/// the parent (J4).
///
/// Replaces the product page's and the Products list's ship dialogs; every
/// answer they had is here. The war room's own dialog is T7's and still
/// ships at standard.
struct ShipSheet: View {
    let engine: GameEngine
    let productID: UUID
    /// The product page's pool readout ("Design 90% …"); the list passes
    /// nothing and the sheet says the short version.
    var preview: String? = nil

    @State private var tier: PriceTier = .standard
    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// presented content before the environment is installed.
    private var shell: GameShell { injectedShell ?? .shared }

    private var state: GameState { engine.state }
    private var product: Product? { state.product(id: productID) }
    private var type: ProductTypeDef? { product.flatMap { engine.content.productType($0.typeID) } }
    private var forecast: ShipForecast? {
        state.shipForecast(productID: productID, balance: engine.balance, content: engine.content)
    }
    /// The forecast's quality, the number the reviews are graded from.
    private var score: Int { Int((forecast?.quality ?? 0).rounded()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let product, case .development = product.stage {
                        header(product)
                        tiers
                        answers(product)
                    } else {
                        Text("It is not a build any more.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Ship it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep working") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - The launch

    private func header(_ product: Product) -> some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Launch")
                PixelText(text: product.name, scale: 3, color: Theme.pixelInk, shadow: true)
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text("\(score)")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.scoreTint(score))
                    Text("forecast · the reviews are graded from this")
                        .font(.footnote)
                        .foregroundStyle(Theme.pixelInk.opacity(0.85))
                }
                Divider().overlay(Theme.pixelInk.opacity(0.3))
                Text(preview ?? "Development stops for good and the press reviews whatever is finished.")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.pixelInk.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - The price

    private var tiers: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Price at launch")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            ForEach(PriceTier.allCases, id: \.self) { option in
                Button { tier = option } label: {
                    ShipSheetRow(
                        title: "\(option.displayName) · \(price(option))",
                        cost: LiveOps.launchTierLine(option, balance: engine.balance, day: state.day),
                        caption: LiveOps.priceCaption(for: option, balance: engine.balance, reviewScore: score),
                        tint: option == .standard ? .secondary : Theme.warning,
                        selected: tier == option
                    )
                }
                .buttonStyle(.pressableRow)
                .accessibilityLabel("Launch at \(option.displayName)")
                .accessibilityAddTraits(tier == option ? .isSelected : [])
            }
        }
    }

    // MARK: - The answers

    @ViewBuilder
    private func answers(_ product: Product) -> some View {
        let parents = state.lifecycleReplaceableParents(for: productID)
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button { ship(replacing: nil) } label: {
                ShipSheetRow(
                    title: "Ship it at \(tier.displayName)",
                    cost: runBothLine(hasParents: !parents.isEmpty)
                        ?? "One more product on the market, and one more hosting bill.",
                    caption: nil,
                    tint: Theme.accent,
                    selected: false
                )
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel("Ship \(product.name) at \(tier.displayName)")
            // K2's third answer: ship it as the v2 of a live product of
            // the same kind, with what carries printed on it.
            ForEach(parents) { parent in
                Button { ship(replacing: parent.id) } label: {
                    ShipSheetRow(
                        title: "Replace \(parent.name) at \(tier.displayName)",
                        cost: replaceCost(parent),
                        caption: "One hosting bill, and this launch skips the saturation \(parent.name) would add.",
                        tint: Theme.positiveCash,
                        selected: false
                    )
                }
                .buttonStyle(.pressableRow)
                .accessibilityLabel("Ship \(product.name) as the replacement of \(parent.name)")
            }
        }
    }

    /// K2's carry, said once: what comes across, and that the parent goes.
    private func replaceCost(_ parent: Product) -> String {
        guard let carry = state.lifecycleCarry(from: parent.id, balance: engine.balance) else {
            return "\(parent.name) retires today"
        }
        let comes = carry.isSubscription
            ? "\(carry.subscribers) of \(carry.parentSubscribers) subscribers carry"
            : "its buzz carries"
        return "\(comes) · \(parent.name) retires today"
    }

    /// J4: what the plain ship costs a live parent, when there is one.
    private func runBothLine(hasParents: Bool) -> String? {
        if let quote = state.buildRunBothQuote(buildID: productID, balance: engine.balance) {
            return BuildCopy.runBoth(quote)
        }
        return hasParents ? "Running both keeps both books and both bills." : nil
    }

    private func ship(replacing parentID: UUID?) {
        let action: GameAction = parentID.map {
            .shipReplacingAt(productID: productID, parentID: $0, tier: tier)
        } ?? .shipAt(productID: productID, tier: tier)
        let rejected = parentID.flatMap {
            state.lifecycleReplaceRefusal(
                productID: productID, parentID: $0, balance: engine.balance, content: engine.content
            )?.sentence
        } ?? "It is not ready to ship yet."
        shell.toasts.send(action, to: engine, rejected: rejected)
        // MARK: T7 (press and stakes) — merge glue: the exclusive picked on the
        // page rides the priced ship; the engine refuses a grant on anything
        // that did not ship today.
        ExclusivePick.shared.grantAfterShip(productID: productID, engine: engine)
        // MARK: end T7
        dismiss()
    }

    /// "$14" or "$9 / mo": the type's list price times the tier's factor.
    private func price(_ tier: PriceTier) -> String {
        guard let type else { return tier.displayName }
        let amount = Int((type.unitPrice * engine.balance.economy.priceTier(tier).priceFactor).rounded())
        return type.revenueModel == .subscription ? "\(amount.money) / mo" : amount.money
    }
}

/// One row of the ship sheet: the price sheet's row, with a tick for the
/// tier that is chosen.
private struct ShipSheetRow: View {
    let title: String
    let cost: String
    let caption: String?
    let tint: Color
    let selected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
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
            Spacer(minLength: 0)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Theme.accent : .clear, lineWidth: 2)
        )
    }
}

// MARK: end T2
