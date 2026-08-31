import PixelKit
import SwiftUI
import TycoonEngine

/// The shop: the catalog of possessions from `balance.instantLife.items`,
/// with the shopping vignette playing up top. Buying sends `.buyItem`;
/// the engine gates wallet and duplicates, this sheet mirrors the gates
/// to disable rows with reasons.
struct ShoppingSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    /// Catalog rows cheapest first, ties by id for a stable order.
    private var catalog: [(id: String, item: BalanceConfig.InstantLifeBalance.ItemDef)] {
        engine.balance.instantLife.items
            .map { (id: $0.key, item: $0.value) }
            .sorted { lhs, rhs in
                if lhs.item.cost != rhs.item.cost { return lhs.item.cost < rhs.item.cost }
                return lhs.id < rhs.id
            }
    }

    var body: some View {
        let life = engine.state.life

        NavigationStack {
            List {
                Section {
                    PixelSceneView(
                        placements: ActivitySceneComposer.compose(
                            style: .shopping,
                            appearance: CharacterAppearance(seed: founderAppearanceSeed),
                            isFounder: true
                        ),
                        sceneSize: ActivitySceneComposer.sceneSize(),
                        accessibilityLabel: "Shopping scene"
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(catalog, id: \.id) { entry in
                        ShopRow(
                            item: entry.item,
                            owned: life.possessions.contains(entry.id),
                            affordable: life.wallet >= entry.item.cost
                        ) {
                            shell.toasts.send(
                                .buyItem(itemID: entry.id),
                                to: engine,
                                rejected: "You can't afford that yet."
                            )
                        }
                    }
                } header: {
                    Text("Wallet: \(life.wallet.money)")
                        .monospacedDigit()
                }
            }
            .navigationTitle("Shopping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var founderAppearanceSeed: UInt64 {
        engine.state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7
    }
}

private struct ShopRow: View {
    let item: BalanceConfig.InstantLifeBalance.ItemDef
    let owned: Bool
    let affordable: Bool
    let buy: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(perkSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.sm)
            if owned {
                Label("Owned", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.positiveCash)
                    .labelStyle(.titleAndIcon)
            } else {
                Button(item.cost.money, action: buy)
                    .font(Theme.Typography.number(.subheadline))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.accent)
                    .disabled(!affordable)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var perkSummary: String {
        var parts = ["+\(Int(item.moodPop)) mood now", "keeps your days brighter"]
        if item.prestige > 0 { parts.append("a bit of status") }
        return parts.joined(separator: " · ")
    }
}
