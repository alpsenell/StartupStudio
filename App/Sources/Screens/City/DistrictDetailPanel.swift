import SwiftUI
import TycoonEngine

/// Bottom overlay on the city map: the selected district's terms and the
/// move/buy/sell actions. The engine enforces every rule; this panel only
/// explains, predicts, and disables with reasons (the `LifeHelpers`
/// contract).
struct DistrictDetailPanel: View {
    let engine: GameEngine
    let district: DistrictID

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var pendingMove: PropertyMove?

    var body: some View {
        let state = engine.state
        let def = engine.balance.city.district(district)
        let isCurrent = district == state.city.district

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(district.displayName)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                if isCurrent {
                    Text(state.city.ownership.isOwned ? "Your office · owned" : "Your office · renting")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                }
                Spacer(minLength: 0)
            }

            Text(perkSummary(def))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !rivalsHere.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(rivalsHere) { rival in
                        HStack(spacing: 3) {
                            PixelPortrait(seed: rival.appearanceSeed, size: 20)
                            Text(rival.name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Theme.chipBackground, in: Capsule())
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                StatPill(systemImage: "key.fill", value: "\(weeklyRent.money)/wk")
                StatPill(systemImage: "signature", value: "Buy \(buyPrice.money)")
            }

            actionRow(isCurrent: isCurrent)
        }
        .padding(Theme.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .animation(.spring(duration: 0.3), value: district)
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingMove != nil },
                set: { if !$0 { pendingMove = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingMove
        ) { move in
            Button(confirmButtonTitle(move)) { commit(move) }
            Button("Cancel", role: .cancel) { pendingMove = nil }
        } message: { move in
            Text(confirmationMessage(move))
        }
    }

    // MARK: - Confirmations

    private var confirmationTitle: String {
        switch pendingMove {
        case .sell: "Sell the office?"
        case .buy: "Buy this office?"
        case .relocate: "Move to \(district.displayName)?"
        case nil: ""
        }
    }

    private func confirmButtonTitle(_ move: PropertyMove) -> String {
        switch move {
        case .sell: "Sell for \(engine.state.city.propertyValue.money)"
        case .buy: "Buy for \(buyPrice.money)"
        case .relocate: "Move for \(relocationCost.money)"
        }
    }

    private func confirmationMessage(_ move: PropertyMove) -> String {
        switch move {
        case .sell:
            "You go back to paying \(weeklyRent.money) a week in rent. Buying back later is at the market price."
        case .buy:
            "The weekly rent stops, and the building becomes an asset you can sell later."
        case .relocate:
            engine.state.city.ownership.isOwned
                ? "Your current office is sold for \(engine.state.city.propertyValue.money) first, and the team packs up."
                : "The team packs up and rent becomes \(weeklyRent.money) a week."
        }
    }

    private func commit(_ move: PropertyMove) {
        pendingMove = nil
        switch move {
        case .sell:
            shell.toasts.send(.sellOffice, to: engine, rejected: "The sale fell through.")
        case .buy:
            shell.toasts.send(.buyOffice, to: engine, rejected: "The purchase fell through.")
        case .relocate:
            shell.toasts.send(
                .relocateOffice(district: district),
                to: engine,
                rejected: "The move fell through."
            )
        }
    }

    // MARK: - Numbers

    /// The current tier's rent in this district (before the Ops discount —
    /// the panel compares districts, the ledger applies discounts).
    private var weeklyRent: Int {
        let def = engine.balance.city.district(district)
        let base = engine.balance.office(engine.state.company.officeTier).weeklyRent
        return Int((Double(base) * def.rentMultiplier).rounded())
    }

    private var buyPrice: Int {
        engine.state.officePurchasePrice(in: district, balance: engine.balance)
    }

    private var relocationCost: Int {
        let config = engine.balance.city
        return Int((Double(config.relocationCostBase)
            * config.district(district).priceMultiplier).rounded())
    }

    private var rivalsHere: [Rival] {
        engine.state.rivals.rivals.filter { $0.homeDistrict == district }
    }

    private func perkSummary(_ def: BalanceConfig.CityBalance.DistrictDef) -> String {
        var parts: [String] = []
        if def.candidateSkillBonus > 0 {
            parts.append("stronger candidates")
        } else if def.candidateSkillBonus < 0 {
            parts.append("weaker candidates")
        }
        if def.extraContractOffers > 0 {
            parts.append("+\(def.extraContractOffers) contract offer\(def.extraContractOffers > 1 ? "s" : "")/wk")
        }
        if def.weeklyReputationDrift > 0 {
            parts.append("prestige address")
        } else if def.weeklyReputationDrift < 0 {
            parts.append("sleepy address")
        }
        if def.moraleBonus > 0 {
            parts.append("team loves it")
        } else if def.moraleBonus < 0 {
            parts.append("long commutes")
        }
        return parts.isEmpty ? "A quiet, no-frills part of town." : parts.joined(separator: " · ").capitalizedFirst
    }

    // MARK: - Actions

    /// The property move awaiting confirmation. All three spend real money
    /// and none of them can be undone, so none of them fires on one tap.
    private enum PropertyMove: Identifiable {
        case sell, buy, relocate

        var id: String {
            switch self {
            case .sell: "sell"
            case .buy: "buy"
            case .relocate: "relocate"
            }
        }
    }

    @ViewBuilder
    private func actionRow(isCurrent: Bool) -> some View {
        let state = engine.state
        if isCurrent {
            if state.city.ownership.isOwned {
                gatedButton(
                    "Sell for \(state.city.propertyValue.money)",
                    systemImage: "signature",
                    blocker: nil
                ) {
                    pendingMove = .sell
                }
            } else {
                gatedButton(
                    "Buy this office for \(buyPrice.money)",
                    systemImage: "signature",
                    blocker: state.company.cash >= buyPrice
                        ? nil
                        : "Need \((buyPrice - state.company.cash).money) more"
                ) {
                    pendingMove = .buy
                }
            }
        } else {
            let saleProceeds = state.city.ownership.isOwned ? state.city.propertyValue : 0
            gatedButton(
                "Move here for \(relocationCost.money)",
                systemImage: "shippingbox.and.arrow.backward.fill",
                blocker: state.company.cash + saleProceeds >= relocationCost
                    ? nil
                    : "Need \((relocationCost - state.company.cash - saleProceeds).money) more"
            ) {
                pendingMove = .relocate
            }
            if state.city.ownership.isOwned {
                Text("Moving sells your current office for \(state.city.propertyValue.money) first.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func gatedButton(
        _ title: String,
        systemImage: String,
        blocker: String?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(blocker != nil)

            if let blocker {
                Text(blocker)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
