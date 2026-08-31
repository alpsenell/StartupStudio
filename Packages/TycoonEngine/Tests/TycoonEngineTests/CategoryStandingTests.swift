import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// "Hold the Category": the standing ledger, its decay, and the forward
/// read it buys.
///
/// The contract this suite exists to protect is that standing costs the
/// simulation nothing. It draws no RNG words, and nothing in the economy
/// consults it — so `BalanceTargetsTests` measures the same table with the
/// ledger running as it did without it. The gates there are the proof;
/// `standingNeverReachesTheEconomy` here is the reminder.
@Suite("Category standing")
struct CategoryStandingTests {
    /// A market that never moves, so a standing assertion is never a
    /// market assertion.
    private static func stillMarket() -> BalanceConfig.MarketBalance {
        var market = BalanceConfig.MarketBalance.standard
        market.shiftIntervalDays = 7
        market.driftSigma = 0
        market.boomChance = 0
        market.crashChance = 0
        return market
    }

    private static func balance(
        _ configure: (inout BalanceConfig.StandingBalance) -> Void = { _ in }
    ) -> BalanceConfig {
        var market = stillMarket()
        configure(&market.standing)
        return TestBalance.make(life: TestBalance.quietLife, market: market)
    }

    /// A released product in "testing", so the topic counts as held.
    private static func liveProduct(quality: Double = 70, offMarket: Bool = false) -> Product {
        Product(
            id: UUID(), name: "Gizmo", typeID: "tool", topicID: "testing",
            stage: .released(ReleaseInfo(
                launchDay: 0,
                quality: quality,
                reviews: [Review(outlet: "TechDaily", score: Int(quality), blurb: "")],
                weeklySales: [],
                offMarket: offMarket,
                hypeAtLaunch: 0,
                adoptionWeeks: 1
            ))
        )
    }

    // MARK: - The ledger

    @Test func aNewGameHoldsNoCategories() {
        let state = GameState.newGame(companyName: "Acme", seed: 1, balance: Self.balance())
        #expect(state.market.standing.isEmpty)
        #expect(state.market.standing(for: "testing") == 0)
        #expect(!state.market.holdsCategory("testing", above: 50))
    }

    @Test func shippingIntoATopicBuildsStandingAndTheReviewsDecideHowMuch() {
        // Reviews are the only variable: same ship fee, different verdict.
        let balance = Self.balance()
        let content = TestContent.tiny()
        let config = balance.market.standing

        // The neutral score pays the ship fee and nothing else; ten points
        // above it pays four more, and a disaster pays less than nothing on
        // the review line while the ship fee still carries it positive.
        #expect(config.launchGain(averageReviewScore: 60) == config.shipGain)
        #expect(config.launchGain(averageReviewScore: 70) == config.shipGain + 4)
        #expect(config.launchGain(averageReviewScore: 20) < config.shipGain)

        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        StandingSystemProbe.launch(
            topicID: "testing", score: 80, &state, balance, content
        )
        #expect(abs(state.market.standing(for: "testing") - 20) < 1e-9)
    }

    @Test func standingIsClampedToTheBalanceBand() {
        let balance = Self.balance()
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        // Twenty perfect launches cannot buy more than the category has.
        for _ in 0..<20 {
            StandingSystemProbe.launch(topicID: "testing", score: 98, &state, balance, content)
        }
        #expect(state.market.standing(for: "testing") == balance.market.standing.maxStanding)

        // And a category cannot go into the red, however long it is left.
        state.market.standing["testing"] = 1
        for _ in 0..<20 {
            StandingSystemProbe.week(&state, balance, content)
        }
        #expect(state.market.standing(for: "testing") == 0)
    }

    @Test func aTopicWithSomethingOnTheMarketEarnsItsRetainerEveryWeek() {
        let balance = Self.balance()
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.products.append(Self.liveProduct())
        state.market.standing["testing"] = 40

        for _ in 0..<4 {
            StandingSystemProbe.week(&state, balance, content)
        }
        let expected = 40 + 4 * balance.market.standing.presenceWeeklyGain
        #expect(abs(state.market.standing(for: "testing") - expected) < 1e-9)
    }

    @Test func aCategoryYouWalkOutOfGoesQuiet() {
        // The point of the whole feature: standing is rent. Ten weeks with
        // nothing on the market costs more than ten weeks of presence pays.
        let balance = Self.balance()
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.market.standing["testing"] = 60

        for _ in 0..<10 {
            StandingSystemProbe.week(&state, balance, content)
        }
        let expected = 60 - 10 * balance.market.standing.decayWeeklyLoss
        #expect(abs(state.market.standing(for: "testing") - expected) < 1e-9)
        #expect(state.market.standing(for: "testing") < 60)
    }

