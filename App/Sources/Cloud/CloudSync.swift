import Foundation
import TycoonSave
import UIKit

// MARK: Iteration 7 — iCloud (R2)

/// The keys in the key-value store: one per slot — `slot0`…`slot3` since
/// the fourth slot (iteration 13, P2; the session iterates the store's
/// count) — and one for the ledger.
enum CloudKey {
    static let legacy = "legacy"

    static func slot(_ slot: Int) -> String { "slot\(slot)" }

    /// The slot a key names, `nil` for `legacy` or anything else.
    static func slot(named key: String) -> Int? {
        guard key.hasPrefix("slot") else { return nil }
        return Int(key.dropFirst(4))
    }
}

/// The store the sync writes to. `NSUbiquitousKeyValueStore` in the app;
/// a dictionary in tests, where the policy and the plumbing are proved
/// without an iCloud account.
protocol CloudKeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data, forKey key: String)
    func removeData(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStore {
    func setData(_ data: Data, forKey key: String) { set(data, forKey: key) }
    func removeData(forKey key: String) { removeObject(forKey: key) }
}

/// The bytes under a key are the save file, LZFSE-compressed: sorted-key
/// JSON shrinks about five times, and the store allows a megabyte per key.
enum CloudBlob {
    /// A slot whose compressed save is over this stays local-only. Under
    /// the store's own 1 MB limit with room for the other three keys.
    static let maxBytes = 900 * 1024

    static func compress(_ data: Data) throws -> Data {
        try (data as NSData).compressed(using: .lzfse) as Data
    }

    static func decompress(_ data: Data) throws -> Data {
        try (data as NSData).decompressed(using: .lzfse) as Data
    }
}

/// Moves the slots and the ledger through the key-value store.
///
/// Pure on the way in — `remote(forKey:)` classifies a blob, `resolve`
/// applies `CloudMergePolicy` — and rate-limited on the way out: a push
/// is coalesced to one write per key per `pushInterval`, and `flush()`
/// writes everything pending at once (the app calls it when it goes to
/// the background, because that is the write that must not wait). The
/// anti-ping-pong rule lives here too: a slot whose verdict was
/// `.takeRemote` is *held* — never pushed — until the local save has been
/// played past the remote day, so a stale autosave on this device can
/// never push day 250 back over another device's day 300.
///
/// The controller never touches the save directory: the session owns the
/// stores, hands bytes in and applies verdicts. That is what keeps it
/// testable with a fake store and a temporary directory.
@MainActor
final class CloudSync {
    /// What a push will write: the slot's current bytes when it runs (so a
    /// burst of autosaves pushes the last one), or a tombstone.
    enum Outgoing {
        case save(() -> Data?)
        case tombstone(deletedAt: Date)
    }

    /// One line per push, for the ping-pong check the doc asks for:
    /// `(key, day, what)`.
    struct PushRecord: Equatable {
        var key: String
        var day: Int?
        var kind: String
    }

    /// A slot the policy told to take the remote: no push until the local
    /// save of the *same company* is past `day`.
    struct Hold: Codable, Equatable {
        var seed: UInt64?
        var day: Int
    }

    let store: any CloudKeyValueStore
    /// `ubiquityIdentityToken != nil` in the app. Off means every method
    /// is a no-op and the status reads `.off`.
    let isAvailable: Bool
    /// Parses a save file's envelope; `SaveStore.envelope(in:)`.
    private let readEnvelope: (Data) -> SaveEnvelope?
    /// The save format this app writes; a blob beyond it is a newer app's.
    private let formatVersion: Int
    private let defaults: UserDefaults
    /// The clock, injectable so the coalescing is tested without waiting.
    var now: () -> Date = Date.init
    var pushInterval: TimeInterval = 30

    /// Called on `NSUbiquitousKeyValueStore.didChangeExternallyNotification`.
    var onExternalChange: (() -> Void)?
    /// Called when a slot crosses the size cap either way.
    var onLocalOnlyKeysChanged: ((Set<String>) -> Void)?

    private(set) var localOnlyKeys: Set<String> = []
    private(set) var pushLog: [PushRecord] = []
    private var pending: [String: Outgoing] = [:]
    private var scheduled: [String: Task<Void, Never>] = [:]
    private var lastPushAt: [String: Date] = [:]
    /// Written once in `init`, read once in `deinit`: never raced.
    private nonisolated(unsafe) var observers: [any NSObjectProtocol] = []

    private static let holdsKey = "cloud.holds"

    init(
        store: any CloudKeyValueStore,
        isAvailable: Bool,
        formatVersion: Int,
        readEnvelope: @escaping (Data) -> SaveEnvelope?,
        defaults: UserDefaults = .standard,
        observesNotifications: Bool = true
    ) {
        self.store = store
        self.isAvailable = isAvailable
        self.formatVersion = formatVersion
        self.readEnvelope = readEnvelope
        self.defaults = defaults
        guard isAvailable, observesNotifications else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onExternalChange?() }
        })
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.flush() }
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Reading

    /// What the cloud holds under `key`, decompressed and classified.
    func remote(forKey key: String) -> CloudRemote {
        guard isAvailable, let blob = store.data(forKey: key) else { return .absent }
        guard let bytes = try? CloudBlob.decompress(blob) else { return .unreadable }
        if let tombstone = CloudTombstone(data: bytes) {
            return .tombstone(deletedAt: tombstone.deletedAt)
        }
        if let envelope = readEnvelope(bytes) {
            return .save(bytes: bytes, envelope: envelope)
        }
        if let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
           let version = root["formatVersion"] as? Int, version > formatVersion {
            return .newerFormat(version)
        }
        return .unreadable
    }

    /// The verdict for `key` against the local envelope (`nil` when the
    /// slot is empty here). A newer app's blob is always kept away from:
    /// `.keepLocal`, and no push either.
    func resolve(key: String, local: SaveEnvelope?) -> (verdict: CloudMergePolicy.Verdict, remote: CloudRemote) {
        let remote = remote(forKey: key)
        guard let policyRemote = remote.policyRemote else { return (.keepLocal, remote) }
        return (CloudMergePolicy.resolve(local: local, remote: policyRemote), remote)
    }

    /// Asks the store to pull; the change notification follows if
    /// anything moved.
    func synchronize() {
        guard isAvailable else { return }
        store.synchronize()
    }

    // MARK: - Holds (the anti-ping-pong rule)

    private var holds: [Int: Hold] {
        get {
            guard let data = defaults.data(forKey: Self.holdsKey),
                  let decoded = try? JSONDecoder().decode([Int: Hold].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: Self.holdsKey)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.holdsKey)
            }
        }
    }

    /// Records that `slot` took the remote copy at `day`: no push of the
    /// same company until it is played past that day.
    func hold(slot: Int, seed: UInt64?, untilDay day: Int) {
        var holds = holds
        holds[slot] = Hold(seed: seed, day: day)
        self.holds = holds
    }

    func clearHold(slot: Int) {
        var holds = holds
        holds.removeValue(forKey: slot)
        self.holds = holds
    }

    func hold(forSlot slot: Int) -> Hold? { holds[slot] }

    /// Whether a push of `slot` must wait. A different company in the slot
    /// (another seed) or a save past the held day lifts the hold.
    func isHeld(slot: Int, local: SaveEnvelope?) -> Bool {
        guard let hold = holds[slot] else { return false }
        guard let local else { return false }
        if hold.seed != nil, local.summary?.seed != hold.seed {
            clearHold(slot: slot)
            return false
        }
        if (local.summary?.day ?? 0) > hold.day {
            clearHold(slot: slot)
            return false
        }
        return true
    }

    // MARK: - Writing

    /// Queues a push of `key`; the bytes are read when the write happens.
    /// One write per key per `pushInterval`, whatever the autosave does.
    func requestPush(key: String, bytes: @escaping () -> Data?) {
        request(key: key, .save(bytes))
    }

    /// Queues a tombstone for `key`. Replaces any save waiting to go.
    func requestTombstone(key: String) {
        request(key: key, .tombstone(deletedAt: now()))
    }

    private func request(key: String, _ outgoing: Outgoing) {
        guard isAvailable else { return }
        pending[key] = outgoing
        guard scheduled[key] == nil else { return }
        let elapsed = now().timeIntervalSince(lastPushAt[key] ?? .distantPast)
        let delay = pushInterval - elapsed
        guard delay > 0 else {
            performPush(key: key)
            return
        }
        scheduled[key] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.scheduled[key] = nil
            self.performPush(key: key)
        }
    }

    /// Writes everything waiting, now. Backgrounding calls this.
    func flush() {
        for key in Array(pending.keys) {
            scheduled[key]?.cancel()
            scheduled[key] = nil
            performPush(key: key)
        }
    }

    /// Keys with a write waiting for its turn.
    var pendingKeys: Set<String> { Set(pending.keys) }

    private func performPush(key: String) {
        guard let outgoing = pending.removeValue(forKey: key) else { return }
        lastPushAt[key] = now()
        // A newer app's blob is never written over.
        if case .newerFormat = remote(forKey: key) { return }
        switch outgoing {
        case .tombstone(let deletedAt):
            guard let bytes = try? CloudTombstone(deletedAt: deletedAt).encoded(),
                  let blob = try? CloudBlob.compress(bytes)
            else { return }
            store.setData(blob, forKey: key)
            pushLog.append(PushRecord(key: key, day: nil, kind: "tombstone"))
        case .save(let provider):
            // The slot may have emptied since the request; nothing to push.
            guard let bytes = provider(), let blob = try? CloudBlob.compress(bytes) else { return }
            if blob.count > CloudBlob.maxBytes {
                if !localOnlyKeys.contains(key) {
                    localOnlyKeys.insert(key)
                    onLocalOnlyKeysChanged?(localOnlyKeys)
                }
                return
            }
            if localOnlyKeys.contains(key) {
                localOnlyKeys.remove(key)
                onLocalOnlyKeysChanged?(localOnlyKeys)
            }
            store.setData(blob, forKey: key)
            pushLog.append(PushRecord(key: key, day: readEnvelope(bytes)?.summary?.day, kind: "save"))
        }
        store.synchronize()
    }
}
