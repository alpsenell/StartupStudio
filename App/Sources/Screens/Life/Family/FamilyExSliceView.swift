import SwiftUI
import TycoonEngine

// MARK: K7 (partner and diary)

/// Iteration 15 — K7. The ex on the cap table, on the marriage card.
///
/// The slice and what it is worth today, *Buy them out* with its price and
/// where the money comes from, the alternative printed under it, and the
/// ex in the address book — or, on a settlement signed before this round,
/// "They changed their number".
struct FamilyExSliceView: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    @State private var showingContact = false

    var body: some View {
        let state = engine.state
        if let settlement = state.familyDrama.settlement {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                slice(settlement, state: state)
                contactRow(settlement, state: state)
            }
            .sheet(isPresented: $showingContact) {
                if let id = settlement.exContactID {
                    ContactSheet(engine: engine, contactID: id)
                }
            }
        }
    }

    // MARK: The slice

    @ViewBuilder
    private func slice(_ settlement: FamilySettlement, state: GameState) -> some View {
        let first = firstName(settlement.exName)
        if settlement.equityGiven > 0 {
            if let day = settlement.boughtOutDay {
                Text("You bought back \(first)'s \(points(settlement.equityGiven)) of the company on day \(day).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let value = state.exSliceValue(balance: engine.balance) ?? 0
                let price = state.exBuyOutPrice(balance: engine.balance) ?? 0
                let blocker = state.exBuyOutBlocker(balance: engine.balance)
                let fromWallet = min(max(0, state.life.wallet), price)
                Text("\(first) holds \(points(settlement.equityGiven)) of the company: \(value.money) at today's valuation.")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.negativeCash)
                    .fixedSize(horizontal: false, vertical: true)
                Button { buyOut(price: price) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Buy them out · \(price.money)")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(blocker == nil ? Theme.accent : .secondary)
                        Text(sourceLine(price: price, fromWallet: fromWallet))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let blocker {
                            Text(blocker)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.warning)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.pressableRow)
                .disabled(blocker != nil)
                Text("Or let it ride: their share of every exit, and a price that grows with the company.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourceLine(price: Int, fromWallet: Int) -> String {
        let multiple = engine.balance.partner.buyOutMultiple
        let over = "×\(String(format: "%g", multiple)) today's value"
        let fromCompany = price - fromWallet
        if fromCompany <= 0 { return "\(over) · all from your wallet" }
        if fromWallet <= 0 { return "\(over) · all from company cash" }
        return "\(over) · \(fromWallet.money) from your wallet, \(fromCompany.money) from company cash"
    }

    private func buyOut(price: Int) {
        Haptics.commit()
        shell.toasts.send(
            .buyOutEx, to: engine,
            ack: "Signed. It is yours again.",
            rejected: engine.state.exBuyOutBlocker(balance: engine.balance) ?? "Not today.",
            icon: "signature"
        )
    }

    // MARK: The ex

    @ViewBuilder
    private func contactRow(_ settlement: FamilySettlement, state: GameState) -> some View {
        if let contact = state.exContact {
            Button {
                showingContact = true
                Haptics.tap()
            } label: {
                Label(
                    "\(firstName(contact.name)) is in your address book · rapport \(Int(contact.rapport.rounded()))",
                    systemImage: "person.crop.circle"
                )
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.pressable)
        } else {
            Label("They changed their number", systemImage: "phone.down.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Formatting

    private func points(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))%" : String(format: "%.1f%%", value)
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

// MARK: end K7

// MARK: K7 (partner and diary)

extension FamilyConfession {
    /// The answer's line, and for "Pack a bag" the slice the settlement
    /// that follows would hand over, at today's valuation — the same
    /// numbers `FamilyDramaSystem.divorce` will use.
    func detail(state: GameState, balance: BalanceConfig) -> String {
        guard self == .leave else { return detail }
        let points = state.familyProjectedExEquity(balance: balance)
        guard points > 0 else { return detail + " · the company stays yours" }
        let value = Int((points / 100 * Double(state.companyValuation(balance: balance))).rounded())
        let shown = points == points.rounded() ? "\(Int(points))" : String(format: "%.1f", points)
        return detail + " · they take \(shown)% of the company (\(value.money) today)"
    }
}

// MARK: end K7
