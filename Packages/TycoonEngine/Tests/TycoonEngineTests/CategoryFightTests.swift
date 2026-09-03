import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The Category Fight (iteration 5, WS-A): the phantom price war, the
/// share floor standing buys, the six-week challenge and the weekly
/// strength bleed.
///
/// The contract this suite protects is the same as `CategoryStandingTests`:
/// none of it reaches a game with `rivalCount = 0`, so the 19 pacing gates
/// measure the same table. Everything here is gated on a rival actually
/// selling into a topic the player is selling into.
@Suite("Category fight")
struct CategoryFightTests {
    private static let content = TestContent.bundled

    /// The bundled balance with the field on.
    private static func balance(rivals: Int = 4) throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = rivals
        return balance
    }

    // MARK: - The phantom price war

    /// Finding 1's evidence: "Anvil Digital started a price war in Finance"
    /// on day 15, against a company with no products. A rival's first
    /// launch into a topic the player has never entered is not the player
    /// beating it, so there is nothing to retaliate against.
    @Test func aFreshGameWithNoProductIsNeverAtWar() throws {
        let balance = try Self.balance()
        for seed in BalanceTargetsTests.seeds {
            var state = GameState.newGame(companyName: "Quiet", seed: seed, balance: balance)
            var wars: [GameEvent] = []
            var launches = 0
            for _ in 0..<90 {
                for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                    if case .priceWarStarted = event { wars.append(event) }
                    if case .rivalProductLaunched = event { launches += 1 }
                }
                #expect(state.products.isEmpty)
            }
            #expect(wars.isEmpty, "seed \(seed): a price war against a company with no products: \(wars)")
        }
    }

    /// …and the war still fires where it should: a player product that
    /// out-sells a rival's twice provokes one (`beatingARivalTwiceStartsAPriceWar`
    /// in `RivalProductTests` is the positive half; this pins that the fix
    /// did not silence it by checking the trigger topic is one the player
    /// is actually in).
    @Test func theWarStillFiresInATopicThePlayerSellsIn() throws {
        let balance = try Self.balance(rivals: 1)
        var state = GameState.newGame(companyName: "Acme", seed: 47, balance: balance)
        state.rivals.rivals = []
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: 88)
        let rivalID = RivalProductTests.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: 30
        )
        var warTopic: String?
        for _ in 0..<(8 * GameState.daysPerWeek) {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .priceWarStarted(let id, let topicID, _, _) = event, id == rivalID {
                    warTopic = topicID
                }
            }
            if warTopic != nil { break }
        }
        #expect(warTopic == "fitness")
    }

    // MARK: - The balance block

    @Test func theShippedBalanceCarriesTheDepthBlock() throws {
        let depth = try BalanceConfig.loadBundled().rivals.depth
        #expect(depth == .default)
        #expect(depth.shareFloorAtFullStanding == 0.55)
        #expect(depth.challengeWeeks == 6)
        #expect(depth.strengthPerWeekBeaten == 1.0)
        #expect(depth.incumbentEnabled)
        #expect(depth.incumbentValuationFloor == 750_000)
    }

    /// A `"rivals"` object from before the block, or one that tunes a
    /// single knob, still decodes — against the shipped defaults.
    @Test func aRivalsBlockWithoutDepthStillDecodes() throws {
        let balance = try BalanceConfig.loadBundled()
        let data = try JSONEncoder().encode(balance.rivals)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["depth"] != nil)

        object.removeValue(forKey: "depth")
        let absent = try JSONDecoder().decode(
            BalanceConfig.RivalBalance.self, from: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(absent.depth == .default)
        #expect(absent.rivalCount == balance.rivals.rivalCount)

        object["depth"] = ["challengeWeeks": 9]
        let partial = try JSONDecoder().decode(
            BalanceConfig.RivalBalance.self, from: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(partial.depth.challengeWeeks == 9)
        #expect(partial.depth.shareFloorAtFullStanding == 0.55)
    }

    // MARK: - Standing holds share

    /// The player's share of a contested topic at a given standing, with a
    /// rival product good enough to push the raw share under every floor.
    private static func share(atStanding standing: Double, floorAtFull: Double = 0.55) throws -> Double {
        var balance = try Self.balance(rivals: 1)
        balance.rivals.depth.shareFloorAtFullStanding = floorAtFull
        balance.rivals.depth.strengthPerWeekBeaten = 0
        balance.rivals.depth.standingPerWeekBeaten = 0
        var state = GameState.newGame(companyName: "Acme", seed: 44, balance: balance)
        state.rivals.rivals = []
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: 40)
        _ = RivalProductTests.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: 90
        )
        state.market.standing["fitness"] = standing
        // Tick to an evolution day so the weekly share pass runs; the
        // market's own retainer moves standing by half a point, which is
        // why the assertions below leave a margin.
        for _ in 0..<balance.rivals.evolveIntervalDays {
            Reducer.tick(&state, balance: balance, content: Self.content)
        }
        return state.rivals.share(for: "fitness")
    }

    @Test func standingHoldsShareOnlyOnceItClearsTheHardFloor() throws {
        // A 40 against a 90 is worth 16% of the market on quality; the old
        // floor makes it 30, and nothing below standing ~55 changes that.
        let raw = (40.0 * 40.0) / (40.0 * 40.0 + 90.0 * 90.0)
        #expect(raw < RivalDepthTuning.shareMin)
        #expect(try Self.share(atStanding: 0) == RivalDepthTuning.shareMin)
        #expect(try Self.share(atStanding: 50) == RivalDepthTuning.shareMin)

        // Above it, the floor is standing's: 0.44 at 80, 0.55 at 100.
        let at80 = try Self.share(atStanding: 80)
        #expect(at80 > RivalDepthTuning.shareMin)
        #expect(abs(at80 - 0.55 * 0.805) < 0.01, "share at standing 80 was \(at80)")
        let at100 = try Self.share(atStanding: 100)
        #expect(abs(at100 - 0.55) < 0.01, "share at standing 100 was \(at100)")

        // And the knob is the whole of it: switched off, standing 100 reads
        // like standing 0.
        #expect(try Self.share(atStanding: 100, floorAtFull: 0) == RivalDepthTuning.shareMin)
    }

    /// The twin of `standingNeverReachesTheEconomy`, with rivals on: a run
    /// whose standing never leaves zero measures the same cash, the same
    /// reputation and the same share whether the floor term is 0.55 or 0.
    /// The floor is the one place standing now reaches the economy, and
    /// this pins that it reaches it through standing alone.
    @Test func atStandingZeroTheFloorIsANoOpToTheDollar() throws {
        func run(floorAtFull: Double) throws -> (cash: Int, reputation: Double, share: [String: Double]) {
            var balance = try Self.balance()
            balance.rivals.depth.shareFloorAtFullStanding = floorAtFull
            // Standing stays at zero: nothing pays into the ledger.
            balance.market.standing.shipGain = 0
            balance.market.standing.reviewGainPerPoint = 0
            balance.market.standing.patchGain = 0
            balance.market.standing.campaignGain = 0
            balance.market.standing.presenceWeeklyGain = 0
            let result = SimRunner.run(
                days: 400, seed: 4_242, bot: SoloSlowBot(),
                balance: balance, content: Self.content
            )
            #expect(result.state.market.standing.values.allSatisfy { $0 == 0 })
            return (result.state.company.cash, result.state.company.reputation, result.state.rivals.playerShare)
        }
        let shipped = try run(floorAtFull: 0.55)
        let off = try run(floorAtFull: 0)
        #expect(shipped.cash == off.cash)
        #expect(shipped.reputation == off.reputation)
        #expect(shipped.share == off.share)
        #expect(!shipped.share.isEmpty, "the run was never contested, so this proves nothing")
    }
}

/// Shared fixtures for the WS-A suites: a player product on the market at
/// a chosen score, in a chosen topic.
enum RivalFightFixtures {
    @discardableResult
    static func addPlayerProduct(
        to state: inout GameState,
        topicID: String,
        score: Int,
        launchDay: Int = 0,
        tier: PriceTier = .standard,
        name: String = "Player Thing"
    ) -> UUID {
        let id = UUID()
        let reviews = (0..<4).map { index in
            Review(outlet: "Outlet \(index)", score: score, blurb: "b")
        }
        state.products.append(Product(
            id: id,
            name: name,
            typeID: "mobile_app",
            topicID: topicID,
            stage: .released(ReleaseInfo(
                launchDay: launchDay,
                quality: Double(score),
                reviews: reviews,
                weeklySales: [],
                offMarket: false,
                priceTier: tier
            ))
        ))
        return id
    }
}
