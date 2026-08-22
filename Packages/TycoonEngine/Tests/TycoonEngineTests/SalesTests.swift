import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Weekly sales")
struct SalesTests {
    /// Ships a perfect-quality product on day 3 so every sales number is exact:
    /// avg review 100 -> q-hat 1.0, peak = 1000 * (0.4 + 0.6) = 1000 units,
    /// decay = 0.1, delist threshold = 0.05 * 1000 = 50 units.
    /// Candidate and contract-offer refreshes are pushed out of the observed
    /// window so the event log only carries product (and weekend) events;
    /// the founder's life is pinned so output is exact.
    private func makeShippedRun() throws -> (state: GameState, balance: BalanceConfig, content: ContentCatalog, id: UUID) {
        let balance = TestBalance.make(
            bugChanceBase: 0,
            skillGrowthRate: 0,
            candidateRefreshDays: 10_000,
            reviewNoiseSigma: 0,
            reviewCeiling: 100,
            salesDecayBase: 0.1,
            salesDecayQualityFactor: 0,
            delistFraction: 0.05,
            contractOfferRefreshDays: 10_000,
            life: TestBalance.quietLife
        )
        let content = TestContent.tiny(
            designPts: 2, codePts: 2, polishPts: 2, unitPrice: 2.0, marketSize: 1000
        )
        var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1

        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "Gizmo", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        // Balanced founder output (design 2.2/3, code 2.6/3, polish 2.4/3
        // per day, growth off): all pools complete after 3 days.
        Reducer.tick(&state, balance: balance, content: content)
        Reducer.tick(&state, balance: balance, content: content)
        Reducer.tick(&state, balance: balance, content: content)
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released product")
            throw CancellationError()
        }
        #expect(info.quality == 100)
        #expect(info.averageReviewScore == 100)
        return (state, balance, content, id)
    }

    @Test func weeklySalesPostDecayAndDelist() throws {
        var (state, balance, content, id) = try makeShippedRun()
        let cashAfterShip = state.company.cash

        // Days 3...7: first weekly post lands on day 7 with w = 0.
        while state.day < 7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        guard case .released(let week0) = try #require(state.products.first).stage else {
            Issue.record("expected a released product")
            return
        }
        #expect(week0.weeklySales == [WeeklySale(weekIndex: 0, units: 1000, revenue: 2000)])
        let salesEntries = state.ledger.entries.filter { $0.category == .sales }
        #expect(salesEntries.count == 1)
        #expect(salesEntries.first == LedgerEntry(day: 7, amount: 2000, category: .sales, label: "Gizmo"))
        // +2000 sales, -400 operating (rent is 0 in the garage).
        #expect(state.company.cash == cashAfterShip + 2000 - balance.weeklyOperatingCost)

        // Day 14: w = 1, units = Int(1000 * 0.1) = 100 (decayed), revenue 200.
        while state.day < 14 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        guard case .released(let week1) = try #require(state.products.first).stage else {
            Issue.record("expected a released product")
            return
        }
        #expect(week1.weeklySales.count == 2)
        #expect(week1.weeklySales.last == WeeklySale(weekIndex: 1, units: 100, revenue: 200))
        #expect(week1.totalRevenue == 2200)
        #expect(week1.offMarket == false)

        // Day 21: w = 2 gives 10 units < 50-unit delist threshold.
        // The product goes off market with the event and no sale row.
        var day21Events: [GameEvent] = []
        while state.day < 21 {
            day21Events = Reducer.tick(&state, balance: balance, content: content)
        }
        guard case .released(let delisted) = try #require(state.products.first).stage else {
            Issue.record("expected a released product")
            return
        }
        #expect(delisted.offMarket == true)
        #expect(delisted.weeklySales.count == 2)
        #expect(day21Events.contains(.productOffMarket(productID: id, day: 21)))

        // No further sales or product events accrue once off market (the
        // founder's weekend events keep coming regardless).
        func productEventCount() -> Int {
            state.eventLog.filter { if case .weekendSpent = $0 { return false } else { return true } }.count
        }
        let cashAfterDelist = state.company.cash
        let eventCountAfterDelist = productEventCount()
        while state.day < 35 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        guard case .released(let final) = try #require(state.products.first).stage else {
            Issue.record("expected a released product")
            return
        }
        #expect(final.weeklySales.count == 2)
        #expect(final.totalRevenue == 2200)
        #expect(productEventCount() == eventCountAfterDelist)
        // Cash only moves by the two weekly operating posts (days 28 and 35).
        #expect(state.company.cash == cashAfterDelist - 2 * balance.weeklyOperatingCost)
        let allSalesEntries = state.ledger.entries.filter { $0.category == .sales }
        #expect(allSalesEntries.count == 2)
    }
}
