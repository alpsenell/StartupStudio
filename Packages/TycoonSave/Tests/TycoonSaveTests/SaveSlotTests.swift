import Foundation
import Testing
import TycoonSave

// MARK: - Fixtures

private struct Dummy: Codable, Sendable, Equatable {
    var name: String
    var score: Int
}

private func makeTempDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("TycoonSaveSlotTests-\(UUID().uuidString)", isDirectory: true)
}

private func fileURL(slot: Int, backup: Bool = false, in directory: URL) -> URL {
    directory.appendingPathComponent(backup ? "slot\(slot).backup.json" : "slot\(slot).json")
}

private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

private func writeJSONObject(_ object: [String: Any], to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try JSONSerialization.data(withJSONObject: object).write(to: url)
}

private func writeGarbage(to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try Data("this is definitely {{{ not json".utf8).write(to: url)
}

private func rootObject(at url: URL) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
}

/// The app's summarizer, stood in for: a summary from the state itself.
private func summarize(_ dummy: Dummy) -> SaveSummary {
    SaveSummary(companyName: dummy.name, founderName: "Founder of \(dummy.name)", day: dummy.score)
}

// MARK: - Tests

@Suite("SaveStore slots")
struct SaveSlotTests {

    @Test("Three slots save, load and list independently")
    func threeSlotsAreIndependent() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        #expect(store.slotCount == 3)

        for slot in 0..<3 {
            let state = Dummy(name: "company\(slot)", score: slot * 100)
            try store.save(state, appVersion: "1.0", summary: summarize(state), slot: slot)
        }

        for slot in 0..<3 {
            #expect(exists(fileURL(slot: slot, in: directory)))
            #expect(store.hasSave(slot: slot))
            let loaded = try #require(try store.load(slot: slot))
            #expect(loaded.state == Dummy(name: "company\(slot)", score: slot * 100))
            #expect(loaded.envelope.summary?.companyName == "company\(slot)")
        }

