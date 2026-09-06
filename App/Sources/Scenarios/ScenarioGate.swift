import Foundation
import TycoonEngine

// MARK: Iteration 8 — scenarios

/// Stops the clock the moment a scenario is decided — won or lost — so
/// the company stands exactly as it was for the result card. A slot's
/// game is not its business.
struct ScenarioGate: AdvanceGate {
    let id = "scenario"
    let isFinished: @MainActor (GameState) -> Bool

    func allows(_ state: GameState) -> Bool {
        guard state.mode.isScenario else { return true }
        return !isFinished(state)
    }
}
