import Charts
import SwiftUI
import TycoonEngine

/// The Finances segment of the Business tab: a weekly cashflow chart over
/// the recent ledger, then the most recent postings.
struct FinancesView: View {
    let engine: GameEngine

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            LoanCard(engine: engine)
            CashflowCard(state: engine.state)
            RecentLedgerCard(state: engine.state)
        }
    }
}

// MARK: - Bank loan

/// Borrow against the company's reputation and repay in chunks; interest
/// posts weekly on whatever stays outstanding.
private struct LoanCard: View {
    let engine: GameEngine

    /// The chunk each borrow/repay tap moves.
    private static let step = 1_000

    @State private var amount = 5_000

    private var loans: BalanceConfig.LoanBalance { engine.balance.loans }

    private var creditLimit: Int {
        loans.baseLimit + Int((engine.state.company.reputation * loans.perReputation).rounded())
    }

    private var outstanding: Int { engine.state.loanBalance }

    private var weeklyInterest: Int {
        Int((Double(outstanding) * loans.weeklyInterestRate).rounded())
    }

    var body: some View {
        CardView("Bank loan", systemImage: "banknote.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Outstanding")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(outstanding.money)
                            .font(.system(.headline, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(outstanding > 0 ? Theme.negativeCash : .primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Credit limit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(creditLimit.money)
                            .font(.system(.headline, design: .rounded))
                            .monospacedDigit()
                    }
                }

                if outstanding > 0 {
                    Text("Interest \(weeklyInterest.money)/wk until repaid.")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                } else {
                    Text("Reputation raises the limit. Interest posts weekly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: Theme.Spacing.md) {
                    Stepper(value: $amount, in: Self.step...100_000, step: Self.step) {
                        Text(amount.money)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityLabel("Loan amount")
                    .accessibilityValue(amount.money)
                }

                HStack(spacing: Theme.Spacing.md) {
                    Button("Borrow") {
                        engine.send(.takeLoan(amount: amount))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(outstanding >= creditLimit)
                    .accessibilityLabel("Borrow \(amount.money)")

                    Button("Repay") {
                        engine.send(.repayLoan(amount: amount))
                    }
                    .buttonStyle(.bordered)
                    .disabled(outstanding == 0 || engine.state.company.cash <= 0)
                    .accessibilityLabel("Repay \(amount.money)")

                    Spacer(minLength: 0)
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))
            }
        }
    }
}

// MARK: - Weekly cashflow chart

/// Income and expenses aggregated per game week: income bars up (green),
/// expense bars down (red), covering the last 12 weeks.
private struct CashflowCard: View {
    let state: GameState

    /// Weeks shown in the chart.
    private static let weekWindow = 12

    private struct WeekCashflow: Identifiable {
        /// 1-based absolute game week.
        let week: Int
        let income: Int
        /// Zero or negative, so it plots below the axis.
        let expense: Int

        var id: Int { week }
    }

    /// One entry per week in the window, zero-filled so quiet weeks keep
    /// their slot and the bars stay evenly spaced.
    private var weeks: [WeekCashflow] {
        let currentWeek = state.day / 7
        let firstWeek = max(0, currentWeek - (Self.weekWindow - 1))

        var income: [Int: Int] = [:]
        var expense: [Int: Int] = [:]
        for entry in state.ledger.entries {
            let week = entry.day / 7
            guard week >= firstWeek else { continue }
            if entry.amount >= 0 {
                income[week, default: 0] += entry.amount
            } else {
                expense[week, default: 0] += entry.amount
            }
        }

        return (firstWeek...currentWeek).map { week in
            WeekCashflow(
                week: week + 1,
                income: income[week] ?? 0,
                expense: expense[week] ?? 0
            )
        }
    }

    private var hasEntries: Bool {
        !state.ledger.entries.isEmpty
    }

    var body: some View {
        CardView("Weekly cashflow", systemImage: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if hasEntries {
                    chart
                    legend
                } else {
                    Text("No transactions yet — the books are still blank.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, Theme.Spacing.sm)
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(weeks) { week in
                BarMark(
                    x: .value("Week", Double(week.week)),
                    y: .value("Income", week.income)
                )
                .foregroundStyle(Theme.positiveCash)
                .cornerRadius(3)

                BarMark(
                    x: .value("Week", Double(week.week)),
                    y: .value("Expenses", week.expense)
                )
                .foregroundStyle(Theme.negativeCash)
                .cornerRadius(3)
            }

            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartXAxisLabel("Game week", alignment: .trailing)
        .chartXScale(domain: xDomain)
        .frame(height: 180)
        .accessibilityLabel("Weekly cashflow chart, last \(weeks.count) weeks")
    }

    /// Half-unit padding keeps the first and last bars from clipping.
    private var xDomain: ClosedRange<Double> {
        let values = weeks.map(\.week)
        let lower = Double(values.min() ?? 1) - 0.5
        let upper = Double(values.max() ?? 1) + 0.5
        return lower...upper
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.lg) {
            legendDot(color: Theme.positiveCash, label: "Income")
            legendDot(color: Theme.negativeCash, label: "Expenses")
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Recent ledger

private struct RecentLedgerCard: View {
    let state: GameState

    /// Rows shown in the list.
    private static let maxRows = 30

    /// Newest first.
    private var recent: [LedgerEntry] {
        Array(state.ledger.entries.suffix(Self.maxRows).reversed())
    }

    var body: some View {
        CardView("Recent transactions", systemImage: "list.bullet") {
            if recent.isEmpty {
                Text("Nothing posted yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { index, entry in
                        LedgerRow(entry: entry)
                        if index < recent.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct LedgerRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.label)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("Day \(entry.day)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Text(entry.amount.money)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.amount >= 0 ? Theme.positiveCash : Theme.negativeCash)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.label), day \(entry.day), \(entry.amount.money)")
    }

    private var icon: String {
        switch entry.category {
        case .operating: "gearshape.fill"
        case .rent: "house.fill"
        case .payroll: "person.2.fill"
        case .sales: "cart.fill"
        case .contracts: "briefcase.fill"
        case .marketing: "megaphone.fill"
        case .research: "flask.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}
