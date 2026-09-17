import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Iteration 7 (R5) — endless.
///
/// Two of the six endings are the founder's own decision rather than
/// somebody else's: the bell at the IPO, and calling it built while still
/// owning all of it. Both used to close the run for good. Now they can be
/// played past, and the run that carries on is the same simulation with
/// three doors shut — no board room, no term sheets, no buyers — and one
/// door still open: the company can still go broke.
@Suite("Endless")
struct EndlessTests {
    private static let content = TestContent.bundled

    private static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    // MARK: - Fixtures

    /// A company rich and well-regarded enough to ring the bell, built the
    /// same way `InvestorTests` builds one.
    private static func ipoReadyState(seed: UInt64 = 21, balance: BalanceConfig) -> GameState {
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        state.day = 200
        state.company.cash = balance.investors.ipoValuationFloor * 2
        state.company.reputation = 60
        state.investors.profitableQuarters = balance.investors.ipoProfitableQuarters
        state.products.append(Product(
            id: UUID(from: &state.rng),
            name: "Ledger",
            typeID: "saas_platform",
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

    /// The same company, one day after the bell.
    private static func publicState(seed: UInt64 = 21, balance: BalanceConfig) throws -> GameState {
        var state = ipoReadyState(seed: seed, balance: balance)
        #expect(state.canFileIPO(balance: balance))
        Reducer.apply(.fileIPO(), to: &state, balance: balance, content: content)
        try #require(state.gameOver?.kind == .ipo)
        return state
    }

    /// An ending nobody can play past, forced onto a live state.
    private static func ended(_ kind: EndingKind, balance: BalanceConfig) -> GameState {
        var state = GameState.newGame(companyName: "Over", seed: 3, balance: balance)
        state.day = 120
        state.gameOver = GameOverInfo(day: state.day, reason: "it ended", kind: kind)
        return state
    }

    // MARK: - Continuing

    /// The IPO: the ending is remembered, the game-over is cleared, and
    /// the day the founder decided is on the record.
    @Test func continuingAfterAnIPOClearsTheEndingAndKeepsIt() throws {
        let balance = try Self.balance()
        var state = try Self.publicState(balance: balance)
        let endingDay = state.day

        let events = Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)

        #expect(state.gameOver == nil)
        #expect(state.epilogue == Epilogue(ending: .ipo, day: endingDay))
        #expect(events == [.continuedAfterEnding(ending: .ipo, day: endingDay)])
        #expect(state.eventLog.contains(.continuedAfterEnding(ending: .ipo, day: endingDay)))
        // The company is still public: nothing about the ending was undone.
        #expect(state.investors.ipoDay == endingDay)
    }

    /// *Still yours* is the other one the founder chooses.
    @Test func continuingAfterStillYoursIsAllowed() throws {
        let balance = try Self.balance()
        var state = Self.ended(.independent, balance: balance)

        let events = Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)

        #expect(state.gameOver == nil)
        #expect(state.epilogue?.ending == .independent)
        #expect(events.count == 1)
    }

    /// The four endings that hand the company to somebody else cannot be
    /// played past — there is nothing left to run.
    @Test func everyOtherEndingRefusesToCarryOn() throws {
        let balance = try Self.balance()
        for kind in [EndingKind.bankruptcy, .oustedByBoard, .soldUp, .acquired] {
            var state = Self.ended(kind, balance: balance)
            let events = Reducer.apply(
                .continueAfterEnding, to: &state, balance: balance, content: Self.content
            )
            #expect(events.isEmpty, "\(kind.rawValue) should refuse")
            #expect(state.epilogue == nil, "\(kind.rawValue) should refuse")
            #expect(state.gameOver?.kind == kind, "\(kind.rawValue) is still over")
        }
    }

    /// A live game has nothing to continue past, and a run already in its
    /// epilogue cannot start a second one.
    @Test func aLiveGameAndASecondHelpingAreBothRefused() throws {
        let balance = try Self.balance()
        var live = GameState.newGame(companyName: "Live", seed: 15, balance: balance)
        #expect(Reducer.apply(.continueAfterEnding, to: &live, balance: balance, content: Self.content).isEmpty)
        #expect(live.epilogue == nil)

        var state = try Self.publicState(balance: balance)
        Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)
        let epilogue = state.epilogue
        state.gameOver = GameOverInfo(day: state.day, reason: "again", kind: .independent)
        #expect(Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content).isEmpty)
        #expect(state.epilogue == epilogue, "the first epilogue stands")
        #expect(state.gameOver != nil)
    }

