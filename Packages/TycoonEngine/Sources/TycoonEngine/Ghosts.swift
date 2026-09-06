import Foundation

// MARK: Iteration 8 — rival ghosts

/// One launch a real player made, replayed into somebody else's market
/// on the day it happened.
public struct GhostLaunch: Codable, Equatable, Hashable, Sendable {
    public var day: Int
    public var topicID: String
    public var typeID: String
    public var name: String
    public var quality: Double

    public init(day: Int, topicID: String, typeID: String, name: String, quality: Double) {
        self.day = day
        self.topicID = topicID
        self.typeID = typeID
        self.name = name
        self.quality = quality
    }
}

/// A real player's company as a rival: what they shipped and when. A
/// ghost never rolls — its launches are facts — so a run with ghosts is
/// as deterministic as one without for everyone given the same scripts.
public struct GhostScript: Codable, Equatable, Hashable, Sendable {
    /// The name on the studio: the player's display name, or their company.
    public var name: String
    public var appearanceSeed: UInt64
    /// Strength the ghost is founded at, from the quality it shipped.
    public var strength: Double
    public var focusTopicIDs: [String]
    public var launches: [GhostLaunch]
    /// What the ghost walked away with, for the result card's ranking.
    public var finalNetWorth: Int

    public init(
        name: String, appearanceSeed: UInt64, strength: Double, focusTopicIDs: [String],
        launches: [GhostLaunch], finalNetWorth: Int
    ) {
        self.name = name
        self.appearanceSeed = appearanceSeed
        self.strength = strength
        self.focusTopicIDs = focusTopicIDs
        self.launches = launches
        self.finalNetWorth = finalNetWorth
    }

    /// A stable id for the rival the ghost founds, off its facts alone.
    public var rivalID: UUID {
        var rng = SeededRNG(seed: appearanceSeed ^ UInt64(bitPattern: Int64(finalNetWorth)) ^ 0x6405_7000_0000_0001)
        return UUID(from: &rng)
    }
}
