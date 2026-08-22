import Testing
import TycoonContent
@testable import TycoonEngine

/// Regression tests for the "zombie engine" bug: a replaced or game-over
/// engine must stop ticking and must never autosave again, otherwise a stale
/// engine keeps overwriting the live game's save file.
@MainActor
@Suite("GameEngine lifecycle")
struct GameEngineLifecycleTests {
    /// Balance tuned so bankruptcy arrives within a few simulated days.
    private static let doomBalance = TestBalance.make(
        startingCash: 0,
        weeklyOperatingCost: 1_000,
        bankruptcyGraceDays: 2
    )

    private func bankruptEngine() -> GameEngine {
        let state = GameState.newGame(companyName: "Doomed", seed: 7, balance: Self.doomBalance)
        let engine = GameEngine(state: state, balance: Self.doomBalance, content: TestContent.bundled)
        var guardRail = 0
        while engine.state.gameOver == nil {
            engine.performTick()
            guardRail += 1
            precondition(guardRail < 1_000, "bankruptcy never arrived — doom balance broken")
        }
        return engine
    }

    @Test func gameOverEngineNeverTicksOrAutosavesAgain() {
        let engine = bankruptEngine()
        var saves = 0
        engine.autosave = { _ in saves += 1 }
        let day = engine.state.day

        // 130 ticks crosses the every-60th-tick autosave policy twice.
        for _ in 0..<130 { engine.performTick() }

        #expect(engine.state.day == day)
        #expect(saves == 0)
    }

    @Test func tickIntoGameOverCancelsARunningLoop() {
        let state = GameState.newGame(companyName: "Doomed", seed: 7, balance: Self.doomBalance)
        let engine = GameEngine(state: state, balance: Self.doomBalance, content: TestContent.bundled)
        engine.setSpeed(.x1)
        #expect(engine.isTickLoopRunning)

        var guardRail = 0
        while engine.state.gameOver == nil {
            engine.performTick()
            guardRail += 1
            precondition(guardRail < 1_000)
        }

        #expect(!engine.isTickLoopRunning)
    }

    @Test func setSpeedAfterGameOverDoesNotRestartTheLoop() {
        let engine = bankruptEngine()
        engine.setSpeed(.x4)
        #expect(!engine.isTickLoopRunning)
    }

    @Test func shutdownCancelsLoopAndDetachesAutosave() {
        let balance = TestBalance.standard
        let state = GameState.newGame(companyName: "Live", seed: 1, balance: balance)
        let engine = GameEngine(state: state, balance: balance, content: TestContent.bundled)
        var saves = 0
        engine.autosave = { _ in saves += 1 }
        engine.setSpeed(.x4)
        #expect(engine.isTickLoopRunning)

        engine.shutdown()

        #expect(!engine.isTickLoopRunning)
        // 60 manual ticks would cross the every-60th-tick autosave policy —
        // after shutdown nothing may fire.
        for _ in 0..<60 { engine.performTick() }
        #expect(saves == 0)
    }
}
