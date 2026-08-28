import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Rival depth: named products, the per-topic share model that replaced the
/// flat competition dent, and the four personalities.
@Suite("Rival products and market share")
struct RivalProductTests {
    private static let content = TestContent.bundled

    private static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    /// The bundled balance with the field cut to a single studio, so a test
    /// about one rival is not quietly contested by the three the system
    /// tops the field up to.
    private static func soloRivalBalance() throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 1
        return balance
    }

    /// A player product on the market in a topic, at a chosen review score.
    private static func addPlayerProduct(
        to state: inout GameState,
        topicID: String,
        score: Int,
        launchDay: Int = 0
    ) {
        let reviews = (0..<4).map { index in
            Review(outlet: "Outlet \(index)", score: score, blurb: "b")
        }
        state.products.append(Product(
            id: UUID(),
            name: "Player Thing",
            typeID: "mobile_app",
            topicID: topicID,
            stage: .released(ReleaseInfo(
                launchDay: launchDay,
                quality: Double(score),
                reviews: reviews,
                weeklySales: [],
                offMarket: false
            ))
        ))
    }

    private static func addRival(
        to state: inout GameState,
        personality: RivalPersonality,
        topicID: String,
        productQuality: Double?,
        launchDay: Int = 0
    ) -> UUID {
        let id = UUID()
        var rival = Rival(
            id: id,
            name: "Testco",
            strength: 50,
            reputation: 40,
            focusTopicIDs: [topicID],
            foundedDay: 0,
            appearanceSeed: 7,
            personality: personality
        )
        if let productQuality {
            rival.products = [RivalProduct(
                id: UUID(), name: "Their Thing", topicID: topicID, typeID: "mobile_app",
                quality: productQuality, launchDay: launchDay, weeklyUnits: 100
            )]
        }
        state.rivals.rivals.append(rival)
        return id
    }

    // MARK: - Named products

    /// Rivals now ship products with names, into topics, at a quality that
    /// tracks their strength.
    @Test func rivalsShipNamedProductsOverALongRun() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 41, balance: balance)
        var launches = 0
        for _ in 0..<730 {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .rivalProductLaunched = event { launches += 1 }
            }
            if state.gameOver != nil { break }
        }

        #expect(launches > 0, "no rival shipped a named product in two years")
        let allProducts = state.rivals.rivals.flatMap(\.products)
        for product in allProducts {
            #expect(!product.name.isEmpty)
            #expect(product.name.count > 2)
            #expect(product.quality >= RivalDepthTuning.qualityMin)
            #expect(product.quality <= RivalDepthTuning.qualityMax)
            #expect(Self.content.topic(product.topicID) != nil)
        }
        // The shelf is capped, so a long run can't grow the save forever.
        for rival in state.rivals.rivals {
            #expect(rival.products.count <= RivalDepthTuning.maxProductsPerRival)
        }
    }

    /// Rivals are named like software studios now, not like bakeries.
    @Test func rivalsAreNamedLikeStudios() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 42, balance: balance)
        Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(!state.rivals.rivals.isEmpty)
        // Every founding name comes from a studio pool — WS-B's when it
        // has one, the built-in one until then. Never the client-company
        // pool that used to make rivals sound like bakeries.
        let clientNames = Set(Self.content.names.clientCompanies)
        for rival in state.rivals.rivals {
            #expect(!rival.name.isEmpty)
            #expect(!clientNames.contains(rival.name), "\(rival.name) is a client company name")
        }
        #expect(RivalPersonality.allCases.contains(state.rivals.rivals[0].personality))
    }

    /// An old product stops competing, so a topic doesn't stay contested
    /// forever by something nobody buys.
    @Test func productsFadeAfterTheRelevanceWindow() {
        let product = RivalProduct(
            id: UUID(), name: "Old Thing", topicID: "fitness", typeID: "mobile_app",
            quality: 70, launchDay: 0, weeklyUnits: 10
        )
        let window = RivalDepthTuning.relevanceWeeks * GameState.daysPerWeek
        #expect(product.isCompeting(on: window - 1))
        #expect(!product.isCompeting(on: window))
    }

    // MARK: - Share

    /// An uncontested topic is the whole market, exactly as it was before
    /// rivals shipped anything.
    @Test func anUncontestedTopicIsTheWholeMarket() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 43, balance: balance)
        Self.addPlayerProduct(to: &state, topicID: "fitness", score: 70)
        Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(state.market.shareMultiplier(for: "fitness") == 1.0)
    }

    /// A better product keeps more of the market than a worse one.
    @Test func shareIsQualityWeighted() throws {
        let balance = try Self.soloRivalBalance()

        func share(playerScore: Int, rivalQuality: Double) -> Double {
            var state = GameState.newGame(companyName: "Acme", seed: 44, balance: balance)
            state.rivals.rivals = []
            Self.addPlayerProduct(to: &state, topicID: "fitness", score: playerScore)
            _ = Self.addRival(
                to: &state, personality: .deepPockets, topicID: "fitness",
                productQuality: rivalQuality
            )
            // Tick to an evolution day so the weekly share pass runs.
            for _ in 0..<balance.rivals.evolveIntervalDays {
                Reducer.tick(&state, balance: balance, content: Self.content)
            }
            return state.rivals.share(for: "fitness")
        }

        let strong = share(playerScore: 85, rivalQuality: 40)
        let even = share(playerScore: 60, rivalQuality: 60)
        let weak = share(playerScore: 35, rivalQuality: 85)

        #expect(strong > even)
        #expect(even > weak)
        #expect(abs(even - 0.5) < 0.05, "an even match should split the market")
        #expect(weak >= RivalDepthTuning.shareMin, "no topic is ever hopeless")
        #expect(strong <= RivalDepthTuning.shareMax)
    }

    /// The share reaches `ProductSystem` through the market accessor, and
    /// survives `MarketSystem` rebuilding the topic on its weekly shift.
    @Test func shareIsMirroredIntoTheMarketEveryDay() throws {
        let balance = try Self.soloRivalBalance()
        var state = GameState.newGame(companyName: "Acme", seed: 45, balance: balance)
        state.rivals.rivals = []
        Self.addPlayerProduct(to: &state, topicID: "fitness", score: 50)
        _ = Self.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: 80
        )

        // Two full weeks: covers a market shift day and the days after it.
        for _ in 0..<(balance.market.shiftIntervalDays * 2 + 1) {
            Reducer.tick(&state, balance: balance, content: Self.content)
            let canonical = state.rivals.share(for: "fitness")
            #expect(state.market.shareMultiplier(for: "fitness") == canonical)
        }
        #expect(state.rivals.share(for: "fitness") < 1.0)
    }

    /// The acceptance bar: a copycat entering the player's best topic
    /// visibly costs them the market inside half a year.
    @Test func aCopycatDentsTheShareWithinTwentySixWeeks() throws {
        let balance = try Self.soloRivalBalance()
        var state = GameState.newGame(companyName: "Acme", seed: 46, balance: balance)
        state.rivals.rivals = []
        Self.addPlayerProduct(to: &state, topicID: "fitness", score: 62)
        let copycatID = Self.addRival(
            to: &state, personality: .copycat, topicID: "productivity", productQuality: nil
        )

        var noticed = false
        var dented = false
        for _ in 0..<(26 * GameState.daysPerWeek) {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .rivalCopycat(let id, let topicID, _) = event, id == copycatID {
                    #expect(topicID == "fitness")
                    noticed = true
                }
            }
            if state.rivals.share(for: "fitness") < 0.7 { dented = true; break }
        }

        #expect(noticed, "the copycat never noticed the player's best topic")
        #expect(dented, "the player's share never dropped below 0.7 in 26 weeks")
    }

    /// Beating a rival repeatedly provokes a price war, which costs share
    /// for a few weeks and then lifts.
    @Test func beatingARivalTwiceStartsAPriceWar() throws {
        let balance = try Self.soloRivalBalance()
        var state = GameState.newGame(companyName: "Acme", seed: 47, balance: balance)
        state.rivals.rivals = []
        Self.addPlayerProduct(to: &state, topicID: "fitness", score: 88)
        let rivalID = Self.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: 30
        )

        var warUntil: Int?
        for _ in 0..<(12 * GameState.daysPerWeek) {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .priceWarStarted(let id, let topicID, let until, _) = event, id == rivalID {
                    #expect(topicID == "fitness")
                    warUntil = until
                }
            }
            if warUntil != nil { break }
        }

        _ = try #require(warUntil, "no price war after being beaten repeatedly")
        let duringWar = state.rivals.share(for: "fitness")

        // The war is worth exactly its penalty: clear it, recompute, and
        // the share comes back. (Ticking past the end isn't the check —
        // a rival the player keeps beating simply starts another one.)
        var peace = state
        peace.rivals.rivals[0].priceWarUntilDay = nil
        peace.rivals.rivals[0].priceWarTopicID = nil
        peace.rivals.rivals[0].weeksBeaten = 0
        for _ in 0..<balance.rivals.evolveIntervalDays {
            Reducer.tick(&peace, balance: balance, content: Self.content)
        }
        #expect(peace.rivals.share(for: "fitness") > duringWar)
        #expect(
            abs(peace.rivals.share(for: "fitness") - duringWar - RivalDepthTuning.priceWarSharePenalty)
                < 0.02
        )
    }

    /// Owning a topic outright is what the chapter-4 goal measures.
    @Test func dominanceCountsOnlyContestedTopics() {
        var rivals = RivalsState.empty
        rivals.playerShare = ["fitness": 0.9, "productivity": 0.4, "gaming": 1.0]
        // fitness is contested and dominated; productivity is contested and
        // lost; gaming has no competitor at all, so it isn't an achievement.
        #expect(rivals.dominatedTopicCount == 1)
    }

    // MARK: - Personalities

    /// The patient studio never folds, however badly it does.
    @Test func theDeepPocketsStudioNeverFolds() throws {
        let balance = try Self.soloRivalBalance()
        var state = GameState.newGame(companyName: "Acme", seed: 48, balance: balance)
        state.rivals.rivals = []
        let stubborn = Self.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: nil
        )
        state.rivals.rivals[0].strength = 1

        for _ in 0..<(20 * GameState.daysPerWeek) {
            Reducer.tick(&state, balance: balance, content: Self.content)
            if state.gameOver != nil { break }
        }
        #expect(state.rivals.rivals.contains { $0.id == stubborn })
    }

    // MARK: - Save compatibility

    /// A save written before rival depth existed decodes with no products,
    /// the patient personality, and an uncontested market.
    @Test func decodesASaveWithoutRivalDepth() throws {
        let json = Data("""
        {
          "id": "11111111-2222-3333-4444-555555555555",
          "name": "Old Rival",
          "strength": 42,
          "reputation": 30,
          "focusTopicIDs": ["fitness"],
          "foundedDay": 3,
          "appearanceSeed": 99
        }
        """.utf8)
        let rival = try JSONDecoder().decode(Rival.self, from: json)
        #expect(rival.products.isEmpty)
        #expect(rival.personality == .deepPockets)
        #expect(!rival.isInPriceWar(on: 100))

        let stateJSON = Data(#"{"rivals":[]}"#.utf8)
        let rivals = try JSONDecoder().decode(RivalsState.self, from: stateJSON)
        #expect(rivals.playerShare.isEmpty)
        #expect(rivals.share(for: "fitness") == 1.0)

        let topic = try JSONDecoder().decode(
            TopicMarket.self, from: Data(#"{"multiplier":1.2,"lastChange":0.1}"#.utf8)
        )
        #expect(topic.playerShare == 1.0)
    }

    /// The share table encodes sorted, whatever order it was filled in.
    @Test func shareEncodesInSortedOrder() throws {
        var a = RivalsState.empty
        a.playerShare = ["zulu": 0.4, "alpha": 0.9, "mike": 0.6]
        var b = RivalsState.empty
        b.playerShare = ["mike": 0.6, "alpha": 0.9, "zulu": 0.4]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(a) == encoder.encode(b))
    }
}
