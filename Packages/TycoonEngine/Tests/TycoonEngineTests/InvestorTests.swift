import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Investors, the board, and the two endings they lead to: the whole path
/// from a first term sheet through quarterly reviews to either an ousting
/// or an IPO.
@Suite("Investors and the board")
struct InvestorTests {
    private static let content = TestContent.bundled

    private static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    /// Builds a company rich and well-regarded enough that investors call.
    private static func fundableState(
        seed: UInt64 = 21,
        balance: BalanceConfig,
        cash: Int = 2_000_000,
        reputation: Double = 60,
        day: Int = 200
    ) -> GameState {
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        state.company.cash = cash
        state.company.reputation = reputation
        state.day = day
        return state
    }

    // MARK: - Content

    @Test func everyPersonaIsAuthoredAndItsExpectationResolves() throws {
        let personas = Self.content.investors
        #expect(personas.count == 8)
        #expect(Set(personas.map(\.id)).count == personas.count)
        for persona in personas {
            #expect(!persona.name.isEmpty)
            #expect(persona.pitch?.isEmpty == false, "\(persona.id) has no pitch")
            #expect(persona.equityAsk > 0 && persona.equityAsk < 50)
            #expect(persona.checkSize > 0)
            #expect(
                BoardExpectation(rawValue: persona.expects) != nil,
                "\(persona.id) expects unknown \(persona.expects)"
            )
        }
        // At least one cheque with no board attached, and one with.
        #expect(personas.contains { !$0.boardSeat })
        #expect(personas.contains { $0.boardSeat })
    }

    // MARK: - Offers

    /// A company that clears a persona's floors eventually gets a call, and
    /// the offer pauses the timeline.
    @Test func aFundableCompanyEventuallyGetsATermSheet() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance)

        var offer: InvestmentOffer?
        for _ in 0..<200 {
            Reducer.tick(&state, balance: balance, content: Self.content)
            if let pending = state.investors.pendingOffer { offer = pending; break }
        }

        let found = try #require(offer, "no investor approached in 200 days")
        #expect(found.amount > 0)
        #expect(found.equity > 0)
        #expect(found.respondByDay > state.day)
        #expect(GameEvent.investmentOffered(
            investorID: found.investorID, amount: found.amount, equity: found.equity,
            respondByDay: found.respondByDay, day: state.day
        ).pausesTimeline)
    }

    /// Nobody funds a company nobody has heard of.
    @Test func anUnknownCompanyIsNeverApproached() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance, cash: 500, reputation: 5, day: 200)

        for _ in 0..<200 {
            Reducer.tick(&state, balance: balance, content: Self.content)
            if state.gameOver != nil { break }
        }
        #expect(state.investors.pendingOffer == nil)
        #expect(state.investors.rounds.isEmpty)
    }

    /// Taking the money: cash in, equity out, investor on the cap table.
    @Test func acceptingAnOfferMovesCashAndEquity() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance)
        state.investors.pendingOffer = InvestmentOffer(
            investorID: "northgate_seed", investorName: "Northgate Seed",
            amount: 250_000, equity: 12, valuation: 2_000_000,
            takesBoardSeat: true, expects: .shipCadence,
            respondByDay: state.day + 7
        )
        let cashBefore = state.company.cash

        let events = Reducer.apply(.acceptInvestment, to: &state, balance: balance, content: Self.content)
        #expect(state.company.cash == cashBefore + 250_000)
        #expect(state.investors.equityRemaining == 88)
        #expect(state.investors.rounds.count == 1)
        #expect(state.investors.hasBoard)
        #expect(state.investors.boardExpectation == .shipCadence)
        #expect(state.investors.pendingOffer == nil)
        #expect(events.contains { if case .investmentAccepted = $0 { true } else { false } })
        #expect(state.ledger.entries.contains { $0.label.contains("Northgate") })
    }

    /// Turning it down keeps the whole company.
    @Test func decliningKeepsEveryPointOfEquity() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance)
        state.investors.pendingOffer = InvestmentOffer(
            investorID: "marguerite_okafor", investorName: "Marguerite Okafor",
            amount: 25_000, equity: 5, valuation: 500_000,
            takesBoardSeat: false, expects: .shipCadence,
            respondByDay: state.day + 7
        )
        let events = Reducer.apply(.declineInvestment, to: &state, balance: balance, content: Self.content)
        #expect(state.investors.equityRemaining == 100)
        #expect(state.investors.rounds.isEmpty)
        #expect(events.contains { if case .investmentDeclined = $0 { true } else { false } })
    }

    /// An unanswered term sheet is withdrawn, not left hanging.
    @Test func anUnansweredOfferIsWithdrawn() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance)
        state.investors.pendingOffer = InvestmentOffer(
            investorID: "marguerite_okafor", investorName: "Marguerite Okafor",
            amount: 25_000, equity: 5, valuation: 500_000,
            takesBoardSeat: false, expects: .shipCadence,
            respondByDay: state.day + 1
        )
        // Hold the offer cadence off, so what the window ends with is the
        // withdrawal and not a fresh approach.
        state.investors.lastOfferDay = state.day
        for _ in 0..<4 { Reducer.tick(&state, balance: balance, content: Self.content) }
        #expect(state.investors.pendingOffer == nil)
        #expect(state.investors.equityRemaining == 100)
    }

    // MARK: - The board

    /// Missing the board's one number, quarter after quarter, ends with the
    /// founder replaced — the full pressure path.
    @Test func aBoardThatKeepsBeingDisappointedRemovesTheFounder() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance, cash: 400_000, reputation: 60, day: 0)
        state.investors.rounds = [RaisedRound(
            investorID: "lantern_partners", investorName: "Lantern Partners",
            amount: 400_000, equity: 15, valuation: 2_600_000, day: 0,
            takesBoardSeat: true, expects: .headcount
        )]
        state.investors.equityRemaining = 85
        state.investors.lastQuarterHeadcount = 40  // never reachable in a garage

        var sawWarning = false
        var sawOusting = false
        for _ in 0..<(balance.investors.reviewIntervalDays * 6) {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .boardDemandedPlan = event { sawWarning = true }
                if case .founderOusted = event { sawOusting = true }
            }
            if state.gameOver != nil { break }
        }

        #expect(sawWarning, "the board never formally demanded a plan")
        #expect(sawOusting, "the board never replaced the founder")
        #expect(state.gameOver?.kind == .oustedByBoard)
        #expect(state.gameOver?.kind.isSuccess == false)
        #expect(!state.investors.reviews.isEmpty)
    }

    /// Meeting the number pulls the pressure back down.
    @Test func meetingTheNumberRelievesPressure() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance, cash: 400_000, reputation: 60, day: 0)
        state.investors.rounds = [RaisedRound(
            investorID: "meridian_growth", investorName: "Meridian Growth",
            amount: 2_500_000, equity: 20, valuation: 12_000_000, day: 0,
            takesBoardSeat: true, expects: .profitability
        )]
        state.investors.boardPressure = 50
        // The quarter starts with less cash than it ends with: profitable.
        state.investors.lastQuarterCash = 1

        for _ in 0..<balance.investors.reviewIntervalDays {
            Reducer.tick(&state, balance: balance, content: Self.content)
        }
        #expect(state.investors.boardPressure < 50)
        #expect(state.investors.latestReview?.met == true)
        #expect(state.investors.profitableQuarters >= 1)
    }

    /// No board, no reviews — an unfunded founder answers to nobody.
    @Test func anUnfundedFounderIsNeverReviewed() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance, cash: 50_000, reputation: 20, day: 0)
        for _ in 0..<(balance.investors.reviewIntervalDays * 2) {
            Reducer.tick(&state, balance: balance, content: Self.content)
            if state.gameOver != nil { break }
        }
        #expect(state.investors.reviews.isEmpty)
        #expect(state.investors.boardPressure == 0)
    }

    // MARK: - Net worth and the IPO

    @Test func netWorthIsTheWalletPlusTheFoundersSlice() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance)
        state.life.wallet = 10_000
        state.investors.equityRemaining = 50
        let valuation = state.companyValuation(balance: balance)
        #expect(state.founderNetWorth(balance: balance) == 10_000 + valuation / 2)
    }

    /// The IPO gate refuses with a reason until every condition is met, and
    /// then ends the run on the best note in the game.
    @Test func theIPOGateExplainsItselfAndThenOpens() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance, cash: 100_000, reputation: 60)
        #expect(!state.canFileIPO(balance: balance))
        #expect(state.ipoBlocker(balance: balance) != nil)
        #expect(Reducer.apply(.fileIPO, to: &state, balance: balance, content: Self.content).isEmpty)
        #expect(state.gameOver == nil)

        state.company.cash = balance.investors.ipoValuationFloor * 2
        #expect(!state.canFileIPO(balance: balance), "profitable quarters still missing")

        state.investors.profitableQuarters = balance.investors.ipoProfitableQuarters
        #expect(state.canFileIPO(balance: balance))
        #expect(state.ipoBlocker(balance: balance) == nil)

        let walletBefore = state.life.wallet
        let events = Reducer.apply(.fileIPO, to: &state, balance: balance, content: Self.content)
        #expect(state.gameOver?.kind == .ipo)
        #expect(state.gameOver?.kind.isSuccess == true)
        #expect(state.life.wallet > walletBefore)
        #expect(state.investors.ipoDay == state.day)
        #expect(events.contains { if case .wentPublic = $0 { true } else { false } })
    }

    /// Filing twice is impossible.
    @Test func theCompanyCanOnlyGoPublicOnce() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance)
        state.company.cash = balance.investors.ipoValuationFloor * 2
        state.investors.profitableQuarters = balance.investors.ipoProfitableQuarters
        Reducer.apply(.fileIPO, to: &state, balance: balance, content: Self.content)
        #expect(state.investors.ipoDay != nil)
        // The run is over, so the reducer ignores everything.
        #expect(Reducer.apply(.fileIPO, to: &state, balance: balance, content: Self.content).isEmpty)
        #expect(!state.canFileIPO(balance: balance))
    }

    // MARK: - Save compatibility

    @Test func decodesWhenTheKeyIsAbsent() throws {
        let state = try JSONDecoder().decode(InvestorState.self, from: Data("{}".utf8))
        #expect(state == .initial)
        #expect(state.equityRemaining == 100)
        #expect(!state.hasBoard)
    }

    @Test func approachedIDsEncodeSorted() throws {
        var a = InvestorState.initial
        a.approachedInvestorIDs = ["zulu", "alpha", "mike"]
        var b = InvestorState.initial
        b.approachedInvestorIDs = ["mike", "zulu", "alpha"]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(a) == encoder.encode(b))
    }

    @Test func roundTripsEveryField() throws {
        var state = InvestorState.initial
        state.equityRemaining = 73
        state.rounds = [RaisedRound(
            investorID: "x", investorName: "X", amount: 1, equity: 27,
            valuation: 2, day: 3, takesBoardSeat: true, expects: .mrrGrowth
        )]
        state.boardPressure = 44
        state.record(BoardReview(day: 91, expectation: .mrrGrowth, met: false, pressure: 44, note: "n"))
        state.approachedInvestorIDs = ["x"]
        state.ipoDay = 500
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(InvestorState.self, from: data) == state)
    }
}
