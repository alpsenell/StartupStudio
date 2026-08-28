import Testing
import TycoonContent
@testable import TycoonEngine

/// Counts autosave invocations.
@MainActor
private final class SaveRecorder {
    var count = 0
    var lastState: GameState?

    func record(_ state: GameState) {
        count += 1
        lastState = state
    }
}

@MainActor
@Suite("GameEngine product loop")
struct GameEngineProductTests {
    @Test func sendAppliesSynchronouslyAndAutosavesOnEvents() {
        let engine = GameEngine.newGame(companyName: "Acme", seed: 1)
        let recorder = SaveRecorder()
        engine.autosave = { recorder.record($0) }

        engine.send(.startProduct(typeID: "mobile_app", topicID: "fitness", name: "FitTrack", focus: .balanced))
        #expect(engine.state.products.count == 1)
        #expect(engine.state.productInDevelopment != nil)
        #expect(recorder.count == 1)
        #expect(recorder.lastState?.products.count == 1)

        // An ignored action produces no events, so no autosave.
        engine.send(.startProduct(typeID: "hologram", topicID: "fitness", name: "Nope", focus: .balanced))
        #expect(engine.state.products.count == 1)
        #expect(recorder.count == 1)
    }

    @Test func autosaveFiresOnEverySixtiethTick() {
        // Candidate refreshes, contract-offer refreshes, random events, and
        // life events are events, so push them past the window. The
        // founder's weekend still produces an event every 7th tick (and a
        // quiet life keeps every other day event-free), so autosave fires
        // on those ticks and on every 60th.
        let balance = TestBalance.make(
            candidateRefreshDays: 10_000, contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000, life: TestBalance.quietLife
        )
        let engine = GameEngine(
            state: .newGame(companyName: "Acme", seed: 1, balance: balance),
            balance: balance,
            content: TestContent.bundled
        )
        let recorder = SaveRecorder()
        engine.autosave = { recorder.record($0) }

        // 120 ticks: autosave fires on every weekend tick plus ticks 60
        // and 120 (neither a multiple of 7).
        for tick in 1...120 {
            engine.performTick()
            let expected = tick / 7 + tick / 60
            #expect(recorder.count == expected, "after tick \(tick)")
        }
        #expect(engine.state.day == 120)
    }

    @Test func autosaveFiresAfterEventProducingTick() {
        // founderCoding 50 makes the balanced-focus founder produce exactly
        // 1 code point per day (life pinned so the founder multiplier is
        // exactly 1): 60 >= 0.6 * 90 clears mobile_app's gate. Candidate
        // refreshes, contract-offer refreshes, random events, and life
        // events are pushed out so only the weekends and the ship produce
        // events.
        let balance = TestBalance.make(
            founderCoding: 60, skillGrowthRate: 0, candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000, eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife
        )
        var state = GameState.newGame(companyName: "Acme", seed: 2, balance: balance)
        TestLife.pinPeak(&state)
        let engine = GameEngine(state: state, balance: balance, content: TestContent.bundled)
        let recorder = SaveRecorder()
        engine.autosave = { recorder.record($0) }

        engine.send(.startProduct(typeID: "mobile_app", topicID: "fitness", name: "FitTrack", focus: .balanced))
        #expect(recorder.count == 1)

        // Force a ship-eligible product, then ship: events -> autosave.
        // 60 ticks carry 8 weekend saves (days 7...56) and the 60th-tick save.
        for _ in 0..<60 { engine.performTick() }
        #expect(recorder.count == 1 + 8 + 1)
        let id = engine.state.products[0].id
        engine.send(.ship(productID: id))
        #expect(recorder.count == 11)

        // Day 61 is neither a weekend nor a 60th tick and produces no
        // event, so nothing saves. (Sales rows are state changes, not
        // GameEvents, until the delist event.)
        let before = recorder.count
        engine.performTick()
        #expect(recorder.count == before)
    }

    @Test func pauseForBackgroundAutosaves() {
        let engine = GameEngine.newGame(companyName: "Acme", seed: 3)
        let recorder = SaveRecorder()
        engine.autosave = { recorder.record($0) }

        engine.pauseForBackground()
        #expect(recorder.count == 1)
        #expect(engine.state.speed == .paused)
    }

    @Test func resumeForcesPausedAndLoadsBundledConfiguration() throws {
        var state = GameEngine.newGame(companyName: "Resumed Co", seed: 4).state
        state.speed = .x4

        let engine = GameEngine.resume(state: state)
        #expect(engine.state.speed == .paused)
        #expect(engine.state.company.name == "Resumed Co")
        #expect(engine.balance == (try BalanceConfig.loadBundled()))
        #expect(engine.content.productType("mobile_app") != nil)
    }
}
