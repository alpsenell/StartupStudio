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

    /// A subscription product on the market. `ipoRequiresSubscription` is
    /// on now that WS-A's live ops makes `ReleaseInfo.isSubscription` real,
    /// so the bankers' third condition needs something that bills weekly.
    private static func withSubscriptionProduct(
        _ state: GameState,
        balance: BalanceConfig
    ) -> GameState {
        var state = state
        _ = balance
        state.products.append(Product(
            id: UUID(from: &state.rng),
            name: "Ledger",
            typeID: "saas",
            topicID: "productivity",
            stage: .released(ReleaseInfo(
                launchDay: state.day,
                quality: 80,
                reviews: [Review(outlet: "Test", score: 80, blurb: "")],
                weeklySales: [],
                offMarket: false,
                isSubscription: true
            ))
        ))
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

    /// A board counting desks does not fire a founder for a room with no
    /// desk left in it.
    ///
    /// "One more head than last quarter, every quarter, forever" is not a
    /// demanding board, it is a countdown: every office fills up in the
    /// end, and an expectation the company is physically unable to satisfy
    /// removes the founder on a schedule regardless of how well they run
    /// it. Measured over five game years before this rule, *every* funded
    /// founder was voted out sooner or later while the bootstrapper next
    /// door sailed on — the money was a trap with extra steps. A full
    /// house counts as met; the board's ask becomes "buy the bigger room",
    /// which is a decision the founder can actually make.
    @Test func aBoardCountingDesksAcceptsAFullHouse() throws {
        let balance = try Self.balance()
        // One tick short of a review, so the roster the board grades is
        // the one this test built rather than whatever a quarter of
        // simulated idleness leaves behind.
        var state = Self.fundableState(
            balance: balance, cash: 400_000, reputation: 60,
            day: balance.investors.reviewIntervalDays - 1
        )
        state.investors.rounds = [RaisedRound(
            investorID: "corvus_capital", investorName: "Corvus Capital",
            amount: 1_200_000, equity: 18, valuation: 6_600_000, day: 0,
            takesBoardSeat: true, expects: .headcount
        )]
        state.investors.boardPressure = 50
        // The founder plus two: a garage seats three, and it is full.
        let cap = balance.office(.garage).headcountCap
        while state.headcount < cap {
            state.employees.append(TestPeople.employee(name: "Hire \(state.headcount)"))
        }
        state.investors.lastQuarterHeadcount = state.headcount

        Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(state.headcount == cap, "the garage grew a desk")
        #expect(state.investors.latestReview?.met == true, "a full garage read as a failure to hire")
        #expect(state.investors.boardPressure < 50)
    }

    /// A growth board is satisfied by a record quarter, even one that did
    /// not beat the last by the asked-for margin.
    ///
    /// Ten per cent more revenue than last quarter, compounding without a
    /// ceiling, is the same countdown as the headcount ask: no studio grows
    /// at 46% a year forever, so the board eventually fires everybody. What
    /// it is really watching for is a company sliding off its peak — and
    /// holding a peak is real work, because a shipped product's sales decay
    /// from the week it lands, so the only way to stay level is to keep
    /// launching into it.
    @Test func aGrowthBoardAcceptsTheCompanySPeakAsWellAsItsGrowth() throws {
        let balance = try Self.balance()
        let quarter = balance.investors.reviewIntervalDays

        func run(thisQuarter: Int, peak: Int) throws -> BoardReview? {
            var state = Self.fundableState(
                balance: balance, cash: 400_000, reputation: 60, day: quarter - 1
            )
            state.investors.rounds = [RaisedRound(
                investorID: "lantern_partners", investorName: "Lantern Partners",
                amount: 400_000, equity: 15, valuation: 2_600_000, day: 0,
                takesBoardSeat: true, expects: .mrrGrowth
            )]
            state.investors.lastQuarterRevenue = peak
            state.investors.peakQuarterRevenue = peak
            state.ledger.post(LedgerEntry(
                day: 1, amount: thisQuarter, category: .sales, label: "Sales"
            ))
            Reducer.tick(&state, balance: balance, content: Self.content)
            return state.investors.latestReview
        }

        // Flat against a $10,000 peak: no growth, but no slide either.
        #expect(try run(thisQuarter: 10_000, peak: 10_000)?.met == true)
        // Growth on the nose against a lower peak: met the old way too.
        #expect(try run(thisQuarter: 11_000, peak: 10_000)?.met == true)
        // Off the peak by a fifth: that is what this board is watching for.
        #expect(try run(thisQuarter: 8_000, peak: 10_000)?.met == false)
    }

    /// A board never fires a founder at the meeting where it first says it
    /// is unhappy.
    ///
    /// `boardDemandedPlan` asks the founder for a plan; a plan the board
    /// never gave them a quarter to execute is a formality, not a warning.
    /// It matters because the step is scaled by the persona's patience: a
    /// twelve-week strategic board moves 65 points at a time, which without
    /// this rule takes a founder sitting on 35 straight past the warning
    /// line and out of the door in the same minute.
    @Test func theWarningAndTheVoteAreNeverTheSameMeeting() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance, cash: 400_000, reputation: 60, day: 0)
        state.investors.rounds = [RaisedRound(
            investorID: "kestrel_industries", investorName: "Kestrel Industries",
            amount: 3_500_000, equity: 25, valuation: 14_000_000, day: 0,
            takesBoardSeat: true, expects: .headcount, patienceWeeks: 12
        )]
        state.investors.equityRemaining = 75
        state.investors.lastQuarterHeadcount = 40  // never reachable in a garage
        // 35 + 65 (30 x 26/12) = 100 on the nose, and the warning line is
        // at 60 — so without the rule this single review both warns and
        // votes.
        state.investors.boardPressure = 35

        var warnedOnDay: Int?
        var oustedOnDay: Int?
        for _ in 0..<(balance.investors.reviewIntervalDays * 3) {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .boardDemandedPlan(_, let day) = event, warnedOnDay == nil {
                    warnedOnDay = day
                }
                if case .founderOusted(let day) = event { oustedOnDay = day }
            }
            if state.gameOver != nil { break }
        }
        let warned = try #require(warnedOnDay, "the board never demanded a plan")
        let out = try #require(oustedOnDay, "the board never voted")
        #expect(
            out - warned >= balance.investors.reviewIntervalDays,
            "the founder was warned on day \(warned) and gone on day \(out)"
        )
    }

    /// Raising again buys goodwill, not amnesia: half the pressure goes,
    /// the rest carries, and the new investor's number is added to what
    /// the room is watching rather than replacing it. A full pardon made
    /// the second cheque an escape hatch priced only in equity — the
    /// harness's own investor bot had to be forbidden from re-raising to
    /// measure an ousting at all.
    @Test func anotherRoundHalvesTheGrudgeRatherThanClearingIt() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance)
        state.investors.boardPressure = 80
        state.investors.equityRemaining = 85
        // A board is already in the room, watching revenue.
        state.investors.rounds = [RaisedRound(
            investorID: "first_light", investorName: "First Light",
            amount: 400_000, equity: 15, valuation: 2_600_000, day: 0,
            takesBoardSeat: true, expects: .mrrGrowth, patienceWeeks: 26
        )]
        state.investors.pendingOffer = InvestmentOffer(
            investorID: "corvus_capital", investorName: "Corvus Capital",
            amount: 1_200_000, equity: 18, valuation: 6_600_000,
            takesBoardSeat: true, expects: .headcount, patienceWeeks: 20,
            respondByDay: state.day + 7
        )
        Reducer.apply(.acceptInvestment, to: &state, balance: balance, content: Self.content)
        #expect(
            state.investors.boardPressure == 80 * balance.investors.raisePressureRelief,
            "a cheque should buy goodwill, not a clean slate"
        )
        #expect(state.investors.equityRemaining == 67, "the reprieve was free")
        // And the founder now answers to two numbers, not one.
        #expect(state.investors.boardExpectations.count == 2)
    }

    /// …but only a board seat buys it. An angel's cheque does not silence
    /// the partner already in the room.
    @Test func anAngelChequeDoesNotClearTheBoardroom() throws {
        let balance = try Self.balance()
        var state = Self.fundableState(balance: balance)
        state.investors.boardPressure = 80
        state.investors.pendingOffer = InvestmentOffer(
            investorID: "marguerite_okafor", investorName: "Marguerite Okafor",
            amount: 25_000, equity: 5, valuation: 500_000,
            takesBoardSeat: false, expects: .shipCadence,
            respondByDay: state.day + 7
        )
        Reducer.apply(.acceptInvestment, to: &state, balance: balance, content: Self.content)
        #expect(state.investors.boardPressure == 80)
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
        #expect(Reducer.apply(.fileIPO(), to: &state, balance: balance, content: Self.content).isEmpty)
        #expect(state.gameOver == nil)

        state.company.cash = balance.investors.ipoValuationFloor * 2
        #expect(!state.canFileIPO(balance: balance), "profitable quarters still missing")

        state.investors.profitableQuarters = balance.investors.ipoProfitableQuarters
        #expect(!state.canFileIPO(balance: balance), "recurring revenue still missing")
        #expect(
            state.ipoBlocker(balance: balance)
                == "Nothing on the market bills monthly. They want recurring revenue."
        )

        state = Self.withSubscriptionProduct(state, balance: balance)
        #expect(state.canFileIPO(balance: balance))
        #expect(state.ipoBlocker(balance: balance) == nil)

        let walletBefore = state.life.wallet
        let events = Reducer.apply(.fileIPO(), to: &state, balance: balance, content: Self.content)
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
        state = Self.withSubscriptionProduct(state, balance: balance)
        Reducer.apply(.fileIPO(), to: &state, balance: balance, content: Self.content)
        #expect(state.investors.ipoDay != nil)
        // The run is over, so the reducer ignores everything.
        #expect(Reducer.apply(.fileIPO(), to: &state, balance: balance, content: Self.content).isEmpty)
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
