import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// `ShipETA` puts a build on a calendar. The agenda draws it as a dated
/// row, so the one thing it must never do is promise a day the build has
/// not reached: the crew's skills grow while they work, so the real gate
/// opens on or before the day this predicts, never after.
@Suite("The ship ETA")
struct ShipETATests {
    private static func balance() -> BalanceConfig {
        TestBalance.make(
            bugChanceBase: 0,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife,
            economy: TestBalance.neutralEconomy
        )
    }

    private static func started(
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> (GameState, UUID) {
        var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        return (state, state.productInDevelopment?.id ?? UUID())
    }

    @Test("The gate is open on the day the ETA names")
    func theETAIsNeverOptimistic() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        var (state, id) = Self.started(balance, content)
        for _ in 0..<10 { Reducer.tick(&state, balance: balance, content: content) }

        let product = try #require(state.product(id: id))
        let eta = try #require(state.shipETA(for: product, balance: balance, content: content))
        #expect(!eta.isReady)
        #expect(eta.daysAway > 0)
        #expect(eta.day == state.day + eta.daysAway)

        while state.day < eta.day {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let forecast = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        #expect(forecast.canShip, "the ETA promised a day the build had not reached")
    }

    @Test("A build nobody is working on has no ETA")
    func anIdleBuildHasNoETA() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        var (state, id) = Self.started(balance, content)
        for index in state.employees.indices {
            state.employees[index].assignment = .idle
        }
        let product = try #require(state.product(id: id))
        #expect(state.shipETA(for: product, balance: balance, content: content) == nil)
    }

    @Test("A build that can ship today reads as ready, today")
    func aReadyBuildReadsAsReady() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        var (state, id) = Self.started(balance, content)
        while state.shipForecast(productID: id, balance: balance, content: content)?.canShip == false {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let product = try #require(state.product(id: id))
        let eta = try #require(state.shipETA(for: product, balance: balance, content: content))
        #expect(eta.isReady)
        #expect(eta.daysAway == 0)
        #expect(eta.day == state.day)
    }

    @Test("A released product is not on the build calendar")
    func aReleasedProductHasNoETA() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        var (state, id) = Self.started(balance, content)
        while state.shipForecast(productID: id, balance: balance, content: content)?.canShip == false {
            Reducer.tick(&state, balance: balance, content: content)
        }
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        let product = try #require(state.product(id: id))
        #expect(state.shipETA(for: product, balance: balance, content: content) == nil)
        #expect(state.shipETAs(balance: balance, content: content).isEmpty)
    }
}
