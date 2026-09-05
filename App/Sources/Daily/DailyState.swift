import Foundation
import TycoonEngine

// MARK: Iteration 7 — the daily (R3)

/// The session's view of today's company: which day it is for, and the
/// result once the year is up or the run ended.
struct DailyState: Equatable {
    var challenge: DailyChallenge
    var score: Int?
    var submitted = false
}
