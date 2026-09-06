import Foundation

// Iteration 9 — L7 owns this file and may reshape it freely.

/// A decor item placed in the pixel home.
public struct PlacedDecor: Codable, Equatable, Sendable, Identifiable {
    /// The slot it stands in — L7 defines the slots per home tier.
    public var id: String { slot }
    public var slot: String
    public var itemID: String

    public init(slot: String, itemID: String) {
        self.slot = slot
        self.itemID = itemID
    }
}

public struct HomeDecorState: Codable, Equatable, Sendable {
    public var placed: [PlacedDecor]

    public init(placed: [PlacedDecor] = []) {
        self.placed = placed
    }

    public static let empty = HomeDecorState()
}
