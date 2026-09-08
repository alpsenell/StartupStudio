import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W1. The room where the cheque is offered.
///
/// Pixel paper, because this is a meeting rather than a screen: the figure
/// large, the strings written out in full above the button, and the two
/// answers at the bottom with nothing hidden behind either of them. Rule 7
/// in its strongest form — the founder cannot say afterwards that nobody
/// told them.
struct DirtyMoneyOfferSheet: View {
    let engine: GameEngine
    let backer: DirtyMoneyBacker

    @Environment(\.dismiss) private var dismiss

    private var money: DirtyMoneyState { engine.state.dirtyMoney }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    PixelPanel {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: backer.symbol)
                                    .font(.title2)
                                    .foregroundStyle(Theme.pixelInk)
                                VStack(alignment: .leading, spacing: 2) {
                                    PixelText(text: backer.displayName, scale: 2, color: Theme.pixelAccent)
                                    Text(backer.blurb)
                                        .font(.footnote)
                                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Divider().background(Theme.pixelInk.opacity(0.3))
                            Text(DirtyMoney.offerLine(backer, cheque: money.offeredCheque))
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(Theme.pixelInk)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(backer.pitch)
                                .font(.footnote)
                                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    CardView("What they will want", systemImage: "list.bullet.indent") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            ForEach(strings, id: \.self) { line in
                                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.warning)
                                        .frame(width: 18)
                                    Text(line)
                                        .font(.footnote)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Divider()
                            Text("Everything you pay them goes on your own record as laundering. An auditor can find it, and a court can hear it.")
                                .font(.caption)
                                .foregroundStyle(Theme.negativeCash)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    CardView("The account today", systemImage: "banknote.fill") {
                        VStack(alignment: .leading, spacing: 4) {
                            DirtyMoneyFigureRow(
                                label: "Cash", value: engine.state.company.cash.money,
                                tint: engine.state.company.cash < 0
                                    ? Theme.negativeCash : .primary
                            )
                            DirtyMoneyFigureRow(
                                label: "Their cheque",
                                value: money.offeredCheque.money,
                                tint: Theme.positiveCash
                            )
                            DirtyMoneyFigureRow(
                                label: "Equity given up", value: "None",
                                tint: Theme.positiveCash
                            )
                        }
                    }

                    VStack(spacing: Theme.Spacing.sm) {
                        Button {
                            Haptics.tap()
                            engine.send(.takeDirtyMoney)
                            dismiss()
                        } label: {
                            answerLabel(
                                "Take the money",
                                detail: "\(money.offeredCheque.money) in the account this week"
                            )
                        }
                        .buttonStyle(PixelButtonStyle(fill: Theme.negativeCash))
                        .disabled(refusal != nil)
                        .opacity(refusal == nil ? 1 : 0.4)

                        if let refusal {
                            Text(refusal.sentence)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.warning)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            Haptics.tap()
                            engine.send(.declineDirtyMoney)
                            dismiss()
                        } label: {
                            answerLabel(
                                "Say no, politely",
                                detail: "They keep the number, and say so twice"
                            )
                        }
                        .buttonStyle(PixelButtonStyle(fill: Theme.pixelAccent))
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("An approach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    /// The two answers read like every other decision in the game: the
    /// act on top, what it does underneath.
    private func answerLabel(_ title: String, detail: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(.headline, design: .rounded))
            Text(detail)
                .font(.caption)
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var refusal: DirtyMoneyRefusal? {
        engine.state.dirtyMoneyTakeRefusal(balance: engine.balance)
    }

    /// The strings, written out one to a line, with the figures the engine
    /// will actually use.
    private var strings: [String] {
        let config = engine.balance.dirtyMoney
        let cheque = money.offeredCheque
        switch backer {
        case .familyOffice:
            let consultant = DirtyMoney.passengerCost(.consultant, cheque: cheque, balance: config)
            return [
                "A consultant on your payroll from month two, at about \(consultant.money) a week. He will not be in.",
                "By month six they name the market your next product ships into.",
                "No board seat. They say this like it is a kindness, and it is.",
            ]
        case .theFront:
            let invoice = DirtyMoney.demandAmount(.invoice, cheque: cheque, balance: config)
            let nephew = DirtyMoney.passengerCost(.nephew, cheque: cheque, balance: config)
            return [
                "An invoice every quarter, about \(invoice.money), from a consultancy that does not exist.",
                "Once you have paid one, a nephew, at about \(nephew.money) a week.",
                "Nothing in writing has your name on it twice.",
            ]
        case .theShark:
            let vig = DirtyMoney.vig(cheque: cheque, balance: config)
            return [
                "\(vig.money) a week, out of the company account, for as long as it is his money.",
                "A missed week is a visit, and a visit costs three weeks.",
                "There is no paperwork at all, which is the problem.",
            ]
        }
    }
}
