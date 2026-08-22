import SwiftUI
import TycoonEngine

/// The founder's personal finances: the wallet, the weekly salary the
/// company pays out, and the recurring home costs that drain the wallet.
struct MoneyCard: View {
    let engine: GameEngine

    /// Salary stepper increment.
    private static let salaryStep = 100

    var body: some View {
        let life = engine.state.life
        let rent = homeWeeklyRent(life.home, balance: engine.balance)
        let kids = life.family.children.count

        CardView("Personal money", systemImage: "wallet.pass.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    WalletBlock(label: "Wallet", value: life.wallet.money, tint: life.wallet < 0 ? Theme.negativeCash : .primary)
                    WalletBlock(label: "Rent", value: "\(rent.money)/wk", tint: .primary)
                }
                if life.wallet < 0 {
                    Text("Your wallet is overdrawn — raise your salary or spend less.")
                        .font(.footnote)
                        .foregroundStyle(Theme.negativeCash)
                }

                Divider()

                Stepper(
                    value: salaryBinding,
                    in: 0...max(0, engine.balance.life.founderSalaryMax),
                    step: Self.salaryStep
                ) {
                    HStack {
                        Text("Salary")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                        Spacer()
                        Text("\(life.founderSalary.money)/wk")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.25), value: life.founderSalary)
                    }
                }
                .accessibilityLabel("Founder salary")
                .accessibilityValue("\(life.founderSalary.money) per week")

                Text(costsLine(rent: rent, kids: kids))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("The company pays your salary out of cash each week; rent comes out of your wallet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Reads the live salary from state and sends `.setFounderSalary` on
    /// every step.
    private var salaryBinding: Binding<Int> {
        Binding(
            get: { engine.state.life.founderSalary },
            set: { engine.send(.setFounderSalary($0)) }
        )
    }

    private func costsLine(rent: Int, kids: Int) -> String {
        var parts = ["Rent \(rent.money)/wk"]
        if kids > 0 {
            parts.append("\(kids) kid\(kids == 1 ? "" : "s") at home")
        }
        parts.append("a baby costs \(engine.balance.life.childStartCost.money) up front")
        return parts.joined(separator: " · ")
    }
}

private struct WalletBlock: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35), value: value)
        }
        .accessibilityElement(children: .combine)
    }
}
