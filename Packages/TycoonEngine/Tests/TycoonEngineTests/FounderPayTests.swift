import Foundation
import Testing
import TycoonContent
import TycoonEngine

private func payEconomy(
    founderPayFairRatio: Double = 1.5,
    founderPayMoralePerRatioPoint: Double = 3,
    founderPayMoraleCap: Double = 10,
    founderPayBoardPressure: Double = 4
) -> BalanceConfig.EconomyBalance {
    var economy = TestBalance.neutralEconomy
    economy.founderPayFairRatio = founderPayFairRatio
    economy.founderPayMoralePerRatioPoint = founderPayMoralePerRatioPoint
    economy.founderPayMoraleCap = founderPayMoraleCap
    economy.founderPayBoardPressure = founderPayBoardPressure
    return economy
}

private func balance(
    economy: BalanceConfig.EconomyBalance = payEconomy()
) -> BalanceConfig {
    TestBalance.make(
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: TestBalance.quietLife,
        economy: economy
    )
}

/// A studio paying three people $1,000 a week, so the median is a round
/// number and the band sits at $1,500.
private func studio(_ balance: BalanceConfig, founderSalary: Int) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
    TestLife.pinPeak(&state)
    for _ in 0..<3 {
        state.employees.append(TestPeople.employee(weeklySalary: 1_000))
    }
    state.life.founderSalary = founderSalary
    return state
}

@Suite("What the founder pays themselves")
struct FounderPayTests {
    @Test("Inside the band, nobody minds")
    func insideTheBandIsFree() {
        let config = balance()
        let state = studio(config, founderSalary: 1_500)
        #expect(state.founderPayExcess(balance: config) == 0)
        #expect(state.founderPayMoralePenalty(balance: config) == 0)
    }

    @Test("Above it, it costs morale on a slope")
    func aboveTheBandIsASlope() {
        let config = balance()
        // 3× the median is 1.5 multiples above a 1.5 band.
        let greedy = studio(config, founderSalary: 3_000)
        #expect(abs(greedy.founderPayExcess(balance: config) - 1.5) < 1e-9)
        #expect(abs(greedy.founderPayMoralePenalty(balance: config) - 4.5) < 1e-9)

        // A slope, not a cliff: more pay, more penalty.
        let greedier = studio(config, founderSalary: 4_000)
        #expect(
            greedier.founderPayMoralePenalty(balance: config)
                > greedy.founderPayMoralePenalty(balance: config)
        )
    }

    @Test("The penalty is capped")
    func penaltyIsCapped() {
        let config = balance()
        let outrageous = studio(config, founderSalary: 100_000)
        #expect(outrageous.founderPayMoralePenalty(balance: config) == 10)
    }

    @Test("The band moves with the roster")
    func bandScalesWithTheTeam() {
        let config = balance()
        var garage = studio(config, founderSalary: 2_000)
        garage.employees.removeAll { !$0.isFounder }
        garage.employees.append(TestPeople.employee(weeklySalary: 4_000))

        // The same $2,000 that was greedy against $1,000-a-week juniors is
        // modest against a $4,000-a-week lead.
        #expect(garage.founderPayExcess(balance: config) == 0)
    }

    @Test("A solo founder answers to nobody")
    func soloFounderIsExempt() {
        let config = balance()
        var solo = studio(config, founderSalary: 5_000)
        solo.employees.removeAll { !$0.isFounder }
        #expect(solo.teamMedianSalary == nil)
        #expect(solo.founderPayExcess(balance: config) == 0)
    }

    @Test("A rescue salary the company set is not resented")
    func rescueSalaryIsExempt() {
        let config = balance()
        var rescued = studio(config, founderSalary: 5_000)
        #expect(rescued.founderPayExcess(balance: config) > 0)

        // Same number, but the company chose it to keep the founder housed.
        rescued.economy.rescueSalary = 5_000
        #expect(rescued.founderPayExcess(balance: config) == 0)
    }

    @Test("It actually reaches the team's morale")
    func moraleFeelsIt() {
        let config = TestBalance.make(
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife,
            staff: .standard,
            economy: payEconomy()
        )
        func settled(_ salary: Int) -> Double {
            var state = studio(config, founderSalary: salary)
            let content = TestContent.tiny()
            for _ in 0..<60 { Reducer.tick(&state, balance: config, content: content) }
            return state.employees.last?.morale ?? 0
        }
        #expect(settled(6_000) < settled(1_000))
    }

    @Test("An economy without the band is the simulation that shipped before it")
    func inertWithoutTheBand() {
        let config = balance(economy: TestBalance.neutralEconomy)
        let greedy = studio(config, founderSalary: 50_000)
        #expect(greedy.founderPayMoralePenalty(balance: config) == 0)
    }

    @Test("The ceiling the UI quotes is the one the engine charges against")
    func ceilingMatchesTheRule() {
        let config = balance()
        let state = studio(config, founderSalary: 0)
        let ceiling = state.fairFounderSalaryCeiling(balance: config)
        #expect(ceiling == 1_500)

        var atCeiling = state
        atCeiling.life.founderSalary = ceiling ?? 0
        #expect(atCeiling.founderPayExcess(balance: config) == 0)
    }
}
