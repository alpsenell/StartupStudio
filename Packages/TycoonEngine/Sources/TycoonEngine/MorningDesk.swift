import Foundation

// Iteration 10 — M5 owns this file and may reshape it freely. The one-
// minute daily ritual: today's desk cards, derived from the run, and the
// per-run record of which days were answered. The streak across runs and
// its rewards live in the ledger (M5's markers in `Legacy.swift`).

public struct DeskState: Codable, Equatable, Sendable {
    /// Wall-clock days (yyyymmdd) on which the desk was cleared.
    public var clearedDays: [Int]

    public init(clearedDays: [Int] = []) {
        self.clearedDays = clearedDays
    }

    public static let empty = DeskState()
}
