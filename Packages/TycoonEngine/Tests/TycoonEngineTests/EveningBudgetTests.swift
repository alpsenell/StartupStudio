import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// A life balance with an evening budget on it, and one without.
private func budgetedLife(
    chill: Int = 5, normal: Int = 3, crunch: Int = 1
) -> BalanceConfig.LifeBalance {
    var life = TestBalance.quietLife
    life.eveningsPerWeek = [
        WorkSchedule.chill.rawValue: chill,
        WorkSchedule.normal.rawValue: normal,
        WorkSchedule.crunch.rawValue: crunch,
    ]
    return life
}

private func balance(
    life: BalanceConfig.LifeBalance = budgetedLife()
) -> BalanceConfig {
    TestBalance.make(
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: life,
        founder: BalanceConfig.FounderBalance(
            skillMidpoint: 50,
            training: [
                TrainingMethod.selfStudy.rawValue: .init(
                    cost: 0, energy: 1, mood: 0, gain: 4, cooldownDays: 0
                ),
            ],
            maxTrainingsPerDay: 1
        ),
        relationships: BalanceConfig.RelationshipBalance(
            partnerActivities: [
                PartnerActivity.call.rawValue: .init(
                    cost: 0, affection: 4, cooldownDays: 0
                ),
            ],
            hangOut: .init(cost: 0, affection: 0, cooldownDays: 0),
            mentorSkillGain: 4,
            mentorEnergyCost: 1,
            mentorCooldownDays: 0
        )
    )
}

private func newGame(_ balance: BalanceConfig) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
    state.life.wallet = 50_000
    TestLife.pinPeak(&state)
    // Mid-week, so a tick inside a test does not land on the refill
    // boundary (`day % 7 == 1`) and quietly hand the founder a new week.
    state.day = 2
    return state
}

@Suite("The evening budget")
struct EveningBudgetTests {
    private func study(_ state: inout GameState, _ config: BalanceConfig) -> [GameEvent] {
        Reducer.apply(
            .trainFounderSkill(skill: .technical, method: .selfStudy),
            to: &state, balance: config, content: TestContent.tiny()
        )
    }

    @Test("The schedule sets the week's evenings")
    func scheduleSetsTheBudget() {
        let config = balance()
        var state = newGame(config)

        state.life.schedule = .crunch
        #expect(state.eveningsLeftThisWeek(config) == 1)
        state.life.schedule = .normal
        #expect(state.eveningsLeftThisWeek(config) == 3)
        state.life.schedule = .chill
        #expect(state.eveningsLeftThisWeek(config) == 5)
    }

    @Test("A signed-off founder gets the chill week's evenings, not the crunch they intend")
    func convalescingReadsTheEffectiveSchedule() {
        let config = balance()
        var state = newGame(config)
        state.life.schedule = .crunch
        state.economy.convalescingUntilDay = state.day + 14

        #expect(state.eveningsLeftThisWeek(config) == 5)
    }

    @Test("Everything personal spends from the same pool")
    func oneMeterForEveryAction() {
        let config = balance()
        var state = newGame(config)
        state.life.schedule = .chill  // five evenings
        TestLife.setPartner(&state, stage: .partner)
        let hire = TestPeople.employee()
        state.employees.append(hire)
        let content = TestContent.tiny()

        _ = study(&state, config)
        #expect(state.eveningsLeftThisWeek(config) == 4)
        Reducer.apply(.spendTimeWithPartner(.call), to: &state, balance: config, content: content)
        #expect(state.eveningsLeftThisWeek(config) == 3)
        Reducer.apply(.hangOutWith(employeeID: hire.id), to: &state, balance: config, content: content)
        #expect(state.eveningsLeftThisWeek(config) == 2)
        Reducer.apply(
            .mentorEmployee(employeeID: hire.id, skill: .coding),
            to: &state, balance: config, content: content
        )
        #expect(state.eveningsLeftThisWeek(config) == 1)
        Reducer.apply(.doInstantActivity(.walk), to: &state, balance: config, content: content)
        #expect(state.eveningsLeftThisWeek(config) == 0)
    }

