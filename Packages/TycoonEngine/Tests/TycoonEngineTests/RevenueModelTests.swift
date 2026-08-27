import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// The two ways a product earns — a one-off sale per unit, or a recurring
/// subscription per customer — and the costs that come with keeping either
/// one on the market.
@Suite("Revenue models")
struct RevenueModelTests {
    /// An economy with the revenue rules live but everything else neutral.
    static func economy(
        churnBase: Double = 0.06,
        churnQualityFactor: Double = 0.03,
        subscriberAcquisitionWeeks: Double = 52,
        hostingCostPerSubscriber: Double = 0.05,
        brooksPenalty: Double = 0,
        subscriptionFloorSubscribers: Int = 8
    ) -> BalanceConfig.EconomyBalance {
        var economy = TestBalance.neutralEconomy
        economy.churnBase = churnBase
        economy.churnQualityFactor = churnQualityFactor
        economy.subscriberAcquisitionWeeks = subscriberAcquisitionWeeks
        economy.hostingCostPerSubscriber = hostingCostPerSubscriber
        economy.brooksPenalty = brooksPenalty
        economy.subscriptionFloorSubscribers = subscriptionFloorSubscribers
        economy.priceTiers = BalanceConfig.EconomyBalance.PriceTierDef.standardTable
        return economy
    }

    /// A catalog whose single type is a subscription product.
    static func subscriptionContent(
        marketSize: Double = 5_200,
        unitPrice: Double = 10,
        hostingCostPerWeek: Double = 150
    ) -> ContentCatalog {
        ContentCatalog(
            productTypes: [ProductTypeDef(
                id: "tool", name: "Tool", iconSystemName: "hammer",
                designPts: 10, codePts: 10, polishPts: 10,
                unitPrice: unitPrice, marketSize: marketSize,
                unlockedFromStart: true, blurb: "A subscription.",
                revenueModel: .subscription, complexity: 1,
                hostingCostPerWeek: hostingCostPerWeek
            )],
            topics: [TopicDef(
                id: "testing", name: "Testing", iconSystemName: "checkmark", fitByType: [:]
            )],
            techTree: [],
            events: [],
            names: NamePools(
                firstNames: ["Ada"], lastNames: ["Lovelace"], clientCompanies: ["TestCo"],
                partnerNames: ["Sam"], childNames: ["Kit"]
            )
        )
    }

