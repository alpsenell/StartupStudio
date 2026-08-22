import Foundation

/// Versioned envelope written to disk. `state` is stored as raw JSON so the
/// envelope can be inspected and migrated without decoding the game payload.
public struct SaveEnvelope: Sendable, Equatable {
    public var formatVersion: Int
    public var savedAt: Date
    public var appVersion: String

    public init(formatVersion: Int, savedAt: Date, appVersion: String) {
        self.formatVersion = formatVersion
        self.savedAt = savedAt
        self.appVersion = appVersion
    }
}

public enum SaveStoreError: Error, Equatable {
    /// Both the main save and the backup failed to decode/migrate.
    case corruptSave
    /// The save was written by a NEWER app (formatVersion > current).
    case futureFormat(Int)
}

/// One migration step: transforms the raw JSON *state dictionary* from
/// version N to N+1. Steps are pure and run in ascending order.
public struct MigrationStep: Sendable {
    public var fromVersion: Int
    public var migrate: @Sendable (inout [String: Any]) throws -> Void

    public init(
        fromVersion: Int,
        migrate: @escaping @Sendable (inout [String: Any]) throws -> Void
    ) {
        self.fromVersion = fromVersion
        self.migrate = migrate
    }
}
