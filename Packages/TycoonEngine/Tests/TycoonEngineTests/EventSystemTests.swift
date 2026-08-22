import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Random events")
struct EventSystemTests {
    /// A balance where nothing but the event system draws from the RNG or
    /// touches cash and the ledger: candidate, contract-offer, and life
    /// event rolls are pushed past every test window, the weekly operating
    /// cost is zeroed, and no test in this suite runs a product past day 0.
    private static func quietBalance(
        eventCheckIntervalDays: Int = 30,
        eventChance: Double
    ) -> BalanceConfig {
        TestBalance.make(
            weeklyOperatingCost: 0,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: eventCheckIntervalDays,
            eventChance: eventChance,
            life: TestBalance.life(lifeEventIntervalDays: 10_000)
        )
    }

    private static func catalog(_ events: [EventDef]) -> ContentCatalog {
        TestContent.tiny(events: events)
    }

    private static let cashHit = EventDef(
        id: "server_bill",
        headline: "Your hosting provider has a very bad Tuesday.",
        impact: .cashDelta(amount: -800),
        weight: 1
    )

    /// Mirrors `SeededRNG.nextUniform()` (top 53 bits of one word) so tests
    /// can predict the event system's draws from a copied generator.
    private static func uniform(_ rng: inout SeededRNG) -> Double {
        Double(rng.next() >> 11) * 0x1.0p-53
    }

    private func randomEvents(in events: [GameEvent]) -> [GameEvent] {
        events.filter {
            if case .randomEvent = $0 { return true }
            return false
        }
    }

    // MARK: - Roll cadence

    @Test func noRollOffIntervalEvenWithACertainHit() {
        let balance = Self.quietBalance(eventChance: 1.0)
        let content = Self.catalog([Self.cashHit])
        var state = GameState.newGame(companyName: "Acme", seed: 8, balance: balance)
        let initialRNG = state.rng

        // Days 1-29: never a multiple of the 30-day interval, so the event
        // system draws nothing — the RNG stays untouched by anything.
        for _ in 0..<29 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            #expect(randomEvents(in: events).isEmpty)
        }
        #expect(state.rng == initialRNG)
        #expect(state.company.cash == balance.startingCash)

