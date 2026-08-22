import Foundation
import Testing
import TycoonSave

// MARK: - Fixtures

/// Stand-in for the game's Codable `GameState`.
private struct Dummy: Codable, Sendable, Equatable {
    var name: String
    var score: Int
}

private func makeTempDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("TycoonSaveTests-\(UUID().uuidString)", isDirectory: true)
}

private func mainFileURL(in directory: URL) -> URL {
    directory.appendingPathComponent("slot0.json")
}

private func backupFileURL(in directory: URL) -> URL {
    directory.appendingPathComponent("slot0.backup.json")
}

/// Hand-writes a raw save file, creating the directory if needed.
private func writeJSONObject(_ object: [String: Any], to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let data = try JSONSerialization.data(withJSONObject: object)
    try data.write(to: url)
}

/// Overwrites (or creates) a file with bytes that are not valid JSON.
private func writeGarbage(to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("this is definitely {{{ not json".utf8).write(to: url)
}

// MARK: - Tests

@Suite("SaveStore")
struct SaveStoreTests {

    // 1.
    @Test("Fresh store reports no save and loads nil")
    func freshStore() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        #expect(!store.hasSave)
        #expect(try store.load() == nil)
    }

    // 2.
    @Test("Save then load round-trips state and envelope")
    func saveLoadRoundTrip() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 3)
        let state = Dummy(name: "Alp", score: 42)
        let before = Date()
        try store.save(state, appVersion: "1.2.3")
        let after = Date()

        #expect(store.hasSave)
        let loaded = try #require(try store.load())
        #expect(loaded.state == state)
        #expect(loaded.envelope.formatVersion == 3)
        #expect(loaded.envelope.appVersion == "1.2.3")
        // savedAt is stored at whole-second ISO 8601 precision, so allow slack.
        #expect(loaded.envelope.savedAt >= before.addingTimeInterval(-1.5))
        #expect(loaded.envelope.savedAt <= after.addingTimeInterval(1.5))
    }

    // 3.
    @Test("Second save rotates the previous save to backup")
    func saveRotatesBackup() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        try store.save(Dummy(name: "older", score: 1), appVersion: "1.0")
        try store.save(Dummy(name: "newer", score: 2), appVersion: "1.1")

        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: mainFileURL(in: directory).path))
        #expect(fileManager.fileExists(atPath: backupFileURL(in: directory).path))

        // The backup holds the OLDER state.
        let backupData = try Data(contentsOf: backupFileURL(in: directory))
        let backupRoot = try #require(
            try JSONSerialization.jsonObject(with: backupData) as? [String: Any]
        )
        #expect(backupRoot["appVersion"] as? String == "1.0")
        let backupState = try #require(backupRoot["state"] as? [String: Any])
        #expect(backupState["name"] as? String == "older")
        #expect(backupState["score"] as? Int == 1)

        // The main slot loads the newer state.
        let loaded = try #require(try store.load())
        #expect(loaded.state == Dummy(name: "newer", score: 2))
        #expect(loaded.envelope.appVersion == "1.1")
    }

    // 4.
    @Test("Corrupt main save falls back to the backup")
    func corruptMainFallsBackToBackup() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        try store.save(Dummy(name: "older", score: 1), appVersion: "1.0")
        try store.save(Dummy(name: "newer", score: 2), appVersion: "1.1")
        try writeGarbage(to: mainFileURL(in: directory))

        let loaded = try #require(try store.load())
        #expect(loaded.state == Dummy(name: "older", score: 1))
        #expect(loaded.envelope.appVersion == "1.0")
    }

    // 5.
    @Test("Corrupt main and backup throws corruptSave")
    func corruptBothThrowsCorruptSave() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        try writeGarbage(to: mainFileURL(in: directory))
        try writeGarbage(to: backupFileURL(in: directory))

        #expect(throws: SaveStoreError.corruptSave) {
            _ = try store.load()
        }
    }

    // 6.
    @Test("A save written by a newer app throws futureFormat")
    func futureFormatThrows() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 2)
        try writeJSONObject(
            [
                "formatVersion": 3,
                "savedAt": "2026-08-21T10:00:00Z",
                "appVersion": "9.9.9",
                "state": ["name": "future", "score": 0],
            ],
            to: mainFileURL(in: directory)
        )

        #expect(throws: SaveStoreError.futureFormat(3)) {
            _ = try store.load()
        }
    }

    // 7a.
    @Test("Migrations upgrade an old save before decoding")
    func migrationRunsOnOldSave() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // v1 stored the score under "points"; v2 renamed it to "score".
        let renamePointsToScore = MigrationStep(fromVersion: 1) { state in
            if let points = state.removeValue(forKey: "points") {
                state["score"] = points
            }
        }
        let store = SaveStore<Dummy>(
            directory: directory,
            currentFormatVersion: 2,
            migrations: [renamePointsToScore]
        )
        try writeJSONObject(
            [
                "formatVersion": 1,
                "savedAt": "2026-08-20T09:00:00Z",
                "appVersion": "0.9.0",
                "state": ["name": "legacy", "points": 7],
            ],
            to: mainFileURL(in: directory)
        )

        let loaded = try #require(try store.load())
        #expect(loaded.state == Dummy(name: "legacy", score: 7))
        // The envelope reports the format version as found on disk.
        #expect(loaded.envelope.formatVersion == 1)
        #expect(loaded.envelope.appVersion == "0.9.0")
    }

    // 7b.
    @Test("An old save with no covering migration throws corruptSave")
    func missingMigrationThrowsCorruptSave() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 2)
        try writeJSONObject(
            [
                "formatVersion": 1,
                "savedAt": "2026-08-20T09:00:00Z",
                "appVersion": "0.9.0",
                "state": ["name": "legacy", "points": 7],
            ],
            to: mainFileURL(in: directory)
        )

        #expect(throws: SaveStoreError.corruptSave) {
            _ = try store.load()
        }
    }

    // 8.
    @Test("deleteAll removes main and backup saves")
    func deleteAllRemovesEverything() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        try store.save(Dummy(name: "a", score: 1), appVersion: "1.0")
        try store.save(Dummy(name: "b", score: 2), appVersion: "1.0")

        try store.deleteAll()

        let fileManager = FileManager.default
        #expect(!fileManager.fileExists(atPath: mainFileURL(in: directory).path))
        #expect(!fileManager.fileExists(atPath: backupFileURL(in: directory).path))
        #expect(!store.hasSave)
        #expect(try store.load() == nil)

        // deleteAll on an already-empty store is a no-op, not an error.
        try store.deleteAll()
    }

    // 9.
    @Test("A failed save never destroys the existing good save")
    func failedSavePreservesExistingSave() throws {
        let directory = makeTempDirectory()
        let fileManager = FileManager.default
        defer {
            try? fileManager.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: directory.path
            )
            try? fileManager.removeItem(at: directory)
        }

        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        let original = Dummy(name: "keeper", score: 1)
        try store.save(original, appVersion: "1.0")

        // Make the save directory read-only so the next write must fail.
        try fileManager.setAttributes(
            [.posixPermissions: 0o555], ofItemAtPath: directory.path
        )
        var saveFailed = false
        do {
            try store.save(Dummy(name: "clobber", score: 2), appVersion: "1.1")
        } catch {
            saveFailed = true
        }
        try fileManager.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: directory.path
        )

        guard saveFailed else {
            // The environment allowed writing into a read-only directory
            // (e.g. running as root), so the scenario is untestable here.
            return
        }
        let loaded = try #require(try store.load())
        #expect(loaded.state == original)
        #expect(loaded.envelope.appVersion == "1.0")
    }
}