    @Test("An exhausted week refuses everything, with a reason")
    func spentWeekRefuses() {
        let config = balance()
        var state = newGame(config)
        state.life.schedule = .crunch  // one evening
        TestLife.setPartner(&state, stage: .partner)
        let content = TestContent.tiny()

        _ = study(&state, config)
        #expect(state.eveningsLeftThisWeek(config) == 0)

        #expect(Reducer.apply(
            .spendTimeWithPartner(.call), to: &state, balance: config, content: content
        ).isEmpty)
        #expect(Reducer.apply(
            .doInstantActivity(.walk), to: &state, balance: config, content: content
        ).isEmpty)
        #expect(state.partnerActivityBlocker(.call, balance: config) == "No evenings left this week")
        #expect(state.instantActivityBlocker(.walk, balance: config) == "No evenings left this week")
        // Training's own per-day cap is the nearer gate today, so give it
        // tomorrow: the week is still spent, and now that is the reason.
        Reducer.tick(&state, balance: config, content: content)
        #expect(state.trainingBlocker(.selfStudy, balance: config) == "No evenings left this week")
    }

    @Test("A new week refills it")
    func weeklyRefill() {
        let config = balance()
        var state = newGame(config)
        state.life.schedule = .crunch
        let content = TestContent.tiny()

        _ = study(&state, config)
        #expect(state.eveningsLeftThisWeek(config) == 0)

        // Tick to the top of the next week.
        repeat {
            Reducer.tick(&state, balance: config, content: content)
        } while state.day % GameState.daysPerWeek != 1
        #expect(state.eveningsLeftThisWeek(config) == 1)
    }

    @Test("Crunch is a real trade: output for the week you have left")
    func crunchCostsEvenings() {
        let config = balance()
        var chill = newGame(config)
        chill.life.schedule = .chill
        var crunch = newGame(config)
        crunch.life.schedule = .crunch

        // Same wellbeing, so the only difference is the schedule.
        #expect(
            crunch.founderOutputMultiplier(balance: config)
                > chill.founderOutputMultiplier(balance: config)
        )
        #expect(
            (crunch.eveningsLeftThisWeek(config) ?? 0) < (chill.eveningsLeftThisWeek(config) ?? 0)
        )
    }

    @Test("Company social actions are the company's time, not the founder's")
    func companySocialIsFree() {
        let config = balance()
        var state = newGame(config)
        state.life.schedule = .crunch
        let hire = TestPeople.employee()
        state.employees.append(hire)

        Reducer.apply(
            .grabCoffee(employeeID: hire.id), to: &state, balance: config, content: TestContent.tiny()
        )
        #expect(state.eveningsLeftThisWeek(config) == 1)
    }

    @Test("A balance with no budget is the simulation that shipped before it")
    func noBudgetIsUnchanged() {
        let config = TestBalance.make(
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife,
            founder: BalanceConfig.FounderBalance(
                training: [
                    TrainingMethod.selfStudy.rawValue: .init(
                        cost: 0, energy: 1, mood: 0, gain: 4, cooldownDays: 0
                    ),
                ],
                maxTrainingsPerDay: 4
            )
        )
        var state = newGame(config)
        state.life.schedule = .crunch

        #expect(state.eveningsLeftThisWeek(config) == nil)
        for _ in 0..<4 { _ = study(&state, config) }
        // Four sessions in a day, gated only by the per-day cap.
        #expect(state.life.trainingsToday == 4)
        #expect(state.life.eveningsSpentThisWeek == 0)
        #expect(state.trainingBlocker(.selfStudy, balance: config) != "No evenings left this week")
    }

    @Test("The per-day cap still stops a whole week landing on one Tuesday")
    func perDayCapSurvives() {
        let config = balance()
        var state = newGame(config)
        state.life.schedule = .chill  // five evenings, but two activities a day
        let content = TestContent.tiny()

        Reducer.apply(.doInstantActivity(.walk), to: &state, balance: config, content: content)
        Reducer.apply(.doInstantActivity(.cinema), to: &state, balance: config, content: content)
        #expect(state.life.instantActionsToday == 2)
        #expect(state.instantActivityBlocker(.restaurant, balance: config) == "Done for today")
        // Three evenings still in hand — the day is what ran out.
        #expect(state.eveningsLeftThisWeek(config) == 3)
    }
}
