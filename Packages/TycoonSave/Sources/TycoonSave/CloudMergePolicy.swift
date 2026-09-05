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
public enum CloudMergePolicy {
    public enum Verdict: Equatable, Sendable {
        /// The local copy stands; nothing is written either way.
        case keepLocal
        /// The remote copy replaces the local one (the local becomes the
        /// slot's backup through the normal rotation).
        case takeRemote
        /// The local copy is newer than the cloud's; push it.
        case pushLocal
    }

    /// R2 implements the seed and day comparison; the scaffold settles
    /// the two one-sided cases so the app can call it today.
    public static func resolve(local: SaveEnvelope?, remote: SaveEnvelope?) -> Verdict {
        switch (local, remote) {
        case (nil, nil):
            return .keepLocal
        case (nil, .some):
            return .takeRemote
        case (.some, nil):
            return .pushLocal
        case (.some, .some):
            // R2: same seed → higher `summary.day` wins, ties keep local;
            // different seeds → newer `savedAt` wins.
            return .keepLocal
        }
    }
}
