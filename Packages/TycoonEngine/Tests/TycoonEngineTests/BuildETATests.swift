import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The build's ETA has one job: name the day the pools fill at today's
/// rate. If the rate it quotes ever drifts from what the next tick lands,
/// the countdown is counting something else.
@Suite("The build ETA")
struct BuildETATests {
    private static func balance() -> BalanceConfig {
        // A quiet life keeps the founder's output factor still from one day
        // to the next, so the projection can be checked against a tick to
        // the last decimal. Bugs draw from the RNG but points do not.
        TestBalance.make(
            bugChanceBase: 0,
            skillGrowthRate: 0,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife
        )
    }

    private static func started(
        _ balance: BalanceConfig,
        _ content: ContentCatalog,
        focus: PhaseFocus = .balanced
    ) -> (GameState, UUID) {
        var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: focus),
            to: &state, balance: balance, content: content
        )
        return (state, state.productInDevelopment?.id ?? UUID())
    }

    @Test("The projected daily rate is what the next tick lands")
    func rateMatchesTheTick() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        var (state, id) = Self.started(balance, content)

        let eta = try #require(state.buildETA(productID: id, balance: balance, content: content))
        #expect(eta.crewCount == 1)
        #expect(eta.designPerDay > 0)
        #expect(eta.codePerDay > 0)
        #expect(eta.polishPerDay > 0)

        guard case .development(let before) = try #require(state.product(id: id)).stage else { return }
        Reducer.tick(&state, balance: balance, content: content)
        guard case .development(let after) = try #require(state.product(id: id)).stage else { return }

        #expect(abs((after.designPts - before.designPts) - eta.designPerDay) < 1e-9)
        #expect(abs((after.codePts - before.codePts) - eta.codePerDay) < 1e-9)
        #expect(abs((after.polishPts - before.polishPts) - eta.polishPerDay) < 1e-9)
    }

    @Test("The countdown reaches zero on the day the pools are full")
    func countdownLandsOnCompletion() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        var (state, id) = Self.started(balance, content)

        let first = try #require(state.buildETA(productID: id, balance: balance, content: content))
        let promised = try #require(first.daysToComplete)
        #expect(promised > 1)

        // Counting down: each tick takes a day off, never adds one, and the
        // promise holds to the day when nothing about the crew changes.
        var previous = promised
        for _ in 0..<promised {
            Reducer.tick(&state, balance: balance, content: content)
            let now = try #require(state.buildETA(productID: id, balance: balance, content: content))
            let days = try #require(now.daysToComplete)
            #expect(days <= previous)
            previous = days
        }
        let done = try #require(state.buildETA(productID: id, balance: balance, content: content))
        #expect(done.daysToComplete == 0)
        #expect(done.isComplete)
        #expect(done.daysToShippable == 0)
    }

    @Test("A shippable build says so before it is finished")
    func shippableBeforeComplete() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        var (state, id) = Self.started(balance, content)
        let eta = try #require(state.buildETA(productID: id, balance: balance, content: content))
        let shippable = try #require(eta.daysToShippable)
        let complete = try #require(eta.daysToComplete)
        #expect(shippable < complete, "the ship gate is 60% of the code pool")

        for _ in 0..<shippable {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let forecast = try #require(state.shipForecast(productID: id, balance: balance, content: content))
        #expect(forecast.canShip)
    }

    @Test("Nobody on the build means no date")
    func noCrewNoDate() throws {
        let balance = Self.balance()
        let content = TestContent.tiny()
        var (state, id) = Self.started(balance, content)
        let founder = try #require(state.employees.first { $0.isFounder })
        Reducer.apply(.assign(employeeID: founder.id, to: .research), to: &state, balance: balance, content: content)

        let eta = try #require(state.buildETA(productID: id, balance: balance, content: content))
        #expect(eta.crewCount == 0)
        #expect(eta.daysToComplete == nil)
        #expect(eta.daysToShippable == nil)
        #expect(eta.designPerDay == 0)
    }

    @Test("A pool the focus has abandoned does not stall the date")
    func abandonedPoolIsNotCounted() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        let (state, id) = Self.started(balance, content, focus: PhaseFocus(design: 0, code: 1, polish: 1))
        let eta = try #require(state.buildETA(productID: id, balance: balance, content: content))
        #expect(eta.designPerDay == 0)
        #expect(eta.designRemaining > 0)
        // Code and polish are moving; the date is theirs.
        #expect(eta.daysToComplete != nil)
        #expect(eta.daysToComplete == BuildETA.days(remaining: eta.polishRemaining, rate: eta.polishPerDay)
            || eta.daysToComplete == BuildETA.days(remaining: eta.codeRemaining, rate: eta.codePerDay))
    }

    @Test("Not in development, no ETA")
    func releasedHasNoETA() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 10, codePts: 10, polishPts: 10)
        var (state, id) = Self.started(balance, content)
        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: content) }
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        guard case .released = try #require(state.product(id: id)).stage else {
            Issue.record("the fixture did not ship")
            return
        }
        #expect(state.buildETA(productID: id, balance: balance, content: content) == nil)
    }
}
