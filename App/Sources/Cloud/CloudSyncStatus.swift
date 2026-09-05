import Foundation
import TycoonSave

// MARK: Iteration 7 — iCloud (R2)

/// What the session knows about the key-value store: the line Settings
/// and the title screen read, the verdicts pulled under a running game
/// and held for the front door, the slots too large to sync, and the
/// controller doing the work. `.off` is the degrade: no iCloud account,
/// saves stay local, and nothing here does anything.
struct CloudSyncStatus {
    enum State: Equatable {
        /// No iCloud account (`ubiquityIdentityToken == nil`), or no
        /// controller attached.
        case off
        /// On, nothing in flight.
        case idle
        /// A pull or a push is in progress.
        case syncing
        /// A slot was replaced from the cloud at the front door.
        case updated(slot: Int, day: Int)
        case failed(String)
    }

    var state: State = .off
    /// Verdicts that arrived while a game was running. They are never
    /// applied under a running game; `returnToFrontDoor()` re-resolves
    /// against the disk and applies what still holds.
    var pending: [CloudUpdate] = []
    /// Slots whose compressed save is over the key-value store's budget.
    /// They stay on this device, and the row says so; the others sync.
    var localOnlySlots: Set<Int> = []
    /// The controller, when iCloud is on. Not part of equality.
    var sync: CloudSync?

    static let off = CloudSyncStatus()

    /// Whether the key-value store is being read and written at all.
    var isOn: Bool { state != .off && sync != nil }

    /// The Settings row's value.
    var settingsLine: String {
        var line: String
        switch state {
        case .off: return "Off — saves stay on this device"
        case .idle: line = "On"
        case .syncing: line = "Syncing…"
        case .updated(let slot, let day): line = "Slot \(slot + 1) updated from iCloud, day \(day)"
        case .failed(let message): line = "Couldn't sync — \(message)"
        }
        let large = localOnlySlots.sorted()
        if !large.isEmpty {
            let names = large.map { "slot \($0 + 1)" }.joined(separator: ", ")
            line += " · \(names.prefix(1).uppercased())\(names.dropFirst()) too large to sync, kept here"
        }
        return line
    }

    /// The one line the title screen shows when a slot came in from the
    /// cloud; `nil` the rest of the time.
    var titleNotice: String? {
        guard case .updated(let slot, let day) = state else { return nil }
        return "Slot \(slot + 1) · updated from iCloud, day \(day)"
    }
}

extension CloudSyncStatus: Equatable {
    static func == (lhs: CloudSyncStatus, rhs: CloudSyncStatus) -> Bool {
        lhs.state == rhs.state && lhs.pending == rhs.pending
            && lhs.localOnlySlots == rhs.localOnlySlots && lhs.sync === rhs.sync
    }
}

/// One slot's verdict against what the cloud holds.
struct CloudUpdate: Equatable {
    var slot: Int
    var verdict: CloudMergePolicy.Verdict
    var remote: CloudRemote
}

/// What the cloud holds under a key, once the blob is decompressed and
/// classified.
enum CloudRemote: Equatable {
    /// No value under the key.
    case absent
    /// A device deleted the slot.
    case tombstone(deletedAt: Date)
    /// A save file, with its envelope.
    case save(bytes: Data, envelope: SaveEnvelope)
    /// A save file written by a newer app (`formatVersion` beyond this
    /// one's). The verdict is always `.keepLocal`, and the key is never
    /// written over: the newer app on the other device owns it now.
    case newerFormat(Int)
    /// Bytes that are neither a save nor a tombstone — damage. Treated as
    /// nothing, so a local copy overwrites them rather than wedging.
    case unreadable

    /// The policy's view of it; `nil` for bytes the policy must not judge.
    var policyRemote: CloudMergePolicy.Remote? {
        switch self {
        case .absent, .unreadable: .absent
        case .tombstone(let deletedAt): .tombstone(deletedAt: deletedAt)
        case .save(_, let envelope): .save(envelope)
        case .newerFormat: nil
        }
    }
}
