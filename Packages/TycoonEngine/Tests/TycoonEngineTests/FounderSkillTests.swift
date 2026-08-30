import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// A founder balance with real numbers on it, for the tests that want to
/// see an attribute actually move something.
private func founderBalance(
    starting: FounderSkillSet = FounderSkillSet(
        conversation: 50, technical: 50, marketKnowledge: 50, leadership: 50, finance: 50
    ),
    maxTrainingsPerDay: Int = 1,
    practiceGain: Double = 0,
    technicalOutputFactor: Double = 0.4,
    marketSalesFactor: Double = 0.45,
    financeDealFactor: Double = 0.35,
    conversationFactor: Double = 0.6,
    leadershipMoraleFactor: Double = 0.12,
    technicalBugDivisor: Double = 200
) -> BalanceConfig.FounderBalance {
    BalanceConfig.FounderBalance(
        starting: starting,
        skillMidpoint: 50,
        training: [
            TrainingMethod.selfStudy.rawValue: .init(
                cost: 0, energy: 10, mood: -2, gain: 4, cooldownDays: 1
            ),
            TrainingMethod.course.rawValue: .init(
                cost: 500, energy: 5, mood: 0, gain: 8, cooldownDays: 3
            ),
            TrainingMethod.coach.rawValue: .init(
                cost: 2_000, energy: 2, mood: 2, gain: 16, cooldownDays: 7
            ),
        ],
        maxTrainingsPerDay: maxTrainingsPerDay,
        practiceGain: practiceGain,
        technicalOutputFactor: technicalOutputFactor,
        marketSalesFactor: marketSalesFactor,
        financeDealFactor: financeDealFactor,
        conversationFactor: conversationFactor,
        leadershipMoraleFactor: leadershipMoraleFactor,
        technicalBugDivisor: technicalBugDivisor
    )
}

private func balance(
    founder: BalanceConfig.FounderBalance = founderBalance(),
    // Frozen by default, like every other suite, so the morale numbers
    // hold still; the leadership test opts into a roster that can move.
    staff: BalanceConfig.StaffBalance = TestBalance.frozenStaff
) -> BalanceConfig {
    TestBalance.make(
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: TestBalance.quietLife,
        staff: staff,
        founder: founder
    )
}

private func newGame(_ balance: BalanceConfig) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: 7, balance: balance)
    state.life.wallet = 50_000
    TestLife.pinPeak(&state)
    return state
}

// MARK: - The attribute sheet

@Suite("Founder attributes")
struct FounderSkillSetTests {
    @Test("A fresh founder starts on the balance's sheet")
    func startsOnTheBalanceSheet() {
        let config = founderBalance(starting: FounderSkillSet(
            conversation: 10, technical: 20, marketKnowledge: 30, leadership: 40, finance: 50
        ))
        let state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance(founder: config))
        #expect(state.life.skills.conversation == 10)
        #expect(state.life.skills.technical == 20)
        #expect(state.life.skills.finance == 50)
    }

    @Test("The subscript clamps to 0...100")
    func subscriptClamps() {
        var skills = FounderSkillSet(
            conversation: 0, technical: 0, marketKnowledge: 0, leadership: 0, finance: 0
        )
        skills[.technical] = 140
        #expect(skills.technical == 100)
        skills[.technical] = -20
        #expect(skills.technical == 0)
    }

    @Test("Growth has diminishing returns")
    func growthDiminishes() {
        var low = FounderSkillSet(
            conversation: 0, technical: 20, marketKnowledge: 0, leadership: 0, finance: 0
        )
        var high = low
        high[.technical] = 90

        low.grow(.technical, by: 10)
        high.grow(.technical, by: 10)

        // 10 × (1 − 0.2) against 10 × (1 − 0.9).
        #expect(abs((low.technical - 20) - 8) < 1e-9)
        #expect(abs((high.technical - 90) - 1) < 1e-9)
    }
}

// MARK: - Training

