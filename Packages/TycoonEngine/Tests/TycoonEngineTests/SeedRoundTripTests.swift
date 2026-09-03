import Foundation
import Testing
@testable import TycoonEngine

/// The seed a game started from survives the save, so an ending can offer
/// the same year again.
@Suite("Seed round trip")
struct SeedRoundTripTests {
    @MainActor
    @Test func aNewGameRemembersItsSeed() throws {
        let engine = GameEngine.newGame(companyName: "Again Ltd", seed: 0xDEAD_BEEF)
        #expect(engine.state.seed == 0xDEAD_BEEF)
        let data = try JSONEncoder().encode(engine.state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded.seed == 0xDEAD_BEEF)
    }

    @MainActor
    @Test func theSameSeedGivesTheSameFirstMonth() {
        let a = GameEngine.newGame(companyName: "Again Ltd", seed: 77)
        let b = GameEngine.newGame(companyName: "Again Ltd", seed: 77)
        var sa = a.state, sb = b.state
        for _ in 0..<28 {
            _ = Reducer.tick(&sa, balance: a.balance, content: a.content)
            _ = Reducer.tick(&sb, balance: b.balance, content: b.content)
        }
        #expect(sa.eventLog == sb.eventLog)
        #expect(sa.candidatePool.map(\.name) == sb.candidatePool.map(\.name))
    }
}
