import Foundation

/// A generic, versioned save-file store with a few numbered slots.
///
/// On-disk format (one JSON object per file, `slot<N>.json` plus a
/// rotating `slot<N>.backup.json` for each slot; `slot0.json` is the file
/// the single-slot store always wrote, byte for byte):
///
/// ```json
/// {
///   "appVersion": "1.2.3",
///   "formatVersion": 2,
///   "savedAt": "2026-08-21T10:00:00Z",
///   "summary": { "companyName": "…", "founderName": "…", "day": 214 },
///   "state": { ... }
/// }
/// ```
///
/// The envelope layer is read and written with `JSONSerialization` so
/// migrations can transform the raw `state` dictionary without decoding the
/// game payload; the `State` payload itself is encoded/decoded with
/// `JSONEncoder`/`JSONDecoder` (ISO 8601 dates, sorted keys). `State` must
/// therefore encode to a JSON *object* (any `Codable` struct/class does).
///
/// `summary` is optional: an app that predates it never wrote it and reads
/// the envelope key by key, so it ignores the key on files this app writes;
/// `slots()` fills a missing summary in by decoding the state once.
///
/// Durability:
/// - Saves are staged to a temp file in the same directory and moved into
///   place, so a failed write never destroys the previous good save.
/// - The previous good `slot<N>.json` rotates to `slot<N>.backup.json`
///   before the new file lands; `load(slot:)` falls back to the backup when
///   the main file is corrupt (or missing after an interrupted save).
/// - Loading never crashes: every failure path is a thrown error or `nil`.
/// - Slots are independent: nothing that happens to one slot's files
///   touches another's.
///
/// Concurrency: this class is `Sendable` because it holds only immutable
/// configuration. File I/O itself is not synchronized across instances (or
/// processes); the app is expected to use a single instance from a single
/// isolation domain — typically the main actor.
/// Envelope keys of the on-disk JSON object.
private enum Key {
    static let formatVersion = "formatVersion"
    static let savedAt = "savedAt"
    static let appVersion = "appVersion"
    static let summary = "summary"
    static let state = "state"
}

public final class SaveStore<State: Codable & Sendable>: Sendable {

    /// Internal read failures. Never surfaced publicly: they either trigger
    /// the backup fallback or are mapped to `SaveStoreError.corruptSave`.
    private enum ReadFailure: Error {
        case notAJSONObject
        case invalidEnvelope
        case stateNotADictionary
        case missingMigration(fromVersion: Int)
    }

    /// The raw pieces of one save file, before the state is decoded.
    private struct RawSave {
        var envelope: SaveEnvelope
        var stateObject: [String: Any]
    }

    /// How many slots the game has. Three: the doc's number, and enough
    /// that a second founder never has to bulldoze the first.
    public static var defaultSlotCount: Int { 3 }

    private let directory: URL
    private let currentFormatVersion: Int
    private let migrationsByFromVersion: [Int: MigrationStep]

    /// Slots are numbered `0 ..< slotCount`.
    public let slotCount: Int

    private func mainFileURL(slot: Int) -> URL {
        directory.appendingPathComponent("slot\(slot).json")
    }

    private func backupFileURL(slot: Int) -> URL {
        directory.appendingPathComponent("slot\(slot).backup.json")
    }

