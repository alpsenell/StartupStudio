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
        #expect(legacyState == state)

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
        #expect(GameEvent.gameOver(day: 1).severity == .info)
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
        #expect(reloaded == balance)
    }
}