        let listed = store.slots()
        #expect(listed.map(\.slot) == [0, 1, 2])
        #expect(listed.map { $0.summary?.day } == [0, 100, 200])
        #expect(listed.allSatisfy { !$0.isEmpty })
    }

    @Test("Saving into one slot never touches another slot's bytes")
    func savingOneSlotLeavesTheOthersByteIdentical() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)

        try store.save(Dummy(name: "first", score: 1), appVersion: "1.0", slot: 0)
        let slot0Before = try Data(contentsOf: fileURL(slot: 0, in: directory))

        try store.save(Dummy(name: "second", score: 2), appVersion: "1.0", slot: 1)
        try store.save(Dummy(name: "second again", score: 3), appVersion: "1.0", slot: 1)

        #expect(try Data(contentsOf: fileURL(slot: 0, in: directory)) == slot0Before)
        #expect(!exists(fileURL(slot: 0, backup: true, in: directory)))
        // Slot 1 rotated its own backup, and only its own.
        #expect(exists(fileURL(slot: 1, backup: true, in: directory)))
        #expect(!exists(fileURL(slot: 2, in: directory)))
    }

    @Test("Deleting one slot leaves the others in place")
    func deletingOneSlotLeavesTheOthers() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        for slot in 0..<3 {
            try store.save(Dummy(name: "a", score: slot), appVersion: "1.0", slot: slot)
            try store.save(Dummy(name: "b", score: slot), appVersion: "1.0", slot: slot)
        }

        try store.delete(slot: 1)

        #expect(!exists(fileURL(slot: 1, in: directory)))
        #expect(!exists(fileURL(slot: 1, backup: true, in: directory)))
        #expect(!store.hasSave(slot: 1))
        #expect(try store.load(slot: 1) == nil)
        for slot in [0, 2] {
            #expect(exists(fileURL(slot: slot, in: directory)))
            #expect(exists(fileURL(slot: slot, backup: true, in: directory)))
            #expect(try #require(try store.load(slot: slot)).state == Dummy(name: "b", score: slot))
        }
        let listed = store.slots()
        #expect(listed[1].isEmpty)
        #expect(!listed[0].isEmpty && !listed[2].isEmpty)

        // Deleting an empty slot is a no-op, not an error.
        try store.delete(slot: 1)
    }

    @Test("deleteAll clears every slot")
    func deleteAllClearsEverySlot() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        for slot in 0..<3 {
            try store.save(Dummy(name: "a", score: slot), appVersion: "1.0", slot: slot)
        }
        try store.deleteAll()
        #expect(store.slots().allSatisfy { $0.isEmpty })
    }

    @Test("A corrupt slot lists as corrupt and never blocks another")
    func corruptSlotListsAsCorrupt() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        let good = Dummy(name: "good", score: 7)
        try store.save(good, appVersion: "1.0", summary: summarize(good), slot: 0)
        try writeGarbage(to: fileURL(slot: 1, in: directory))
        try writeGarbage(to: fileURL(slot: 1, backup: true, in: directory))

        let listed = store.slots()
        #expect(listed[0].summary?.companyName == "good")
        #expect(listed[1].contents == .corrupt)
        #expect(listed[2].isEmpty)
        #expect(throws: SaveStoreError.corruptSave) { _ = try store.load(slot: 1) }
        #expect(try #require(try store.load(slot: 0)).state == good)
    }

    @Test("A slot whose main file is corrupt lists from its backup")
    func corruptMainListsFromBackup() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        let older = Dummy(name: "older", score: 1)
        try store.save(older, appVersion: "1.0", summary: summarize(older), slot: 2)
        try store.save(Dummy(name: "newer", score: 2), appVersion: "1.1", slot: 2)
        try writeGarbage(to: fileURL(slot: 2, in: directory))

        let row = store.slotSummary(slot: 2)
        #expect(row.summary?.companyName == "older")
        #expect(row.summary?.day == 1)
    }

    @Test("A slot from a newer app lists as a future format")
    func futureFormatSlotLists() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 2)
        try writeJSONObject(
            [
                "formatVersion": 5,
                "savedAt": "2026-08-21T10:00:00Z",
                "appVersion": "9.9.9",
                "state": ["name": "future", "score": 0],
            ],
            to: fileURL(slot: 1, in: directory)
        )
        #expect(store.slotSummary(slot: 1).contents == .futureFormat(5))
        #expect(store.slotSummary(slot: 0).isEmpty)
    }

    @Test("An old single-slot directory lists as slot 0, summarized from its state")
    func legacySingleSlotListsAsSlotZero() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // Exactly what the single-slot store wrote: no summary key.
        try writeJSONObject(
            [
                "formatVersion": 1,
                "savedAt": "2026-08-20T09:00:00Z",
                "appVersion": "0.9.0",
                "state": ["name": "legacy", "score": 400],
            ],
            to: fileURL(slot: 0, in: directory)
        )
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)

        let listed = store.slots(summarize: summarize)
        #expect(listed.count == 3)
        let row = try #require(listed.first)
        #expect(row.slot == 0)
        #expect(row.summary == SaveSummary(companyName: "legacy", founderName: "Founder of legacy", day: 400))
        #expect(row.lastPlayed == ISO8601DateFormatter().date(from: "2026-08-20T09:00:00Z"))
        #expect(listed[1].isEmpty && listed[2].isEmpty)

        // Without a summarizer the slot still lists, with a blank summary.
        #expect(store.slots()[0].summary == SaveSummary(companyName: "", founderName: "", day: 0))
        // And it still loads, as the single-slot API always did.
        let loaded = try #require(try store.load())
        #expect(loaded.state == Dummy(name: "legacy", score: 400))
        #expect(loaded.envelope.summary == nil)
    }

    @Test("An old save is migrated before it is summarized")
    func legacySlotIsMigratedBeforeSummarizing() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let renamePointsToScore = MigrationStep(fromVersion: 1) { state in
            if let points = state.removeValue(forKey: "points") { state["score"] = points }
        }
        let store = SaveStore<Dummy>(
            directory: directory, currentFormatVersion: 2, migrations: [renamePointsToScore]
        )
        try writeJSONObject(
            [
                "formatVersion": 1,
                "savedAt": "2026-08-20T09:00:00Z",
                "appVersion": "0.9.0",
                "state": ["name": "legacy", "points": 12],
            ],
            to: fileURL(slot: 0, in: directory)
        )
        #expect(store.slotSummary(slot: 0, summarize: summarize).summary?.day == 12)
    }

    @Test("The default slot is still slot0.json with the same envelope keys")
    func defaultSlotKeepsItsLayout() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        try store.save(Dummy(name: "plain", score: 1), appVersion: "1.0")

        let root = try rootObject(at: fileURL(slot: 0, in: directory))
        #expect(Set(root.keys) == ["appVersion", "formatVersion", "savedAt", "state"])
        #expect(store.hasSave)
        #expect(try #require(try store.load()).state == Dummy(name: "plain", score: 1))
    }

    @Test("A summary rides in the envelope and decodes with missing or extra fields")
    func summaryRoundTripsAndTolerates() throws {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore<Dummy>(directory: directory, currentFormatVersion: 1)
        let summary = SaveSummary(
            companyName: "Northgate", founderName: "Mira", day: 214,
            ending: "acquired", chapter: 3, chapterTitle: "The loft",
            founderAppearanceSeed: 0x5EED
        )
        try store.save(Dummy(name: "n", score: 1), appVersion: "1.0", summary: summary, slot: 1)

        let root = try rootObject(at: fileURL(slot: 1, in: directory))
        #expect(root["summary"] != nil)
        #expect(try #require(try store.load(slot: 1)).envelope.summary == summary)
        #expect(store.slotSummary(slot: 1).summary == summary)

        // A summary from another app version: a field missing, a field
        // this app has never heard of. Both read.
        try writeJSONObject(
            [
                "formatVersion": 1,
                "savedAt": "2026-08-20T09:00:00Z",
                "appVersion": "2.0.0",
                "summary": ["companyName": "Future Co", "day": 9, "mascot": "otter"],
                "state": ["name": "f", "score": 9],
            ],
            to: fileURL(slot: 2, in: directory)
        )
        let row = store.slotSummary(slot: 2)
        #expect(row.summary == SaveSummary(companyName: "Future Co", founderName: "", day: 9))

        // A summary that is not even an object is ignored, not fatal.
        try writeJSONObject(
            [
                "formatVersion": 1,
                "savedAt": "2026-08-20T09:00:00Z",
                "appVersion": "2.0.0",
                "summary": "nonsense",
                "state": ["name": "g", "score": 3],
            ],
            to: fileURL(slot: 0, in: directory)
        )
        #expect(store.slotSummary(slot: 0, summarize: summarize).summary?.companyName == "g")
    }
}
