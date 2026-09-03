import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The two ladders (WS-G, iteration 5): which one a run is on, what the
/// independent one measures, the ending it leads to, and the bar the
/// feature has to clear — reachable without a cheque, and not free.
@Suite("Two ladders")
struct LadderTests {
    private static let content = TestContent.bundled

    private static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    /// A term sheet on the table, so a test can answer it.
    private static func offer(on day: Int) -> InvestmentOffer {
        InvestmentOffer(
            investorID: "test_angel", investorName: "Test Angel", amount: 60_000,
            equity: 12, valuation: 500_000, takesBoardSeat: false,
            expects: .profitability, respondByDay: day + 7
        )
    }

    private static func ids(_ goals: [GoalProgress]) -> Set<String> {
        Set(goals.map(\.id))
    }

    // MARK: - The track

    /// The founder's first "Stay independent" is the declaration; the
    /// card flips the same day. Signing later closes the ladder for good —
    /// a second refusal cannot reopen it.
    @Test func decliningOpensTheLadderAndSigningClosesItForGood() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 21, balance: balance)
        state.progression.chapter = 3
        Reducer.tick(&state, balance: balance, content: Self.content)

        // Undeclared: the catalog reads as it always did.
        #expect(state.declaredGoalTrack == nil)
        #expect(state.goalTrack == .funded)
        #expect(Self.ids(state.progression.activeGoals).contains("g3_reach_the_studio"))

        state.investors.pendingOffer = Self.offer(on: state.day)
        let declined = Reducer.apply(
            .declineInvestment, to: &state, balance: balance, content: Self.content
        )
        #expect(declined.contains { if case .investmentDeclined = $0 { true } else { false } })
        #expect(state.goalTrack == .independent)
        #expect(state.declaredGoalTrack == .independent)
        #expect(state.progression.independentSinceDay == state.day)
        // Refreshed on the spot, not a day later.
        let independent = Self.ids(state.progression.activeGoals)
        #expect(independent.contains("g3i_six_tenured"))
        #expect(!independent.contains("g3_reach_the_studio"))

        // A round signed: funded, and the funded chapter-3 goals open.
        state.investors.pendingOffer = Self.offer(on: state.day)
        let accepted = Reducer.apply(
            .acceptInvestment, to: &state, balance: balance, content: Self.content
        )
        #expect(accepted.contains { if case .investmentAccepted = $0 { true } else { false } })
        #expect(state.investors.equityRemaining < 100)
        #expect(state.goalTrack == .funded)
        #expect(state.declaredGoalTrack == .funded)
        let funded = Self.ids(state.progression.activeGoals)
        #expect(funded.contains("g3_reach_the_studio"))
        #expect(!funded.contains("g3i_six_tenured"))

        // …and never back: the declaration is still on record, the cap
        // table outranks it.
        state.investors.pendingOffer = Self.offer(on: state.day)
        Reducer.apply(.declineInvestment, to: &state, balance: balance, content: Self.content)
        #expect(state.progression.independentSinceDay != nil)
        #expect(state.goalTrack == .funded)
        Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(state.goalTrack == .funded)
        #expect(Self.ids(state.progression.activeGoals).contains("g3_reach_the_studio"))
    }

    /// The neutrality argument, pinned: an offer that expires unanswered —
    /// which is every offer a pacing bot ever sees — declares nothing, so
    /// those runs stay on the goals they were measured on.
    @Test func lettingATermSheetExpireDeclaresNothing() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 22, balance: balance)
        state.progression.chapter = 3
        var offer = Self.offer(on: state.day)
        offer.respondByDay = state.day
        state.investors.pendingOffer = offer

        var withdrawn = false
        for _ in 0..<3 {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .investmentWithdrawn = event { withdrawn = true }
            }
        }
        #expect(withdrawn)
        #expect(state.investors.pendingOffer == nil)
        #expect(state.declaredGoalTrack == nil)
        #expect(state.goalTrack == .funded)
        #expect(Self.ids(state.progression.activeGoals).contains("g3_reach_the_studio"))
    }

    /// Only the active ladder is measured: a goal on the other one never
    /// progresses, never completes, never pays.
    @Test func theOtherLadderIsNeitherMeasuredNorPaid() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 23, balance: balance)
        state.progression.chapter = 3
        state.progression.independentSinceDay = 0
        // Would finish the funded "Earn $75,000 from one product" on sight.
        state.progression.stats.bestProductRevenue = 100_000
        // Would finish the independent "four profitable quarters".
        state.investors.profitableQuarters = 4
        let cash = state.company.cash

        let events = Reducer.tick(&state, balance: balance, content: Self.content)
        let completed = events.compactMap { event -> String? in
            if case .goalCompleted(let id, _) = event { return id }
            return nil
        }
        #expect(completed.contains("g3i_four_profitable_quarters"))
        #expect(!completed.contains("g3_a_hundred_and_fifty_k_product"))
        #expect(!state.progression.completedGoalIDs.contains("g3_a_hundred_and_fifty_k_product"))
        #expect(state.progression.goalProgress["g3_a_hundred_and_fifty_k_product"] == nil)
        // The funded goal's $5,000 never landed.
        #expect(state.company.cash < cash + 5_000)
    }

    /// Four of the active ladder's six open the next chapter, on either
    /// ladder, and the chapter-4 ladder that opens is the same one.
    @Test func fourOfTheActiveLadderOpenTheNextChapter() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 24, balance: balance)
        state.progression.chapter = 3
        state.progression.independentSinceDay = 0
        for goal in Self.content.goals(inChapter: 3, track: .independent).prefix(4) {
            state.progression.completedGoalIDs.insert(goal.id)
        }
        Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(state.progression.chapter == 4)
        let active = Self.ids(state.progression.activeGoals)
        #expect(active.isSubset(of: Set(Self.content.goals(inChapter: 4, track: .independent).map(\.id))))
        #expect(!active.contains("g4_raise_a_round"))
    }

    // MARK: - The conditions

    /// Each new condition kind reads the state it names, on a fixture.
    @Test func everyIndependentConditionMeasuresWhatItAsksFor() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 25, balance: balance)
        func measure(_ kind: GoalDef.Condition.Kind, _ amount: Double = 1) -> Double {
            ProgressionSystem.measure(
                GoalDef.Condition(kind: kind, amount: amount),
                state: state, balance: balance, content: Self.content
            ).value
        }

        state.investors.profitableQuarters = 5
        #expect(measure(.profitableQuarters, 8) == 5)

        #expect(measure(.officeOwned) == 0)
        state.city.ownership = .owned(purchasePrice: 90_000)
        #expect(measure(.officeOwned) == 1)

        state.day = 800
        func hire(_ name: String, on day: Int) -> Employee {
            Employee(
                id: UUID(), name: name, skills: SkillSet(coding: 40, design: 30, marketing: 20),
                weeklySalary: 800, assignment: .idle, isFounder: false, hiredDay: day,
                appearanceSeed: 1, role: .backend
            )
        }
        let founder = state.employees[0]
        state.employees = [
            founder,
            hire("Veteran", on: 800 - GameState.daysPerYear),
            hire("Newcomer", on: 800 - GameState.daysPerYear + 1),
        ]
        // The founder has been there since day 0 and does not count.
        #expect(measure(.tenuredStaff, 6) == 1)

        // 800 days is 2.19 years, read to a tenth.
        #expect(measure(.yearsTrading, 5) == 2.1)
        state.day = 3 * GameState.daysPerYear
        #expect(measure(.yearsTrading, 5) == 3)

        // Two things on sale at once, counted on the weekly beat. The
        // garage has one build slot; the loft has the second.
        state.day = 6
        state.progression.stats.liveProductsWeeks = 0
        state.products = []
        state.company.officeTier = .loft
        Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "fitness", name: "One", focus: .balanced),
            to: &state, balance: balance, content: Self.content
        )
        Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "finance", name: "Two", focus: .balanced),
            to: &state, balance: balance, content: Self.content
        )
        for index in state.products.indices {
            state.products[index].stage = .released(ReleaseInfo(
                launchDay: 6, quality: 50, reviews: [], weeklySales: [], offMarket: false
            ))
        }
        #expect(measure(.liveProductsWeeks, 26) == 0)
        Reducer.tick(&state, balance: balance, content: Self.content)
        #expect(state.day == 7)
        #expect(state.products.count == 2)
        #expect(measure(.liveProductsWeeks, 26) == 1)

        // Ready to stay independent mirrors the gate exactly.
        #expect(measure(.readyToStayIndependent) == 0)
        state.day = balance.investors.independentMinDay
        state.investors.profitableQuarters = balance.investors.independentProfitableQuarters
        state.company.reputation = balance.investors.independentMinReputation
        state.investors.equityRemaining = 100
        #expect(state.canStayIndependent(balance: balance))
        #expect(measure(.readyToStayIndependent) == 1)
    }

    // MARK: - The ending

    /// Refused before the gate, with a reason a screen can show; ends the
    /// run as *Still yours* after it, once.
    @Test func stillYoursIsRefusedBeforeTheGateAndEndsTheRunAfter() throws {
        let balance = try Self.balance()
        let config = balance.investors
        var state = GameState.newGame(companyName: "Acme", seed: 26, balance: balance)

        let refused = Reducer.apply(
            .declareIndependence, to: &state, balance: balance, content: Self.content
        )
        #expect(refused.isEmpty)
        #expect(state.gameOver == nil)
        #expect(state.independenceBlocker(balance: balance)?.contains("Too soon") == true)

        // Each gate, in the order the blocker names them.
        state.day = config.independentMinDay
        #expect(state.independenceBlocker(balance: balance)?.contains("profitable quarter") == true)
        state.investors.profitableQuarters = config.independentProfitableQuarters
        #expect(state.independenceBlocker(balance: balance)?.contains("Reputation") == true)
        state.company.reputation = config.independentMinReputation
        #expect(state.independenceBlocker(balance: balance) == nil)
        #expect(state.canStayIndependent(balance: balance))

        // A sold share is the one gate no quarter fixes.
        var diluted = state
        diluted.investors.equityRemaining = 85
        #expect(!diluted.canStayIndependent(balance: balance))
        #expect(diluted.independenceBlocker(balance: balance)?.contains("15%") == true)
        #expect(Reducer.apply(
            .declareIndependence, to: &diluted, balance: balance, content: Self.content
        ).isEmpty)

        let wallet = state.life.wallet
        let events = Reducer.apply(
            .declareIndependence, to: &state, balance: balance, content: Self.content
        )
        #expect(events.contains { if case .stayedIndependent = $0 { true } else { false } })
        #expect(events.contains { if case .gameOver = $0 { true } else { false } })
        let info = try #require(state.gameOver)
        #expect(info.kind == .independent)
        #expect(info.kind.isSuccess)
        #expect(info.day == state.day)
        #expect(info.reason.hasPrefix("You still owned 100%."))
        // Nobody was bought out: the founder keeps the company, not a cheque.
        #expect(state.life.wallet == wallet)
        #expect(state.investors.equityRemaining == 100)

        // Once.
        #expect(!state.canStayIndependent(balance: balance))
        #expect(Reducer.apply(
            .declareIndependence, to: &state, balance: balance, content: Self.content
        ).isEmpty)
    }

    // MARK: - Saves

    /// The two new fields round-trip, and a save from before the ladders
    /// reads as undeclared.
    @Test func theLadderRoundTripsAndOldSavesReadAsUndeclared() throws {
        var state = ProgressionState.initial
        state.independentSinceDay = 140
        state.stats.liveProductsWeeks = 17
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(ProgressionState.self, from: data) == state)

        let old = try JSONDecoder().decode(ProgressionState.self, from: Data("{}".utf8))
        #expect(old.independentSinceDay == nil)
        #expect(old.stats.liveProductsWeeks == 0)
    }

    // MARK: - The bar

    /// The tell for the whole feature. A bootstrapped studio that plays
    /// the independent game — every weekend spent, somebody to go home to,
    /// every term sheet declined — reaches *Still yours* on some seeds
    /// inside four years and not on others. Zero would mean the ladder is
    /// the funded one with the numbers filed off; ten would mean it is
    /// free. Measured: 5 of 10, chapter 5 on 8, and on every seed that
    /// fell short the blocker is the eight-quarter run.
    @Test func theIndependentPlayerReachesStillYoursOnSomeSeedsAndNotOthers() throws {
        let fourYears = 4 * GameState.daysPerYear
        let balance = try InvestorTargetsTests.balance()
        let runs = BalanceTargetsTests.seeds.map { seed in
            SimRunner.run(
                days: fourYears, seed: seed, bot: GoalIndependentBot(),
                balance: balance, content: Self.content
            )
        }
        let stayed = runs.filter { $0.endingKind == .independent }
        #expect(
            (3...7).contains(stayed.count),
            "the independent player reached Still yours on \(stayed.count)/10 seeds"
        )
        for run in stayed {
            let state = run.state
            #expect(state.investors.equityRemaining == 100)
            #expect(state.investors.profitableQuarters >= balance.investors.independentProfitableQuarters)
            #expect(state.company.reputation >= balance.investors.independentMinReputation)
            #expect(state.gameOver?.day ?? 0 >= balance.investors.independentMinDay)
            #expect(state.progression.chapter >= 4, "Still yours arrived before the ladder did")
        }
        // Not free: a company still trading at the horizon that could
        // not declare is the ladder's other half.
        #expect(
            runs.contains { $0.endingKind == nil && !$0.state.canStayIndependent(balance: balance) },
            "every surviving seed could declare — the gate is not biting"
        )
        // And it never signed: the whole run stayed on its own ladder.
        for run in runs where run.state.progression.chapter >= 3 {
            #expect(run.state.goalTrack == .independent)
        }
    }
}
