import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// The promise WS-A enforces at merge for every workstream: a save written
/// by the shipped app — before the scaffold, before the economy pass, before
/// anything in iteration 2 — still loads, still ticks, and still round-trips.
///
/// `Fixtures/v1-main-a3b92ad.json` is a real 400-day run stripped of every
/// key added after `a3b92ad` (see `FixtureGenerator`), so it is exactly the
/// shape a player's save file has today. `saveFormatVersion` stays 1: no
/// migration step was needed, because every field this iteration added
/// decodes with a default.
@Suite("Legacy save compatibility")
struct LegacySaveCompatibilityTests {
    static func legacyData() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "v1-main-a3b92ad", withExtension: "json"),
            "the legacy save fixture is missing from the test bundle"
        )
        return try Data(contentsOf: url)
    }

    static func legacyState() throws -> GameState {
        try JSONDecoder().decode(GameState.self, from: try legacyData())
    }

    @Test func aSaveFromTheShippedAppStillDecodes() throws {
        let state = try Self.legacyState()

        #expect(state.schemaVersion == 1)
        #expect(state.day == 400)
        #expect(state.company.name == "Determined")
        #expect(state.employees.count == 2)
        #expect(state.products.count == 1)
        #expect(state.loanBalance == 5_000)
        #expect(state.research.activeNodeID == "code_reviews")
    }

    @Test func everythingIterationTwoAddedDecodesAsAFreshDefault() throws {
        let state = try Self.legacyState()

        // The four workstream sub-states.
        #expect(state.economy == .initial)
        #expect(state.narrative == .initial)
        #expect(state.progression == .initial)
        #expect(state.investors == .initial)
        // WS-A's own additions, field by field.
        #expect(state.economy.workPace == .normal)
        #expect(state.economy.pendingResignation == nil)
        #expect(state.economy.updates.isEmpty)
        #expect(!state.economy.chronicCondition)
        #expect(state.economy.pauseEvents.isEmpty)
        #expect(state.life.awaySinceDay == nil)
        // Traits are the one iteration-2 field that does *not* come back
        // empty: WS-F derives them from the appearance seed and backfills
        // them in `Employee.init(from:)`, so a pre-iteration-2 employee
        // gains their two traits on decode rather than being trait-less
        // forever. Deterministic, and the seed is a v1 key. The founder is
        // exempt by design and stays trait-less.
        #expect(try #require(state.employees.first { $0.isFounder }).traits.isEmpty)
        for employee in state.employees where !employee.isFounder {
            #expect(employee.traits.count == TraitEffects.traitsPerEmployee)
            #expect(employee.traits.allSatisfy(TraitEffects.canonicalTraitIDs.contains))
            #expect(
                employee.traits
                    == TraitEffects.derivedTraitIDs(appearanceSeed: employee.appearanceSeed)
            )
        }
        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("the fixture's product should be released")
            return
        }
        #expect(info.liveBugs == 0)
        #expect(info.priceTier == .standard)
        #expect(info.subscribers == 0)
        #expect(!info.isSubscription)
        #expect(info.lastUpdateDay == nil)
        #expect(info.updateCount == 0)
        // …and the data that *was* in the save is untouched.
        #expect(info.reviews.count == 4)
        #expect(!info.weeklySales.isEmpty)
    }

    @Test func aLegacySaveKeepsPlaying() throws {
        var state = try Self.legacyState()
        let balance = try BalanceConfig.loadBundled().adjusted(for: state.difficulty)
        let content = TestContent.bundled
        let dayBefore = state.day

        for _ in 0..<30 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.day == dayBefore + 30)
        #expect(state.gameOver == nil, "the fixture studio should survive a month")
        // The new systems are live on it: the tick graded the day's events
        // and the calendar reads off the resumed clock.
        #expect(state.calendar.year == 2)
        #expect(state.calendar.monthName == "March")
    }

    @Test func aLegacySaveReEncodesAndReDecodesIdentically() throws {
        var state = try Self.legacyState()
        let balance = try BalanceConfig.loadBundled().adjusted(for: state.difficulty)
        for _ in 0..<30 {
            Reducer.tick(&state, balance: balance, content: TestContent.bundled)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        // Byte-identical on a second pass: nothing in the state encodes from
        // an unordered collection.
        #expect(try encoder.encode(decoded) == data)
        #expect(decoded.schemaVersion == 1, "no migration was needed")
    }

    /// The rule itself, stated as a test: nothing this iteration added may
    /// be a *required* key, or an existing save would fail to load.
    @Test func noKeyWasRenamedOrRemoved() throws {
        let legacy = try #require(
            try JSONSerialization.jsonObject(with: try Self.legacyData()) as? [String: Any]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let current = try #require(
            try JSONSerialization.jsonObject(
                with: try encoder.encode(try Self.legacyState())
            ) as? [String: Any]
        )
        for key in legacy.keys {
            #expect(current[key] != nil, "the save format dropped '\(key)'")
        }
    }
}
