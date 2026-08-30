import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// The forecast has one job: quote the number the launch will actually
/// produce. If it ever drifts from `ProductSystem.ship`, the sheet is
/// lying to the player about the only decision the screen is for.
@Suite("The ship forecast")
struct ShipForecastTests {
    private static func balance() -> BalanceConfig {
        // The test economy neutralises the crew ceiling; this suite is
        // about surfacing it, so put the shipped value back.
        var economy = TestBalance.neutralEconomy
        economy.qualityCeilingBase = 0.35
        return TestBalance.make(
            bugChanceBase: 0,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife,
            economy: economy
        )
    }

    /// A product part-built by ticking, so the pools hold whatever the
    /// simulation actually put in them.
    private static func inProgress(
        _ balance: BalanceConfig,
        _ content: ContentCatalog,
        days: Int
    ) -> (GameState, UUID) {
        var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = state.productInDevelopment?.id ?? UUID()
        for _ in 0..<days { Reducer.tick(&state, balance: balance, content: content) }
        return (state, id)
    }

    @Test("The projected quality is the quality that ships")
    func forecastMatchesTheLaunch() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 40, codePts: 40, polishPts: 40)
        var (state, id) = Self.inProgress(balance, content, days: 60)

        let forecast = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        try #require(forecast.canShip)

        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        guard case .released(let info) = try #require(state.product(id: id)).stage else { return }

        #expect(abs(info.quality - forecast.quality) < 1e-9)
    }

    @Test("A product nobody could ship yet says so")
    func earlyProductCannotShip() {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 500, codePts: 500, polishPts: 500)
        let (state, id) = Self.inProgress(balance, content, days: 2)

        #expect(state.shipForecast(productID: id, balance: balance, content: content)?.canShip == false)
    }

    @Test("The crew's ceiling is named, and it is not 100")
    func crewCeilingIsVisible() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 20, codePts: 20, polishPts: 20)
        let (state, id) = Self.inProgress(balance, content, days: 90)

        let forecast = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        // A founder building alone cannot reach 100 however long they take.
        #expect(forecast.crewCeiling < 1)
        #expect(forecast.quality <= forecast.crewCeiling * 100 + 1e-9)
        #expect(forecast.limitingFactor != nil)
    }

    @Test("A poor topic pairing is named rather than hidden in the number")
    func topicFitIsVisible() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(
            designPts: 20, codePts: 20, polishPts: 20, topicFit: 0.8
        )
        let (state, id) = Self.inProgress(balance, content, days: 40)

        let forecast = try #require(
            state.shipForecast(productID: id, balance: balance, content: content)
        )
        #expect(forecast.topicFit == 0.8)
    }

    @Test("Nothing is forecast for a product that already shipped")
    func releasedProductsHaveNoForecast() throws {
        let balance = Self.balance()
        let content = TestContent.tiny(designPts: 20, codePts: 20, polishPts: 20)
        var (state, id) = Self.inProgress(balance, content, days: 60)
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        #expect(state.shipForecast(productID: id, balance: balance, content: content) == nil)
    }
}