        // Day 30 rolls, and eventChance 1.0 always hits.
        let day30 = Reducer.tick(&state, balance: balance, content: content)
        #expect(day30 == [.randomEvent(eventID: "server_bill", day: 30)])
        #expect(randomEvents(in: state.eventLog) == [.randomEvent(eventID: "server_bill", day: 30)])
    }

    @Test func missAtIntervalConsumesExactlyTheRollDraw() {
        let balance = Self.quietBalance(eventChance: 0.0)
        let content = Self.catalog([Self.cashHit])
        var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)

        for _ in 0..<29 { Reducer.tick(&state, balance: balance, content: content) }
        var expectedRNG = state.rng
        _ = expectedRNG.next() // the roll

        let day30 = Reducer.tick(&state, balance: balance, content: content)
        #expect(randomEvents(in: day30).isEmpty)
        #expect(state.rng == expectedRNG)
        #expect(state.company.cash == balance.startingCash)
        #expect(state.ledger.entries.allSatisfy { $0.category != .other })
    }

    @Test func hitConsumesRollPlusPickInTheDocumentedOrder() {
        let balance = Self.quietBalance(eventChance: 1.0)
        let content = Self.catalog([Self.cashHit])
        var state = GameState.newGame(companyName: "Acme", seed: 10, balance: balance)

        for _ in 0..<29 { Reducer.tick(&state, balance: balance, content: content) }
        var expectedRNG = state.rng
        _ = expectedRNG.next() // 1. the roll
        _ = expectedRNG.next() // 2. the weighted pick

        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.rng == expectedRNG) // 3. applying the impact draws nothing
    }

    @Test func emptyCatalogDrawsNothingAtTheInterval() {
        let balance = Self.quietBalance(eventChance: 1.0)
        let content = Self.catalog([])
        var state = GameState.newGame(companyName: "Acme", seed: 11, balance: balance)
        let initialRNG = state.rng

        for _ in 0..<60 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            #expect(randomEvents(in: events).isEmpty)
        }
        #expect(state.rng == initialRNG)
    }

    @Test func customIntervalIsHonored() {
        let balance = Self.quietBalance(eventCheckIntervalDays: 5, eventChance: 1.0)
        let content = Self.catalog([Self.cashHit])
        var state = GameState.newGame(companyName: "Acme", seed: 12, balance: balance)

        var hitDays: [Int] = []
        for _ in 0..<20 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            if !randomEvents(in: events).isEmpty { hitDays.append(state.day) }
        }
        #expect(hitDays == [5, 10, 15, 20])
    }

    // MARK: - Determinism

    @Test func hitOrMissAtTheIntervalIsDeterministicPerSeed() {
        let balance = Self.quietBalance(eventChance: 0.2)
        let content = Self.catalog([Self.cashHit])

        func firesOnDay30(seed: UInt64) -> Bool {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            // Predict the day-30 roll from the untouched generator: nothing
            // else draws before it.
            var probe = state.rng
            let predicted = Self.uniform(&probe) < balance.eventChance

            var fired = false
            for _ in 0..<30 {
                let events = Reducer.tick(&state, balance: balance, content: content)
                fired = fired || !randomEvents(in: events).isEmpty
            }
            #expect(fired == predicted, "seed \(seed)")
            return fired
        }

        var outcomes = Set<Bool>()
        for seed in 1...UInt64(30) {
            let first = firesOnDay30(seed: seed)
            #expect(first == firesOnDay30(seed: seed), "same seed, same outcome")
            outcomes.insert(first)
        }
        // 30 seeds at a 20% chance cover both outcomes.
        #expect(outcomes == [true, false])
    }

    @Test func weightedPickIsDeterministicAndMatchesTheCumulativeWeights() throws {
        let light = EventDef(
            id: "light", headline: "Light news.", impact: .reputationDelta(amount: 1), weight: 1
        )
        let heavy = EventDef(
            id: "heavy", headline: "Heavy news.", impact: .reputationDelta(amount: -1), weight: 3
        )
        let balance = Self.quietBalance(eventChance: 1.0)
        let content = Self.catalog([light, heavy])

        var lightPicks = 0
        for seed in 1...UInt64(40) {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)

            // Predict both draws: the roll always hits at chance 1.0, then
            // the pick maps one word onto the cumulative weights
            // [light: 0, heavy: 1...3].
            var probe = state.rng
            _ = probe.next() // the roll
            let pick = Int(probe.next() % 4)
            let expectedID = pick == 0 ? "light" : "heavy"

            for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: content) }
            #expect(randomEvents(in: state.eventLog) == [.randomEvent(eventID: expectedID, day: 30)], "seed \(seed)")
            if expectedID == "light" { lightPicks += 1 }
        }
        // 40 seeds at a 25% share cover both events.
        #expect(lightPicks > 0)
        #expect(lightPicks < 40)
    }

    // MARK: - Impacts

    @Test func cashDeltaMovesCashAndPostsALedgerEntryLabeledWithTheHeadline() throws {
        let balance = Self.quietBalance(eventChance: 1.0)
        let content = Self.catalog([Self.cashHit])
        var state = GameState.newGame(companyName: "Acme", seed: 13, balance: balance)

        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: content) }

        #expect(state.company.cash == balance.startingCash - 800)
        let entry = try #require(state.ledger.entries.last)
        #expect(entry.day == 30)
        #expect(entry.amount == -800)
        #expect(entry.category == .other)
        #expect(entry.label == "Your hosting provider has a very bad Tuesday.")
    }

    @Test func positiveCashDeltaPaysOut() {
        let gift = EventDef(
            id: "gift", headline: "A gift arrives.", impact: .cashDelta(amount: 2_000), weight: 1
        )
        let balance = Self.quietBalance(eventChance: 1.0)
        let content = Self.catalog([gift])
        var state = GameState.newGame(companyName: "Acme", seed: 14, balance: balance)

        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: content) }

        #expect(state.company.cash == balance.startingCash + 2_000)
        #expect(state.ledger.entries.last?.amount == 2_000)
    }

    @Test func reputationDeltaAppliesAndClampsToBothBounds() {
        let boost = EventDef(
            id: "boost", headline: "Great press.", impact: .reputationDelta(amount: 5), weight: 1
        )
        let slam = EventDef(
            id: "slam", headline: "Bad press.", impact: .reputationDelta(amount: -5), weight: 1
        )
        let balance = Self.quietBalance(eventChance: 1.0)

        var state = GameState.newGame(companyName: "Acme", seed: 15, balance: balance)
        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: Self.catalog([boost])) }
        #expect(state.company.reputation == 15) // 10 + 5, unclamped
        // Reputation events post nothing to the ledger.
        #expect(state.ledger.entries.allSatisfy { $0.category != .other })

        state = GameState.newGame(companyName: "Acme", seed: 15, balance: balance)
        state.company.reputation = 98
        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: Self.catalog([boost])) }
        #expect(state.company.reputation == 100) // clamped at the ceiling

        state = GameState.newGame(companyName: "Acme", seed: 15, balance: balance)
        state.company.reputation = 3
        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: Self.catalog([slam])) }
        #expect(state.company.reputation == 0) // clamped at the floor
    }

    @Test func hypeDeltaLandsOnTheInDevelopmentProduct() throws {
        let buzz = EventDef(
            id: "buzz", headline: "A blog features you.",
            impact: .hypeDeltaOnActiveProduct(amount: 10), weight: 1
        )
        // hypeDecayRate 0 keeps the delta exactly observable.
        let balance = TestBalance.make(
            candidateRefreshDays: 10_000, contractOfferRefreshDays: 10_000,
            hypeDecayRate: 0, eventChance: 1.0
        )
        let content = Self.catalog([buzz])
        var state = GameState.newGame(companyName: "Acme", seed: 16, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)

        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: content) }

        guard case .development(let dev) = try #require(state.product(id: productID)).stage else {
            Issue.record("expected the product to still be in development")
            return
        }
        #expect(dev.hype == 10)
        #expect(state.eventLog.contains(.randomEvent(eventID: "buzz", day: 30)))
    }

    @Test func hypeDeltaWithoutAProductInDevelopmentIsANoOpButStillEmits() {
        let buzz = EventDef(
            id: "buzz", headline: "A blog features you.",
            impact: .hypeDeltaOnActiveProduct(amount: 10), weight: 1
        )
        let balance = Self.quietBalance(eventChance: 1.0)
        let content = Self.catalog([buzz])
        var state = GameState.newGame(companyName: "Acme", seed: 17, balance: balance)

        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: content) }

        #expect(randomEvents(in: state.eventLog) == [.randomEvent(eventID: "buzz", day: 30)])
        #expect(state.products.isEmpty)
        #expect(state.company.cash == balance.startingCash)
        #expect(state.company.reputation == 10)
    }

    @Test func negativeHypeDeltaClampsAtZero() throws {
        let backlash = EventDef(
            id: "backlash", headline: "The internet turns on you.",
            impact: .hypeDeltaOnActiveProduct(amount: -50), weight: 1
        )
        let balance = TestBalance.make(
            candidateRefreshDays: 10_000, contractOfferRefreshDays: 10_000,
            hypeDecayRate: 0, eventChance: 1.0
        )
        let content = Self.catalog([backlash])
        var state = GameState.newGame(companyName: "Acme", seed: 18, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)

        for _ in 0..<30 { Reducer.tick(&state, balance: balance, content: content) }

        guard case .development(let dev) = try #require(state.product(id: productID)).stage else {
            Issue.record("expected the product to still be in development")
            return
        }
        #expect(dev.hype == 0)
    }
}
