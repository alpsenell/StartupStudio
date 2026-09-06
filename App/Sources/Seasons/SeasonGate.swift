import Foundation
import TycoonEngine

// MARK: Iteration 8 — seasons

/// Stops a season's clock at the end of its year, the daily's way.
struct SeasonGate: AdvanceGate {
    let id = "season"
    var horizon: Int = GameSeason.horizonDays

    func allows(_ state: GameState) -> Bool {
        guard state.mode.isSeason else { return true }
        return state.day < horizon
    }
}
