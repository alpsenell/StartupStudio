import Foundation
import Testing
import TycoonSave

private struct Dummy: Codable, Sendable, Equatable {
    var name: String
    var score: Int
}

private func makeTempDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CloudMergePolicy-\(UUID().uuidString)", isDirectory: true)
}

/// The cloud merge policy as a table (iteration 7, R2): the same company
/// is further along on the higher day, a different company is the more
/// recently saved one, a tombstone deletes anything older than itself.
@Suite("Cloud merge policy")
struct CloudMergePolicyTests {
    private static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private static func envelope(
        seed: UInt64?, day: Int, savedAt: TimeInterval = 0
    ) -> SaveEnvelope {
        SaveEnvelope(
            formatVersion: 1,
            savedAt: t0.addingTimeInterval(savedAt),
            appVersion: "0.1.0",
            summary: SaveSummary(companyName: "Co", founderName: "F", day: day, seed: seed)
        )
    }

    typealias Verdict = CloudMergePolicy.Verdict

    // MARK: Same seed: the day decides

    @Test(
        "Same seed: the higher day wins, a tie keeps local",
        arguments: [
            (localDay: 100, remoteDay: 340, verdict: Verdict.takeRemote),
            (localDay: 340, remoteDay: 100, verdict: Verdict.pushLocal),
            (localDay: 210, remoteDay: 210, verdict: Verdict.keepLocal),
            (localDay: 0, remoteDay: 1, verdict: Verdict.takeRemote),
        ]
    )
    func sameSeed(localDay: Int, remoteDay: Int, verdict: Verdict) {
        // The wall clock says the opposite of the day on purpose: the
        // local save is the more recent write in every row.
        let local = Self.envelope(seed: 4242, day: localDay, savedAt: 1_000)
        let remote = Self.envelope(seed: 4242, day: remoteDay, savedAt: 0)
        #expect(CloudMergePolicy.resolve(local: local, remote: remote) == verdict)
    }

    // MARK: Different seeds: the wall clock decides

    @Test(
        "Different seeds: the newer save wins, a tie keeps local",
        arguments: [
            (localAt: 0.0, remoteAt: 60.0, verdict: Verdict.takeRemote),
            (localAt: 60.0, remoteAt: 0.0, verdict: Verdict.pushLocal),
            (localAt: 30.0, remoteAt: 30.0, verdict: Verdict.keepLocal),
        ]
    )
    func differentSeeds(localAt: TimeInterval, remoteAt: TimeInterval, verdict: Verdict) {
        // The in-game day says the opposite on purpose: the local company
        // is the one further along in every row.
        let local = Self.envelope(seed: 1, day: 900, savedAt: localAt)
        let remote = Self.envelope(seed: 2, day: 3, savedAt: remoteAt)
        #expect(CloudMergePolicy.resolve(local: local, remote: remote) == verdict)
    }

    @Test("A summary without a seed cannot claim to be the same company, so the clock decides")
    func unknownSeedFallsBackToTheClock() {
        let old = Self.envelope(seed: nil, day: 500, savedAt: 0)
        let new = Self.envelope(seed: 7, day: 20, savedAt: 10)
        #expect(CloudMergePolicy.resolve(local: old, remote: new) == .takeRemote)
        #expect(CloudMergePolicy.resolve(local: new, remote: old) == .pushLocal)
        let bothUnknown = Self.envelope(seed: nil, day: 20, savedAt: 10)
        #expect(CloudMergePolicy.resolve(local: old, remote: bothUnknown) == .takeRemote)
    }

    // MARK: One-sided

    @Test("Nothing on either side keeps local; a lone copy moves toward the other side")
    func oneSided() {
        let env = Self.envelope(seed: 1, day: 1)
        #expect(CloudMergePolicy.resolve(local: nil, remote: nil) == .keepLocal)
        #expect(CloudMergePolicy.resolve(local: nil, remote: env) == .takeRemote)
        #expect(CloudMergePolicy.resolve(local: env, remote: nil) == .pushLocal)
        #expect(CloudMergePolicy.resolve(local: nil, remote: .absent) == .keepLocal)
        #expect(CloudMergePolicy.resolve(local: env, remote: .absent) == .pushLocal)
        #expect(CloudMergePolicy.resolve(local: nil, remote: .save(env)) == .takeRemote)
    }

