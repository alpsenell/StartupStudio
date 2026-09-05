import Foundation

// MARK: Iteration 7 — the cloud merge policy (R2)

/// Which of two copies of a slot wins when a device pulls from iCloud.
///
/// A pure function over the two envelopes, so it never decodes a state
/// and is tested as a table. The key-value store is last-writer-wins by
/// wall clock; this layers the owner's rule on top: the same company
/// (same `summary.seed`) is further along on the higher in-game day, a
/// different company in the slot is whichever was saved most recently,
/// because in-game day says nothing about which company the player meant.
///
/// The cloud can also hold a *tombstone* for a slot — the record that a
/// device deleted it — so a deletion propagates instead of being undone
/// by the next device that still has the file.
public enum CloudMergePolicy {
    public enum Verdict: Equatable, Sendable {
        /// The local copy stands; nothing is written either way.
        case keepLocal
        /// The remote copy replaces the local one (the local becomes the
        /// slot's backup through the normal rotation). Against a
        /// tombstone this means: delete the local copy.
        case takeRemote
        /// The local copy is newer than the cloud's; push it.
        case pushLocal
    }

    /// What the cloud holds for a slot.
    public enum Remote: Equatable, Sendable {
        /// No value under the key.
        case absent
        /// A device deleted the slot at `deletedAt`.
        case tombstone(deletedAt: Date)
        /// A save file, described by its envelope.
        case save(SaveEnvelope)
    }

    /// The two-envelope form: `nil` remote is `.absent`.
    public static func resolve(local: SaveEnvelope?, remote: SaveEnvelope?) -> Verdict {
        resolve(local: local, remote: remote.map(Remote.save) ?? .absent)
    }

    /// The full rule.
    ///
    /// - Neither side has anything → `.keepLocal` (nothing to do).
    /// - Only the cloud has a save → `.takeRemote`; only this device has
    ///   one → `.pushLocal`.
    /// - Both have a save with the **same seed** → the higher
    ///   `summary.day` wins; a tie keeps local (and pushes nothing, so two
    ///   devices at the same day never trade identical bytes).
    /// - Both have a save with **different seeds** — or either side's
    ///   seed is unknown, as on a summary written before seeds were
    ///   recorded — → the newer `savedAt` wins; a tie keeps local.
    /// - The cloud holds a **tombstone**: a local save written *after* the
    ///   deletion is a company the player went on to play and is pushed;
    ///   anything older is deleted (`.takeRemote`). No local save →
    ///   `.keepLocal`.
    public static func resolve(local: SaveEnvelope?, remote: Remote) -> Verdict {
        switch (local, remote) {
        case (nil, .absent), (nil, .tombstone):
            return .keepLocal
        case (nil, .save):
            return .takeRemote
        case (.some, .absent):
            return .pushLocal
        case (.some(let local), .tombstone(let deletedAt)):
            return local.savedAt > deletedAt ? .pushLocal : .takeRemote
        case (.some(let local), .save(let remote)):
            if let localSeed = local.summary?.seed, let remoteSeed = remote.summary?.seed,
               localSeed == remoteSeed {
                let localDay = local.summary?.day ?? 0
                let remoteDay = remote.summary?.day ?? 0
                if remoteDay > localDay { return .takeRemote }
                if remoteDay < localDay { return .pushLocal }
                return .keepLocal
            }
            if remote.savedAt > local.savedAt { return .takeRemote }
            if remote.savedAt < local.savedAt { return .pushLocal }
            return .keepLocal
        }
    }
}

/// The small JSON object a device leaves under a slot's key when it
/// deletes the slot, so the other devices delete theirs too rather than
/// pushing the file back. Distinguished from a save file by the
/// `tombstone` key — a save file never has one.
public struct CloudTombstone: Codable, Equatable, Sendable {
    public var tombstone: Bool
    public var deletedAt: Date

    public init(deletedAt: Date) {
        self.tombstone = true
        self.deletedAt = deletedAt
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// The bytes that go under the key (before compression).
    public func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    /// `nil` when `data` is not a tombstone — a save file, or garbage.
    public init?(data: Data) {
        guard let decoded = try? Self.decoder.decode(CloudTombstone.self, from: data),
              decoded.tombstone
        else { return nil }
        self = decoded
    }
}
