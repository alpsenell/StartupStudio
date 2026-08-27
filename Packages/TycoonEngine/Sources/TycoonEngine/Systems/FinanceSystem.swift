import TycoonContent

/// Daily finance system: posts weekly expenses (operating costs, office
/// rent and amenity upkeep after the Operations discount, payroll, loan
/// interest) and tracks debt/bankruptcy. Also hosts the upgradeOffice,
/// loan, and buildAmenity action handlers used by `Reducer.apply`.
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

            let rent = state.officeWeeklyRent(balance: balance)
            if rent > 0 {
                post(amount: -rent, category: .rent, label: "Office rent", to: &state)
            }

            let upkeep = state.amenityWeeklyUpkeep(balance: balance)
            if upkeep > 0 {
                post(amount: -upkeep, category: .rent, label: "Amenities", to: &state)
            }

            let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
            if payroll > 0 {
                post(amount: -payroll, category: .payroll, label: "Payroll", to: &state)
            }

            if state.loanBalance > 0 {
                let interest = Int((Double(state.loanBalance) * balance.loans.weeklyInterestRate).rounded())
                if interest > 0 {
                    post(amount: -interest, category: .other, label: "Loan interest", to: &state)
                }
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
    /// effect implicitly via the balance lookups keyed on `officeTier`. An
    /// owned space is auto-sold first (upgrading means moving buildings),
    /// so the affordability gate counts the sale proceeds.
    static func upgradeOffice(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        let saleProceeds = state.city.ownership.isOwned ? state.city.propertyValue : 0
        guard let next = state.company.officeTier.next,
              state.company.cash + saleProceeds >= balance.office(next).upgradeCost
        else { return [] }

        var events: [GameEvent] = []
        if state.city.ownership.isOwned {
            events.append(contentsOf: CitySystem.sellOffice(state: &state))
        }

        post(
            amount: -balance.office(next).upgradeCost,
            category: .other,
            label: "Office upgrade: \(next.displayName)",
            to: &state
        )
        state.company.officeTier = next
        state.milestonesReached.insert(next.rawValue)
        events.append(.officeUpgraded(tier: next, day: state.day))
        return events
    }

    /// Borrows from the bank up to the remaining credit limit
    /// (`baseLimit + reputation × perReputation − outstanding`). Interest
    /// on the outstanding balance posts weekly. Ignored for non-positive
    /// amounts and once the limit is reached.
    static func takeLoan(
        amount: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let limit = balance.loans.baseLimit
            + Int((state.company.reputation * balance.loans.perReputation).rounded())
        let headroom = limit - state.loanBalance
        guard amount > 0, headroom > 0 else { return [] }

        let borrowed = min(amount, headroom)
        state.loanBalance += borrowed
        post(amount: borrowed, category: .other, label: "Loan drawdown", to: &state)
        return [.loanTaken(amount: borrowed, day: state.day)]
    }

    /// Buys an office amenity: the cost posts to the ledger and the amenity
    /// joins `amenities` (where it stays across office upgrades; its weekly
    /// upkeep posts with the rent). Ignored when already owned, below the
    /// amenity's minimum office tier, or unaffordable.
    static func buildAmenity(
        _ amenity: Amenity,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let def = balance.company.amenity(amenity)
        guard !state.amenities.contains(amenity),
              state.company.officeTier.rank >= def.minTier.rank,
              state.company.cash >= def.upgradeCost
        else { return [] }

        post(
            amount: -def.upgradeCost,
            category: .other,
            label: "Built: \(amenity.displayName)",
            to: &state
        )
        state.amenities.insert(amenity)
        return [.amenityBuilt(amenity: amenity, day: state.day)]
    }

    /// Repays loan principal, capped by the outstanding balance and by the
    /// cash on hand. Ignored for non-positive amounts, an empty loan, and
    /// non-positive cash.
    static func repayLoan(amount: Int, state: inout GameState) -> [GameEvent] {
        guard amount > 0, state.loanBalance > 0, state.company.cash > 0 else { return [] }

        let repaid = min(amount, state.loanBalance, state.company.cash)
        state.loanBalance -= repaid
        post(amount: -repaid, category: .other, label: "Loan repayment", to: &state)
        return [.loanRepaid(amount: repaid, day: state.day)]
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
