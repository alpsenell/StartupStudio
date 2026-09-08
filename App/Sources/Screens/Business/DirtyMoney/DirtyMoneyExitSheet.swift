import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W1. The three ways out, priced, with what each
/// one costs afterwards written under it.
///
/// None of them is free and none of them is clean: pay them off and the
/// payment is itself laundering; turn witness and the heat never goes
/// away; sell up and the run ends with their name on the building.
struct DirtyMoneyExitSheet: View {
    let engine: GameEngine
    let backer: DirtyMoneyBacker

    @Environment(\.dismiss) private var dismiss
    @State private var confirming: DirtyMoneyExit?

    private var money: DirtyMoneyState { engine.state.dirtyMoney }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    PixelPanel {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            PixelText(
                                text: "Three doors", scale: 2, color: Theme.pixelAccent
                            )
                            Text("You have had \(money.cheque.money) of \(backer.displayName)'s money and put \(money.laundered.money) through them. There is no door back to the morning before that.")
                                .font(.footnote)
                                .foregroundStyle(Theme.pixelInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    CardView("The ways out", systemImage: "door.left.hand.open") {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(DirtyMoneyExit.allCases, id: \.rawValue) { exit in
                                DirtyMoneyExitRow(
                                    exit: exit,
                                    detail: detail(exit),
                                    refusal: refusal(exit)
                                ) {
                                    confirming = exit
                                }
                            }
                        }
                    }

                    CardView("On the record", systemImage: "folder.fill.badge.person.crop") {
                        VStack(alignment: .leading, spacing: 4) {
                            DirtyMoneyFigureRow(
                                label: "Through them",
                                value: money.laundered.money,
                                tint: Theme.warning
                            )
                            DirtyMoneyFigureRow(
                                label: "Payments still open on the record",
                                value: "\(openLaundering)"
                            )
                            DirtyMoneyFigureRow(
                                label: "Notoriety",
                                value: "\(Int(engine.state.crime.notoriety.rounded()))",
                                tint: engine.state.crime.notoriety > 50
                                    ? Theme.negativeCash : .primary
                            )
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("The way out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Not yet") { dismiss() }
                }
            }
        }
        .confirmationDialog(
            confirming.map(confirmTitle) ?? "",
            isPresented: dialogPresented,
            titleVisibility: .visible,
            presenting: confirming
        ) { exit in
            Button(exit.displayName, role: exit == .soldUp ? .destructive : nil) {
                Haptics.tap()
                engine.send(action(exit))
                dismiss()
            }
            Button("Not yet", role: .cancel) {}
        } message: { exit in
            Text(confirmBody(exit))
        }
    }

    private var openLaundering: Int {
        engine.state.crime.record.filter { $0.offence == .launderMoney && $0.isOpen }.count
    }

    private func action(_ exit: DirtyMoneyExit) -> GameAction {
        switch exit {
        case .paidOff: .payOffBacker
        case .turnedWitness: .turnWitnessOnBacker
        case .soldUp: .sellUpToBacker
        }
    }

    private func refusal(_ exit: DirtyMoneyExit) -> String? {
        switch exit {
        case .paidOff:
            engine.state.dirtyMoneyPayOffRefusal(balance: engine.balance)?.sentence
        case .turnedWitness:
            engine.state.dirtyMoneyWitnessRefusal()?.sentence
        case .soldUp:
            engine.state.dirtyMoneySellUpRefusal()?.sentence
        }
    }

    private func detail(_ exit: DirtyMoneyExit) -> String {
        switch exit {
        case .paidOff:
            let price = engine.state.dirtyMoneyPayOffPrice(balance: engine.balance)
            return "\(price.money) · the strings stop, and the payment is one more line on your record"
        case .turnedWitness:
            return "Free · a case in front of a judge, and their heat never cools again"
        case .soldUp:
            let price = engine.state.dirtyMoneySellUpPrice(balance: engine.balance)
            let share = Int(
                (Double(price) * engine.balance.dirtyMoney.sellUpFounderFraction).rounded()
            )
            return "\(price.money), \(share.money) of it yours · the run ends here"
        }
    }

    private func confirmTitle(_ exit: DirtyMoneyExit) -> String {
        switch exit {
        case .paidOff: "Pay them off?"
        case .turnedWitness: "Give a statement?"
        case .soldUp: "Sell them the company?"
        }
    }

    private func confirmBody(_ exit: DirtyMoneyExit) -> String {
        switch exit {
        case .paidOff:
            "The cheque back, with a multiple on it and a surcharge for how annoyed they are. It also goes on your record, because it is money through them."
        case .turnedWitness:
            "You walk in and tell them everything. The case is listed today rather than in some week a roll chooses, and the heat has a floor under it for the rest of the run."
        case .soldUp:
            "They have wanted this since the first phone call. It ends the run and it is in the biography for good."
        }
    }

    private var dialogPresented: Binding<Bool> {
        Binding(
            get: { confirming != nil },
            set: { presented in if !presented { confirming = nil } }
        )
    }
}

/// One door, with its price — or why it is shut.
struct DirtyMoneyExitRow: View {
    let exit: DirtyMoneyExit
    let detail: String
    let refusal: String?
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(refusal == nil ? Theme.accent : Color.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(exit.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(refusal == nil ? .primary : .secondary)
                    Text(refusal ?? detail)
                        .font(.caption)
                        .foregroundStyle(refusal == nil ? Color.secondary : Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .disabled(refusal != nil)
        .accessibilityLabel("\(exit.displayName). \(refusal ?? detail)")
    }

    private var symbol: String {
        switch exit {
        case .paidOff: "banknote.fill"
        case .turnedWitness: "building.columns.fill"
        case .soldUp: "signature"
        }
    }
}