    // MARK: - The three closed doors

    /// A year of an epilogue run: no board grades it, no investor writes
    /// to it, nobody bids for it.
    @Test func theEpilogueYearHasNoBoardNoTermSheetAndNoBuyer() throws {
        let balance = try Self.balance()
        var state = try Self.publicState(balance: balance)
        Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)

        var events: [GameEvent] = []
        for _ in 0..<GameState.daysPerYear {
            events.append(contentsOf: Reducer.tick(&state, balance: balance, content: Self.content))
            if state.gameOver != nil { break }
        }

        #expect(state.day == 200 + GameState.daysPerYear, "the whole year ran, and nothing ended it")
        for event in events {
            switch event {
            case .boardReviewed, .boardDemandedPlan, .earnOutReviewed:
                Issue.record("the board sat again: \(event)")
            case .investmentOffered, .investmentAccepted:
                Issue.record("a round was seated: \(event)")
            case .buyoutOffered, .earnOutSigned:
                Issue.record("a buyer called: \(event)")
            default:
                break
            }
        }
        #expect(state.investors.pendingOffer == nil)
        #expect(state.rivals.pendingBuyout == nil)
        #expect(state.investors.reviews.isEmpty)
    }

    /// The two endings the founder declares are behind them, so both gates
    /// read false however good the numbers get.
    @Test func theEndingsTheFounderDeclaresAreClosed() throws {
        let balance = try Self.balance()
        var state = try Self.publicState(balance: balance)
        Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)

        state.investors.profitableQuarters = 99
        state.investors.equityRemaining = 100
        state.company.reputation = 99
        state.company.cash = balance.investors.ipoValuationFloor * 4
        state.day = balance.investors.independentMinDay + 1

        #expect(!state.canFileIPO(balance: balance))
        #expect(!state.canStayIndependent(balance: balance))
        #expect(state.ipoBlocker(balance: balance) != nil)
        #expect(state.independenceBlocker(balance: balance) != nil)
        #expect(Reducer.apply(.fileIPO(), to: &state, balance: balance, content: Self.content).isEmpty)
        #expect(
            Reducer.apply(.declareIndependence, to: &state, balance: balance, content: Self.content).isEmpty
        )
        #expect(state.gameOver == nil, "neither ending fired")
    }

    /// A term sheet already on the desk when the bell rang cannot be
    /// signed afterwards, and it lapses on its own deadline.
    @Test func aTermSheetLeftOnTheDeskCannotBeSignedAfterwards() throws {
        let balance = try Self.balance()
        var state = try Self.publicState(balance: balance)
        state.investors.pendingOffer = InvestmentOffer(
            investorID: "northgate_seed", investorName: "Northgate Seed",
            amount: 250_000, equity: 12, valuation: 2_000_000,
            takesBoardSeat: true, expects: .shipCadence,
            respondByDay: state.day + 3
        )
        Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)

        #expect(Reducer.apply(.acceptInvestment, to: &state, balance: balance, content: Self.content).isEmpty)
        #expect(state.investors.rounds.isEmpty)
        #expect(!state.investors.hasBoard)

        for _ in 0..<10 { Reducer.tick(&state, balance: balance, content: Self.content) }
        #expect(state.investors.pendingOffer == nil, "it lapsed")
    }

    // MARK: - The door that stays open

    /// Bankruptcy is still on the table: an epilogue is a company that
    /// still has to make payroll.
    @Test func bankruptcyIsStillPossibleInTheEpilogue() throws {
        var balance = try Self.balance()
        var state = try Self.publicState(balance: balance)
        Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)

        // The money is gone and the rent is enormous: the same doom the
        // lifecycle suite uses, applied to a company past its ending.
        balance.weeklyOperatingCost = 1_000_000
        balance.bankruptcyGraceDays = 2
        state.company.cash = 0

        for _ in 0..<GameState.daysPerYear {
            Reducer.tick(&state, balance: balance, content: Self.content)
            if state.gameOver != nil { break }
        }
        #expect(state.gameOver?.kind == .bankruptcy)
        #expect(state.epilogue?.ending == .ipo, "and the biography still knows it was public")
    }

    // MARK: - Determinism

    /// The engine is still the engine: the same seed, continued and run
    /// for a year, is the same bytes twice.
    @Test func theSameSeedContinuedRunsTheSameYearTwice() throws {
        let balance = try Self.balance()

        func year(seed: UInt64) throws -> Data {
            var state = try Self.publicState(seed: seed, balance: balance)
            Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)
            for _ in 0..<GameState.daysPerYear {
                Reducer.tick(&state, balance: balance, content: Self.content)
                if state.gameOver != nil { break }
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(state)
        }

        #expect(try year(seed: 21) == year(seed: 21))
        #expect(try year(seed: 21) != year(seed: 22), "and a different seed is a different year")
    }

    /// An epilogue is optional state: it encodes only when set, and a save
    /// written before it existed still decodes.
    @Test func theEpilogueRoundTrips() throws {
        let balance = try Self.balance()
        var state = try Self.publicState(balance: balance)
        Reducer.apply(.continueAfterEnding, to: &state, balance: balance, content: Self.content)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded.epilogue == state.epilogue)
        #expect(decoded.gameOver == nil)
    }
}

