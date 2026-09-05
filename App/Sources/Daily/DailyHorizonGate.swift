import Foundation
import TycoonEngine

// MARK: Iteration 7 — the daily (R3)

/// Stops the clock at the end of the daily's year.
///
/// The same seam the unlock uses (R6): a gate never hides or deletes
/// anything, it only refuses ticks. At day 364 the company stands exactly
/// as the last tick left it — every screen, every action, the save — and
/// the score is read off it.
///
/// It only ever refuses a daily: a slot's game is not this gate's
/// business, so the gate can stay installed while the player is anywhere.
struct DailyHorizonGate: AdvanceGate {
    let id = "daily"

    /// The last day the clock may advance from. 364 (`GameState.daysPerYear`)
    /// by default; injectable so a test does not have to tick a year.
    var horizon: Int = DailyChallenge.horizonDays

    func allows(_ state: GameState) -> Bool {
        guard state.mode.isDaily else { return true }
        return state.day < horizon
    }
}
