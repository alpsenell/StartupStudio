import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The strength history behind the rival profile's sparkline (iteration
/// 6, U3): one sample per weekly pass, a year deep, append-only, written
/// to a save only once there is one, and read back as empty from a save
/// that never had it.
@Suite("Rival strength history")
struct RivalStrengthHistoryTests {
    static let content = TestContent.bundled
    static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled
    }()

    private func rival(history: [Double] = []) -> Rival {
        Rival(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
            name: "Parallax", strength: 40, reputation: 30, focusTopicIDs: ["fitness"],
            foundedDay: 7, appearanceSeed: 99, strengthHistory: history
        )
    }

    @Test func aSampleLandsEveryWeeklyPassAndNoneInBetween() {
        var state = GameState.newGame(companyName: "Fixture", seed: 4242, balance: Self.balance)
        let interval = Self.balance.rivals.evolveIntervalDays
        for _ in 0..<(interval * 4 + 3) {
            _ = Reducer.tick(&state, balance: Self.balance, content: Self.content)
        }
        // Four weekly passes since founding on day 1; a rival founded on
        // the first tick has been through every one of them.
        let rival = state.rivals.rivals.first { $0.foundedDay <= interval }
        #expect(rival != nil, "the field is founded on the first tick")
        #expect(rival?.strengthHistory.count == 4, "one sample per weekly pass, none on other days")
        #expect(rival?.strengthHistory.last == rival?.strength, "the last sample is this week's strength")
    }

    @Test func theHistoryIsCappedAtAYear() {
        var rival = rival()
        for week in 0..<80 {
            rival.strength = Double(week)
            rival.recordStrength()
        }
        #expect(rival.strengthHistory.count == Rival.strengthHistoryWeeks)
        #expect(rival.strengthHistory.first == 28.0, "the oldest week drops first")
        #expect(rival.strengthHistory.last == 79.0)
    }

    @Test func anEmptyHistoryIsNotWrittenAndAFullOneIs() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bare = try encoder.encode(rival())
        #expect(!String(decoding: bare, as: UTF8.self).contains("strengthHistory"))

        let kept = try encoder.encode(rival(history: [40, 41.5]))
        #expect(String(decoding: kept, as: UTF8.self).contains("\"strengthHistory\":[40,41.5]"))

        let decoded = try JSONDecoder().decode(Rival.self, from: kept)
        #expect(decoded.strengthHistory == [40, 41.5])
        #expect(decoded == rival(history: [40, 41.5]))
    }

    @Test func aRivalWrittenBeforeTheHistoryExistedDecodesEmpty() throws {
        let legacy = """
        {"appearanceSeed":99,"focusTopicIDs":["fitness"],"foundedDay":7,\
        "id":"00000000-0000-0000-0000-000000000042","isIncumbent":false,"name":"Parallax",\
        "personality":"deepPockets","products":[],"reputation":30,"strength":40,"weeksBeaten":0}
        """
        let decoded = try JSONDecoder().decode(Rival.self, from: Data(legacy.utf8))
        #expect(decoded.strengthHistory.isEmpty)
        #expect(decoded == rival())
        // Re-encoded, it is the same bytes it was.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(String(decoding: try encoder.encode(decoded), as: UTF8.self) == legacy.replacingOccurrences(of: "\\\n", with: ""))
    }

    @Test func theLegacySaveStillRoundTrips() throws {
        let state = try LegacySaveCompatibilityTests.legacyState()
        for rival in state.rivals.rivals {
            #expect(rival.strengthHistory.isEmpty)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let once = try encoder.encode(state)
        let twice = try encoder.encode(try JSONDecoder().decode(GameState.self, from: once))
        #expect(once == twice)
    }

    @Test func theHistoryMovesNoNumber() throws {
        // The same seed, the same days, with and without the samples: the
        // world is identical once the history is set aside.
        var withHistory = GameState.newGame(companyName: "Fixture", seed: 31_415, balance: Self.balance)
        for _ in 0..<120 {
            _ = Reducer.tick(&withHistory, balance: Self.balance, content: Self.content)
        }
        var stripped = withHistory
        for index in stripped.rivals.rivals.indices {
            stripped.rivals.rivals[index].strengthHistory = []
        }
        #expect(withHistory.rivals.rivals.contains { !$0.strengthHistory.isEmpty })
        #expect(stripped.day == withHistory.day)
        #expect(stripped.company == withHistory.company)
        #expect(stripped.rivals.playerShare == withHistory.rivals.playerShare)
        #expect(stripped.worldRNG == withHistory.worldRNG)
        #expect(stripped.rng == withHistory.rng)
        #expect(stripped.rivals.rivals.map(\.strength) == withHistory.rivals.rivals.map(\.strength))
    }
}
