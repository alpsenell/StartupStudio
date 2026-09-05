import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 7 — iCloud (R2)

/// The session's side of the key-value store: when to pull, what to apply,
/// when to push.
///
/// - **Pull** on launch and on every external change; **apply** a slot
///   verdict only while the front door is up. Under a running game the
///   `.takeRemote` verdicts wait in `cloud.pending`, and
///   `returnToFrontDoor()` re-resolves against the disk as it is then.
/// - **Push** after every local save, coalesced by `CloudSync` to one
///   write per key per 30 s, and flushed when the app backgrounds. A slot
///   the policy told to take from the cloud is held until it has been
///   played past the remote day (`CloudSync.isHeld`), so a stale autosave
///   never pushes an older day back.
/// - **Delete** pushes a tombstone, so the other devices delete too.
/// - The **ledger** merges both ways at every pull: it is never the
///   running game, so it needs no door.
extension GameSession {
    /// Launch: the real store when there is an account, `.off` otherwise.
    func bootstrapCloud() {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            cloud = .off
            return
        }
        attachCloud(CloudSync(
            store: NSUbiquitousKeyValueStore.default,
            isAvailable: true,
            formatVersion: Self.saveFormatVersion,
            readEnvelope: { [store] in store.envelope(in: $0) }
        ))
    }

    /// Attaches a controller — the real one, or a test's fake — and pulls
    /// once. `nil`, or a controller with no account, turns the sync off.
    func attachCloud(_ sync: CloudSync?) {
        guard let sync, sync.isAvailable else {
            cloud = .off
            return
        }
        var status = CloudSyncStatus()
        status.state = .idle
        status.sync = sync
        cloud = status
        sync.onExternalChange = { [weak self] in self?.pullFromCloud() }
        sync.onLocalOnlyKeysChanged = { [weak self] keys in
            self?.cloud.localOnlySlots = Set(keys.compactMap(CloudKey.slot(named:)))
        }
        sync.synchronize()
        pullFromCloud()
    }

    /// Reads every key and resolves it against the disk. Slot verdicts
    /// apply at the door and wait otherwise; the ledger merges either way.
    func pullFromCloud() {
        guard let sync = cloud.sync, cloud.isOn else { return }
        cloud.state = .syncing
        let updates = (0..<store.slotCount).map { slot -> CloudUpdate in
            let (verdict, remote) = sync.resolve(key: CloudKey.slot(slot), local: localEnvelope(slot))
            return CloudUpdate(slot: slot, verdict: verdict, remote: remote)
        }
        mergeLedgerFromCloud(sync)
        if isAtFrontDoor {
            apply(updates)
        } else {
            // A copy this device is ahead of can go now; a copy that is
            // ahead of this device waits for the door.
            for update in updates where update.verdict == .pushLocal {
                pushSlot(update.slot)
            }
            cloud.pending = updates.filter { $0.verdict == .takeRemote }
            cloud.state = .idle
        }
    }

    /// `returnToFrontDoor()`: whatever was held is re-resolved against the
    /// disk as it is now — the game may have been played past it — and
    /// applied.
    func applyPendingCloudUpdates() {
        guard isAtFrontDoor, !cloud.pending.isEmpty else { return }
        cloud.pending = []
        pullFromCloud()
    }

    /// After a local save of `slot`.
    func cloudDidPersist(slot: Int) {
        pushSlot(slot)
    }

    /// After `deleteSlot`: the deletion propagates as a tombstone.
    func cloudDidDelete(slot: Int) {
        guard let sync = cloud.sync, cloud.isOn else { return }
        sync.clearHold(slot: slot)
        cloud.pending.removeAll { $0.slot == slot }
        sync.requestTombstone(key: CloudKey.slot(slot))
    }

    /// The ledger changed here: push it.
    func pushLedger() {
        guard let sync = cloud.sync, cloud.isOn else { return }
        sync.requestPush(key: CloudKey.legacy) { [legacyStore] in legacyStore.rawSave() }
    }

    // MARK: - Private

    private func localEnvelope(_ slot: Int) -> SaveEnvelope? {
        if case .saved(_, let envelope) = store.slotSummary(slot: slot, summarize: SaveSummary.init(state:)).contents {
            return envelope
        }
        return nil
    }

    private func pushSlot(_ slot: Int) {
        guard let sync = cloud.sync, cloud.isOn else { return }
        guard !sync.isHeld(slot: slot, local: localEnvelope(slot)) else { return }
        // The cloud is ahead of this slot and waiting for the door; the
        // local copy is not the one to keep.
        guard !cloud.pending.contains(where: { $0.slot == slot && $0.verdict == .takeRemote }) else { return }
        sync.requestPush(key: CloudKey.slot(slot)) { [store] in store.rawSave(slot: slot) }
    }

    /// At the door: takes, pushes, and says what changed.
    private func apply(_ updates: [CloudUpdate]) {
        guard let sync = cloud.sync else { return }
        var updated: (slot: Int, day: Int)?
        var failure: String?
        for update in updates {
            switch update.verdict {
            case .keepLocal:
                continue
            case .pushLocal:
                pushSlot(update.slot)
            case .takeRemote:
                switch update.remote {
                case .save(let bytes, let envelope):
                    do {
                        try store.importRaw(bytes, slot: update.slot)
                        let day = envelope.summary?.day ?? 0
                        sync.hold(slot: update.slot, seed: envelope.summary?.seed, untilDay: day)
                        reloadSlotFromDisk(update.slot)
                        updated = (update.slot, day)
                    } catch SaveStoreError.futureFormat {
                        failure = "slot \(update.slot + 1) was saved by a newer version of the app"
                    } catch {
                        failure = error.localizedDescription
                    }
                case .tombstone:
                    // Not `deleteSlot`: that would push the tombstone back.
                    try? store.delete(slot: update.slot)
                    sync.clearHold(slot: update.slot)
                    reloadSlotFromDisk(update.slot)
                case .absent, .newerFormat, .unreadable:
                    continue
                }
            }
        }
        cloud.pending = []
        if let failure {
            cloud.state = .failed(failure)
        } else if let updated {
            cloud.state = .updated(slot: updated.slot, day: updated.day)
        } else {
            cloud.state = .idle
        }
    }

    /// Both ways: the union is saved here when it adds to this device's
    /// ledger, and pushed when it adds to the cloud's.
    private func mergeLedgerFromCloud(_ sync: CloudSync) {
        switch sync.remote(forKey: CloudKey.legacy) {
        case .save(let bytes, _):
            guard let remote = try? legacyStore.read(raw: bytes) else { return }
            let merged = ledger.merged(with: remote)
            if merged != ledger {
                ledger = merged
                saveLedger(push: merged != remote)
            } else if merged != remote {
                pushLedger()
            }
        case .absent:
            if !ledger.isEmpty { pushLedger() }
        case .tombstone, .newerFormat, .unreadable:
            break
        }
    }
}
