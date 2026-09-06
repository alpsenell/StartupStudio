import Foundation

// Iteration 9 — L4 owns this file and may reshape it freely. Other lanes
// read `state.life.friends.friends` at most.

/// A named friend of the founder: somebody from before the company.
public struct Friend: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var appearanceSeed: UInt64
    /// Who they are in the founder's life — L4 defines the archetypes.
    public var archetype: String
    /// 0...100, grown by the founder's own evenings, decayed by silence.
    public var bond: Double

    public init(id: UUID, name: String, appearanceSeed: UInt64, archetype: String, bond: Double) {
        self.id = id
        self.name = name
        self.appearanceSeed = appearanceSeed
        self.archetype = archetype
        self.bond = bond
    }
}

public struct FriendsState: Codable, Equatable, Sendable {
    public var friends: [Friend]

    public init(friends: [Friend] = []) {
        self.friends = friends
    }

    public static let empty = FriendsState()
}
