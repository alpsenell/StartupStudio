import Foundation
import Testing
import TycoonEngine

/// Guards the seams cut by the pre-branch scaffold commit: the four
/// workstream sub-states and the five balance blocks decode when their key
/// is absent (the save-compat rule every workstream follows), employee
/// traits round-trip and default to empty, and the defaulted
/// `FounderProfile` reproduces today's founder without disturbing the RNG.
@Suite("Scaffold contract")
struct ScaffoldContractTests {
    @Test func newGameStateRoundTripsAndOmittedSubStatesDecodeAsInitial() throws {
        let balance = try BalanceConfig.loadBundled()
        var state = GameState.newGame(companyName: "Determined", seed: 4242, balance: balance)
        for _ in 0..<40 { Reducer.tick(&state, balance: balance, content: TestContent.bundled) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)

        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["economy"] != nil)
        #expect(object["narrative"] != nil)
        #expect(object["progression"] != nil)
        #expect(object["investors"] != nil)
        for key in ["economy", "narrative", "progression", "investors"] {
            object.removeValue(forKey: key)
        }
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let legacyState = try JSONDecoder().decode(GameState.self, from: legacy)

        // Each stripped sub-state comes back as `.initial` and everything
        // else survives. (The scaffold compared whole states, which only
        // held while every sub-state was still empty; WS-A's economy and
        // WS-F's progression both carry real data after 40 ticks.)
        #expect(legacyState.economy == .initial)
        #expect(legacyState.narrative == .initial)
        #expect(legacyState.progression == .initial)
        #expect(legacyState.investors == .initial)

        var expected = state
        expected.economy = .initial
        expected.narrative = .initial
        expected.progression = .initial
        expected.investors = .initial
        #expect(legacyState == expected)

        let employeeData = try encoder.encode(state.employees[0])
        var employeeObject = try #require(
            try JSONSerialization.jsonObject(with: employeeData) as? [String: Any]
        )
        #expect(employeeObject["traits"] != nil)
        employeeObject.removeValue(forKey: "traits")
        let legacyEmployee = try JSONDecoder().decode(
            Employee.self, from: try JSONSerialization.data(withJSONObject: employeeObject)
        )
        #expect(legacyEmployee.traits.isEmpty)
    }

    @Test func founderDefaultProfileMatchesTodaysFounder() throws {
        let balance = try BalanceConfig.loadBundled()
        let plain = GameState.newGame(companyName: "X", seed: 99, balance: balance)
        let explicit = GameState.newGame(
            companyName: "X", seed: 99, balance: balance, founder: .default
        )
        #expect(plain == explicit)
        #expect(plain.employees[0].name == "Founder")
        #expect(plain.devSlots == 1)
        #expect(plain.productsInDevelopment.isEmpty)
        // Graded by WS-A's pause policy: running out of money always stops
        // the clock, a hire never does.
        #expect(GameEvent.gameOver(day: 1).severity == .critical)
        #expect(GameEvent.hired(employeeID: UUID(), day: 1).severity == .info)
        #expect(plain.market.shareMultiplier(for: "fitness") == 1.0)

        let pinned = GameState.newGame(
            companyName: "X", seed: 99, balance: balance,
            founder: FounderProfile(name: "Ada", archetype: .designer, appearanceSeed: 7)
        )
        #expect(pinned.employees[0].name == "Ada")
        #expect(pinned.employees[0].appearanceSeed == 7)
        #expect(pinned.rng == plain.rng)
        #expect(pinned.employees[0].id == plain.employees[0].id)
    }

    @Test func balanceDecodesWithoutTheWorkstreamBlocks() throws {
        let balance = try BalanceConfig.loadBundled()
        let data = try JSONEncoder().encode(balance)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["economy", "narrative", "progression", "investors", "traits"] {
            #expect(object[key] != nil)
            object.removeValue(forKey: key)
        }
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let reloaded = try JSONDecoder().decode(BalanceConfig.self, from: stripped)

        // Every workstream block falls back to `.default`; everything else
        // survives the round trip untouched. (The scaffold could compare
        // the whole config because every block was still empty; once a
        // workstream tunes its object — WS-F's `progression` is the first —
        // only the non-workstream fields can match.)
        #expect(reloaded.progression == .default)
        #expect(reloaded.economy == .default)
        #expect(reloaded.narrative == .default)
        #expect(reloaded.investors == .default)
        #expect(reloaded.traits == .default)

        var expected = balance
        expected.economy = .default
        expected.narrative = .default
        expected.progression = .default
        expected.investors = .default
        expected.traits = .default
        #expect(reloaded == expected)
    }
}
