import Foundation
import Testing
import TycoonSave

private struct Dummy: Codable, Sendable, Equatable {
    var name: String
    var score: Int
}

private func makeTempDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("TycoonSaveI7-\(UUID().uuidString)", isDirectory: true)
}

@Suite("Iteration 7 save scaffold")
struct Iteration7SaveScaffoldTests {
    @Test("A summary's seed and epilogue round-trip and read as nil when absent")
    func summaryNewFields() throws {
        let summary = SaveSummary(
            companyName: "Co", founderName: "Ada", day: 40, seed: 4242, epilogue: "ipo"
        )
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(SaveSummary.self, from: data)
        #expect(decoded == summary)
        #expect(decoded.seed == 4242)
        #expect(decoded.epilogue == "ipo")

        let old = try JSONDecoder().decode(
            SaveSummary.self,
            from: try JSONSerialization.data(withJSONObject: ["companyName": "Old", "day": 3])
        )
        #expect(old.seed == nil)
        #expect(old.epilogue == nil)
    }

    @Test("Raw bytes round-trip through another store and rotate the backup")
    func rawRoundTrip() throws {
        let a = makeTempDirectory()
        let b = makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: a)
            try? FileManager.default.removeItem(at: b)
        }
        let source = SaveStore<Dummy>(directory: a, currentFormatVersion: 1)
        let target = SaveStore<Dummy>(directory: b, currentFormatVersion: 1)
        #expect(source.rawSave(slot: 1) == nil)

        try source.save(Dummy(name: "cloud", score: 9), appVersion: "1", summary: SaveSummary(companyName: "C", founderName: "F", day: 9, seed: 7), slot: 1)
        let bytes = try #require(source.rawSave(slot: 1))

        try target.save(Dummy(name: "local", score: 1), appVersion: "1", slot: 1)
        try target.importRaw(bytes, slot: 1)
        let loaded = try #require(try target.load(slot: 1))
        #expect(loaded.state == Dummy(name: "cloud", score: 9))
        #expect(loaded.envelope.summary?.seed == 7)
        #expect(FileManager.default.fileExists(atPath: b.appendingPathComponent("slot1.backup.json").path))
        #expect(target.rawSave(slot: 1) == bytes)
    }

    @Test("Importing bytes that are not a save touches nothing")
    func importRejectsGarbage() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore<Dummy>(directory: dir, currentFormatVersion: 1)
        try store.save(Dummy(name: "keep", score: 2), appVersion: "1")
        #expect(throws: SaveStoreError.corruptSave) {
            try store.importRaw(Data("not json".utf8))
        }
        let loaded = try #require(try store.load())
        #expect(loaded.state.name == "keep")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".tmp") }
        #expect(leftovers.isEmpty)
    }

    @Test("Importing a newer format is refused as such")
    func importRejectsFuture() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore<Dummy>(directory: dir, currentFormatVersion: 1)
        let future: [String: Any] = [
            "formatVersion": 9, "savedAt": "2026-09-05T00:00:00Z", "appVersion": "9",
            "state": ["name": "x", "score": 0],
        ]
        #expect(throws: SaveStoreError.futureFormat(9)) {
            try store.importRaw(try JSONSerialization.data(withJSONObject: future))
        }
        #expect(store.hasSave == false)
    }

    @Test("The merge policy settles the one-sided cases")
    func mergePolicyOneSided() {
        let env = SaveEnvelope(formatVersion: 1, savedAt: Date(), appVersion: "1")
        #expect(CloudMergePolicy.resolve(local: nil, remote: nil) == .keepLocal)
        #expect(CloudMergePolicy.resolve(local: nil, remote: env) == .takeRemote)
        #expect(CloudMergePolicy.resolve(local: env, remote: nil) == .pushLocal)
    }
}