    /// Ships a product of `content`'s single type at a hand-set review
    /// score, then ticks `weeks` sales weeks.
    static func launched(
        content: ContentCatalog,
        balance: BalanceConfig,
        score: Int,
        priceTier: PriceTier = .standard,
        weeks: Int = 0,
        seed: UInt64 = 21
    ) throws -> (GameState, UUID) {
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.products.first?.id)
        let type = try #require(content.productType("tool"))
        state.products[0].stage = .released(ReleaseInfo(
            launchDay: 0,
            quality: Double(score),
            reviews: [Review(outlet: "Test", score: score, blurb: "")],
            weeklySales: [],
            offMarket: false,
            priceTier: priceTier,
            isSubscription: type.revenueModel == .subscription
        ))
        for _ in 0..<(weeks * 7) {
            Reducer.tick(&state, balance: balance, content: content)
        }
        return (state, id)
    }

    static func release(_ state: GameState, _ id: UUID) throws -> ReleaseInfo {
        guard case .released(let info)? = state.product(id: id)?.stage else {
            Issue.record("expected a released stage")
            return ReleaseInfo(
                launchDay: 0, quality: 0, reviews: [], weeklySales: [], offMarket: true
            )
        }
        return info
    }

    // MARK: - Subscriptions

    @Test func subscribersAccumulateWeekByWeekInsteadOfSpiking() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        let content = Self.subscriptionContent()
        let (state, id) = try Self.launched(content: content, balance: balance, score: 80, weeks: 4)
        let info = try Self.release(state, id)

        #expect(info.isSubscription)
        #expect(info.weeklySales.count == 4)
        // Week 1: 5200/52 × (0.4 + 0.6×0.8) = 88 sign-ups, no book to churn.
        #expect(info.weeklySales[0].units == 88)
        // Every week adds more than it loses at this quality, so the book grows.
        let units = info.weeklySales.map(\.units)
        #expect(units == units.sorted(), "the subscriber book should grow: \(units)")
        #expect(info.subscribers == units.last)
        // Revenue is the book × the price, not a one-off sale.
        #expect(info.weeklySales[3].revenue == units[3] * 10)
    }

    @Test func aBetterProductChurnsLess() throws {
        func book(score: Int) throws -> Int {
            let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
            let content = Self.subscriptionContent()
            let (state, id) = try Self.launched(
                content: content, balance: balance, score: score, weeks: 20
            )
            return try Self.release(state, id).subscribers
        }
        let good = try book(score: 90)
        let poor = try book(score: 40)
        // Quality buys sign-ups (0.4 + 0.6·q, so 1.47× here) *and* keeps
        // them (churn 0.06 − 0.03·q, so 0.033/wk against 0.048/wk). The
        // book has to open up by more than the sign-up ratio alone.
        #expect(
            Double(good) > Double(poor) * 1.55,
            "a 90 should hold far more of its book than a 40: \(good)/\(poor)"
        )
    }

    @Test func aSubscriptionDelistsWhenTheBookEmptiesOut() throws {
        // Nobody signs up (a huge acquisition window) and 30% churns a week.
        let balance = TestBalance.make(
            life: TestBalance.quietLife,
            economy: Self.economy(
                churnBase: 0.3, churnQualityFactor: 0, subscriberAcquisitionWeeks: 1_000_000
            )
        )
        let content = Self.subscriptionContent()
        var (state, id) = try Self.launched(content: content, balance: balance, score: 60)
        if case .released(var info) = state.products[0].stage {
            info.subscribers = 100
            info.adoptionWeeks = 1
            state.products[0].stage = .released(info)
        }
        for _ in 0..<(20 * 7) {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(try Self.release(state, id).offMarket)
    }

    // MARK: - Hosting

    @Test func everythingOnTheMarketCostsMoneyToKeepRunning() throws {
        let balance = TestBalance.make(
            weeklyOperatingCost: 0, life: TestBalance.quietLife, economy: Self.economy()
        )
        let content = Self.subscriptionContent(hostingCostPerWeek: 150)
        let (state, _) = try Self.launched(content: content, balance: balance, score: 80, weeks: 1)

        let hosting = state.ledger.entries.filter { $0.category == .hosting }
        #expect(hosting.count == 1)
        // 150 flat + 0.05 per subscriber on a book of 88 = 154.
        #expect(hosting[0].amount == -154)
        #expect(hosting[0].label == "Hosting & support")
    }

    @Test func aOneOffProductPostsOnlyItsFlatHostingBill() throws {
        let balance = TestBalance.make(
            weeklyOperatingCost: 0, life: TestBalance.quietLife, economy: Self.economy()
        )
        let content = ContentCatalog(
            productTypes: [ProductTypeDef(
                id: "tool", name: "Tool", iconSystemName: "hammer",
                designPts: 10, codePts: 10, polishPts: 10,
                unitPrice: 2, marketSize: 1_000, unlockedFromStart: true,
                blurb: "A one-off.", hostingCostPerWeek: 25
            )],
            topics: [TopicDef(
                id: "testing", name: "Testing", iconSystemName: "checkmark", fitByType: [:]
            )],
            techTree: [], events: [],
            names: NamePools(
                firstNames: ["Ada"], lastNames: ["Lovelace"], clientCompanies: ["TestCo"],
                partnerNames: ["Sam"], childNames: ["Kit"]
            )
        )
        let (state, id) = try Self.launched(content: content, balance: balance, score: 80, weeks: 1)

        #expect(try Self.release(state, id).subscribers == 0)
        let hosting = state.ledger.entries.filter { $0.category == .hosting }
        #expect(hosting.map(\.amount) == [-25])
    }

    // MARK: - Price tiers

    @Test func budgetTradesMarginForReachAndPremiumTheReverse() throws {
        func firstWeek(_ tier: PriceTier) throws -> WeeklySale {
            let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
            let content = TestContent.tiny(
                designPts: 10, codePts: 10, polishPts: 10, unitPrice: 10, marketSize: 1_000
            )
            let (state, id) = try Self.launched(
                content: content, balance: balance, score: 90, priceTier: tier, weeks: 1
            )
            return try #require(try Self.release(state, id).weeklySales.first)
        }

        let budget = try firstWeek(.budget)
        let standard = try firstWeek(.standard)
        let premium = try firstWeek(.premium)

        #expect(budget.units == Int(Double(standard.units) * 1.5))
        #expect(premium.units == Int(Double(standard.units) * 0.6))
        // Budget: 1.5× the units at 0.6× the price — slightly less money.
        #expect(budget.revenue < standard.revenue)
        // Premium: 0.6× the units at 1.6× the price — slightly less again.
        #expect(premium.revenue < standard.revenue)
    }

    @Test func aPremiumPriceTheReviewsDoNotBackUpDoublesChurn() throws {
        func book(_ tier: PriceTier, score: Int) throws -> Int {
            let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
            let content = Self.subscriptionContent()
            let (state, id) = try Self.launched(
                content: content, balance: balance, score: score, priceTier: tier, weeks: 15
            )
            return try Self.release(state, id).subscribers
        }
        // A 50 is below the premium quality threshold (70); a 90 is not.
        let overpriced = try book(.premium, score: 50)
        let fair = try book(.standard, score: 50)
        #expect(overpriced < fair)
        let justified = try book(.premium, score: 90)
        let standard90 = try book(.standard, score: 90)
        // At 90 the only difference is the demand factor, not the churn.
        #expect(justified > Int(Double(standard90) * 0.5))
    }

    // MARK: - Team size

    @Test func addingPeopleToOneBuildBuysLessThanItLooks() throws {
        func dailyCode(crew: Int, penalty: Double) throws -> Double {
            var economy = TestBalance.neutralEconomy
            economy.brooksPenalty = penalty
            let balance = TestBalance.make(
                skillGrowthRate: 0, life: TestBalance.quietLife, economy: economy
            )
            let content = TestContent.tiny(designPts: 500, codePts: 500, polishPts: 500)
            var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
            TestLife.pinPeak(&state)
            Reducer.apply(
                .startProduct(
                    typeID: "tool", topicID: "testing", name: "T",
                    focus: PhaseFocus(design: 0, code: 1, polish: 0)
                ),
                to: &state, balance: balance, content: content
            )
            let id = try #require(state.products.first?.id)
            for _ in 1..<crew {
                state.employees.append(TestPeople.employee(
                    coding: 50, design: 50, assignment: .product(id)
                ))
            }
            Reducer.tick(&state, balance: balance, content: content)
            guard case .development(let dev) = try #require(state.products.first).stage else {
                Issue.record("expected a development stage")
                return 0
            }
            return dev.codePts
        }

        let solo = try dailyCode(crew: 1, penalty: 0.10)
        let five = try dailyCode(crew: 5, penalty: 0.10)
        let fiveWithoutPenalty = try dailyCode(crew: 5, penalty: 0)
        // Five hands do less than five hands' work…
        #expect(five < fiveWithoutPenalty)
        // …exactly 1 / (1 + 0.10 × 4) of it.
        #expect(abs(five - fiveWithoutPenalty / 1.4) < 1e-9)
        // …but still more than one.
        #expect(five > solo)
    }

    // MARK: - Save compatibility

    @Test func releaseInfoDecodesWithoutTheRevenueModelKeys() throws {
        let json = """
        {"launchDay":3,"quality":70,"reviews":[],"weeklySales":[],"offMarket":false}
        """
        let info = try JSONDecoder().decode(ReleaseInfo.self, from: Data(json.utf8))
        #expect(!info.isSubscription)
        #expect(info.subscribers == 0)
        #expect(info.priceTier == .standard)
        #expect(info.liveBugs == 0)
        #expect(info.lastUpdateDay == nil)
        #expect(info.updateCount == 0)
    }
}
