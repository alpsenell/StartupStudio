import SwiftUI
import TycoonEngine

/// The founder's personal finances: the wallet, the weekly salary the
/// company pays out, and the recurring home costs that drain the wallet.
struct MoneyCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    /// Salary stepper increment.
    private static let salaryStep = 100

    var body: some View {
        let state = engine.state
        let life = state.life
        let rent = homeWeeklyRent(life.home, balance: engine.balance)
        let kids = life.family.children.count

        CardView("Personal money", systemImage: "wallet.pass.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    WalletBlock(label: "Wallet", value: life.wallet.money, tint: life.wallet < 0 ? Theme.negativeCash : .primary)
                    WalletBlock(label: "Rent", value: "\(rent.money)/wk", tint: .primary)
                }
                if life.wallet < 0 {
                    WalletDebtWarning(
                        wallet: life.wallet,
                        weeklyShortfall: weeklyShortfall(rent: rent, kids: kids),
                        canRaiseSalary: life.founderSalary < engine.balance.life.founderSalaryMax
                    ) {
                        raiseSalaryToCover(rent: rent, kids: kids)
                    }
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
                            .font(Theme.Typography.number(.subheadline))
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                            .animation(Theme.Motion.valueChange, value: life.founderSalary)
                    }
                }
                .accessibilityLabel("Founder salary")
                .accessibilityValue("\(life.founderSalary.money) per week")

                Text(costsLine(rent: rent, kids: kids))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                // What the team makes of the number. The stepper used to
                // have exactly one downside — company cash — which made it
                // the free pipe behind every personal purchase in the game.
                if let median = state.teamMedianSalary {
                    PayBandNote(
                        median: median,
                        ceiling: state.fairFounderSalaryCeiling(balance: engine.balance) ?? 0,
                        moralePenalty: state.founderPayMoralePenalty(balance: engine.balance),
                        hasBoard: state.investors.boardExpectation != nil
                    )
                }

                // MARK: Iteration 11 — N3 (assets, vices and the doctor)
                // The other half of the founder's money: what they own.
                // A line rather than a card, because the card itself is
                // three sections further down the tab — this is the
                // cross-reference, not a second front door.
                AssetsMoneyNote(engine: engine)
                // MARK: end of Iteration 11 — N3

                MoneySheetLink(engine: engine)
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
            set: { salary in
                shell.toasts.send(
                    .setFounderSalary(salary),
                    to: engine,
                    ack: "Your salary is now \(salary.money)/wk",
                    icon: "wallet.pass.fill"
                )
            }
        )
    }

    /// What the wallet loses each week after the salary lands: home rent
    /// plus the per-child cost, minus the salary. Positive means the
    /// wallet is draining.
    private func weeklyShortfall(rent: Int, kids: Int) -> Int {
        let costs = rent + kids * engine.balance.life.childWeeklyCost
        return costs - engine.state.life.founderSalary
    }

    /// Raises the founder's salary to cover the weekly costs exactly,
    /// clamped to the balance's maximum.
    private func raiseSalaryToCover(rent: Int, kids: Int) {
        let costs = rent + kids * engine.balance.life.childWeeklyCost
        let target = min(costs, engine.balance.life.founderSalaryMax)
        guard target > engine.state.life.founderSalary else { return }
        shell.toasts.send(
            .setFounderSalary(target),
            to: engine,
            ack: "Salary raised to \(target.money)/wk to cover the bills",
            icon: "wallet.pass.fill"
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
                .font(Theme.Typography.number(.title3))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .combine)
    }
}


/// The overdrawn-wallet warning: how deep the hole is, how fast it is
/// getting deeper, and the one-tap way out.
private struct WalletDebtWarning: View {
    let wallet: Int
    let weeklyShortfall: Int
    let canRaiseSalary: Bool
    let raiseSalary: () -> Void

    /// Weeks until the wallet is another thousand down — a concrete
    /// countdown rather than a vague warning.
    private var weeksPerThousand: Int? {
        guard weeklyShortfall > 0 else { return nil }
        return max(1, 1000 / weeklyShortfall)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.bold))
                Text("Overdrawn by \(abs(wallet).money)")
                    .font(Theme.Typography.number(.subheadline))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.negativeCash)

            Text(detail)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if canRaiseSalary, weeklyShortfall > 0 {
                Button {
                    Haptics.commit()
                    raiseSalary()
                } label: {
                    Label("Pay yourself enough to cover it", systemImage: "arrow.up.circle.fill")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.negativeCash.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private var detail: String {
        guard let weeks = weeksPerThousand else {
            return "Your salary covers the bills — the hole stops getting deeper, but it does not fill itself."
        }
        return "Rent and home costs run \(weeklyShortfall.money) a week past your salary: another \(1000.money) down every \(weeks) week\(weeks == 1 ? "" : "s")."
    }
}


// MARK: - The pay band

/// Where the founder's salary sits against the team's, and what it costs
/// when it sits too far above.
///
/// A multiple of the median rather than a fixed number, so the line moves
/// with the roster: the same $2,000 a week is unremarkable in a studio of
/// leads and conspicuous in a room of juniors.
private struct PayBandNote: View {
    let median: Int
    let ceiling: Int
    let moralePenalty: Double
    let hasBoard: Bool

    var body: some View {
        if moralePenalty > 0 {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: "eye.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("−\(moralePenalty.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale))) morale across the team")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.warning)
                    Text(detail)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.warning.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityElement(children: .combine)
        } else {
            Text("Your team's median is \(median.money)/wk. Up to \(ceiling.money) raises no eyebrows.")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
    }

    private var detail: String {
        let base = "They know what you pay them — the median is \(median.money)/wk."
        return hasBoard ? base + " Your board has noticed too." : base
    }
}


// MARK: - Iteration 11 — N3 (assets, vices and the doctor)

/// One line under the salary stepper: what the founder owns, what it
/// costs them a week, and — when there is nothing yet — that there is a
/// whole other column waiting. Silent about the vices and the doctor:
/// this card is about money.
private struct AssetsMoneyNote: View {
    let engine: GameEngine

    var body: some View {
        let state = engine.state
        let worth = state.assetResaleValue(balance: engine.balance)
        let weekly = state.assetWeeklyCosts(balance: engine.balance)
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "key.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
            Text(line(worth: worth, weekly: weekly))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func line(worth: Int, weekly: Int) -> String {
        guard worth != 0 || weekly != 0 else {
            return "You own nothing but what is in your wallet. Your things are further down this tab."
        }
        if weekly > 0 {
            return "Your things are worth \(worth.money) and cost \(weekly.money)/wk to keep."
        }
        if weekly < 0 {
            return "Your things are worth \(worth.money) and bring in \(abs(weekly).money)/wk."
        }
        return "Your things are worth \(worth.money)."
    }
}
