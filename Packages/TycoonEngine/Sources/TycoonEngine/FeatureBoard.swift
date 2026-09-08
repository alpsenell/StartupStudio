import Foundation

// Iteration 10 — M1 owns this file and may reshape it freely. The board a
// product is built from: feature cards placed on it, synergies between
// them, and the market's appetite. `Product.features` (M1 adds it to
// `Product`'s hand-written Codable, decode-if-present) holds the placed
// card ids.

/// One feature card as content: M1 defines the catalog (id, name, the
/// topics and product types it fits, the tech node that unlocks it, the
/// skill it leans on, and the cards it synergises with).
public struct FeatureCard: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