/// The clock after the ending: the loop that an ending cancelled for good
/// has to come back, or "Keep running it" hands the player a frozen game.
@MainActor
@Suite("Endless — the clock")
struct EndlessClockTests {
    private static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled
    }()

    private func publicEngine() -> GameEngine {
        var state = GameState.newGame(companyName: "Acme", seed: 21, balance: Self.balance)
        state.day = 200
        state.company.cash = Self.balance.investors.ipoValuationFloor * 2
        state.company.reputation = 60
        state.investors.profitableQuarters = Self.balance.investors.ipoProfitableQuarters
        state.products.append(Product(
            id: UUID(from: &state.rng),
            name: "Ledger",
            typeID: "saas_platform",
            topicID: "productivity",
            stage: .released(ReleaseInfo(
                launchDay: state.day, quality: 80,
                reviews: [Review(outlet: "Test", score: 80, blurb: "")],
                weeklySales: [], offMarket: false, isSubscription: true
            ))
        ))
        return GameEngine(state: state, balance: Self.balance, content: TestContent.bundled)
    }

    @Test func theLoopComesBackWhenTheFounderKeepsRunningIt() {
        let engine = publicEngine()
        engine.setSpeed(.x2)
        #expect(engine.isTickLoopRunning)

        engine.send(.fileIPO())
        #expect(engine.state.gameOver?.kind == .ipo)
        // The loop's next tick is the one that cancels it for good.
        engine.performTick()
        #expect(!engine.isTickLoopRunning)
        #expect(engine.state.day == 200, "an ended game does not advance")

        engine.send(.continueAfterEnding)
        #expect(engine.state.gameOver == nil)
        #expect(engine.isTickLoopRunning, "the clock runs again at the speed it was on")
        #expect(engine.state.speed == .x2)

        engine.performTick()
        #expect(engine.state.day == 201)
    }

    /// And the speed control still works: an ended engine refuses every
    /// speed, a continued one takes them.
    @Test func theSpeedControlWorksAgainAfterContinuing() {
        let engine = publicEngine()
        engine.send(.fileIPO())
        engine.setSpeed(.x4)
        #expect(engine.state.speed == .paused, "an ended game refuses the clock")

        engine.send(.continueAfterEnding)
        engine.setSpeed(.x4)
        #expect(engine.state.speed == .x4)
        #expect(engine.isTickLoopRunning)
    }
}
