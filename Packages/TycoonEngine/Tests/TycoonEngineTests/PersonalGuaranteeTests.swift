import Foundation
import Testing
import TycoonContent
import TycoonEngine

private func guaranteeEconomy(
    unsecuredCreditFraction: Double = 0.45,
    guaranteeHomeFactor: Double = 0.7,
    guaranteeCallDays: Int = 7,
    creditLimitBase: Int = 20_000
) -> BalanceConfig.EconomyBalance {
    var economy = TestBalance.neutralEconomy
    economy.unsecuredCreditFraction = unsecuredCreditFraction
    economy.guaranteeHomeFactor = guaranteeHomeFactor
    economy.guaranteeCallDays = guaranteeCallDays
    economy.creditLimitBase = creditLimitBase
    economy.creditLimitRevenueFactor = 0
    economy.creditLimitPerReputation = 0
    return economy
}

private func balance(
    economy: BalanceConfig.EconomyBalance = guaranteeEconomy()
) -> BalanceConfig {
    TestBalance.make(
        // A real grace period, because the call is keyed off it: the
        // founder's assets go at `grace − guaranteeCallDays`, a week
        // before the company itself does.
        bankruptcyGraceDays: 21,
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: TestBalance.quietLife,
        economy: economy
    )
}

/// A founder in a house: $40,000 of home, $28,000 of collateral at the
/// shipped 0.7 haircut.
private func housed(_ balance: BalanceConfig, home: HomeTier = .house) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: 6, balance: balance)
    TestLife.pinPeak(&state)
    state.life.home = home
    state.life.wallet = 0
    return state
}

@Suite("The personal guarantee")
struct PersonalGuaranteeTests {
    @Test("The bank lends less on the company's name than it used to")
    func unsecuredIsASliceOfTheCeiling() {
        let config = balance()
        let state = housed(config)
        #expect(state.creditLimit(balance: config) == 20_000)
        #expect(state.unsecuredCreditLimit(balance: config) == 9_000)
    }

    @Test("A plain loan stops at the unsecured line")
    func plainLoanStopsAtTheLine() {
        let config = balance()
        var state = housed(config)

        Reducer.apply(
            .takeLoan(amount: 20_000), to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.loanBalance == 9_000)
        #expect(state.guaranteedDebt == 0)
    }

    @Test("The house unlocks the rest, and only the rest is guaranteed")
    func securedLoanDrawsUnsecuredFirst() {
        let config = balance()
        var state = housed(config)

        Reducer.apply(
            .takeSecuredLoan(amount: 20_000),
            to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.loanBalance == 20_000)
        // Nobody stakes their home for money the bank would have lent
        // anyway: only the $11,000 above the unsecured line is secured.
        #expect(state.guaranteedDebt == 11_000)
    }

    @Test("A studio flat secures nothing")
    func studioFlatHasNoCollateral() {
        let config = balance()
        var state = housed(config, home: .studioFlat)
        #expect(state.guaranteeCapacity(balance: config) == 0)

        Reducer.apply(
            .takeSecuredLoan(amount: 20_000),
            to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.loanBalance == 9_000)
        #expect(state.guaranteedDebt == 0)
    }

    @Test("Repayment clears the guaranteed slice first")
    func repaymentFreesTheHouseFirst() {
        let config = balance()
        var state = housed(config)
        let content = TestContent.tiny()
        Reducer.apply(.takeSecuredLoan(amount: 20_000), to: &state, balance: config, content: content)
        state.company.cash = 50_000

        Reducer.apply(.repayLoan(amount: 11_000), to: &state, balance: config, content: content)
        #expect(state.guaranteedDebt == 0)
        #expect(state.loanBalance == 9_000)
    }

