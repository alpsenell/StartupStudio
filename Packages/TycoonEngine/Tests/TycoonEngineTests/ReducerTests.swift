import Foundation
import Testing
import TycoonEngine

@Suite("Reducer")
struct ReducerTests {
    /// No test in this suite starts a product, so the bundled catalog is inert.
    private let content = TestContent.bundled

    @Test func tickAdvancesDayByExactlyOne() {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.day == 1)
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.day == 2)
    }

    @Test func weeklyOperatingCostsPostEverySevenTicks() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.company.cash == balance.startingCash)
        #expect(state.ledger.entries.isEmpty)

        Reducer.tick(&state, balance: balance, content: content) // day 7
        #expect(state.company.cash == balance.startingCash - balance.weeklyOperatingCost)
        #expect(state.ledger.entries.count == 1)
        let entry = try #require(state.ledger.entries.first)
        #expect(entry.day == 7)
        #expect(entry.amount == -balance.weeklyOperatingCost)
        #expect(entry.category == .operating)
        #expect(entry.label == "Operating costs")

        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) } // day 14
        #expect(state.company.cash == balance.startingCash - 2 * balance.weeklyOperatingCost)
        #expect(state.ledger.entries.count == 2)
        let second = try #require(state.ledger.entries.last)
        #expect(second.day == 14)
        #expect(second.amount == -balance.weeklyOperatingCost)
    }

    @Test func weeklyRentPostsWhenOfficeRentIsNonZero() throws {
        let balance = TestBalance.make(garageRent: 150)
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)

        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) } // day 7
        #expect(state.company.cash == balance.startingCash - balance.weeklyOperatingCost - 150)
        #expect(state.ledger.entries.count == 2)
        let rentEntry = try #require(state.ledger.entries.last)
        #expect(rentEntry.day == 7)
        #expect(rentEntry.amount == -150)
        #expect(rentEntry.category == .rent)
    }

    @Test func determinismOver200DaysIncludingByteIdenticalJSON() throws {
        let balance = try BalanceConfig.loadBundled()
        var a = GameState.newGame(companyName: "Acme", seed: 99, balance: balance)
        var b = GameState.newGame(companyName: "Acme", seed: 99, balance: balance)

        for _ in 0..<200 {
            Reducer.tick(&a, balance: balance, content: content)
            Reducer.tick(&b, balance: balance, content: content)
        }

        #expect(a == b)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let dataA = try encoder.encode(a)
        let dataB = try encoder.encode(b)
        #expect(dataA == dataB)
    }

    @Test func bankruptcyWarningGraceAndGameOver() {
        let balance = TestBalance.make(
            startingCash: 500,
            weeklyOperatingCost: 10_000,
            bankruptcyGraceDays: 3
        )
        var state = GameState.newGame(companyName: "Doomed", seed: 5, balance: balance)

        var collected: [GameEvent] = []
        for _ in 0..<7 { collected += Reducer.tick(&state, balance: balance, content: content) }

        // Enters debt on day 7 and warns that day. The life system resolves
        // the founder's weekend and the contract system refreshes its weekly
        // offer sheet on day 7, both before finance runs.
        #expect(state.company.cash == 500 - 10_000)
        #expect(state.company.daysInDebt == 1)
        let day7: [GameEvent] = [
            .weekendSpent(activity: .rest, day: 7),
            .contractOffersRefreshed(day: 7),
            .bankruptcyWarning(day: 7),
        ]
        #expect(collected == day7)
        #expect(state.eventLog == day7)
        #expect(state.gameOver == nil)

        // Grace period: still alive through day 7 + graceDays - 1.
        Reducer.tick(&state, balance: balance, content: content) // day 8
        Reducer.tick(&state, balance: balance, content: content) // day 9
        #expect(state.gameOver == nil)

        // Game over exactly bankruptcyGraceDays days after entering debt.
        let events = Reducer.tick(&state, balance: balance, content: content) // day 10
        #expect(events == [.gameOver(day: 10)])
        #expect(state.gameOver != nil)
        #expect(state.gameOver?.day == 10)
        #expect(state.eventLog.contains(.gameOver(day: 10)))

        // Further ticks change nothing.
        let frozen = state
        for _ in 0..<5 {
            let noOpEvents = Reducer.tick(&state, balance: balance, content: content)
            #expect(noOpEvents.isEmpty)
        }
        #expect(state == frozen)
    }

    @Test func recoveringFromDebtResetsDaysInDebt() {
        let balance = TestBalance.make(
            startingCash: 500,
            weeklyOperatingCost: 10_000,
            bankruptcyGraceDays: 10
        )
        var state = GameState.newGame(companyName: "Lucky", seed: 5, balance: balance)

        for _ in 0..<8 { Reducer.tick(&state, balance: balance, content: content) } // day 8, in debt 2 days
        #expect(state.company.daysInDebt == 2)

        state.company.cash = 100_000 // external rescue
        Reducer.tick(&state, balance: balance, content: content) // day 9
        #expect(state.company.daysInDebt == 0)
        #expect(state.gameOver == nil)
    }

    @Test func ledgerNeverExceeds500Entries() {
        // Garage rent 100 gives 2 entries per week; 300 weeks = 600 posted
        // entries. Random events are pushed out so no cash event adds an
        // unplanned entry.
        let balance = TestBalance.make(
            startingCash: 10_000_000,
            weeklyOperatingCost: 100,
            garageRent: 100,
            eventCheckIntervalDays: 10_000
        )
        var state = GameState.newGame(companyName: "Hoarder", seed: 3, balance: balance)

        var maxObservedCount = 0
        for _ in 0..<(7 * 300) {
            Reducer.tick(&state, balance: balance, content: content)
            maxObservedCount = max(maxObservedCount, state.ledger.entries.count)
        }

        #expect(maxObservedCount == 500)
        #expect(state.ledger.entries.count == 500)
        // The most recent entries are the ones retained.
        #expect(state.ledger.entries.last?.day == 7 * 300)
        // 600 posted, oldest 100 dropped: first survivor is week 51's operating entry.
        #expect(state.ledger.entries.first?.day == 357)
    }

    @Test func eventLogNeverExceeds500Entries() {
        // Daily candidate and contract-offer refreshes post 2 events per
        // tick, plus the founder's weekend every 7th day: 600 days = 1200 +
        // 85 = 1285 logged events. The founder's life is quiet so no
        // absence skips a weekend.
        let balance = TestBalance.make(
            startingCash: 10_000_000,
            candidateRefreshDays: 1,
            contractOfferRefreshDays: 1,
            life: TestBalance.quietLife
        )
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Chronicler", seed: 4, balance: balance)

        var maxObservedCount = 0
        for _ in 0..<600 {
            Reducer.tick(&state, balance: balance, content: content)
            maxObservedCount = max(maxObservedCount, state.ledger.entries.count)
            maxObservedCount = max(maxObservedCount, state.eventLog.count)
        }

        #expect(maxObservedCount == 500)
        #expect(state.eventLog.count == 500)
        // The most recent events are the ones retained.
        #expect(state.eventLog.last == .contractOffersRefreshed(day: 600))
        // 1285 logged, oldest 785 dropped: through day 364 that is 728 +
        // 52 = 780 events, so the first survivor is the 786th — day 367's
        // offer refresh.
        #expect(state.eventLog.first == .contractOffersRefreshed(day: 367))
    }
}