    @Test func delistingTheLastProductStartsTheDecay() {
        let balance = Self.balance()
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        state.products.append(Self.liveProduct(offMarket: true))
        state.market.standing["testing"] = 50

        StandingSystemProbe.week(&state, balance, content)
        #expect(state.market.standing(for: "testing") == 50 - balance.market.standing.decayWeeklyLoss)
    }

    @Test func aCategoryNobodyHasEverEnteredStaysAtZeroRatherThanGoingNegative() {
        let balance = Self.balance()
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        for _ in 0..<5 {
            StandingSystemProbe.week(&state, balance, content)
        }
        // No entry at all — an untouched topic is not bookkeeping.
        #expect(state.market.standing["testing"] == nil)
    }

    @Test func aPatchAndACampaignBothPayIntoTheCategory() throws {
        var balance = Self.balance()
        balance.economy.campaignCooldownDays = 0
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        let product = Self.liveProduct()
        state.products.append(product)
        state.market.standing["testing"] = 10

        let events = MarketingSystem.startCampaign(
            kindID: CampaignKind.socialPush.rawValue, productID: product.id,
            state: &state, balance: balance, content: content
        )
        #expect(!events.isEmpty, "the campaign was refused, so this proves nothing")
        let afterCampaign = 10 + balance.market.standing.campaignGain
        #expect(abs(state.market.standing(for: "testing") - afterCampaign) < 1e-9)

        // A patch already at full points lands on the next tick.
        state.economy.updates.append(ProductUpdate(
            productID: product.id, startedDay: state.day,
            designPts: 1, codePts: 1, polishPts: 1,
            progressDesign: 1, progressCode: 1, progressPolish: 1
        ))
        let landed = Reducer.tick(&state, balance: balance, content: content)
        #expect(
            landed.contains { if case .updateShipped = $0 { true } else { false } },
            "the patch did not land, so this proves nothing"
        )
        #expect(
            abs(state.market.standing(for: "testing")
                - (afterCampaign + balance.market.standing.patchGain)) < 1e-9
        )
    }

    // MARK: - What standing buys

    @Test func theForwardReadIsOnlyForCategoriesYouHold() {
        let balance = Self.balance()
        let threshold = balance.market.standing.forecastThreshold
        var market = MarketState(topics: ["testing": TopicMarket(multiplier: 1.2, lastChange: 0)])

        market.standing["testing"] = threshold - 0.1
        #expect(market.forecast(for: "testing", market: balance.market) == nil)

        market.standing["testing"] = threshold
        let forecast = market.forecast(for: "testing", market: balance.market)
        #expect(forecast != nil)
        #expect(forecast?.weeksAhead == balance.market.forecastHorizonWeeks)
        #expect(forecast?.current == 1.2)
    }

    @Test func theBandWidensWithTheHorizonAndWithTheMarketsOwnViolence() throws {
        var market = try BalanceConfig.loadBundled().market
        let near = MarketForecast.project(
            topicID: "fitness", current: 1.0, weeks: 1, market: market
        )
        let far = MarketForecast.project(
            topicID: "fitness", current: 1.0, weeks: 6, market: market
        )
        #expect(far.high - far.low > near.high - near.low)
        #expect(far.jumpChance > near.jumpChance)

        // A calmer market is a narrower read at the same horizon.
        market.driftSigma /= 4
        market.boomChance /= 4
        market.crashChance /= 4
        let calm = MarketForecast.project(
            topicID: "fitness", current: 1.0, weeks: 6, market: market
        )
        #expect(calm.high - calm.low < far.high - far.low)
    }

    @Test func aTopicAgainstItsCeilingHasMoreRoomToFallThanToRise() throws {
        // The clamps are the honest half of the read: no draw is needed to
        // know that a market at the top of its range is not going higher.
        let market = try BalanceConfig.loadBundled().market
        let hot = MarketForecast.project(
            topicID: "fitness", current: market.multiplierMax, weeks: 3, market: market
        )
        #expect(hot.high == market.multiplierMax)
        #expect(hot.low < market.multiplierMax)
        #expect(hot.lean(threshold: market.driftSigma / 2) == .cooling)

        let cold = MarketForecast.project(
            topicID: "fitness", current: market.multiplierMin, weeks: 3, market: market
        )
        #expect(cold.low == market.multiplierMin)
        #expect(cold.lean(threshold: market.driftSigma / 2) == .warming)

        // With room either side and a symmetric jump table, no lean.
        let even = MarketForecast.project(
            topicID: "fitness", current: 1.0, weeks: 3, market: market
        )
        #expect(even.lean(threshold: market.driftSigma / 2) == .steady)
        #expect(even.expected == 1.0)
    }

    @Test func theShippedBalanceCarriesTheStandingLedger() throws {
        let market = try BalanceConfig.loadBundled().market
        #expect(market.forecastHorizonWeeks == 3)
        #expect(market.standing.maxStanding == 100)
        #expect(market.standing.forecastThreshold == 50)
        #expect(market.standing.decayWeeklyLoss > market.standing.presenceWeeklyGain,
                "standing has to be rent: presence must not outrun neglect")
    }

    /// A `Balance.json` written before "Hold the Category" still loads, and
    /// loads with the shipped ledger rather than zeros.
    @Test func aBalanceFileWithoutTheStandingBlockStillDecodes() throws {
        let json = """
        {
            "shiftIntervalDays": 7, "driftSigma": 0.06,
            "multiplierMin": 0.4, "multiplierMax": 1.8,
            "boomChance": 0.05, "boomJump": 0.4,
            "crashChance": 0.05, "crashJump": 0.4
        }
        """
        let market = try JSONDecoder().decode(
            BalanceConfig.MarketBalance.self, from: Data(json.utf8)
        )
        #expect(market.forecastHorizonWeeks
            == BalanceConfig.MarketBalance.defaultForecastHorizonWeeks)
        #expect(market.standing == .standard)
    }

    // MARK: - The balance contract

    /// Standing is a ledger and nothing reads it. Two identical runs, one
    /// with the ledger's gains multiplied tenfold, must be the same run —
    /// same cash, same day, same RNG position. If this ever fails, some
    /// system has started consulting standing and the pacing table needs
    /// re-measuring before that ships.
    @Test func standingNeverReachesTheEconomy() throws {
        func run(scale: Double) throws -> (cash: Int, reputation: Double, standing: Double) {
            var balance = try BalanceConfig.loadBundled()
            balance.rivals.rivalCount = 0
            balance.market.standing.shipGain *= scale
            balance.market.standing.patchGain *= scale
            balance.market.standing.campaignGain *= scale
            balance.market.standing.presenceWeeklyGain *= scale
            let result = SimRunner.run(
                days: 400, seed: 4_242, bot: SoloSlowBot(),
                balance: balance, content: TestContent.bundled
            )
            let standing = result.state.market.standing.values.reduce(0, +)
            return (result.state.company.cash, result.state.company.reputation, standing)
        }

        let plain = try run(scale: 1)
        let loud = try run(scale: 10)
        #expect(plain.cash == loud.cash)
        #expect(plain.reputation == loud.reputation)
        #expect(loud.standing > plain.standing, "the tenfold ledger did not actually differ")
    }

    /// Standing survives a save and comes back exactly, and a save written
    /// before it existed loads with every category at zero.
    @Test func standingRoundTripsAndOldSavesLoadWithNoCategories() throws {
        var market = MarketState(
            topics: ["fitness": TopicMarket(multiplier: 1.2, lastChange: 0.1)],
            history: ["fitness": [1.1, 1.2]],
            recentEvents: [MarketEvent(day: 7, topicID: "fitness", kind: .boom)],
            standing: ["fitness": 62.5, "music": 3]
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(market)
        let decoded = try JSONDecoder().decode(MarketState.self, from: data)
        #expect(decoded == market)
        #expect(decoded.standing(for: "fitness") == 62.5)

        // Stable order: the standing map encodes as an array sorted by
        // topic, like the history, so two identical states never differ by
        // the dictionary's hash order.
        market.standing = ["music": 3, "fitness": 62.5]
        var object = try #require(
            try JSONSerialization.jsonObject(with: try encoder.encode(market)) as? [String: Any]
        )
        let entries = try #require(object["standing"] as? [[String: Any]])
        #expect(entries.compactMap { $0["topicID"] as? String } == ["fitness", "music"])

        // A pre-standing save: same payload with the key removed.
        object.removeValue(forKey: "standing")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let fromLegacy = try JSONDecoder().decode(MarketState.self, from: legacy)
        #expect(fromLegacy.standing.isEmpty)
        #expect(fromLegacy.standing(for: "fitness") == 0)
        #expect(fromLegacy.multiplier(for: "fitness") == 1.2)
    }
}

/// `StandingSystem` is internal to the engine and its hooks live inside
/// `ProductSystem` / `LiveOpsSystem`. These drive it the way the systems
/// do, so the suite tests the shipped path rather than a parallel one.
private enum StandingSystemProbe {
    /// One weekly market beat, which is where the retainer and the decay
    /// are applied.
    static func week(
        _ state: inout GameState, _ balance: BalanceConfig, _ content: ContentCatalog
    ) {
        state.day += balance.market.shiftIntervalDays
        _ = MarketSystem.run(&state, balance, content)
    }

    static func launch(
        topicID: String, score: Int,
        _ state: inout GameState, _ balance: BalanceConfig, _ content: ContentCatalog
    ) {
        StandingSystem.recordLaunch(
            topicID: topicID, averageReviewScore: score, &state, balance
        )
    }
}
