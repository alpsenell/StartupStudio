import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// Regenerates `Fixtures/v1-main-a3b92ad.json`, the legacy save
/// `LegacySaveCompatibilityTests` reads.
///
/// The fixture is a real 400-tick run encoded with sorted keys and then
/// stripped of every key that did not exist on `main` at `a3b92ad` — the
/// four workstream sub-states, employee traits, and the fields WS-A added
/// to `LifeState`, `DevProgress` and `ReleaseInfo`. What is left is
/// byte-for-byte the shape the shipped app writes today, which is the point:
/// a save from the App Store build has to keep loading.
///
/// Disabled by default; run it deliberately after a *deliberate* schema
/// change with:
///
///     REGENERATE_LEGACY_FIXTURE=1 swift test --filter regenerateLegacySaveFixture
@Suite("Fixture generator")
struct FixtureGenerator {
    /// Keys added after `a3b92ad`, by the object that owns them.
    static let addedKeys: Set<String> = [
        // GameState sub-states (scaffold)
        "economy", "narrative", "progression", "investors",
        // Employee (scaffold)
        "traits",
        // LifeState (WS-A)
        "awaySinceDay",
        // DevProgress (WS-A)
        "crewSkillDaySum", "crewSkillDays",
        // ReleaseInfo (WS-A)
        "liveBugs", "priceTier", "subscribers", "isSubscription",
        "lastUpdateDay", "updateCount",
    ]

    static func stripAddedKeys(_ value: Any) -> Any {
        if var object = value as? [String: Any] {
            for key in addedKeys { object.removeValue(forKey: key) }
            return object.mapValues(stripAddedKeys)
        }
        if let array = value as? [Any] {
            return array.map(stripAddedKeys)
        }
        return value
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["REGENERATE_LEGACY_FIXTURE"] != nil))
    func regenerateLegacySaveFixture() throws {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 0
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Determined", seed: 4_242, balance: balance)
        // A funded studio, so the fixture is a healthy 400-day save rather
        // than a bankruptcy that stopped ticking on day 126.
        state.company.cash = 250_000

        // A run with something of everything on the books: staff, a
        // released product, a contract, research, a loan.
        Reducer.apply(
            .startProduct(
                typeID: "mobile_app", topicID: "fitness", name: "FitTrack", focus: .balanced
            ),
            to: &state, balance: balance, content: content
        )
        Reducer.apply(.takeLoan(amount: 5_000), to: &state, balance: balance, content: content)
        for day in 0..<400 {
            Reducer.tick(&state, balance: balance, content: content)
            if day == 40, let candidate = state.candidatePool.first {
                Reducer.apply(
                    .hire(candidateID: candidate.id), to: &state, balance: balance, content: content
                )
            }
            if day == 120, let product = state.productInDevelopment {
                Reducer.apply(
                    .ship(productID: product.id), to: &state, balance: balance, content: content
                )
            }
            if day == 200 {
                Reducer.apply(
                    .startResearch(nodeID: "code_reviews"),
                    to: &state, balance: balance, content: content
                )
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(state)
        let stripped = Self.stripAddedKeys(
            try JSONSerialization.jsonObject(with: data)
        )
        let legacy = try JSONSerialization.data(
            withJSONObject: stripped, options: [.sortedKeys, .prettyPrinted]
        )

        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/v1-main-a3b92ad.json")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try legacy.write(to: url)
        print("wrote \(legacy.count) bytes to \(url.path)")
    }
}
