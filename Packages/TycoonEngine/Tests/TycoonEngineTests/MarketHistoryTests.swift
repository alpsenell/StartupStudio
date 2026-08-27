import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Market history")
struct MarketHistoryTests {
    private static func weeklyMarket(boom: Double = 0, crash: Double = 0) -> BalanceConfig.MarketBalance {
        var market = BalanceConfig.MarketBalance.standard
        market.shiftIntervalDays = 7
        market.driftSigma = 0
        market.boomChance = boom
        market.crashChance = crash
        return market
    }

    @Test func bundledBalanceCarriesTheCaps() throws {
        let balance = try BalanceConfig.loadBundled()
        #expect(balance.marketHistoryWeeks == 26)
        #expect(balance.marketEventLogCap == 30)
    }

    @Test func newGameStartsWithNoHistoryAndNoEvents() {
        let state = GameState.newGame(companyName: "Acme", seed: 1, balance: TestBalance.standard)
        #expect(state.market.history.isEmpty)
        #expect(state.market.recentEvents.isEmpty)
        #expect(state.market.trend(for: "fitness") == 0)
    }

    @Test func eachShiftAppendsThePostShiftMultiplierOldestFirst() {
        // Every shift booms by exactly +0.4 (sigma 0), so the multiplier
        // walks 1.4, 1.8, 1.8 (clamped) — and history records each step.
        let balance = TestBalance.make(market: Self.weeklyMarket(boom: 1))
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        for _ in 0..<6 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.market.history["testing"] == nil)

