import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Exit terms (iteration 5, WS-B): a distress sale is not a win, and a
/// strategic one can be taken as an earn-out.
@Suite("Exit terms")
struct ExitTermsTests {
    static let content = TestContent.bundled

    static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    /// A company with a rival on the field and an offer on the table, of
    /// the given kind, without waiting for the weekly roll to produce one.
    /// The offer is synthesised the way `RivalSystem.buyoutCheck` would
    /// write it; only the roll is skipped.
    static func stateWithOffer(
        strategic: Bool,
        amount: Int,
        seed: UInt64 = 41,
        cash: Int = 200_000,
        reputation: Double = 70
    ) throws -> GameState {
        let balance = try balance()
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        // One tick founds the field; the buyer needs a name.
        Reducer.tick(&state, balance: balance, content: content)
        let buyer = try #require(state.rivals.rivals.first, "no rival was founded on the first tick")
        state.company.cash = cash
        state.company.reputation = reputation
        state.rivals.pendingBuyout = BuyoutOffer(
            rivalID: buyer.id, amount: amount, respondByDay: state.day + 5
        )
        state.rivals.lastBuyoutDay = state.day
        state.rivals.lastBuyoutWasStrategic = strategic
        return state
    }

    // MARK: - Sold up

    /// A distress bid accepted ends the run as `.soldUp`: not a success,
    /// and the reason says what actually happened.
    @Test func aDistressSaleIsSoldUpNotAWin() throws {
        let balance = try Self.balance()
        var state = try Self.stateWithOffer(strategic: false, amount: 20_460)
        let buyerName = try #require(state.rivals.rivals.first?.name)
        let cashBefore = state.company.cash

        let events = Reducer.apply(.acceptBuyout, to: &state, balance: balance, content: Self.content)

        #expect(state.gameOver?.kind == .soldUp)
        #expect(state.gameOver?.kind.isSuccess == false)
        #expect(state.gameOver?.reason == "\(buyerName) bought the name and the desks for $20,460.")
        #expect(state.company.cash == cashBefore + 20_460)
        #expect(state.rivals.pendingBuyout == nil)
        #expect(events.contains(.companySold(rivalID: state.rivals.rivals[0].id, amount: 20_460, day: state.day)))
        #expect(events.contains(.gameOver(day: state.day)))
    }

    /// A strategic offer taken for cash is the acquisition it always was.
    @Test func aStrategicCashSaleIsAnAcquisitionAtThePrice() throws {
        let balance = try Self.balance()
        var state = try Self.stateWithOffer(strategic: true, amount: 1_250_000)
        let buyerName = try #require(state.rivals.rivals.first?.name)
        let cashBefore = state.company.cash

        Reducer.apply(.acceptBuyout, to: &state, balance: balance, content: Self.content)

        #expect(state.gameOver?.kind == .acquired)
        #expect(state.gameOver?.kind.isSuccess == true)
        #expect(state.gameOver?.reason == "Acquired by \(buyerName) for $1,250,000.")
        #expect(state.company.cash == cashBefore + 1_250_000)
    }

    /// The real distress path — a company nobody has heard of, approached
    /// by the weekly roll — lands on the same ending.
    @Test func theWeeklyRollsDistressBidEndsAsSoldUp() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 32, balance: balance)
        state.company.cash = 60_000
        state.company.reputation = 8
        var offered = false
        for _ in 0..<400 {
            Reducer.tick(&state, balance: balance, content: Self.content)
            if state.rivals.pendingBuyout != nil { offered = true; break }
            if state.gameOver != nil { break }
        }
        try #require(offered, "no rival approached a weak company in 400 days")
        #expect(!state.rivals.lastBuyoutWasStrategic)
        Reducer.apply(.acceptBuyout, to: &state, balance: balance, content: Self.content)
        #expect(state.gameOver?.kind == .soldUp)
    }

    /// The new ending survives a save round trip and grades itself.
    @Test func soldUpRoundTripsAndGradesAsAFailure() throws {
        #expect(EndingKind.soldUp.isSuccess == false)
        #expect(EndingKind.soldUp.headline == "Sold up")
        let info = GameOverInfo(day: 140, reason: "r", kind: .soldUp)
        let data = try JSONEncoder().encode(info)
        #expect(try JSONDecoder().decode(GameOverInfo.self, from: data).kind == .soldUp)
    }
}
