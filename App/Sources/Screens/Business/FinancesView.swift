import Charts
import SwiftUI
import TycoonEngine

/// The Finances segment of the Business tab: a weekly cashflow chart over
/// the recent ledger, then the most recent postings.
struct FinancesView: View {
    let engine: GameEngine

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // MARK: Iteration 11, wave two — W1 (dirty money)
            // First on the page, above the run rate and the bank, because
            // an approach has a week on it and a string has a date on it —
            // and because the two things a founder reads underneath it
            // (the runway, the credit limit) are the reasons they are
            // reading this at all. Draws nothing whatsoever until
            // somebody has called.
            DirtyMoneyCard(engine: engine)
            // MARK: end of Iteration 11, wave two — W1
            RunRateCard(engine: engine)
            LoanCard(engine: engine)
            // MARK: T7 (press and stakes)
            // The asset line: what the company owns of other companies.
            // Nothing until it owns some.
            if !engine.state.rivals.stakes.isEmpty {
                RivalStakeAssetCard(engine: engine)
            }
            // MARK: end T7
            CashflowCard(state: engine.state)
            CategoryBreakdownCard(state: engine.state)
            RecentLedgerCard(state: engine.state)
        }
        // MARK: Iteration 11, wave two — W1 (the identity gate)
        // The one flag W1's engine gate reads: an offer may only be made
        // once the player has looked at their own finances in this run. A
        // pacing bot opens no screens, so it never sets this and is never
        // offered anything.
        .onAppear {
            engine.send(.noticeFinancesOpened)
            // The lane's screenshot pass starts here rather than on the
            // card, because until it has run there is no card to hang a
            // task on.
            DirtyMoneyDebug.startIfAsked(engine: engine)
        }
        // MARK: end of Iteration 11, wave two — W1
    }
}

// MARK: - Bank loan