        Reducer.tick(&state, balance: balance, content: content) // day 7
        #expect(state.market.history["testing"] == [1.4])
        for _ in 0..<14 {
            Reducer.tick(&state, balance: balance, content: content) // days 14, 21
        }
        let history = state.market.history["testing"] ?? []
        #expect(history.count == 3)
        for (actual, expected) in zip(history, [1.4, 1.8, 1.8]) {
            #expect(abs(actual - expected) < 1e-9)
        }
        #expect(abs(state.market.multiplier(for: "testing") - 1.8) < 1e-9)
    }

    @Test func historyIsCappedAtMarketHistoryWeeksKeepingTheNewest() throws {
        var market = Self.weeklyMarket(boom: 1)
        market.boomJump = 0.1 // 1.1, 1.2, 1.3, 1.4, 1.5
        let balance = TestBalance.make(market: market, marketHistoryWeeks: 3)
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        for _ in 0..<35 { // five shifts
            Reducer.tick(&state, balance: balance, content: content)
        }
        let history = try #require(state.market.history["testing"])
        #expect(history.count == 3)
        for (actual, expected) in zip(history, [1.3, 1.4, 1.5]) {
            #expect(abs(actual - expected) < 1e-9)
        }
        #expect(state.market.recentEvents.count == 5)
    }

    @Test func boomsAndCrashesAreLoggedNewestLastAndCapped() {
        let balance = TestBalance.make(market: Self.weeklyMarket(boom: 1), marketEventLogCap: 2)
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        for _ in 0..<7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.market.recentEvents == [MarketEvent(day: 7, topicID: "testing", kind: .boom)])

        for _ in 0..<14 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.market.recentEvents == [
            MarketEvent(day: 14, topicID: "testing", kind: .boom),
            MarketEvent(day: 21, topicID: "testing", kind: .boom),
        ])
    }

    @Test func crashesLogTheCrashKindAndQuietDriftLogsNothing() {
        let crashing = TestBalance.make(market: Self.weeklyMarket(crash: 1))
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: crashing)
        for _ in 0..<7 {
            Reducer.tick(&state, balance: crashing, content: content)
        }
        #expect(state.market.recentEvents == [MarketEvent(day: 7, topicID: "testing", kind: .crash)])

        let quiet = TestBalance.make(market: Self.weeklyMarket())
        var quietState = GameState.newGame(companyName: "Acme", seed: 1, balance: quiet)
        for _ in 0..<21 {
            Reducer.tick(&quietState, balance: quiet, content: content)
        }
        #expect(quietState.market.recentEvents.isEmpty)
        #expect(quietState.market.history["testing"]?.count == 3)
    }

    @Test func trendIsTheLastMultiplierMinusTheOneFourWeeksEarlier() {
        var market = MarketState.neutral
        #expect(market.trend(for: "fitness") == 0)
        market.history["fitness"] = [1.0, 1.1, 1.2, 1.3]
        #expect(market.trend(for: "fitness") == 0, "four samples are not enough")
        market.history["fitness"] = [1.0, 1.1, 1.2, 1.3, 1.5]
        #expect(abs(market.trend(for: "fitness") - 0.5) < 1e-12)
        market.history["fitness"] = [0.9, 0.8, 1.0, 1.1, 1.2, 1.3, 0.7]
        #expect(abs(market.trend(for: "fitness") - (0.7 - 1.0)) < 1e-12)
        #expect(market.trend(for: "unknown") == 0)
    }

    @Test func historyOfManyTopicsAccumulatesThroughTheRealCatalog() throws {
        // No rivals: a rival shipping dents a multiplier after the shift
        // appended it to the history, breaking `history.last == multiplier`.
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 0
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        for _ in 0..<(7 * 30) {
            Reducer.tick(&state, balance: balance, content: content)
        }
        for topic in content.topics {
            let history = try #require(state.market.history[topic.id], Comment(rawValue: topic.id))
            #expect(history.count == balance.marketHistoryWeeks)
            #expect(history.last == state.market.multiplier(for: topic.id))
        }
        #expect(state.market.recentEvents.count <= balance.marketEventLogCap)
        #expect(state.market.recentEvents == state.market.recentEvents.sorted { $0.day < $1.day })
    }

    // MARK: - Persistence

    /// The save store encodes with `.sortedKeys` (Foundation's JSONEncoder
    /// orders object keys only under that option), so that is the contract
    /// checked here; the history array itself is ordered by topic id, which
    /// no encoder option influences.
    @Test func historyEncodesInTopicOrderRegardlessOfInsertionOrderAndRoundTrips() throws {
        var a = MarketState.neutral
        a.topics["zeta"] = TopicMarket(multiplier: 1.2, lastChange: 0.1)
        a.topics["alpha"] = TopicMarket(multiplier: 0.9, lastChange: -0.1)
        a.history["zeta"] = [1.0, 1.2]
        a.history["alpha"] = [1.0, 0.9]
        a.history["mid"] = [1.1]
        a.recentEvents = [MarketEvent(day: 7, topicID: "zeta", kind: .boom)]

        var b = MarketState.neutral
        b.history["mid"] = [1.1]
        b.topics["alpha"] = TopicMarket(multiplier: 0.9, lastChange: -0.1)
        b.history["alpha"] = [1.0, 0.9]
        b.recentEvents = [MarketEvent(day: 7, topicID: "zeta", kind: .boom)]
        b.history["zeta"] = [1.0, 1.2]
        b.topics["zeta"] = TopicMarket(multiplier: 1.2, lastChange: 0.1)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let dataA = try encoder.encode(a)
        let dataB = try encoder.encode(b)
        #expect(dataA == dataB)

        let object = try #require(try JSONSerialization.jsonObject(with: dataA) as? [String: Any])
        let entries = try #require(object["history"] as? [[String: Any]])
        #expect(entries.map { $0["topicID"] as? String } == ["alpha", "mid", "zeta"])
        #expect(entries[2]["values"] as? [Double] == [1.0, 1.2])

        let decoded = try JSONDecoder().decode(MarketState.self, from: dataA)
        #expect(decoded == a)
        #expect(try encoder.encode(decoded) == dataA)
    }

    @Test func savesWithoutHistoryStillLoad() throws {
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: TestBalance.standard)
        state.market.topics["fitness"] = TopicMarket(multiplier: 1.3, lastChange: 0.2)
        let data = try JSONEncoder().encode(state)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var market = try #require(object["market"] as? [String: Any])
        market["history"] = nil
        market["recentEvents"] = nil
        object["market"] = market
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(GameState.self, from: legacy)
        #expect(decoded.market.topics["fitness"] == TopicMarket(multiplier: 1.3, lastChange: 0.2))
        #expect(decoded.market.history.isEmpty)
        #expect(decoded.market.recentEvents.isEmpty)
    }
}