    @Test("Stay in debt and the bank takes the wallet, then the house")
    func theBankComesForTheHouse() {
        let config = balance()
        var state = housed(config)
        let content = TestContent.tiny()
        Reducer.apply(.takeSecuredLoan(amount: 20_000), to: &state, balance: config, content: content)
        state.company.cash = -1_000
        state.life.wallet = 2_000

        var events: [GameEvent] = []
        for _ in 0..<16 {
            events += Reducer.tick(&state, balance: config, content: content)
        }

        // The wallet went first...
        #expect(state.life.wallet == 0)
        // ...then the house, one tier down through the eviction path.
        #expect(state.life.home == .apartment)
        #expect(events.contains { if case .homeDowngraded = $0 { true } else { false } })
        #expect(state.guaranteedDebt < 11_000)
        // And the player is told, both times.
        #expect(events.count { if case .guaranteeCalled = $0 { true } else { false } } == 2)
    }

    @Test("A seizure pays the bank, not the company")
    func seizureIsNotAFundingRound() {
        let config = balance()
        var state = housed(config)
        let content = TestContent.tiny()
        Reducer.apply(.takeSecuredLoan(amount: 20_000), to: &state, balance: config, content: content)
        state.company.cash = -1_000
        state.life.wallet = 5_000
        let debtBefore = state.loanBalance

        // Past the call day, still inside the company's grace period.
        for _ in 0..<16 {
            Reducer.tick(&state, balance: config, content: content)
        }

        // The founder's savings went to the bank: the debt fell by what
        // was taken, and the company's cash is no better for it. Crediting
        // cash *as well* would have made signing a guarantee a way to
        // raise money out of your own house.
        let seized = 5_000 - state.life.wallet
        #expect(seized > 0)
        #expect(state.loanBalance <= debtBefore - seized)
        #expect(state.company.cash < 0)
    }

    @Test("Nothing is called from a founder who never signed")
    func noGuaranteeNoCall() {
        let config = balance()
        var state = housed(config)
        let content = TestContent.tiny()
        Reducer.apply(.takeLoan(amount: 9_000), to: &state, balance: config, content: content)
        state.company.cash = -1_000
        state.life.wallet = 5_000

        var events: [GameEvent] = []
        for _ in 0..<16 {
            events += Reducer.tick(&state, balance: config, content: content)
        }
        // The wallet still pays the week's rent — but nothing was seized,
        // and the house is not the bank's to take.
        // Two weeks of rent came out; nothing was seized.
        #expect(state.life.wallet > 3_000)
        #expect(state.life.home == .house)
        #expect(!events.contains { if case .homeDowngraded = $0 { true } else { false } })
    }

    @Test("The founder is warned on the first day of debt, and told when")
    func theWarningComesFirst() {
        let config = balance()
        var state = housed(config)
        let content = TestContent.tiny()
        Reducer.apply(.takeSecuredLoan(amount: 20_000), to: &state, balance: config, content: content)
        state.company.cash = -1_000
        state.life.wallet = 50_000

        let firstDay = Reducer.tick(&state, balance: config, content: content)
        let warning = firstDay.compactMap { event -> Int? in
            if case .guaranteeAtRisk(_, let callOnDay, _) = event { return callOnDay }
            return nil
        }.first
        // Warned on day one of debt, with the date — and the date is a
        // week before the company's own deadline, not the day after
        // tomorrow.
        #expect(warning != nil)
        #expect(warning == state.day + (21 - config.economy.guaranteeCallDays) - 1)
        // And comfortably before the company's own deadline.
        #expect((warning ?? 0) < state.day + 21)
        // Nothing has been taken yet.
        #expect(state.life.wallet > 40_000)
    }

    @Test("A house forgives less debt than the founder loses")
    func collateralIsWorthLessThanTheHouse() {
        let config = balance()
        let state = housed(config)
        // The bank lends against 70% of the home's value, so foreclosing
        // writes off less than the founder gave up — which is what makes
        // signing a loss rather than a way to sell your house.
        #expect(state.guaranteeCapacity(balance: config) == 28_000)
        #expect(config.life.home(.house).upgradeCost == 40_000)
    }

    @Test("An economy without guarantees lends exactly as it did before")
    func inertWithoutTheSplit() {
        let config = balance(economy: TestBalance.neutralEconomy)
        var state = housed(config)
        let full = state.creditLimit(balance: config)

        #expect(state.unsecuredCreditLimit(balance: config) == full)
        #expect(state.guaranteeCapacity(balance: config) == 0)
        Reducer.apply(
            .takeLoan(amount: full), to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.loanBalance == full)
    }
}
