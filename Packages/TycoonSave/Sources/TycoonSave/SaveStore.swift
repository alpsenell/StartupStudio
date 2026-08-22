import Foundation

/// A generic, versioned, single-slot save-file store.
///
/// On-disk format (one JSON object per file, `slot0.json` plus a rotating
/// `slot0.backup.json`):
///
/// ```json
/// {
///   "appVersion": "1.2.3",
///   "formatVersion": 2,
///   "savedAt": "2026-08-21T10:00:00Z",
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
/// Durability:
/// - Saves are staged to a temp file in the same directory and moved into
///   place, so a failed write never destroys the previous good save.
/// - The previous good `slot0.json` rotates to `slot0.backup.json` before the
///   new file lands; `load()` falls back to the backup when the main file is
///   corrupt (or missing after an interrupted save).
/// - Loading never crashes: every failure path is a thrown error or `nil`.
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

    private let directory: URL
    private let currentFormatVersion: Int
    private let migrationsByFromVersion: [Int: MigrationStep]

    private var mainFileURL: URL { directory.appendingPathComponent("slot0.json") }
    private var backupFileURL: URL { directory.appendingPathComponent("slot0.backup.json") }

    /// - Parameters:
    ///   - directory: where save files live; pass `nil` for the default
    ///     (Application Support/Saves under the app container, created on
    ///     demand).
    ///   - currentFormatVersion: the format this app writes.
    ///   - migrations: ordered steps covering fromVersion = 1 ..< currentFormatVersion.
    ///     If several steps share a `fromVersion`, the first one wins.
    public init(
        directory: URL? = nil,
        currentFormatVersion: Int,
        migrations: [MigrationStep] = []
    ) {
        self.directory = directory ?? Self.defaultDirectory()
        self.currentFormatVersion = currentFormatVersion
        self.migrationsByFromVersion = Dictionary(
            migrations.map { ($0.fromVersion, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Atomic write of envelope + state to `slot0.json`. The previous good
    /// `slot0.json` (if any) rotates to `slot0.backup.json` first.
    public func save(_ state: State, appVersion: String) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let stateData = try encoder.encode(state)
        let stateObject = try JSONSerialization.jsonObject(
            with: stateData, options: [.fragmentsAllowed]
        )

        let root: [String: Any] = [
            Key.formatVersion: currentFormatVersion,
            Key.savedAt: ISO8601DateFormatter().string(from: Date()),
            Key.appVersion: appVersion,
            Key.state: stateObject,
        ]
        let rootData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])

        // Stage the new save in the same directory first: if this write
        // fails, nothing on disk has been touched yet.
        let stagingURL = directory.appendingPathComponent("slot0.\(UUID().uuidString).tmp")
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

    /// `nil` when no save exists. Tries `slot0.json`; on decode/migration
    /// failure falls back to `slot0.backup.json`; if both fail throws
    /// `.corruptSave`. Throws `.futureFormat` if the envelope's
    /// `formatVersion` exceeds current. Runs migrations when
    /// `formatVersion < current`, then decodes `State`.
    public func load() throws -> (state: State, envelope: SaveEnvelope)? {
        let fileManager = FileManager.default
        let mainExists = fileManager.fileExists(atPath: mainFileURL.path)
        let backupExists = fileManager.fileExists(atPath: backupFileURL.path)
        guard mainExists || backupExists else { return nil }

        if mainExists {
            do {
                return try readSave(at: mainFileURL)
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
                return try readSave(at: backupFileURL)
            } catch SaveStoreError.futureFormat(let version) {
                throw SaveStoreError.futureFormat(version)
            } catch {
                throw SaveStoreError.corruptSave
            }
        }
        throw SaveStoreError.corruptSave
    }

    /// True if `slot0.json` exists on disk.
    public var hasSave: Bool {
        FileManager.default.fileExists(atPath: mainFileURL.path)
    }

    /// Removes `slot0.json` and `slot0.backup.json` (new-game flow).
    public func deleteAll() throws {
        let fileManager = FileManager.default
        for url in [mainFileURL, backupFileURL]
        where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Private

    private func readSave(at url: URL) throws -> (state: State, envelope: SaveEnvelope) {
        let data = try Data(contentsOf: url)
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

        let migratedData = try JSONSerialization.data(withJSONObject: stateObject)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(State.self, from: migratedData)
        let envelope = SaveEnvelope(
            formatVersion: formatVersion,
            savedAt: savedAt,
            appVersion: appVersion
        )
        return (state: state, envelope: envelope)
    }

    private static func defaultDirectory() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Saves", isDirectory: true)
    }
}
