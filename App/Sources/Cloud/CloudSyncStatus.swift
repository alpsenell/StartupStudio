import Foundation

// MARK: Iteration 7 — iCloud (R2)

/// What the Settings row and the title screen say about the key-value
/// store. `.off` is the degrade: no iCloud account, saves stay local.
enum CloudSyncStatus: Equatable {
    case off
    case idle
    case syncing
    /// A slot was replaced from the cloud at the front door.
    case updated(slot: Int, day: Int)
    case failed(String)
}
