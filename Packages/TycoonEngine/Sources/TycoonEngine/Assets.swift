import Foundation

// Iteration 11 — N3 owns this file and may reshape it freely. The founder's
// assets (cars, a second property, pets, the casino, the lottery, the
// crypto wallet), the doctor's office (named ailments, treatments,
// therapy) and the vices, all on one slot.

public struct AssetsState: Codable, Equatable, Sendable {
    /// Owned things — N3 defines the shape (id, kind, bought day, condition).
    public var owned: [String]
    /// Named ailments the founder currently has.
    public var ailments: [String]
    /// Vice id → 0…100 dependency.
    public var vices: [String: Double]

    public init(owned: [String] = [], ailments: [String] = [], vices: [String: Double] = [:]) {
        self.owned = owned
        self.ailments = ailments
        self.vices = vices
    }

    public static let empty = AssetsState()
}
