import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Time stops only when it matters, and the game always knows why. The old
/// engine paused about once every four days — 169 to 204 times over two
/// years — mostly for market swings in topics the studio had nothing in.
@Suite("Pause policy")
struct PausePolicyTests {
    static func economy(pauseBudgetDays: Int = 5) -> BalanceConfig.EconomyBalance {
        var economy = TestBalance.neutralEconomy
        economy.pauseBudgetDays = pauseBudgetDays
        return economy
    }

    static func state(pauseBudgetDays: Int = 5) -> (GameState, BalanceConfig) {
        let balance = TestBalance.make(economy: economy(pauseBudgetDays: pauseBudgetDays))
        var state = GameState.newGame(companyName: "Acme", seed: 61, balance: balance)
        state.day = 100
        return (state, balance)
    }

    // MARK: - Grading

    @Test func moneyDeadlinesAndPeopleLeavingAreAlwaysCritical() {
        let critical: [GameEvent] = [
            .bankruptcyWarning(day: 1),
            .gameOver(day: 1),
            .poachAttempt(rivalID: UUID(), employeeID: UUID(), offeredWeeklySalary: 1, respondByDay: 5, day: 1),
            .buyoutOffered(rivalID: UUID(), amount: 1, respondByDay: 5, day: 1),
            .staffEventOccurred(employeeID: UUID(), kind: .familyEmergency, respondByDay: 5, day: 1),
            .resignationNotice(employeeID: UUID(), name: "Kim", respondByDay: 8, day: 1),
            .employeeQuit(employeeID: UUID(), name: "Kim", day: 1),
            .breakup(day: 1),
            .founderAway(reason: "Burnout", untilDay: 8, day: 1),
            .founderAway(reason: "Hospital", untilDay: 15, day: 1),
        ]
        for event in critical {
            #expect(event.severity == .critical, "\(event)")
            #expect(event.pausesTimeline)
        }
    }

    @Test func routineGoodNewsNeverStopsTheClock() {
        let quiet: [GameEvent] = [
            .hired(employeeID: UUID(), day: 1),
            .contractDelivered(contractID: UUID(), quality: 90, payout: 100, day: 1),
            .campaignStarted(campaignID: UUID(), day: 1),
            .rivalShipped(rivalID: UUID(), topicID: "fitness", day: 1),
            .weekendSpent(activity: .rest, day: 1),
            .priceChanged(productID: UUID(), tier: .budget, day: 1),
            .departmentFormed(department: .legal, day: 1),
            .salaryChanged(employeeID: UUID(), weeklySalary: 1, day: 1),
        ]
        for event in quiet {
            #expect(!event.pausesTimeline, "\(event) should not stop the clock")
        }
        #expect(GameEvent.weekendSpent(activity: .rest, day: 1).severity == .quiet)
    }

    @Test func aVacationIsNotAnEmergencyButAHospitalStayIs() {
        #expect(GameEvent.founderAway(reason: "Vacation", untilDay: 8, day: 1).severity == .notable)
        #expect(GameEvent.founderAway(reason: "Hospital", untilDay: 8, day: 1).severity == .critical)
    }

    // MARK: - The owned-topic rule

    @Test func aMarketSwingInSomebodyElsesTopicIsSomebodyElsesNews() throws {
        var (state, balance) = Self.state()
        let boom = GameEvent.marketBoom(topicID: "testing", day: state.day)

        #expect(PausePolicy.pausingEvents([boom], state: state, balance: balance).isEmpty)

        // Put something on the market in that topic and it matters.
        state.products = [Product(
            id: UUID(), name: "T", typeID: "tool", topicID: "testing",
            stage: .released(ReleaseInfo(
                launchDay: 0, quality: 70, reviews: [], weeklySales: [], offMarket: false
            ))
        )]
        #expect(PausePolicy.pausingEvents([boom], state: state, balance: balance) == [boom])

        // A delisted product is not a stake either.
        state.products[0].stage = .released(ReleaseInfo(
            launchDay: 0, quality: 70, reviews: [], weeklySales: [], offMarket: true
        ))
        #expect(PausePolicy.pausingEvents([boom], state: state, balance: balance).isEmpty)
    }