@Suite("Founder training")
struct FounderTrainingTests {
    @Test("A course costs the wallet and the day, and moves the attribute")
    func courseCosts() {
        let config = balance()
        var state = newGame(config)
        let before = state.life.skills.marketKnowledge

        let events = Reducer.apply(
            .trainFounderSkill(skill: .marketKnowledge, method: .course),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(state.life.wallet == 50_000 - 500)
        #expect(state.life.skills.marketKnowledge > before)
        #expect(state.life.meters.energy == 95)
        #expect(state.life.trainingsToday == 1)
        #expect(events.contains { if case .founderTrained = $0 { true } else { false } })
    }

    @Test("Self-study is free, so an overdrawn founder can still read a book")
    func selfStudyIsFree() {
        let config = balance()
        var state = newGame(config)
        state.life.wallet = -9_000

        Reducer.apply(
            .trainFounderSkill(skill: .conversation, method: .selfStudy),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(state.life.skills.conversation > 50)
        #expect(state.life.wallet == -9_000)
    }

    @Test("The day's training cap holds, and a new day clears it")
    func dailyCap() {
        let config = balance()
        var state = newGame(config)
        let content = TestContent.tiny()

        Reducer.apply(
            .trainFounderSkill(skill: .finance, method: .course),
            to: &state, balance: config, content: content
        )
        let afterFirst = state.life.skills.leadership
        // Second session, different method (so no cooldown in the way) —
        // refused purely on the day's cap.
        let refused = Reducer.apply(
            .trainFounderSkill(skill: .leadership, method: .coach),
            to: &state, balance: config, content: content
        )
        #expect(refused.isEmpty)
        #expect(state.life.skills.leadership == afterFirst)

        Reducer.tick(&state, balance: config, content: content)
        #expect(state.life.trainingsToday == 0)
        let allowed = Reducer.apply(
            .trainFounderSkill(skill: .leadership, method: .coach),
            to: &state, balance: config, content: content
        )
        #expect(!allowed.isEmpty)
    }

    @Test("A method's cooldown is per method")
    func cooldownIsPerMethod() {
        let config = balance(founder: founderBalance(maxTrainingsPerDay: 5))
        var state = newGame(config)
        let content = TestContent.tiny()

        Reducer.apply(
            .trainFounderSkill(skill: .finance, method: .coach),
            to: &state, balance: config, content: content
        )
        // Same method again today: refused.
        #expect(Reducer.apply(
            .trainFounderSkill(skill: .finance, method: .coach),
            to: &state, balance: config, content: content
        ).isEmpty)
        // A different method is a different cooldown.
        #expect(!Reducer.apply(
            .trainFounderSkill(skill: .finance, method: .course),
            to: &state, balance: config, content: content
        ).isEmpty)
    }

    @Test("Training is refused while the founder is away")
    func refusedWhileAway() {
        let config = balance()
        var state = newGame(config)
        state.life.awayUntilDay = state.day + 7
        state.life.awayReason = "Hospital"

        #expect(Reducer.apply(
            .trainFounderSkill(skill: .technical, method: .course),
            to: &state, balance: config, content: TestContent.tiny()
        ).isEmpty)
        #expect(state.life.wallet == 50_000)
    }

    @Test("A poor founder can't afford the coach")
    func coachNeedsMoney() {
        let config = balance()
        var state = newGame(config)
        state.life.wallet = 100

        #expect(Reducer.apply(
            .trainFounderSkill(skill: .technical, method: .coach),
            to: &state, balance: config, content: TestContent.tiny()
        ).isEmpty)
        #expect(state.trainingBlocker(.coach, balance: config) == "Need 1900 more")
    }
}

// MARK: - What the attributes are worth

@Suite("Founder attribute effects")
struct FounderSkillEffectTests {
    @Test("The shipped starting sheet is exactly neutral")
    func neutralAtTheMidpoint() {
        let config = balance()
        let state = newGame(config)
        #expect(abs(state.founderTalentFactor(config) - 1) < 1e-9)
        #expect(abs(state.founderMarketFactor(config) - 1) < 1e-9)
        #expect(abs(state.founderDealFactor(config) - 1) < 1e-9)
        #expect(abs(state.founderCharmFactor(config) - 1) < 1e-9)
        #expect(abs(state.founderLeadershipMoraleDelta(config)) < 1e-9)
    }

    @Test("Technical scales the founder's own output and their bugs")
    func technicalScalesOutput() {
        let config = balance()
        var state = newGame(config)
        let neutral = state.founderOutputMultiplier(balance: config)
        let neutralBugs = state.founderBugChanceMultiplier(balance: config)

        state.life.skills.technical = 100
        #expect(state.founderOutputMultiplier(balance: config) > neutral)
        #expect(state.founderBugChanceMultiplier(balance: config) < neutralBugs)

        state.life.skills.technical = 0
        #expect(state.founderOutputMultiplier(balance: config) < neutral)
        #expect(state.founderBugChanceMultiplier(balance: config) > neutralBugs)
    }

    @Test("Every effect is off in a balance with no founder block")
    func offWithoutTheBlock() {
        let config = TestBalance.make(life: TestBalance.quietLife)
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: config)
        TestLife.pinPeak(&state)
        let neutral = state.founderOutputMultiplier(balance: config)

        state.life.skills.technical = 100
        state.life.skills.marketKnowledge = 100
        #expect(abs(state.founderOutputMultiplier(balance: config) - neutral) < 1e-9)
        #expect(abs(state.founderMarketFactor(config) - 1) < 1e-9)
    }

    @Test("Leadership moves the morale the team settles at")
    func leadershipMovesMorale() {
        let config = balance(staff: .standard)
        var good = newGame(config)
        good.employees.append(TestPeople.employee())
        var bad = good
        good.life.skills.leadership = 100
        bad.life.skills.leadership = 0

        let content = TestContent.tiny()
        for _ in 0..<20 {
            Reducer.tick(&good, balance: config, content: content)
            Reducer.tick(&bad, balance: config, content: content)
        }

        let goodMorale = good.employees.last?.morale ?? 0
        let badMorale = bad.employees.last?.morale ?? 0
        #expect(goodMorale > badMorale)
    }
}
