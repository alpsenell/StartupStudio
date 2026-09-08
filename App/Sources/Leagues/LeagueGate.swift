import Foundation
import TycoonEngine

// MARK: Iteration 10 — M4 (leagues)

/// Stops a league week's clock at the end of its year, the daily's way:
/// the gate refuses ticks, nothing is hidden or deleted, and the score is
/// read off the company exactly as the last tick left it.
struct LeagueGate: AdvanceGate {
    let id = "league"
    var horizon: Int = LeagueWeek.horizonDays

    func allows(_ state: GameState) -> Bool {
        guard state.mode.isLeague else { return true }
        return state.day < horizon
    }
}
