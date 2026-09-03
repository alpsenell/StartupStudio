import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Buy Back the Board (iteration 5, WS-B): a seated round can be paid out
/// of the cap table, its ask leaves the room by construction, and the
/// equity comes home to the exit.
@Suite("Buy back the board")
struct BuybackTests {
    static let content = TestContent.bundled

    static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    static let lantern = RaisedRound(
        investorID: "lantern_partners", investorName: "Lantern Partners",
        amount: 400_000, equity: 15, valuation: 2_600_000, day: 0,
        takesBoardSeat: true, expects: .headcount
    )
    static let meridian = RaisedRound(
        investorID: "meridian_growth", investorName: "Meridian Growth",
        amount: 2_500_000, equity: 20, valuation: 12_000_000, day: 30,
        takesBoardSeat: true, expects: .profitability
    )

    /// A company with the given rounds seated and the room at `pressure`.
    static func seated(
        _ rounds: [RaisedRound],
        cash: Int = 2_000_000,
        pressure: Double = 40,
        seed: UInt64 = 51
    ) throws -> GameState {
        let balance = try balance()
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        state.company.cash = cash
        state.company.reputation = 60
        state.investors.rounds = rounds
        state.investors.equityRemaining = 100 - rounds.reduce(0) { $0 + $1.equity }
        state.investors.boardPressure = pressure
        state.investors.approachedInvestorIDs = Set(rounds.map(\.investorID))
        return state
    }

    // MARK: - The price

