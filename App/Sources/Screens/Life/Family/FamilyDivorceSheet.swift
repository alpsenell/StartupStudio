import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W2. The settlement: two columns, everything
/// either of you owns in one of them.
///
/// Tap a column to arm it and tap a thing to move it, the way the incident
/// room arms a lane and the furnish sheet arms a slot; a drag does the
/// same thing for anybody who reaches for one. The running total under the
/// columns is `GameState.assetSplitValue`, which is the arithmetic the
/// engine is about to do — so the number on the sheet is the number in the
/// save.
struct FamilyDivorceSheet: View {
    let engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    /// Catalog ids (plus `"home"` and `"pet"`) in the founder's column.
    @State private var mine: Set<String> = []
    @State private var armedColumn: Column = .mine
    @State private var lawyer: CrimeLawyer = .dutySolicitor
    @State private var seeded = false
    @State private var confirming = false

    private enum Column { case mine, theirs }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if engine.state.familyDrama.settlement != nil {
                        settledCard
                    } else {
                        entitlementCard
                        columnsCard
                        lawyerCard
                        commitCard
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("The settlement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: seed)
            // A garage that filled while the sheet was open is still the
            // founder's: re-lay the table rather than showing yesterday's.
            .onChange(of: engine.state.assets.owned.count) {
                seeded = false
                seed()
            }
        }
    }

    // MARK: - Setup

    private func seed() {
        guard !seeded else { return }
        seeded = true
        // Everything starts on the founder's side, which is what everybody
        // assumes on the first morning.
        mine = Set(engine.state.assets.owned.map(\.catalogID))
        mine.insert(FamilyDivorceSheet.homeToken)
        if engine.state.assets.owned.contains(where: { !$0.petName.isEmpty }) {
            mine.insert(FamilyDivorceSheet.petToken)
        }
    }

    static let homeToken = "home"
    static let petToken = "pet"

    // MARK: - What the law thinks

    private var entitlementCard: some View {
        let config = engine.balance.familyDrama
        let marriedDays = engine.state.life.family.stage == .married
            ? max(0, engine.state.day - engine.state.life.family.stageSinceDay)
            : 0
        let share = FamilyDrama.entitlement(
            lawyer: lawyer,
            theirLawyer: .highStreet,
            affairDiscovered: engine.state.interactions.affairDiscoveredDay != nil,
            marriedDays: marriedDays,
            balance: config
        )
        let equity = FamilyDrama.equityToEx(
            marriedDays: marriedDays,
            equityRemaining: engine.state.investors.equityRemaining,
            balance: config
        )
        return CardView("What you are owed", systemImage: "scalemass.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(estate == 0
                    ? "\(Int((share * 100).rounded()))% of nothing"
                    : "\(Int((share * 100).rounded()))% of \(estate.money)")
                    .font(Theme.Typography.number(.title3))
                Text(engine.state.interactions.affairDiscoveredDay != nil
                    ? "Half, and then the solicitors argue. The affair is on the record, which costs you \(Int(config.affairSharePenalty * 100)) points of it."
                    : "Half, and then the solicitors argue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if equity > 0 {
                    Text("Married \(marriedDays / 364) years: \(Int(equity.rounded()))% of the company goes with them.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.negativeCash)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var estate: Int { engine.state.assetResaleValue(balance: engine.balance) }

    /// What the roof is worth in a settlement — the ladder's own price for
    /// the tier, which is what the engine pays back for losing it.
    private var homeWorth: Int {
        engine.balance.life.home(engine.state.life.home).upgradeCost
    }

    // MARK: - The two columns

    private var columnsCard: some View {
        let split = engine.state.assetSplitValue(keeping: mine, balance: engine.balance)
        return CardView("The table", systemImage: "rectangle.split.2x1.fill") {
            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    columnHeader(.mine, title: "Yours", total: split.mine)
                    columnHeader(.theirs, title: exName, total: split.theirs)
                }
                Text(armedColumn == .mine
                    ? "Tap a thing to keep it. Tap the other column first to give something away."
                    : "Tap a thing to let it go.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(rows, id: \.id) { row in
                        FamilyThingRow(
                            row: row,
                            isMine: mine.contains(row.id),
                            tap: { move(row.id) }
                        )
                    }
                }
            }
        }
    }

    private func columnHeader(_ column: Column, title: String, total: Int) -> some View {
        let armed = armedColumn == column
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(1)
            Text(total.money)
                .font(Theme.Typography.number(.footnote))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(armed ? Theme.accent.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(armed ? Theme.accent : Theme.chipBackground, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            armedColumn = column
            Haptics.tap()
        }
        // Dropping a thing on a column works too, for anybody who reaches
        // for it.
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            set(id, toMine: column == .mine)
            return true
        }
        .accessibilityAddTraits(armed ? [.isSelected] : [])
        .accessibilityLabel("\(title), \(total.money)")
    }

    private var exName: String {
        engine.state.life.family.partnerName ?? "Theirs"
    }

