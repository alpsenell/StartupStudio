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
            // The bank comes for the founder before it comes for the
            // company. It pays down debt and moves no cash, so it never
            // rescues a run on its own.
            events.append(contentsOf: callGuarantee(&state, balance))
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

    /// What the bank will lend this studio in total: a base line of credit,
    /// half of the last `economy.creditRevenueWeeks` of trading revenue
    /// (sales and contract payouts — banks lend against a book, not a
    /// pitch), and a premium per point of reputation. Public so the
    /// finances screen can show the same number the engine enforces.
    public static func creditLimit(_ state: GameState, _ balance: BalanceConfig) -> Int {
        let economy = balance.economy
        let window = state.day - economy.creditRevenueWeeks * GameState.daysPerWeek
        let trailingRevenue = state.ledger.entries.reduce(0) { total, entry in
            guard entry.day > window, entry.amount > 0,
                  entry.category == .sales || entry.category == .contracts
            else { return total }
            return total + entry.amount
        }
        return economy.creditLimitBase
            + Int((Double(trailingRevenue) * economy.creditLimitRevenueFactor).rounded())
            + Int((state.company.reputation * economy.creditLimitPerReputation).rounded())
    }

    /// What the bank will lend on the company's own name — a fraction of
    /// the full ceiling. The rest needs the founder's signature.
    ///
    /// The full ceiling was never the thing stopping anybody: measured
    /// over ten seeds of two years, the bots that ever ran short sat below
    /// a fortnight's burn in 7–11% of weeks, and at those moments the
    /// limit was worth 8.6 and 18.7 weeks of burn. Raising a ceiling
    /// nobody reaches is a button nobody presses; splitting the one that
    /// already exists turns credit that was free into a decision.
    public static func unsecuredCreditLimit(_ state: GameState, _ balance: BalanceConfig) -> Int {
        Int((Double(creditLimit(state, balance))
            * min(1, max(0, balance.economy.unsecuredCreditFraction))).rounded())
    }

    /// What the founder's home is worth as collateral. A studio flat
    /// secures nothing: the ladder finally means something beyond a mood
    /// bonus.
    public static func guaranteeCapacity(_ state: GameState, _ balance: BalanceConfig) -> Int {
        Int((Double(balance.life.home(state.life.home).upgradeCost)
            * balance.economy.guaranteeHomeFactor).rounded())
    }

    /// Borrows from the bank on the company's name alone, up to
    /// `unsecuredCreditLimit − outstanding`. Interest on the outstanding
    /// balance posts weekly. Ignored for non-positive amounts and once the
    /// limit is reached.
    static func takeLoan(
        amount: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let headroom = unsecuredCreditLimit(state, balance) - state.loanBalance
        guard amount > 0, headroom > 0 else { return [] }

        let borrowed = min(amount, headroom)
        state.loanBalance += borrowed
        post(amount: borrowed, category: .other, label: "Loan drawdown", to: &state)
        return [.loanTaken(amount: borrowed, day: state.day)]
    }

    /// Borrows against the founder's house.
    ///
    /// Draws the unsecured headroom first — nobody stakes their home for
    /// money the bank would have lent anyway — and secures only the
    /// remainder, capped by what the home is worth and by the bank's full
    /// ceiling. While any of it is outstanding the company's debt is the
    /// founder's problem: see `callGuarantee`.
    static func takeSecuredLoan(
        amount: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard amount > 0 else { return [] }
        let unsecuredHeadroom = max(0, unsecuredCreditLimit(state, balance) - state.loanBalance)
        let securedHeadroom = max(0, min(
            creditLimit(state, balance) - state.loanBalance - unsecuredHeadroom,
            guaranteeCapacity(state, balance) - state.economy.guaranteedLoanAmount
        ))
        let borrowed = min(amount, unsecuredHeadroom + securedHeadroom)
        guard borrowed > 0 else { return [] }

        state.loanBalance += borrowed
        state.economy.guaranteedLoanAmount += max(0, borrowed - unsecuredHeadroom)
        post(amount: borrowed, category: .other, label: "Loan drawdown", to: &state)
        return [.loanTaken(amount: borrowed, day: state.day)]
    }

    /// The bank calling the founder's guarantee in.
    ///
    /// Runs once the company has been in debt for `guaranteeCallDays` with
    /// guaranteed borrowing outstanding. The wallet pays what it can; if
    /// it cannot, the house goes — one tier down, through the same
    /// `.homeDowngraded` path an eviction uses, with its value written off
    /// what is owed.
    ///
    /// None of it reaches company cash. The company's bankruptcy clock
    /// keeps running underneath, so this is the founder losing their
    /// savings and their house *and* very possibly the company anyway,
    /// which is what a personal guarantee is. Making the seizure a cash
    /// injection would have made signing one a way to *raise money*.
    static func callGuarantee(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let economy = balance.economy
        guard state.economy.guaranteedLoanAmount > 0,
              state.company.daysInDebt > economy.guaranteeCallDays
        else { return [] }

        // Seized money goes to the *bank*, not into the company's account:
        // it pays the debt down and moves no cash. Crediting company cash
        // as well — which this did — paid the company twice for the same
        // seizure, and turned the founder's house into a fundraising round
        // with a mood penalty attached.
        var events: [GameEvent] = []
        if state.life.wallet > 0 {
            let paid = min(state.life.wallet, state.economy.guaranteedLoanAmount)
            state.life.wallet -= paid
            state.economy.guaranteedLoanAmount -= paid
            state.loanBalance = max(0, state.loanBalance - paid)
            events.append(.guaranteeCalled(amount: paid, tookHome: false, day: state.day))
        }
        guard state.economy.guaranteedLoanAmount > 0,
              let cheaper = state.life.home.previous
        else { return events }

        let released = min(
            state.economy.guaranteedLoanAmount,
            Int((Double(balance.life.home(state.life.home).upgradeCost)
                * economy.guaranteeHomeFactor).rounded())
        )
        state.life.home = cheaper
        state.economy.guaranteedLoanAmount -= released
        state.loanBalance = max(0, state.loanBalance - released)
        state.life.meters.apply(mood: -balance.life.breakupMoodPenalty)
        events.append(.guaranteeCalled(amount: released, tookHome: true, day: state.day))
        events.append(.homeDowngraded(tier: cheaper, day: state.day))
        return events
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
        // Clear the guaranteed slice first: a founder paying down debt
        // wants their house out of it before the bank's unsecured half.
        state.economy.guaranteedLoanAmount = max(0, state.economy.guaranteedLoanAmount - repaid)
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