    // MARK: Tombstones

    @Test("A tombstone deletes a local save older than the deletion and yields to one newer")
    func tombstone() {
        let deletedAt = Self.t0.addingTimeInterval(100)
        let older = Self.envelope(seed: 1, day: 400, savedAt: 50)
        let newer = Self.envelope(seed: 2, day: 2, savedAt: 150)
        let sameInstant = Self.envelope(seed: 1, day: 400, savedAt: 100)
        #expect(CloudMergePolicy.resolve(local: older, remote: .tombstone(deletedAt: deletedAt)) == .takeRemote)
        #expect(CloudMergePolicy.resolve(local: sameInstant, remote: .tombstone(deletedAt: deletedAt)) == .takeRemote)
        #expect(CloudMergePolicy.resolve(local: newer, remote: .tombstone(deletedAt: deletedAt)) == .pushLocal)
        #expect(CloudMergePolicy.resolve(local: nil, remote: .tombstone(deletedAt: deletedAt)) == .keepLocal)
    }

    @Test("A tombstone round-trips and is never mistaken for a save file")
    func tombstoneCodec() throws {
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_123)
        let stone = CloudTombstone(deletedAt: deletedAt)
        let bytes = try stone.encoded()
        let decoded = try #require(CloudTombstone(data: bytes))
        #expect(decoded == stone)
        #expect(decoded.deletedAt == deletedAt)

        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore<Dummy>(directory: dir, currentFormatVersion: 1)
        try store.save(Dummy(name: "a", score: 1), appVersion: "1")
        let saveBytes = try #require(store.rawSave())
        #expect(CloudTombstone(data: saveBytes) == nil, "a save file is not a tombstone")
        #expect(store.envelope(in: bytes) == nil, "a tombstone is not a save file")
        #expect(CloudTombstone(data: Data("nope".utf8)) == nil)
    }

    // MARK: Raw bytes

    @Test("Raw bytes read back as the envelope and the state without touching a slot")
    func readRaw() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore<Dummy>(directory: dir, currentFormatVersion: 1)
        let summary = SaveSummary(companyName: "C", founderName: "F", day: 88, seed: 99)
        try store.save(Dummy(name: "cloud", score: 3), appVersion: "1", summary: summary, slot: 2)
        let bytes = try #require(store.rawSave(slot: 2))

        let envelope = try #require(store.envelope(in: bytes))
        #expect(envelope.summary == summary)
        #expect(envelope.formatVersion == 1)

        let read = try store.read(raw: bytes)
        #expect(read.state == Dummy(name: "cloud", score: 3))
        #expect(read.envelope == envelope)
        #expect(store.hasSave(slot: 0) == false, "reading bytes writes nothing")

        #expect(throws: SaveStoreError.corruptSave) { try store.read(raw: Data("{}".utf8)) }
        let future: [String: Any] = [
            "formatVersion": 9, "savedAt": "2026-09-05T00:00:00Z", "appVersion": "9",
            "state": ["name": "x", "score": 0],
        ]
        #expect(throws: SaveStoreError.futureFormat(9)) {
            try store.read(raw: try JSONSerialization.data(withJSONObject: future))
        }
    }

    @Test("Raw bytes run the migrations on the way in, like a file in a slot")
    func readRawMigrates() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let v2 = SaveStore<Dummy>(
            directory: dir, currentFormatVersion: 2,
            migrations: [MigrationStep(fromVersion: 1) { state in state["score"] = (state["points"] as? Int) ?? 0 }]
        )
        let v1File: [String: Any] = [
            "formatVersion": 1, "savedAt": "2026-09-05T00:00:00Z", "appVersion": "0.9",
            "state": ["name": "old", "points": 42],
        ]
        let read = try v2.read(raw: try JSONSerialization.data(withJSONObject: v1File))
        #expect(read.state == Dummy(name: "old", score: 42))
        #expect(read.envelope.formatVersion == 1)
    }
}
