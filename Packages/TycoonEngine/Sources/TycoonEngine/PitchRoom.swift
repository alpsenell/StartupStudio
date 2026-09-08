import Foundation

// Iteration 10 — M2 owns this file and may reshape it freely. A pitch is
// a short conversation in the networking floor's exchange format with an
// investor, a client, a journalist or the board; `nil` on `GameState`
// when nobody is across the table.

public struct PitchState: Codable, Equatable, Sendable {
    /// Who is across the table — M2 defines the kinds.
    public var counterpart: String
    public var day: Int
    public var exchangesLeft: Int

    public init(counterpart: String, day: Int, exchangesLeft: Int) {
        self.counterpart = counterpart
        self.day = day
        self.exchangesLeft = exchangesLeft
    }
}
