import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Guards the seams the iteration 7 scaffold cut: the four per-run fields
/// stay off a standard run's save, `GameRules.standard` is the identity
/// on the balance, the daily's derivation is pinned, the app's two engine
/// hooks behave, and the one ETA agrees with itself.
@Suite("Iteration 7 scaffold contract")
struct Iteration7ScaffoldTests {
    private static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled
    }()

    private func encoded(_ state: GameState) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: Per-run fields

    @Test("A standard run's save carries none of the four new keys")
    func standardRunOmitsNewKeys() throws {
        let state = GameState.newGame(companyName: "Plain", seed: 11, balance: Self.balance)
        let object = try encoded(state)
        for key in ["mode", "rules", "heirloom", "epilogue"] {
            #expect(object[key] == nil, "\(key) must be absent on a standard run")
        }
        #expect(state.mode == .standard)
        #expect(state.rules == .standard)
        #expect(state.heirloom == nil)
        #expect(state.epilogue == nil)
        #expect(state.isRanked)
    }

    @Test("Non-default run fields round-trip and decode with defaults when absent")
    func runFieldsRoundTrip() throws {
        var state = GameState.newGame(
            companyName: "Custom", seed: 12, balance: Self.balance,
            rules: GameRules(rivalsEnabled: false, startingCash: 50_000), mode: .daily(day: 248)
        )
        state.epilogue = Epilogue(ending: .ipo, day: 900)
        let object = try encoded(state)
        #expect(object["mode"] != nil)
        #expect(object["rules"] != nil)
        #expect(object["epilogue"] != nil)

        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.mode == .daily(day: 248))
        #expect(decoded.rules.startingCash == 50_000)
        #expect(decoded.epilogue?.ending == .ipo)

        var stripped = object
        for key in ["mode", "rules", "heirloom", "epilogue"] { stripped.removeValue(forKey: key) }
        let legacy = try JSONDecoder().decode(
            GameState.self, from: try JSONSerialization.data(withJSONObject: stripped)
        )
        #expect(legacy.mode == .standard)
        #expect(legacy.rules == .standard)
        #expect(legacy.epilogue == nil)
    }

    @Test("A custom run is unranked; an heirloom makes a standard run unranked")
    func rankedRules() {
        #expect(RunMode.custom.isRanked == false)
        #expect(RunMode.daily(day: 1).isRanked)
        let person = LegacyPerson(
            id: UUID(), name: "Marco", appearanceSeed: 1,
            skills: SkillSet(coding: 50, design: 50, marketing: 50), rapport: 60
        )
        let state = GameState.newGame(
            companyName: "Heir", seed: 13, balance: Self.balance, heirloom: .person(person)
        )
        #expect(state.isRanked == false)
        #expect(state.heirloom == .person(person))
    }

    @Test("The scaffold's heirloom stub changes nothing but the record of it")
    func heirloomStubIsNeutral() throws {
        let plain = GameState.newGame(companyName: "Same", seed: 14, balance: Self.balance)
        var heir = GameState.newGame(
            companyName: "Same", seed: 14, balance: Self.balance, heirloom: .perk(id: "press_contacts")
        )
        heir.heirloom = nil
        #expect(heir == plain)
    }

    // MARK: Rules on the balance

    @Test("GameRules.standard is the identity on the balance")
    func standardRulesAreIdentity() {
        #expect(Self.balance.applying(.standard) == Self.balance)
        #expect(GameRules().isStandard)
    }

    @Test("Rules move only the three values they name")
    func rulesMoveTheirValues() {
        let rules = GameRules(rivalsEnabled: false, incumbentEnabled: false, startingCash: 77_000)
        let applied = Self.balance.applying(rules)
        #expect(applied.rivals.rivalCount == 0)
        #expect(applied.rivals.depth.incumbentEnabled == false)
        #expect(applied.startingCash == 77_000)
        var expected = Self.balance
        expected.rivals.rivalCount = 0
        expected.rivals.depth.incumbentEnabled = false
        expected.startingCash = 77_000
        #expect(applied == expected)
    }

    // MARK: The action

    /// R5 implements the ending-side behaviour in `EndlessTests`; a live
    /// game has nothing to continue past, whoever asks.
    @Test("continueAfterEnding is refused on a live game")
    func continueAfterEndingRefused() {
        var live = GameState.newGame(companyName: "Live", seed: 15, balance: Self.balance)
        #expect(Reducer.apply(.continueAfterEnding, to: &live, balance: Self.balance, content: TestContent.bundled).isEmpty)
        #expect(live.epilogue == nil)
    }

    // MARK: The daily

    @Test("The daily's derivation is pinned")
    func dailyTableIsPinned() {
        let table: [(Int, UInt64, FoundingOrigin, Difficulty)] = [
            (0, 7_228_580_221_918_885_751, .mortgaged, .easy),
            (1, 8_358_231_295_106_158_512, .garage, .normal),
            (2, 14_256_709_756_143_053_960, .garage, .normal),
            (100, 17_138_062_380_635_075_348, .garage, .easy),
            (247, 3_131_462_525_305_386_972, .garage, .hard),
            (248, 7_118_041_768_617_355_666, .spinOut, .hard),
            (365, 16_814_110_772_462_409_022, .spinOut, .hard),
            (1000, 11_856_574_923_827_605_210, .spinOut, .hard),
            (4242, 600_013_793_093_361_587, .mortgaged, .easy),
            (20000, 7_453_652_789_834_888_665, .cofounded, .easy),
        ]
        for (day, seed, origin, difficulty) in table {
            let challenge = DailyChallenge.forDay(day)
            #expect(challenge.seed == seed, "day \(day)")
            #expect(challenge.origin == origin, "day \(day)")
            #expect(challenge.difficulty == difficulty, "day \(day)")
        }
        #expect(DailyChallenge.dayNumber(for: DailyChallenge.epoch) == 0)
        #expect(DailyChallenge.dayNumber(for: DailyChallenge.epoch.addingTimeInterval(86_399)) == 0)
        #expect(DailyChallenge.dayNumber(for: DailyChallenge.epoch.addingTimeInterval(86_400)) == 1)
        #expect(DailyChallenge.horizonDays == 364)
    }

    // MARK: Seed codes (R4 implements)

    @Test("A seed code round-trips")
    func seedCodeRoundTrips() {
        let code = SeedCode(seed: 0xDEAD_BEEF_0000_0001, origin: .spinOut, difficulty: .hard)
        #expect(SeedCode.decode(code.encoded) == code)
    }

    // MARK: One ETA

    @Test("shipETA is buildETA's ship gate on every fixture build")
    func shipETAAgreesWithBuildETA() {
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "ETA", seed: 16, balance: Self.balance)
        let type = content.productTypes[0]
        let topic = content.topics[0]
        _ = Reducer.apply(
            .startProduct(typeID: type.id, topicID: topic.id, name: "One", focus: .balanced),
            to: &state, balance: Self.balance, content: content
        )
        for _ in 0..<10 { Reducer.tick(&state, balance: Self.balance, content: content) }
        for product in state.productsInDevelopment {
            let ship = state.shipETA(for: product, balance: Self.balance, content: content)
            let build = state.buildETA(productID: product.id, balance: Self.balance, content: content)
            #expect(ship?.daysAway == build?.daysToShippable)
            if let ship { #expect(ship.day == state.day + ship.daysAway) }
        }
    }
}

