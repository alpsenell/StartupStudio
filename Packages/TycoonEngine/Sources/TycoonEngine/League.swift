import Foundation

// Iteration 10 — M4 owns this file and may reshape it freely. Weekly
// leagues on one seed with promotion and relegation, and "Beat my
// company" challenges carried by a seed code plus a year grid. The run
// side is `RunMode.league(week:)` (M4's marker in `RunMode.swift`); the
// standings and the tier live in the ledger (M4's markers in
// `Legacy.swift`) and in the app.

public struct LeagueWeek: Codable, Equatable, Sendable {
    public var week: Int
    public var seed: UInt64

    public init(week: Int, seed: UInt64) {
        self.week = week
        self.seed = seed
    }
}