    /// `equity% × valuation × premium × (1 + pressure/100)`: the slice at
    /// the forward premium they paid, surcharged by the temperature of
    /// the room.
    @Test func thePriceIsTheSliceAtThePremiumPlusThePressure() throws {
        let balance = try Self.balance()
        var state = try Self.seated([Self.lantern], pressure: 40)
        let valuation = Double(state.companyValuation(balance: balance))
        #expect(balance.investors.buybackPremium == 2.5)
        #expect(
            state.buybackPrice(for: Self.lantern, balance: balance)
                == Int((0.15 * valuation * 2.5 * 1.4).rounded())
        )
        state.investors.boardPressure = 0
        #expect(
            state.buybackPrice(for: Self.lantern, balance: balance)
                == Int((0.15 * valuation * 2.5).rounded())
        )
        // A founder at 80 pays 1.8× to end the meeting.
        state.investors.boardPressure = 80
        #expect(
            state.buybackPrice(for: Self.lantern, balance: balance)
                == Int((0.15 * valuation * 2.5 * 1.8).rounded())
        )
        // Cheapest when small and broke: the same slice of a smaller company.
        state.company.cash = 50_000
        state.investors.boardPressure = 0
        #expect(state.buybackPrice(for: Self.lantern, balance: balance) < Int((0.15 * valuation * 2.5).rounded()))
    }

    // MARK: - The action

    /// Cash out with a ledger line, the round to `boughtOut` with the day
    /// and the price, the equity home, the ask out of the room, the
    /// pressure gone with the last seat, and the event.
    @Test func buyingBackTheOnlyRoundEmptiesTheRoom() throws {
        let balance = try Self.balance()
        var state = try Self.seated([Self.lantern], pressure: 40)
        state.day = 400
        let price = state.buybackPrice(for: Self.lantern, balance: balance)
        let cashBefore = state.company.cash
        #expect(state.investors.boardExpectations == [.headcount])
        #expect(state.investors.hasBoard)

        let events = Reducer.apply(
            .buyBackRound(investorID: "lantern_partners"),
            to: &state, balance: balance, content: Self.content
        )

        #expect(events == [.roundBoughtBack(investorID: "lantern_partners", amount: price, day: 400)])
        #expect(state.company.cash == cashBefore - price)
        #expect(state.ledger.entries.last?.label == "Bought out Lantern Partners")
        #expect(state.ledger.entries.last?.amount == -price)
        #expect(state.ledger.entries.last?.category == .other)
        #expect(state.investors.rounds.isEmpty)
        #expect(state.investors.boughtOut.count == 1)
        #expect(state.investors.boughtOut.first?.investorID == "lantern_partners")
        #expect(state.investors.boughtOut.first?.boughtOutDay == 400)
        #expect(state.investors.boughtOut.first?.buybackPrice == price)
        #expect(state.investors.equityRemaining == 100)
        #expect(state.investors.boardExpectations.isEmpty)
        #expect(!state.investors.hasBoard)
        #expect(state.investors.boardExpectation == nil)
        #expect(state.investors.boardPressure == 0)
        #expect(state.investors.totalRaised == 0, "a bought-out round is no longer money raised")
        #expect(state.investors.approachedInvestorIDs.contains("lantern_partners"), "they do not come back")
    }

    /// With no seated round left, the next quarterly review has nobody to
    /// grade for: no verdict, no pressure, nothing on the record.
    @Test func buyingBackTheOnlyRoundStopsTheNextReview() throws {
        let balance = try Self.balance()
        var control = try Self.seated([Self.lantern], pressure: 40)
        control.investors.lastQuarterHeadcount = 40  // a miss, every quarter
        var bought = control
        Reducer.apply(
            .buyBackRound(investorID: "lantern_partners"),
            to: &bought, balance: balance, content: Self.content
        )
        try #require(bought.investors.rounds.isEmpty)

        func reviewed(_ state: inout GameState) -> Bool {
            var saw = false
            for _ in 0..<balance.investors.reviewIntervalDays {
                for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                    if case .boardReviewed = event { saw = true }
                }
            }
            return saw
        }
        #expect(reviewed(&control), "the control's board never met, so the buyback measures nothing")
        #expect(!reviewed(&bought), "a board with no seat still reviewed the founder")
        #expect(bought.investors.reviews.isEmpty)
        #expect(bought.investors.boardPressure == 0)
        #expect(control.investors.boardPressure > 40)
    }

    /// Buying back one of two boards takes only its ask out of the room;
    /// the other keeps watching, and the pressure stays.
    @Test func buyingBackOneOfTwoBoardsLeavesTheOthersAsk() throws {
        let balance = try Self.balance()
        var state = try Self.seated([Self.lantern, Self.meridian], cash: 20_000_000, pressure: 55)
        #expect(state.investors.boardExpectations == [.headcount, .profitability])

        Reducer.apply(
            .buyBackRound(investorID: "lantern_partners"),
            to: &state, balance: balance, content: Self.content
        )

        #expect(state.investors.rounds.map(\.investorID) == ["meridian_growth"])
        #expect(state.investors.boardExpectations == [.profitability])
        #expect(state.investors.boardExpectation == .profitability)
        #expect(state.investors.equityRemaining == 80)
        #expect(state.investors.boardPressure == 55)
    }

    /// Without the cash the action is refused and nothing moves.
    @Test func buyingBackNeedsTheCash() throws {
        let balance = try Self.balance()
        // The price reads the valuation, which reads the cash: at 15% and
        // 2.5× under a 40-pressure room the price is 0.525 of a valuation
        // that is the cash plus the reputation term, so an account under
        // about $99k cannot cover its own buyback.
        var state = try Self.seated([Self.lantern], cash: 50_000)
        let short = state.buybackPrice(for: Self.lantern, balance: balance)
        try #require(state.company.cash < short)
        let before = state

        let events = Reducer.apply(
            .buyBackRound(investorID: "lantern_partners"),
            to: &state, balance: balance, content: Self.content
        )

        #expect(events.isEmpty)
        #expect(state.investors == before.investors)
        #expect(state.company.cash == before.company.cash)
        #expect(state.ledger.entries.count == before.ledger.entries.count)
    }

    /// A round that is not on the table, or a run that has ended, is ignored.
    @Test func anUnknownRoundOrAFinishedRunIsIgnored() throws {
        let balance = try Self.balance()
        var state = try Self.seated([Self.lantern])
        #expect(Reducer.apply(
            .buyBackRound(investorID: "nobody"), to: &state, balance: balance, content: Self.content
        ).isEmpty)
        state.gameOver = GameOverInfo(day: state.day, reason: "r", kind: .oustedByBoard)
        #expect(Reducer.apply(
            .buyBackRound(investorID: "lantern_partners"), to: &state, balance: balance, content: Self.content
        ).isEmpty)
        #expect(state.investors.rounds.count == 1)
    }

    // MARK: - What it buys

    /// The whole point: the founder's slice at the bell. At the same
    /// valuation, buying back 15% raises the IPO proceeds by exactly
    /// `15% × valuation × 1.4`.
    @Test func buyingBackRaisesIPOProceedsByExactlyTheSlice() throws {
        let balance = try Self.balance()
        var state = try Self.seated([Self.lantern], cash: 6_000_000, pressure: 20)
        state.investors.profitableQuarters = 3
        state.products.append(Product(
            id: UUID(), name: "Ledger", typeID: "saas", topicID: "productivity",
            stage: .released(ReleaseInfo(
                launchDay: 0, quality: 80,
                reviews: [Review(outlet: "Test", score: 80, blurb: "")],
                weeklySales: [], offMarket: false, isSubscription: true
            ))
        ))
        try #require(state.canFileIPO(balance: balance))
        let valuation = state.companyValuation(balance: balance)

        func proceeds(_ state: GameState) -> Int? {
            var copy = state
            for event in Reducer.apply(.fileIPO, to: &copy, balance: balance, content: Self.content) {
                if case let .wentPublic(proceeds, _) = event { return proceeds }
            }
            return nil
        }
        let before = try #require(proceeds(state))
        #expect(before == Int((Double(valuation) * 1.4 * 0.85).rounded()))

        let price = state.buybackPrice(for: Self.lantern, balance: balance)
        Reducer.apply(
            .buyBackRound(investorID: "lantern_partners"),
            to: &state, balance: balance, content: Self.content
        )
        try #require(state.investors.equityRemaining == 100)
        // Put the price back so the valuation is the same one: the claim
        // is about the equity term, and the cash term moves with it.
        state.company.cash += price
        #expect(state.companyValuation(balance: balance) == valuation)
        let after = try #require(proceeds(state))
        #expect(after == Int((Double(valuation) * 1.4).rounded()))
        #expect(
            abs((after - before) - Int((0.15 * Double(valuation) * 1.4).rounded())) <= 1,
            "the bell paid \(after - before) more for 15% of \(valuation)"
        )
    }

    // MARK: - Saves

    /// Bought-out rounds round-trip, and a save from before the buyback
    /// existed reads as none, with its seated rounds untouched.
    @Test func boughtOutRoundsRoundTripAndDecodeEmpty() throws {
        var state = InvestorState.initial
        var round = Self.lantern
        round.boughtOutDay = 400
        round.buybackPrice = 1_234_567
        state.boughtOut = [round]
        state.rounds = [Self.meridian]
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(InvestorState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.boughtOut.first?.boughtOutDay == 400)
        #expect(decoded.boughtOut.first?.buybackPrice == 1_234_567)

        let legacy = try JSONDecoder().decode(InvestorState.self, from: Data("{}".utf8))
        #expect(legacy.boughtOut.isEmpty)
        #expect(legacy == .initial)

        // A round written before the fields existed decodes as still seated.
        let old = Data(#"{"investorID":"x","investorName":"X","amount":1,"equity":5,"valuation":2,"day":3,"takesBoardSeat":true,"expects":"headcount"}"#.utf8)
        let seated = try JSONDecoder().decode(RaisedRound.self, from: old)
        #expect(seated.boughtOutDay == nil)
        #expect(seated.buybackPrice == nil)

        // And through the whole game state, byte-identical on a second pass.
        let balance = try Self.balance()
        var game = try Self.seated([Self.lantern, Self.meridian], cash: 20_000_000)
        Reducer.apply(
            .buyBackRound(investorID: "lantern_partners"),
            to: &game, balance: balance, content: Self.content
        )
        for _ in 0..<30 { Reducer.tick(&game, balance: balance, content: Self.content) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(game)
        let back = try JSONDecoder().decode(GameState.self, from: bytes)
        #expect(back == game)
        #expect(back.investors.boughtOut.count == 1)
        #expect(try encoder.encode(back) == bytes)
    }
}
