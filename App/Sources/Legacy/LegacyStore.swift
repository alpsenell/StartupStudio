import Foundation
import TycoonEngine
import TycoonSave

// MARK: Iteration 7 — the ledger on disk (R2)

/// The legacy ledger's own store: a second `SaveStore` in a second
/// directory (`…/Legacy`), one slot, so `deleteAll()` on the saves store
/// cannot reach it by construction.
@MainActor
final class LegacyStore {
    static let formatVersion = 1

    private let store: SaveStore<LegacyLedger>

    /// - Parameter directory: where the ledger lives; `nil` for the app's
    ///   own `Application Support/Legacy`.
    init(directory: URL? = nil) {
        store = SaveStore<LegacyLedger>(
            directory: directory ?? Self.defaultDirectory(),
            currentFormatVersion: Self.formatVersion,
            slotCount: 1
        )
    }

    /// The ledger directory that sits beside a saves directory — the
    /// session derives it so a test's temporary tree holds both.
    static func directory(besideSaves saveDirectory: URL?) -> URL? {
        saveDirectory?.deletingLastPathComponent().appendingPathComponent("Legacy", isDirectory: true)
    }

    /// Whether a ledger has ever been written. The first launch that finds
    /// none seeds `endingsReached` from the slots.
    var exists: Bool { store.hasSave(slot: 0) }

    /// The ledger, or an empty one when there is none or it will not read.
    func load() -> LegacyLedger {
        (try? store.load(slot: 0))?.state ?? .empty
    }

    func save(_ ledger: LegacyLedger, appVersion: String) throws {
        try store.save(ledger, appVersion: appVersion, slot: 0)
    }

    /// The ledger file's bytes, for the cloud.
    func rawSave() -> Data? { store.rawSave(slot: 0) }

    /// A ledger another device wrote, decoded for merging.
    func read(raw data: Data) throws -> LegacyLedger { try store.read(raw: data).state }

    func envelope(in data: Data) -> SaveEnvelope? { store.envelope(in: data) }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Legacy", isDirectory: true)
    }
}
