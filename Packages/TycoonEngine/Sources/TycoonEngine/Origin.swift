import Foundation

/// How the company was founded — the choice above the difficulty rows on
/// the new-game flow's Stakes page (WS-H, iteration 5).
///
/// Every origin is a set of pure state deltas applied in `GameState.newGame`
/// after the RNG setup, never a multiplier and never a draw, so the same
/// seed with the same origin is the same game and `.garage` is the game
/// that shipped.
public enum FoundingOrigin: String, Codable, Equatable, Sendable, CaseIterable {
    /// Alone, $12,000, a garage. Today's game.
    case garage
    /// A second person in the garage on day 0 who owns 30% of it forever.
    case cofounded
    /// You left a big company with a client: a signed contract, a little
    /// reputation, and a non-compete on one topic for a year.
    case spinOut
    /// You own a flat and the bank has already lent against it.
    case mortgaged

    public var displayName: String {
        switch self {
        case .garage: "Garage"
        case .cofounded: "Co-founded"
        case .spinOut: "Spin-out"
        case .mortgaged: "Mortgaged"
        }
    }

    public var blurb: String {
        switch self {
        case .garage: "Alone, twelve thousand dollars, and a garage."
        case .cofounded: "Somebody builds beside you from day one. They own a third of it."
        case .spinOut: "A client, a deadline, a little reputation, and a topic you can't touch for a year."
        case .mortgaged: "A year of runway, borrowed against the flat you live in."
        }
    }

    public var systemImageName: String {
        switch self {
        case .garage: "house.fill"
        case .cofounded: "person.2.fill"
        case .spinOut: "arrow.turn.up.right"
        case .mortgaged: "building.columns.fill"
        }
    }
}