/// Borrow against the company's reputation and repay in chunks; interest
/// posts weekly on whatever stays outstanding.
private struct LoanCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    /// The chunk each borrow/repay tap moves.
    private static let step = 1_000

    @State private var amount = 5_000
    @State private var confirmingGuarantee = false

    private var loans: BalanceConfig.LoanBalance { engine.balance.loans }

    /// Asked of the engine. This used to be computed here out of
    /// `balance.loans` while `FinanceSystem` lent against `balance.economy`
    /// — a studio with revenue could borrow more than this screen said,
    /// and the reputation term shown was double the one honoured.
    private var creditLimit: Int {
        engine.state.creditLimit(balance: engine.balance)
    }

    /// What the bank will lend on the company's name alone; the rest needs
    /// the founder's signature and their house behind it.
    private var unsecuredHeadroom: Int {
        engine.state.unsecuredHeadroom(balance: engine.balance)
    }

    private var securedHeadroom: Int {
        engine.state.securedHeadroom(balance: engine.balance)
    }

    private var guaranteedDebt: Int { engine.state.guaranteedDebt }

    private var outstanding: Int { engine.state.loanBalance }

    private var weeklyInterest: Int {
        Int((Double(outstanding) * loans.weeklyInterestRate).rounded())
    }

    /// What the bank will still lend: the stepper can never ask for more
    /// (it used to run to $100,000 regardless of the limit).
    private var headroom: Int {
        max(0, creditLimit - outstanding)
    }

    /// A repayment is capped by both the debt and the cash on hand.
    private var repayable: Int {
        max(0, min(amount, min(outstanding, engine.state.company.cash)))
    }

    /// Keeps the stepper's value inside the current headroom as the limit
    /// moves with reputation and the outstanding balance.
    private var clampedAmount: Binding<Int> {
        Binding(
            get: { min(amount, max(Self.step, headroom)) },
            set: { amount = $0 }
        )
    }

    private var headroomCaption: String {
        if headroom < Self.step {
            return "You are at the limit — repay some before borrowing again."
        }
        return "You can borrow up to \(headroom.money) more."
    }

    /// The stepper is bounded by the unsecured line, because the two
    /// buttons draw against different things: `Borrow` takes what the bank
    /// will give the company, `Borrow against your home` goes past it.
    private var unsecuredAmount: Int { min(amount, unsecuredHeadroom) }

    var body: some View {
        CardView("Bank loan", systemImage: "banknote.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Outstanding")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(outstanding.money)
                            .font(Theme.Typography.number(.headline))
                            .foregroundStyle(outstanding > 0 ? Theme.negativeCash : .primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Credit limit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(creditLimit.money)
                            .font(Theme.Typography.number(.headline))
                    }
                }

                if outstanding > 0 {
                    Text("Interest \(weeklyInterest.money)/wk until repaid.")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.warning)
                } else {
                    Text("Revenue and reputation raise the limit. Interest posts weekly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CreditSplitBar(
                    unsecuredHeadroom: unsecuredHeadroom,
                    securedHeadroom: securedHeadroom,
                    guaranteedDebt: guaranteedDebt
                )

                HStack(spacing: Theme.Spacing.md) {
                    Stepper(value: clampedAmount, in: Self.step...max(Self.step, headroom), step: Self.step) {
                        Text(amount.money)
                            .font(Theme.Typography.number(.subheadline))
                    }
                    .accessibilityLabel("Loan amount")
                    .accessibilityValue(amount.money)
                }

                if securedHeadroom >= Self.step {
                    Button {
                        confirmingGuarantee = true
                    } label: {
                        Label(
                            "Borrow against your home",
                            systemImage: "house.fill"
                        )
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.warning)
                    .accessibilityHint("Puts your home up as collateral")
                }

                HStack(spacing: Theme.Spacing.md) {
                    Button("Borrow") {
                        shell.toasts.send(
                            .takeLoan(amount: unsecuredAmount),
                            to: engine,
                            rejected: "The bank turned that down."
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(unsecuredHeadroom < Self.step)
                    .accessibilityLabel("Borrow \(unsecuredAmount.money)")

                    Button("Repay \(repayable.money)") {
                        shell.toasts.send(
                            .repayLoan(amount: repayable),
                            to: engine,
                            rejected: "There is nothing to repay right now."
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(repayable <= 0)
                    .accessibilityLabel("Repay \(repayable.money)")

                    Spacer(minLength: 0)
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))

                Text(headroomCaption)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            "Put your home up?",
            isPresented: $confirmingGuarantee,
            titleVisibility: .visible
        ) {
            Button("Sign the guarantee", role: .destructive) {
                shell.toasts.send(
                    .takeSecuredLoan(amount: max(amount, unsecuredHeadroom + Self.step)),
                    to: engine,
                    ack: "Signed. The bank has your house on file.",
                    rejected: "The bank turned that down.",
                    icon: "house.fill",
                    tint: Theme.warning
                )
            }
            Button("Not that desperate", role: .cancel) {}
        } message: {
            Text(
                "The bank will lend past \(unsecuredHeadroom.money) only against your home. "
                    + "If the company stays in the red, they take your savings and then the house."
            )
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
                        .emptySectionText()
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
                    .emptySectionText()
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
                .font(Theme.Typography.number(.subheadline))
                .foregroundStyle(entry.amount >= 0 ? Theme.positiveCash : Theme.negativeCash)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.label), day \(entry.day), \(entry.amount.money)")
    }

    /// One shared mapping for every category, so a bucket looks the same
    /// in the ledger, the weekly report and the breakdown card.
    private var icon: String { entry.category.systemImage }
}

// MARK: - Run rate

/// Where the money is actually coming from right now: recurring revenue
/// from subscription products, one-time sales, and what the live products
/// cost to keep running.
private struct RunRateCard: View {
    /// The same number the HUD shows under the date, in the one place the
    /// money is itemised.
    private var runwayValue: String {
        let cash = engine.state.company.cash
        let burn = engine.weeklyBurn
        if cash < 0 { return "in the red" }
        guard burn > 0 else { return "no burn" }
        return "\(cash / burn) wk"
    }

    private var runwayTint: Color {
        let cash = engine.state.company.cash
        let burn = engine.weeklyBurn
        if cash < 0 { return Theme.negativeCash }
        guard burn > 0 else { return Theme.positiveCash }
        return cash / burn <= 4 ? Theme.warning : .primary
    }

    let engine: GameEngine

    /// Weekly subscription revenue across every live subscription product.
    private var monthlyRecurring: Int {
        engine.state.products.reduce(0) { total, product in
            guard case .released(let info) = product.stage, info.isSubscription, !info.offMarket else {
                return total
            }
            let price = engine.content.productType(product.typeID)?.unitPrice ?? 0
            return total + Int((Double(info.subscribers) * price).rounded())
        }
    }

    /// The most recent full week of one-time sales revenue.
    private var lastWeekSales: Int {
        let week = max(0, engine.state.day / 7 - 1)
        return engine.state.ledger.entries
            .filter { $0.day / 7 == week && $0.category == .sales && $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
    }

    /// Hosting and other running costs posted last week.
    private var lastWeekRunningCosts: Int {
        let week = max(0, engine.state.day / 7 - 1)
        return engine.state.ledger.entries
            .filter { $0.day / 7 == week && $0.amount < 0 && isRunningCost($0.category) }
            .reduce(0) { $0 - $1.amount }
    }

    /// Operating-style buckets. Written as a positive list rather than a
    /// `default`, so a category appended by another workstream shows up as
    /// a warning here instead of being silently lumped in with payroll.
    /// `.hosting` is the truest running cost in the game — every product
    /// left on the market bills for servers every week, whether it sells
    /// anything or not.
    private func isRunningCost(_ category: LedgerEntry.Category) -> Bool {
        switch category {
        case .operating, .rent, .hosting: true
        case .payroll, .sales, .contracts, .marketing, .research, .other: false
        @unknown default: true
        }
    }

    var body: some View {
        CardView("Run rate", systemImage: "speedometer") {
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                if monthlyRecurring > 0 {
                    FinanceStat(
                        label: "Recurring",
                        value: "\(monthlyRecurring.money)/wk",
                        tint: Theme.positiveCash
                    )
                }
                FinanceStat(
                    label: "Sales last week",
                    value: lastWeekSales.money,
                    tint: lastWeekSales > 0 ? Theme.positiveCash : .secondary
                )
                FinanceStat(
                    label: "Running costs",
                    value: lastWeekRunningCosts.money,
                    tint: Theme.negativeCash
                )
                FinanceStat(
                    label: "Runway",
                    value: runwayValue,
                    tint: runwayTint
                )
            }
            MoneySheetLink(engine: engine)
        }
    }
}

/// Last week's postings summed per bucket, largest first — the same
/// breakdown the weekly report shows, kept on the finances screen for the
/// weeks the player skipped.
private struct CategoryBreakdownCard: View {
    let state: GameState

    private var week: Int { max(0, state.day / 7 - 1) }

    private var totals: [(category: LedgerEntry.Category, income: Int, expense: Int)] {
        var income: [LedgerEntry.Category: Int] = [:]
        var expense: [LedgerEntry.Category: Int] = [:]
        for entry in state.ledger.entries where entry.day / 7 == week {
            if entry.amount >= 0 {
                income[entry.category, default: 0] += entry.amount
            } else {
                expense[entry.category, default: 0] -= entry.amount
            }
        }
        let categories = Set(income.keys).union(expense.keys)
        return categories
            .map { (category: $0, income: income[$0] ?? 0, expense: expense[$0] ?? 0) }
            .sorted {
                let left = max($0.income, $0.expense)
                let right = max($1.income, $1.expense)
                return left == right
                    ? $0.category.rawValue < $1.category.rawValue
                    : left > right
            }
    }

    var body: some View {
        CardView("Last week by category", systemImage: "chart.pie.fill") {
            if totals.isEmpty {
                Text("Nothing posted last week.")
                    .emptySectionText()
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(totals, id: \.category) { row in
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: row.category.systemImage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(row.category.displayName)
                                .font(.subheadline)
                            Spacer(minLength: Theme.Spacing.sm)
                            if row.income > 0 {
                                Text("+\(row.income.money)")
                                    .font(Theme.Typography.number(.footnote))
                                    .foregroundStyle(Theme.positiveCash)
                            }
                            if row.expense > 0 {
                                Text("-\(row.expense.money)")
                                    .font(Theme.Typography.number(.footnote))
                                    .foregroundStyle(Theme.negativeCash)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

private struct FinanceStat: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(.title3))
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The credit split

/// Where the bank's ceiling divides: what it will lend the company, what
/// it will lend only against the founder's house, and how much of the
/// house is already spoken for.
///
/// A bar rather than three numbers, because the point is the *proportion*
/// — that the second half of the credit line is a different kind of money,
/// and that signing for it moves the risk onto the person rather than the
/// company.
private struct CreditSplitBar: View {
    let unsecuredHeadroom: Int
    let securedHeadroom: Int
    let guaranteedDebt: Int

    private var total: Int { max(1, unsecuredHeadroom + securedHeadroom) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if unsecuredHeadroom + securedHeadroom > 0 {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: width(unsecuredHeadroom, in: geometry.size.width))
                        Capsule()
                            .fill(Theme.warning.opacity(0.65))
                    }
                }
                .frame(height: 6)

                HStack(spacing: Theme.Spacing.md) {
                    LegendDot(color: Theme.accent, label: "\(unsecuredHeadroom.money) on the company")
                    if securedHeadroom > 0 {
                        LegendDot(
                            color: Theme.warning.opacity(0.65),
                            label: "\(securedHeadroom.money) on your house"
                        )
                    }
                }
            }

            if guaranteedDebt > 0 {
                Label(
                    "\(guaranteedDebt.money) of this debt is personally guaranteed.",
                    systemImage: "house.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.warning)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func width(_ value: Int, in available: CGFloat) -> CGFloat {
        max(0, available * CGFloat(value) / CGFloat(total))
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
