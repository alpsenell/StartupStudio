import TycoonContent

/// Daily finance system: posts weekly expenses and tracks debt/bankruptcy.
/// Also hosts the upgradeOffice action handler used by `Reducer.apply`.
enum FinanceSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []

        // Weekly postings every 7 ticks.
        if state.day % GameState.daysPerWeek == 0 {
            post(
                amount: -balance.weeklyOperatingCost,
                category: .operating,
                label: "Operating costs",
                to: &state
            )

            let rent = balance.office(state.company.officeTier).weeklyRent
            if rent > 0 {
                post(amount: -rent, category: .rent, label: "Office rent", to: &state)
            }

            let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
            if payroll > 0 {
                post(amount: -payroll, category: .payroll, label: "Payroll", to: &state)
            }
        }

        // Debt / bankruptcy check, daily, after postings.
        if state.company.cash < 0 {
            if state.company.daysInDebt == 0 {
                events.append(.bankruptcyWarning(day: state.day))
            }
            state.company.daysInDebt += 1
            if state.company.daysInDebt > balance.bankruptcyGraceDays {
                state.gameOver = GameOverInfo(
                    day: state.day,
                    reason: "Bankruptcy: cash stayed negative beyond the \(balance.bankruptcyGraceDays)-day grace period."
                )
                events.append(.gameOver(day: state.day))
            }
        } else {
            state.company.daysInDebt = 0
        }

        return events
    }

    // MARK: - Actions

    /// Moves the company one office tier up the ladder. Ignored at the top
    /// of the ladder and while the next tier's upgrade cost is unaffordable.
    /// The cost posts to the ledger, the reached tier's raw value is recorded
    /// in `milestonesReached`, and the new tier's headcount cap and rent take
    /// effect implicitly via the balance lookups keyed on `officeTier`.
    static func upgradeOffice(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let next = state.company.officeTier.next,
              state.company.cash >= balance.office(next).upgradeCost
        else { return [] }

        post(
            amount: -balance.office(next).upgradeCost,
            category: .other,
            label: "Office upgrade: \(next.displayName)",
            to: &state
        )
        state.company.officeTier = next
        state.milestonesReached.insert(next.rawValue)
        return [.officeUpgraded(tier: next, day: state.day)]
    }

    private static func post(
        amount: Int,
        category: LedgerEntry.Category,
        label: String,
        to state: inout GameState
    ) {
        state.company.cash += amount
        state.ledger.post(
            LedgerEntry(day: state.day, amount: amount, category: category, label: label)
        )
    }
}
