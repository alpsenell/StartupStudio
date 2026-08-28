import Foundation
import Testing
import TycoonContent
import TycoonEngine

private func guaranteeEconomy(
    unsecuredCreditFraction: Double = 0.45,
    guaranteeHomeFactor: Double = 1,
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
        bankruptcyGraceDays: 1_000,
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: TestBalance.quietLife,
        economy: economy
    )
}

/// A founder in a house — worth $40,000 of collateral at a factor of 1.
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
        for _ in 0..<10 {
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

        // One tick past the call window.
        for _ in 0..<(config.economy.guaranteeCallDays + 2) {
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
        for _ in 0..<10 {
            events += Reducer.tick(&state, balance: config, content: content)
        }
        // The wallet still pays the week's rent — but nothing was seized,
        // and the house is not the bank's to take.
        #expect(state.life.wallet > 4_000)
        #expect(state.life.home == .house)
        #expect(!events.contains { if case .homeDowngraded = $0 { true } else { false } })
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