    private var rows: [FamilyThing] {
        var out: [FamilyThing] = [FamilyThing(
            id: FamilyDivorceSheet.homeToken,
            name: engine.state.life.home.displayName,
            detail: engine.state.life.family.children.isEmpty
                ? "\(homeWorth.money) · losing it is one rung down the ladder"
                : "\(homeWorth.money) · the roof follows the children, whatever this column says",
            icon: "house.fill"
        )]
        for owned in engine.state.assets.owned {
            let def = engine.balance.assets.asset(owned.catalogID)
            let value = engine.state.assetResaleValue(of: owned, balance: engine.balance)
            if !owned.petName.isEmpty {
                out.append(FamilyThing(
                    id: FamilyDivorceSheet.petToken,
                    name: owned.petName,
                    detail: value > 0
                        ? "\(def?.name ?? "The animal") · \(value.money)"
                        : "\(def?.name ?? "The animal") · worth nothing, which is not the point",
                    icon: "pawprint.fill"
                ))
            } else {
                out.append(FamilyThing(
                    id: owned.catalogID,
                    name: def?.name ?? owned.catalogID,
                    detail: owned.needsRepair ? "\(value.money) · broken" : value.money,
                    icon: icon(for: def?.assetKind)
                ))
            }
        }
        if let crypto = engine.state.assets.crypto, crypto.value > 0 {
            out.append(FamilyThing(
                id: "crypto",
                name: "The wallet",
                detail: "\(crypto.value.money) · split down the middle whatever you do",
                icon: "bitcoinsign.circle.fill"
            ))
        }
        return out
    }

    private func icon(for kind: AssetKind?) -> String {
        switch kind {
        case .car: "car.fill"
        case .property: "building.2.fill"
        case .pet: "pawprint.fill"
        default: "shippingbox.fill"
        }
    }

    private func move(_ id: String) {
        guard id != "crypto" else { return }
        set(id, toMine: armedColumn == .mine)
    }

    private func set(_ id: String, toMine: Bool) {
        guard id != "crypto" else { return }
        if toMine { mine.insert(id) } else { mine.remove(id) }
        Haptics.tap()
    }

    // MARK: - Who is representing you

    private var lawyerCard: some View {
        CardView("Representation", systemImage: "briefcase.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(CrimeLawyer.ladder, id: \.self) { tier in
                    let fee = FamilyDrama.lawyerFee(tier, balance: engine.balance.familyDrama)
                    Button { lawyer = tier; Haptics.tap() } label: {
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Image(systemName: lawyer == tier
                                ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(lawyer == tier ? Theme.accent : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.displayName)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                Text("\(fee == 0 ? "Free" : fee.money) · \(tier.blurb)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.pressableRow)
                    .disabled(engine.state.life.wallet < fee)
                }
            }
        }
    }

    // MARK: - Sign it

    private var commitCard: some View {
        let split = engine.state.assetSplitValue(keeping: mine, balance: engine.balance)
        let marriedDays = engine.state.life.family.stage == .married
            ? max(0, engine.state.day - engine.state.life.family.stageSinceDay)
            : 0
        let share = FamilyDrama.entitlement(
            lawyer: lawyer, theirLawyer: .highStreet,
            affairDiscovered: engine.state.interactions.affairDiscoveredDay != nil,
            marriedDays: marriedDays, balance: engine.balance.familyDrama
        )
        let owed = Int((Double(estate) * share).rounded())
        let cheque = owed - split.mine
        return CardView("Sign it", systemImage: "signature") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(cheque >= 0
                    ? "You keep less than you are owed, so about \(cheque.money) comes back to you."
                    : "You keep more than you are owed, so about \((-cheque).money) goes the other way.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(confirming ? "Sign it. It is done." : "Divide the estate",
                       systemImage: confirming ? "checkmark.seal.fill" : "rectangle.split.2x1.fill") {
                    if confirming {
                        engine.send(.divorceSettlement(keep: mine.sorted(), lawyer: lawyer))
                        confirming = false
                        Haptics.commit()
                    } else {
                        confirming = true
                        Haptics.tap()
                    }
                }
                .buttonStyle(.pressable)
                .font(.footnote.weight(.semibold))
                Text("There is no version of this you can undo.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Afterwards

    private var settledCard: some View {
        let settlement = engine.state.familyDrama.settlement
        return CardView("Settled", systemImage: "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Day \(settlement?.day ?? 0). \(settlement?.exName ?? "They") took what they took.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let lost = settlement?.lostAssetIDs, !lost.isEmpty {
                    Text(lost.compactMap { engine.balance.assets.asset($0)?.name }
                        .joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - One thing on the table

/// A line in the settlement: the roof, a car, the dog, the wallet.
struct FamilyThing: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let icon: String
}

private struct FamilyThingRow: View {
    let row: FamilyThing
    let isMine: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: row.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isMine ? Theme.accent : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(row.detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text(isMine ? "yours" : "theirs")
                    .font(.caption2.weight(.bold))
                    .kerning(0.6)
                    .foregroundStyle(isMine ? Theme.accent : Theme.warning)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isMine ? Theme.accent.opacity(0.08) : Theme.chipBackground)
            )
        }
        .buttonStyle(.pressableRow)
        .draggable(row.id)
        .accessibilityLabel("\(row.name), \(row.detail)")
        .accessibilityValue(isMine ? "yours" : "theirs")
        .accessibilityHint("Tap to move it to the armed column")
    }
}
