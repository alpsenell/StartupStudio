import Testing
import TycoonEngine

@Suite("GameState")
struct GameStateTests {
    @Test func newGameInitialState() {
        let balance = TestBalance.standard
        let state = GameState.newGame(companyName: "Acme", seed: 7, balance: balance)

        #expect(state.schemaVersion == 1)
        #expect(state.day == 0)
        #expect(state.speed == .paused)
        #expect(state.company.name == "Acme")
        #expect(state.company.cash == balance.startingCash)
        #expect(state.company.reputation == 10)
        #expect(state.company.officeTier == .garage)
        #expect(state.company.daysInDebt == 0)
        #expect(state.ledger.entries.isEmpty)
        #expect(state.eventLog.isEmpty)
        #expect(state.gameOver == nil)
    }

    @Test func calendarDerivations() {
        var state = GameState.newGame(companyName: "Acme", seed: 7, balance: TestBalance.standard)

        #expect(state.year == 1)
        #expect(state.weekOfYear == 1)
        #expect(state.dayOfWeek == 1)
        #expect(state.dateLabel == "W1 · Y1")

        state.day = 15
        #expect(state.year == 1)
        #expect(state.weekOfYear == 3)
        #expect(state.dayOfWeek == 2)
        #expect(state.dateLabel == "W3 · Y1")

        state.day = 363
        #expect(state.year == 1)
        #expect(state.weekOfYear == 52)
        #expect(state.dayOfWeek == 7)

        state.day = 364
        #expect(state.year == 2)
        #expect(state.weekOfYear == 1)
        #expect(state.dayOfWeek == 1)
        #expect(state.dateLabel == "W1 · Y2")
    }

    @Test func simSpeedMetadata() {
        #expect(SimSpeed.allCases == [.paused, .x1, .x2, .x4])
        #expect(SimSpeed.paused.ticksPerSecond == nil)
        #expect(SimSpeed.x1.ticksPerSecond == 1)
        #expect(SimSpeed.x2.ticksPerSecond == 2)
        #expect(SimSpeed.x4.ticksPerSecond == 4)
        #expect(SimSpeed.paused.label == "Paused")
        #expect(SimSpeed.x1.label == "1x")
        #expect(SimSpeed.x2.label == "2x")
        #expect(SimSpeed.x4.label == "4x")
    }

    @Test func officeTierMetadata() {
        #expect(OfficeTier.allCases == [.garage, .loft, .studio, .campus])
        #expect(OfficeTier.garage.displayName == "Garage")
        #expect(OfficeTier.loft.displayName == "Loft")
        #expect(OfficeTier.studio.displayName == "Studio")
        #expect(OfficeTier.campus.displayName == "Campus")
    }
}
