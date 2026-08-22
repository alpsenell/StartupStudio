import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Review model & hype-driven sales")
struct ReviewModelTests {
    private let content = TestContent.tiny(designPts: 10, codePts: 10, polishPts: 10)

    /// Starts a product, pins its development pools/hype by hand, and ships.
    private func ship(
        dev: DevProgress,
        onDay day: Int = 0,
        balance: BalanceConfig,
        content: ContentCatalog
    ) throws -> (info: ReleaseInfo, state: GameState) {
        var state = GameState.newGame(companyName: "Acme", seed: 60, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        state.products[0].stage = .development(dev)
        state.day = day
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            throw CancellationError()
        }
        return (info, state)
    }

    @Test func reviewScoreMatchesHandComputedExpectationCases() throws {
        let balance = TestBalance.make(reviewNoiseSigma: 0)

        // Case A — year 1, reputation 10: expected = 30 + 3*0 + 0.15*10 = 31.5.
        // Quality 80 (full pools, 2 bugs) beats it: no shortfall, no hype,
        // so every outlet scores Int(80) = 80.
        let strong = try ship(
            dev: DevProgress(
                designPts: 10, codePts: 10, polishPts: 10,
                openBugs: 2, focus: .balanced, hype: 0
            ),
            balance: balance, content: content
        )
        #expect(abs(strong.info.quality - 80.0) < 1e-9)
        #expect(strong.info.hypeAtLaunch == 0)
        #expect(strong.info.reviews.count == 4)
        #expect(strong.info.reviews.allSatisfy { $0.score == 80 })

        // Case B — year 2 (day 364), reputation 10:
        // expected = 30 + 3*1 + 0.15*10 = 34.5. Quality 27 (pools 0/6/0:
        // completion 0.45 * 0.6) falls short:
        // score = 27 - 0.5 * (34.5 - 27) = 23.25 -> 23 at every outlet.
        let weak = try ship(
            dev: DevProgress(
                designPts: 0, codePts: 6, polishPts: 0,
                openBugs: 0, focus: .balanced, hype: 0
            ),
            onDay: 364,
            balance: balance, content: content
        )
        #expect(abs(weak.info.quality - 27.0) < 1e-9)
        #expect(weak.info.reviews.count == 4)
        #expect(weak.info.reviews.allSatisfy { $0.score == 23 })
        #expect(weak.info.averageReviewScore == 23)
    }

    @Test func hypeAtLaunchLiftsReviewsByTheHypeBonus() throws {
        let balance = TestBalance.make(reviewNoiseSigma: 0)

        // Quality 80 with 30 hype: score = 80 + 30/20 = 81.5 -> 81.
        let hyped = try ship(
            dev: DevProgress(
                designPts: 10, codePts: 10, polishPts: 10,
                openBugs: 2, focus: .balanced, hype: 30
            ),
            balance: balance, content: content
        )
        #expect(abs(hyped.info.quality - 80.0) < 1e-9)
        #expect(abs(hyped.info.hypeAtLaunch - 30.0) < 1e-9)
        #expect(hyped.info.reviews.allSatisfy { $0.score == 81 })
    }

    @Test func salesPeakGainsTheExactHypeMultiplier() throws {
        // Mirrors SalesTests' exact-numbers setup, plus 30 launch hype:
        // avg review 100 -> q-hat 1.0, peak = 1000 * (0.4 + 0.6) * 1.1 = 1100.
        let balance = TestBalance.make(
            bugChanceBase: 0,
            skillGrowthRate: 0,
            candidateRefreshDays: 10_000,
            reviewNoiseSigma: 0,
            reviewCeiling: 100,
            salesDecayBase: 0.1,
            salesDecayQualityFactor: 0,
            delistFraction: 0.05,
            contractOfferRefreshDays: 10_000
        )
        let content = TestContent.tiny(
            designPts: 2, codePts: 2, polishPts: 2, unitPrice: 2.0, marketSize: 1000
        )
        var state = GameState.newGame(companyName: "Acme", seed: 61, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "Gizmo", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        state.products[0].stage = .development(DevProgress(
            designPts: 2, codePts: 2, polishPts: 2,
            openBugs: 0, focus: .balanced, hype: 30
        ))
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        guard case .released(let shipped) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        #expect(shipped.quality == 100)
        #expect(shipped.averageReviewScore == 100) // 100 + 1.5 hype clamps at the ceiling
        #expect(abs(shipped.hypeAtLaunch - 30.0) < 1e-9)

        // Week 0 posts the boosted peak; week 1 decays from that same peak.
        while state.day < 7 { Reducer.tick(&state, balance: balance, content: content) }
        while state.day < 14 { Reducer.tick(&state, balance: balance, content: content) }
        guard case .released(let sold) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        #expect(sold.weeklySales == [
            WeeklySale(weekIndex: 0, units: 1100, revenue: 2200),
            WeeklySale(weekIndex: 1, units: 110, revenue: 220),
        ])
    }
}