    // MARK: - The budget

    @Test func onlyOneNotableInterruptionEveryFewDays() throws {
        var (state, balance) = Self.state(pauseBudgetDays: 5)
        let reviews = GameEvent.reviewsIn(productID: UUID(), averageScore: 70, day: state.day)
        let research = GameEvent.researchCompleted(nodeID: "code_reviews", day: state.day)

        // Two notable events on the same day: only the first gets through.
        let sameDay = PausePolicy.pausingEvents([reviews, research], state: state, balance: balance)
        #expect(sameDay == [reviews])

        // Spend the budget and the next few days stay quiet.
        state.economy.lastNonCriticalPauseDay = state.day
        #expect(PausePolicy.pausingEvents([research], state: state, balance: balance).isEmpty)
        state.day += 4
        #expect(PausePolicy.pausingEvents([research], state: state, balance: balance).isEmpty)
        state.day += 1
        #expect(PausePolicy.pausingEvents([research], state: state, balance: balance) == [research])
    }

    @Test func theBudgetNeverSilencesSomethingCritical() throws {
        var (state, balance) = Self.state()
        state.economy.lastNonCriticalPauseDay = state.day
        let notable = GameEvent.reviewsIn(productID: UUID(), averageScore: 70, day: state.day)
        let critical = GameEvent.bankruptcyWarning(day: state.day)

        let pausing = PausePolicy.pausingEvents([notable, critical], state: state, balance: balance)
        #expect(pausing == [critical])
    }

    @Test func aBudgetOfZeroTurnsTheThrottleOff() throws {
        let (state, balance) = Self.state(pauseBudgetDays: 0)
        let a = GameEvent.reviewsIn(productID: UUID(), averageScore: 70, day: state.day)
        let b = GameEvent.researchCompleted(nodeID: "code_reviews", day: state.day)
        #expect(PausePolicy.pausingEvents([a, b], state: state, balance: balance) == [a, b])
    }

    // MARK: - Wiring

    @Test func theTickRecordsWhyItStoppedAndSpendsTheBudget() throws {
        let balance = TestBalance.make(
            life: TestBalance.quietLife, economy: Self.economy()
        )
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 62, balance: balance)
        state.company.cash = -1 // a bankruptcy warning on the next tick

        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.economy.pauseEvents.count == 1)
        if case .bankruptcyWarning = state.economy.pauseEvents[0] {} else {
            Issue.record("expected the warning, got \(state.economy.pauseEvents)")
        }
        // Critical pauses do not spend the non-critical budget.
        #expect(state.economy.lastNonCriticalPauseDay == nil)
    }

    @Test func aQuietDayNeverStopsTheClock() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        var state = GameState.newGame(companyName: "Acme", seed: 64, balance: balance)
        for _ in 0..<6 {
            Reducer.tick(&state, balance: balance, content: TestContent.tiny())
            #expect(state.economy.pauseEvents.isEmpty)
        }
    }
}

/// The engine half of the pause policy: `GameEngine` stops on exactly the
/// reasons `PausePolicy` gave, and the speed control clears them.
@MainActor
@Suite("Pause policy (engine)")
struct PausePolicyEngineTests {
    @Test func theEngineStopsOnTheReasonsThePolicyGave() throws {
        let balance = TestBalance.make(
            life: TestBalance.quietLife, economy: PausePolicyTests.economy()
        )
        var state = GameState.newGame(companyName: "Acme", seed: 63, balance: balance)
        state.company.cash = -1
        let engine = GameEngine(state: state, balance: balance, content: TestContent.tiny())
        engine.setSpeed(.x1)

        engine.performTick()
        #expect(engine.state.speed == .paused)
        #expect(engine.lastPauseEvents.count == 1)

        // Answering the pause clears the reason on both sides.
        engine.setSpeed(.x1)
        #expect(engine.lastPauseEvents.isEmpty)
        #expect(engine.state.economy.pauseEvents.isEmpty)
    }
}