    /// - Parameters:
    ///   - directory: where save files live; pass `nil` for the default
    ///     (Application Support/Saves under the app container, created on
    ///     demand).
    ///   - currentFormatVersion: the format this app writes.
    ///   - migrations: ordered steps covering fromVersion = 1 ..< currentFormatVersion.
    ///     If several steps share a `fromVersion`, the first one wins.
    ///   - slotCount: how many slots to keep; at least one.
    public init(
        directory: URL? = nil,
        currentFormatVersion: Int,
        migrations: [MigrationStep] = [],
        slotCount: Int = SaveStore.defaultSlotCount
    ) {
        self.directory = directory ?? Self.defaultDirectory()
        self.currentFormatVersion = currentFormatVersion
        self.migrationsByFromVersion = Dictionary(
            migrations.map { ($0.fromVersion, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.slotCount = max(1, slotCount)
    }

    /// Atomic write of envelope + state to `slot<N>.json`. The previous
    /// good `slot<N>.json` (if any) rotates to `slot<N>.backup.json` first.
    /// `summary` rides in the envelope for `slots()` to list.
    public func save(
        _ state: State, appVersion: String, summary: SaveSummary? = nil, slot: Int = 0
    ) throws {
        checkSlot(slot)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let stateData = try encoder.encode(state)
        let stateObject = try JSONSerialization.jsonObject(
            with: stateData, options: [.fragmentsAllowed]
        )

        var root: [String: Any] = [
            Key.formatVersion: currentFormatVersion,
            Key.savedAt: ISO8601DateFormatter().string(from: Date()),
            Key.appVersion: appVersion,
            Key.state: stateObject,
        ]
        if let summary {
            root[Key.summary] = try JSONSerialization.jsonObject(
                with: try encoder.encode(summary), options: [.fragmentsAllowed]
            )
        }
        let rootData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])

        // Stage the new save in the same directory first: if this write
        // fails, nothing on disk has been touched yet.
        let mainFileURL = mainFileURL(slot: slot)
        let backupFileURL = backupFileURL(slot: slot)
        let stagingURL = directory.appendingPathComponent("slot\(slot).\(UUID().uuidString).tmp")
        try rootData.write(to: stagingURL, options: [.atomic])
        do {
            // Rotate the previous good save to the backup slot, then move the
            // staged file into place (a rename within one directory).
            if fileManager.fileExists(atPath: mainFileURL.path) {
                if fileManager.fileExists(atPath: backupFileURL.path) {
                    try fileManager.removeItem(at: backupFileURL)
                }
                try fileManager.moveItem(at: mainFileURL, to: backupFileURL)
            }
            try fileManager.moveItem(at: stagingURL, to: mainFileURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    /// `nil` when no save exists in the slot. Tries `slot<N>.json`; on
    /// decode/migration failure falls back to `slot<N>.backup.json`; if
    /// both fail throws `.corruptSave`. Throws `.futureFormat` if the
    /// envelope's `formatVersion` exceeds current. Runs migrations when
    /// `formatVersion < current`, then decodes `State`.
    public func load(slot: Int = 0) throws -> (state: State, envelope: SaveEnvelope)? {
        checkSlot(slot)
        return try withFallback(slot: slot) { url in
            let raw = try readRaw(at: url)
            return (state: try decodeState(raw), envelope: raw.envelope)
        }
    }

    /// True if `slot0.json` exists on disk.
    public var hasSave: Bool {
        hasSave(slot: 0)
    }

    /// True if `slot<N>.json` exists on disk.
    public func hasSave(slot: Int) -> Bool {
        checkSlot(slot)
        return FileManager.default.fileExists(atPath: mainFileURL(slot: slot).path)
    }

    // MARK: - Raw bytes (iteration 7, R2's cloud sync)

    /// The slot's save file exactly as written — envelope and state — or
    /// `nil` when the slot is empty. The bytes are what iCloud carries, so
    /// a cloud blob is a save file and migrations run on the way back in.
    public func rawSave(slot: Int = 0) -> Data? {
        checkSlot(slot)
        return try? Data(contentsOf: mainFileURL(slot: slot))
    }

    /// Decodes a save file's bytes without touching the disk: the envelope
    /// and the migrated state, exactly as `load` would produce them for a
    /// file in a slot. Throws `.futureFormat` and `.corruptSave` the way
    /// `load` does. What the cloud sync uses to merge the legacy ledger.
    public func read(raw data: Data) throws -> (state: State, envelope: SaveEnvelope) {
        let raw: RawSave
        do {
            raw = try parseRaw(data)
        } catch let error as SaveStoreError {
            throw error
        } catch {
            throw SaveStoreError.corruptSave
        }
        do {
            return (state: try decodeState(raw), envelope: raw.envelope)
        } catch {
            throw SaveStoreError.corruptSave
        }
    }

    /// The envelope of a save file's bytes — `nil` when they are not a
    /// save this store could read. Cheap: the state is parsed as JSON but
    /// never decoded. What the cloud merge policy is fed.
    public func envelope(in data: Data) -> SaveEnvelope? {
        (try? parseRaw(data))?.envelope
    }

    /// Installs `data` — a save file another device wrote — as the slot's
    /// save, staged and rotated exactly like `save`: the previous good
    /// file becomes the backup. The bytes must parse as an envelope this
    /// store can read (`.futureFormat` and `.corruptSave` throw before
    /// anything on disk is touched); migrations are *not* run here, they
    /// run on `load` as for any file.
    public func importRaw(_ data: Data, slot: Int = 0) throws {
        checkSlot(slot)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let mainFileURL = mainFileURL(slot: slot)
        let backupFileURL = backupFileURL(slot: slot)
        let stagingURL = directory.appendingPathComponent("slot\(slot).\(UUID().uuidString).tmp")
        try data.write(to: stagingURL, options: [.atomic])
        do {
            do {
                _ = try readRaw(at: stagingURL)
            } catch let error as SaveStoreError {
                throw error
            } catch {
                throw SaveStoreError.corruptSave
            }
            if fileManager.fileExists(atPath: mainFileURL.path) {
                if fileManager.fileExists(atPath: backupFileURL.path) {
                    try fileManager.removeItem(at: backupFileURL)
                }
                try fileManager.moveItem(at: mainFileURL, to: backupFileURL)
            }
            try fileManager.moveItem(at: stagingURL, to: mainFileURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    /// Removes `slot<N>.json` and `slot<N>.backup.json` — one slot, and
    /// nothing else in the directory (new-game flow into that slot).
    public func delete(slot: Int) throws {
        checkSlot(slot)
        let fileManager = FileManager.default
        for url in [mainFileURL(slot: slot), backupFileURL(slot: slot)]
        where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Removes every slot's save and backup.
    public func deleteAll() throws {
        for slot in 0..<slotCount {
            try delete(slot: slot)
        }
    }

    // MARK: - Listing

    /// One row per slot, `0 ..< slotCount`, without decoding any state a
    /// summary can stand in for.
    ///
    /// A slot whose envelope carries a summary lists from that alone. A
    /// slot written before summaries existed (a single-slot `slot0.json`)
    /// has its state decoded and migrated once and handed to `summarize`;
    /// with no summarizer such a slot lists with an empty summary rather
    /// than not at all. A corrupt or newer-format slot lists as exactly
    /// that, and never stops the others listing.
    public func slots(
        summarize: ((State) -> SaveSummary)? = nil
    ) -> [SlotSummary] {
        (0..<slotCount).map { slotSummary(slot: $0, summarize: summarize) }
    }

    /// The listing row for one slot. See `slots(summarize:)`.
    public func slotSummary(
        slot: Int, summarize: ((State) -> SaveSummary)? = nil
    ) -> SlotSummary {
        checkSlot(slot)
        do {
            guard let found = try withFallback(slot: slot, { url -> (SaveSummary, SaveEnvelope) in
                let raw = try readRaw(at: url)
                if let summary = raw.envelope.summary {
                    return (summary, raw.envelope)
                }
                // Decoding the state is the one way to know what an old
                // save holds; a state that will not decode is a corrupt
                // file, and the backup gets its turn.
                let state = try decodeState(raw)
                let summary = summarize?(state)
                    ?? SaveSummary(companyName: "", founderName: "", day: 0)
                return (summary, raw.envelope)
            }) else {
                return SlotSummary(slot: slot, contents: .empty)
            }
            return SlotSummary(slot: slot, contents: .saved(summary: found.0, envelope: found.1))
        } catch SaveStoreError.futureFormat(let version) {
            return SlotSummary(slot: slot, contents: .futureFormat(version))
        } catch {
            return SlotSummary(slot: slot, contents: .corrupt)
        }
    }

    // MARK: - Private

    /// Runs `read` on the slot's main file, then on its backup when the
    /// main file is missing or fails for any reason but a newer format.
    /// `nil` when the slot has neither file; `.corruptSave` when both fail.
    private func withFallback<T>(
        slot: Int, _ read: (URL) throws -> T
    ) throws -> T? {
        let fileManager = FileManager.default
        let mainFileURL = mainFileURL(slot: slot)
        let backupFileURL = backupFileURL(slot: slot)
        let mainExists = fileManager.fileExists(atPath: mainFileURL.path)
        let backupExists = fileManager.fileExists(atPath: backupFileURL.path)
        guard mainExists || backupExists else { return nil }

        if mainExists {
            do {
                return try read(mainFileURL)
            } catch SaveStoreError.futureFormat(let version) {
                // A newer-format save is intact, just unreadable by this app
                // version; do not fall back over it.
                throw SaveStoreError.futureFormat(version)
            } catch {
                // Corrupt or unmigratable: fall through to the backup.
            }
        }
        if backupExists {
            do {
                return try read(backupFileURL)
            } catch SaveStoreError.futureFormat(let version) {
                throw SaveStoreError.futureFormat(version)
            } catch {
                throw SaveStoreError.corruptSave
            }
        }
        throw SaveStoreError.corruptSave
    }

    /// Parses the envelope and runs the migrations on the raw state
    /// dictionary, without decoding `State`.
    private func readRaw(at url: URL) throws -> RawSave {
        try parseRaw(try Data(contentsOf: url))
    }

    /// The same, on bytes already in hand.
    private func parseRaw(_ data: Data) throws -> RawSave {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ReadFailure.notAJSONObject
        }
        guard let formatVersion = root[Key.formatVersion] as? Int else {
            throw ReadFailure.invalidEnvelope
        }
        if formatVersion > currentFormatVersion {
            throw SaveStoreError.futureFormat(formatVersion)
        }
        guard
            let savedAtString = root[Key.savedAt] as? String,
            let savedAt = ISO8601DateFormatter().date(from: savedAtString),
            let appVersion = root[Key.appVersion] as? String
        else {
            throw ReadFailure.invalidEnvelope
        }
        guard var stateObject = root[Key.state] as? [String: Any] else {
            throw ReadFailure.stateNotADictionary
        }

        if formatVersion < currentFormatVersion {
            for version in formatVersion..<currentFormatVersion {
                guard let step = migrationsByFromVersion[version] else {
                    throw ReadFailure.missingMigration(fromVersion: version)
                }
                try step.migrate(&stateObject)
            }
        }

        // A summary that will not decode is treated as absent, not as a
        // corrupt save: it is a convenience beside the state, never the
        // state itself.
        var summary: SaveSummary?
        if let summaryObject = root[Key.summary] as? [String: Any],
           let summaryData = try? JSONSerialization.data(withJSONObject: summaryObject) {
            summary = try? JSONDecoder().decode(SaveSummary.self, from: summaryData)
        }

        let envelope = SaveEnvelope(
            formatVersion: formatVersion,
            savedAt: savedAt,
            appVersion: appVersion,
            summary: summary
        )
        return RawSave(envelope: envelope, stateObject: stateObject)
    }

    private func decodeState(_ raw: RawSave) throws -> State {
        let migratedData = try JSONSerialization.data(withJSONObject: raw.stateObject)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(State.self, from: migratedData)
    }

    /// A slot outside `0 ..< slotCount` is a programming error, not a
    /// data error: nothing on disk can make it happen.
    private func checkSlot(_ slot: Int) {
        precondition(
            (0..<slotCount).contains(slot),
            "SaveStore slot \(slot) is outside 0..<\(slotCount)"
        )
    }

    private static func defaultDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Saves", isDirectory: true)
    }
}
