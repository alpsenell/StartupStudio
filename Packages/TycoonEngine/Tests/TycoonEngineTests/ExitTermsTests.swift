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

    // MARK: - The earn-out

    /// Signs the earn-out on a strategic offer and pins the acquirer's
    /// number to profitability, which a test can then meet or miss by
    /// moving the quarter's opening balance.
    static func signed(price: Int) throws -> (GameState, BalanceConfig) {
        let balance = try balance()
        var state = try stateWithOffer(strategic: true, amount: price, cash: 500_000)
        Reducer.apply(.acceptBuyoutEarnOut, to: &state, balance: balance, content: content)
        try #require(state.investors.earnOut != nil)
        state.investors.earnOut?.expectation = .profitability
        return (state, balance)
    }

    /// Ticks to the next review day and returns that day's events.
    static func tickToNextReview(_ state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        let interval = balance.investors.reviewIntervalDays
        var events: [GameEvent] = []
        repeat {
            events = Reducer.tick(&state, balance: balance, content: content)
        } while state.day % interval != 0 && state.gameOver == nil
        return events
    }

    /// Signing: 60% lands today, the team takes it badly, the acquirer's
    /// seat watches the first number the company would miss, the room now
    /// has that seat in it, and the quarter's clock restarts so the cheque
    /// is not a profitable quarter.
    @Test func signingTheEarnOutPaysSixtyPercentAndSeatsTheAcquirer() throws {
        let balance = try Self.balance()
        var state = try Self.stateWithOffer(strategic: true, amount: 1_000_000)
        let worker = TestPeople.employee()
        state.employees.append(worker)
        let moraleBefore = worker.morale
        let expected = state.earnOutExpectation(balance: balance)
        let cashBefore = state.company.cash
        let buyer = try #require(state.rivals.rivals.first)

        let events = Reducer.apply(
            .acceptBuyoutEarnOut, to: &state, balance: balance, content: Self.content
        )

        let earnOut = try #require(state.investors.earnOut)
        #expect(earnOut.buyerName == buyer.name)
        #expect(earnOut.buyerRivalID == buyer.id)
        #expect(earnOut.price == 1_000_000)
        #expect(earnOut.paid == 600_000)
        #expect(earnOut.outstanding == 400_000)
        #expect(earnOut.expectation == expected)
        #expect(earnOut.remainingReviews == 2)
        #expect(earnOut.patienceWeeks == 12)
        #expect(earnOut.missedReviews == 0)
        #expect(state.company.cash == cashBefore + 600_000)
        #expect(state.employee(id: worker.id)?.morale == moraleBefore - 8)
        #expect(
            state.investors.lastQuarterCash == state.company.cash,
            "the cheque that just landed must not be the profitable quarter"
        )
        #expect(state.investors.boardExpectations == [expected])
        #expect(state.investors.boardExpectation == expected)
        #expect(state.rivals.pendingBuyout == nil)
        #expect(state.gameOver == nil)
        #expect(events == [
            .earnOutSigned(rivalID: buyer.id, upfront: 600_000, price: 1_000_000, day: state.day),
        ])
        #expect(state.ledger.entries.last?.amount == 600_000)
    }

    /// A distress bid has no earn-out: the action is refused and the offer
    /// stays on the table.
    @Test func aDistressBidHasNoEarnOut() throws {
        let balance = try Self.balance()
        var state = try Self.stateWithOffer(strategic: false, amount: 20_460)
        let events = Reducer.apply(
            .acceptBuyoutEarnOut, to: &state, balance: balance, content: Self.content
        )
        #expect(events.isEmpty)
        #expect(state.investors.earnOut == nil)
        #expect(state.rivals.pendingBuyout != nil)
        #expect(state.gameOver == nil)
    }

    /// The acquirer's number is the first one, in the board's own order,
    /// the company would miss this morning; a company passing all four is
    /// held to profitability. Arithmetic on state, no draws.
    @Test func theAcquirerWatchesTheFirstNumberTheCompanyWouldMiss() throws {
        let balance = try Self.balance()
        // No sales yet: the first ask, revenue growth, is the miss.
        let fresh = try Self.stateWithOffer(strategic: true, amount: 500_000)
        #expect(fresh.earnOutExpectation(balance: balance) == .mrrGrowth)

        // Sales but nothing shipped this quarter: the second ask.
        var selling = fresh
        selling.ledger.post(LedgerEntry(day: selling.day, amount: 50_000, category: .sales, label: "Sales"))
        #expect(selling.earnOutExpectation(balance: balance) == .shipCadence)

        // Passing everything: profitability, by default.
        var thriving = selling
        for name in ["Ledger", "Quill"] {
            thriving.products.append(Product(
                id: UUID(),
                name: name,
                typeID: "saas",
                topicID: "productivity",
                stage: .released(ReleaseInfo(
                    launchDay: thriving.day, quality: 80,
                    reviews: [Review(outlet: "Test", score: 80, blurb: "")],
                    weeklySales: [], offMarket: false, isSubscription: true
                ))
            ))
        }
        thriving.investors.lastQuarterHeadcount = 0
        thriving.investors.lastQuarterCash = 1
        #expect(thriving.earnOutExpectation(balance: balance) == .profitability)

        // The same arithmetic, twice: no draw moved.
        #expect(thriving.worldRNG == fresh.worldRNG)
        #expect(thriving.investorRNG == fresh.investorRNG)
        #expect(thriving.rng == fresh.rng)
    }

    /// Two met reviews pay the whole price, to the dollar, and the run
    /// ends `.acquired` on the second review day.
    @Test func meetingBothReviewsPaysTheWholePriceToTheDollar() throws {
        // 60% and two 20% tranches of this do not round to it; the last
        // review pays what is left, so the total is exact.
        var (state, balance) = try Self.signed(price: 1_000_003)
        let buyerID = try #require(state.investors.earnOut?.buyerRivalID)
        #expect(state.investors.earnOut?.paid == 600_002)

        state.investors.lastQuarterCash = 1
        let first = Self.tickToNextReview(&state, balance: balance)
        #expect(state.day == 91)
        #expect(first.contains(.earnOutReviewed(met: true, paid: 200_001, remainingReviews: 1, day: 91)))
        #expect(state.investors.earnOut?.paid == 800_003)
        #expect(state.gameOver == nil)

        state.investors.lastQuarterCash = 1
        let second = Self.tickToNextReview(&state, balance: balance)
        #expect(state.day == 182)
        #expect(second.contains(.earnOutReviewed(met: true, paid: 200_000, remainingReviews: 0, day: 182)))
        #expect(second.contains(.companySold(rivalID: buyerID, amount: 1_000_003, day: 182)))
        #expect(state.investors.earnOut?.paid == 1_000_003)
        #expect(state.investors.earnOut?.outstanding == 0)
        #expect(state.gameOver?.kind == .acquired)
        #expect(state.gameOver?.kind.isSuccess == true)
        #expect(state.gameOver?.day == 182)
        #expect(state.gameOver?.reason.contains("every dollar") == true)
        let tranches = state.ledger.entries.filter { $0.label.hasSuffix("earn-out") }.map(\.amount)
        #expect(tranches == [200_001, 200_000])
    }

    /// A miss pays nothing and lands past the warning line — the acquirer
    /// is a twelve-week board — and a met second review still closes the
    /// sale, at 80%.
    @Test func missingOneReviewForfeitsItsTranche() throws {
        var (state, balance) = try Self.signed(price: 1_000_000)

        // An opening balance the quarter cannot reach: a miss.
        state.investors.lastQuarterCash = Int.max / 2
        let first = Self.tickToNextReview(&state, balance: balance)
        #expect(first.contains(.earnOutReviewed(met: false, paid: 0, remainingReviews: 1, day: 91)))
        #expect(first.contains(.boardDemandedPlan(pressure: state.investors.boardPressure, day: 91)))
        #expect(state.investors.earnOut?.missedReviews == 1)
        #expect(state.investors.earnOut?.paid == 600_000)
        #expect(state.investors.boardPressure >= balance.investors.boardWarningPressure)
        #expect(state.gameOver == nil)

        state.investors.lastQuarterCash = 1
        let second = Self.tickToNextReview(&state, balance: balance)
        #expect(second.contains(.earnOutReviewed(met: true, paid: 200_000, remainingReviews: 0, day: 182)))
        #expect(state.investors.earnOut?.paid == 800_000)
        #expect(state.investors.earnOut?.outstanding == 200_000)
        #expect(state.gameOver?.kind == .acquired)
        #expect(state.gameOver?.reason.contains("$200,000 of the $1,000,000 earn-out forfeited") == true)
    }

    /// Two misses: the acquirer brings in their own CEO. The ordinary
    /// ousting, keeping the 60% that was paid.
    @Test func missingBothReviewsIsAnOustingKeepingTheUpfront() throws {
        var (state, balance) = try Self.signed(price: 1_000_000)
        let cashAfterSigning = state.company.cash

        state.investors.lastQuarterCash = Int.max / 2
        _ = Self.tickToNextReview(&state, balance: balance)
        state.investors.lastQuarterCash = Int.max / 2
        let second = Self.tickToNextReview(&state, balance: balance)

        #expect(second.contains(.earnOutReviewed(met: false, paid: 0, remainingReviews: 0, day: 182)))
        #expect(second.contains(.founderOusted(day: 182)))
        #expect(state.gameOver?.kind == .oustedByBoard)
        #expect(state.gameOver?.kind.isSuccess == false)
        #expect(state.gameOver?.day == 182)
        #expect(state.investors.earnOut?.paid == 600_000)
        #expect(state.investors.earnOut?.missedReviews == 2)
        #expect(state.gameOver?.reason.contains("$600,000 of $1,000,000") == true)
        // Nothing was clawed back: only the quarter's burn left the account.
        #expect(state.company.cash > cashAfterSigning - 50_000)
        #expect(state.company.cash > 500_000)
    }

    /// A company being paid for over an earn-out is already sold: no term
    /// sheet arrives, and the bell is off.
    @Test func anEarnOutClosesTheTermSheetAndTheBell() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 21, balance: balance)
        state.company.cash = 6_000_000
        state.company.reputation = 60
        state.investors.profitableQuarters = 3
        state.products.append(Product(
            id: UUID(), name: "Ledger", typeID: "saas", topicID: "productivity",
            stage: .released(ReleaseInfo(
                launchDay: 0, quality: 80,
                reviews: [Review(outlet: "Test", score: 80, blurb: "")],
                weeklySales: [], offMarket: false, isSubscription: true
            ))
        ))
        #expect(state.canFileIPO(balance: balance))

        let earnOut = EarnOut(
            buyerName: "Quill Systems", buyerRivalID: UUID(), price: 2_000_000, paid: 1_200_000,
            expectation: .shipCadence, remainingReviews: 99, patienceWeeks: 12
        )
        state.investors.earnOut = earnOut
        #expect(!state.canFileIPO(balance: balance))
        #expect(state.ipoBlocker(balance: balance)?.contains("Quill Systems") == true)
        let filed = Reducer.apply(.fileIPO, to: &state, balance: balance, content: Self.content)
        #expect(filed.isEmpty)
        #expect(state.gameOver == nil)

        // The same fundable company, with and without the acquirer.
        var control = state
        control.investors.earnOut = nil
        control.day = 200
        state.day = 200
        func offered(_ state: inout GameState) -> Bool {
            for _ in 0..<200 {
                for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                    if case .investmentOffered = event { return true }
                }
                if state.gameOver != nil { return false }
            }
            return false
        }
        #expect(offered(&control), "the control was never approached, so the guard measures nothing")
        #expect(!offered(&state), "a term sheet arrived for a company that is being bought")
    }

    /// The earn-out round-trips inside the investor state, and a save
    /// written before it existed reads as none.
    @Test func theEarnOutRoundTripsAndDecodesNilWhenAbsent() throws {
        var state = InvestorState.initial
        state.earnOut = EarnOut(
            buyerName: "Quill Systems", buyerRivalID: UUID(), price: 1_000_000, paid: 800_000,
            expectation: .headcount, remainingReviews: 1, patienceWeeks: 12, missedReviews: 1
        )
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(InvestorState.self, from: data) == state)

        let legacy = try JSONDecoder().decode(InvestorState.self, from: Data("{}".utf8))
        #expect(legacy.earnOut == nil)
        #expect(legacy == .initial)

        // And through the whole game state, mid earn-out.
        var (game, balance) = try Self.signed(price: 750_000)
        for _ in 0..<40 { Reducer.tick(&game, balance: balance, content: Self.content) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(game)
        let decoded = try JSONDecoder().decode(GameState.self, from: bytes)
        #expect(decoded == game)
        #expect(decoded.investors.earnOut?.price == 750_000)
        #expect(try encoder.encode(decoded) == bytes)
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