/// The two hooks the app installs on the engine.
@MainActor
@Suite("Iteration 7 engine hooks")
struct Iteration7EngineHookTests {
    private static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled
    }()

    private func engine() -> GameEngine {
        let state = GameState.newGame(companyName: "Hooked", seed: 17, balance: Self.balance)
        return GameEngine(state: state, balance: Self.balance, content: TestContent.bundled)
    }

    @Test("A closed gate refuses ticks and refuses to run, but pausing and actions still work")
    func closedGateRefusesTheClock() {
        let engine = engine()
        engine.advanceGate = { _ in false }
        let day = engine.state.day
        engine.performTick()
        #expect(engine.state.day == day)
        #expect(engine.state.speed == .paused)
        engine.setSpeed(.x1)
        #expect(engine.state.speed == .paused)
        #expect(engine.isTickLoopRunning == false)
        engine.setSpeed(.paused)
        #expect(engine.state.speed == .paused)
        #expect(engine.mayAdvance == false)
        engine.advanceGate = { _ in true }
        engine.performTick()
        #expect(engine.state.day == day + 1)
    }

    @Test("No gate means the clock runs as it always did")
    func noGateIsOpen() {
        let engine = engine()
        #expect(engine.mayAdvance)
        let day = engine.state.day
        engine.performTick()
        #expect(engine.state.day == day + 1)
    }

    @Test("The event sink sees every event a tick or a send produces")
    func eventSinkReceivesEvents() {
        let engine = engine()
        var seen: [GameEvent] = []
        engine.eventSink = { seen.append(contentsOf: $0) }
        let before = engine.state.eventLog.count
        var guardRail = 0
        while engine.state.eventLog.count == before, guardRail < 400 {
            engine.performTick()
            guardRail += 1
        }
        #expect(!seen.isEmpty)
        #expect(seen.count == engine.state.eventLog.count - before)
    }
}
