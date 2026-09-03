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
