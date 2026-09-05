import Foundation
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// A dictionary standing in for `NSUbiquitousKeyValueStore`, so the
/// policy and the plumbing are proved without an iCloud account.
final class FakeKeyValueStore: CloudKeyValueStore, @unchecked Sendable {
    var values: [String: Data] = [:]
    var writes: [String] = []
    var removals: [String] = []
    var synchronizeCount = 0

    func data(forKey key: String) -> Data? { values[key] }

    func setData(_ data: Data, forKey key: String) {
        values[key] = data
        writes.append(key)
    }

    func removeData(forKey key: String) {
        values.removeValue(forKey: key)
        removals.append(key)
    }

    func synchronize() -> Bool {
        synchronizeCount += 1
        return true
    }

    /// The day a slot key's blob carries, decoded through `store`.
    func day(forKey key: String, via store: SaveStore<GameState>) -> Int? {
        guard let blob = values[key], let bytes = try? CloudBlob.decompress(blob) else { return nil }
        return store.envelope(in: bytes)?.summary?.day
    }

    func isTombstone(_ key: String) -> Bool {
        guard let blob = values[key], let bytes = try? CloudBlob.decompress(blob) else { return false }
        return CloudTombstone(data: bytes) != nil
    }
}

/// iCloud (iteration 7, R2): verdicts wait for the front door, a slot
/// taken from the cloud is never pushed back until it is played past the
/// remote day, deletions propagate as tombstones, pushes coalesce, an
/// oversize slot stays home and says so, and the ledger merges both ways.
@MainActor
final class CloudSyncTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudSyncTests-\(UUID().uuidString)", isDirectory: true)
        suiteName = "CloudSyncTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// A device: its own saves directory (and ledger beside it).
    private func saves(_ device: String) -> URL {
        root.appendingPathComponent(device, isDirectory: true).appendingPathComponent("Saves", isDirectory: true)
    }

    private func session(_ device: String) -> GameSession {
        GameSession(saveDirectory: saves(device), slot: 0, remembersSlot: false)
    }

    private func sync(_ store: FakeKeyValueStore, for session: GameSession, available: Bool = true) -> CloudSync {
        CloudSync(
            store: store, isAvailable: available,
            formatVersion: GameSession.saveFormatVersion,
            readEnvelope: { [saveStore = session.store] in saveStore.envelope(in: $0) },
            defaults: defaults, observesNotifications: false
        )
    }

    private func founder(_ name: String) -> FounderProfile {
        FounderProfile(name: name, archetype: .hacker, appearanceSeed: 0x5EED)
    }

    /// Starts a company in slot 0 of `session` and leaves it running.
    private func startRunning(_ session: GameSession, seed: UInt64 = 4242, company: String = "Northgate") {
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: company, difficulty: .normal, seed: seed)
        XCTAssertFalse(session.isAtFrontDoor)
    }

    /// The compressed bytes of `state` as another device would have saved it.
    private func blob(of state: GameState, savedInto directory: URL) throws -> Data {
        let other = SaveStore<GameState>(directory: directory, currentFormatVersion: 1)
        try other.save(state, appVersion: "0.1.0", summary: SaveSummary(state: state), slot: 0)
        return try CloudBlob.compress(try XCTUnwrap(other.rawSave(slot: 0)))
    }

    // MARK: - The door

    func testAPendingCloudVerdictIsNotAppliedUnderARunningGame() throws {
        let store = FakeKeyValueStore()
        let session = session("a")
        startRunning(session)
        let localDay = session.engine.state.day

        // Another device is at day 900 of the same company.
        var ahead = session.engine.state
        ahead.day = 900
        store.values["slot0"] = try blob(of: ahead, savedInto: root.appendingPathComponent("other"))

        let sync = sync(store, for: session)
        session.attachCloud(sync)

        XCTAssertTrue(session.cloud.isOn)
        XCTAssertEqual(session.cloud.pending.map(\.slot), [0], "the verdict waits")
        XCTAssertEqual(session.cloud.pending.first?.verdict, .takeRemote)
        XCTAssertEqual(session.engine.state.day, localDay, "the running game is untouched")
        XCTAssertEqual(session.slots[0].summary?.day, localDay, "and so is its file")
        XCTAssertNil(session.cloud.titleNotice)

        // An autosave under the pending verdict does not push the stale day back.
        session.engine.autosave?(session.engine.state)
        XCTAssertFalse(store.writes.contains("slot0"), "the local copy is behind the cloud; nothing pushed")

        // Back at the door the verdict applies: the slot is replaced, the
        // engine behind Continue is the cloud's day 900, and the title says so.
        session.returnToFrontDoor()
        XCTAssertTrue(session.cloud.pending.isEmpty)
        XCTAssertEqual(session.engine.state.day, 900)
        XCTAssertEqual(session.slots[0].summary?.day, 900)
        XCTAssertEqual(session.cloud.state, .updated(slot: 0, day: 900))
        XCTAssertEqual(session.cloud.titleNotice, "Slot 1 · updated from iCloud, day 900")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: saves("a").appendingPathComponent("slot0.backup.json").path),
            "the loser is the backup"
        )
    }

    func testTheAntiPingPongRuleHoldsATakenSlotUntilItIsPlayedPast() throws {
        let store = FakeKeyValueStore()
        let session = session("a")
        startRunning(session)
        var ahead = session.engine.state
        ahead.day = 300
        store.values["slot0"] = try blob(of: ahead, savedInto: root.appendingPathComponent("other"))
        let sync = sync(store, for: session)
        session.attachCloud(sync)
        session.returnToFrontDoor()
        XCTAssertEqual(session.engine.state.day, 300)
        XCTAssertEqual(sync.hold(forSlot: 0)?.day, 300)
        store.writes = []

        // The slot autosaves at the day it was taken at: held, no push.
        session.engine.autosave?(session.engine.state)
        XCTAssertEqual(store.writes.filter { $0 == "slot0" }.count, 0, "day 300 is not pushed back over day 300")

        // Played past the remote day: the hold lifts and the push goes.
        var played = session.engine.state
        played.day = 301
        session.engine.autosave?(played)
        XCTAssertEqual(store.writes.filter { $0 == "slot0" }.count, 1)
        XCTAssertEqual(store.day(forKey: "slot0", via: session.store), 301)
        XCTAssertNil(sync.hold(forSlot: 0))
        XCTAssertEqual(sync.pushLog.last, CloudSync.PushRecord(key: "slot0", day: 301, kind: "save"))
    }

    func testADifferentCompanyInTheSlotLiftsTheHold() throws {
        let store = FakeKeyValueStore()
        let session = session("a")
        startRunning(session)
        var ahead = session.engine.state
        ahead.day = 300
        store.values["slot0"] = try blob(of: ahead, savedInto: root.appendingPathComponent("other"))
        let sync = sync(store, for: session)
        session.attachCloud(sync)
        session.returnToFrontDoor()
        XCTAssertNotNil(sync.hold(forSlot: 0))
        store.writes = []

        // A new company founded into the slot is day 0 of another seed: pushed.
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Dev Anand"), companyName: "Rooftop", difficulty: .hard, seed: 77)
        XCTAssertTrue(store.writes.contains("slot0"))
        XCTAssertEqual(store.day(forKey: "slot0", via: session.store), 0)
        XCTAssertNil(sync.hold(forSlot: 0))
    }

    // MARK: - Pushes

    func testALocalSaveIsPushedAtTheDoorAndTheOtherDeviceTakesIt() throws {
        let store = FakeKeyValueStore()
        let a = session("a")
        startRunning(a)
        a.returnToFrontDoor()
        a.attachCloud(sync(store, for: a))
        XCTAssertTrue(store.writes.contains("slot0"), "a lone local copy goes up")
        XCTAssertEqual(store.day(forKey: "slot0", via: a.store), 0)
        XCTAssertEqual(a.cloud.state, .idle)

        let b = session("b")
        XCTAssertTrue(b.slots[0].isEmpty)
        b.attachCloud(sync(store, for: b))
        XCTAssertEqual(b.slots[0].summary?.companyName, "Northgate")
        XCTAssertEqual(b.engine.state.seed, 4242, "the current slot's engine is rebuilt from the file")
        XCTAssertTrue(b.hasCurrentGame)
        XCTAssertEqual(b.cloud.state, .updated(slot: 0, day: 0))
    }

    func testPushesCoalesceToOneWritePerKeyPerInterval() throws {
        let store = FakeKeyValueStore()
        let session = session("a")
        let sync = sync(store, for: session)
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        sync.now = { clock }
        let bytes = Data("{\"formatVersion\":1}".utf8)

        sync.requestPush(key: "slot1") { bytes }
        sync.requestPush(key: "slot1") { bytes }
        sync.requestPush(key: "slot1") { bytes }
        XCTAssertEqual(store.writes, ["slot1"], "the first goes now, the rest wait for the window")
        XCTAssertEqual(sync.pendingKeys, ["slot1"])

        // Backgrounding flushes what is waiting.
        sync.flush()
        XCTAssertEqual(store.writes, ["slot1", "slot1"])
        XCTAssertTrue(sync.pendingKeys.isEmpty)

        // Past the window the next request writes at once.
        clock = clock.addingTimeInterval(31)
        sync.requestPush(key: "slot1") { bytes }
        XCTAssertEqual(store.writes.count, 3)
        XCTAssertEqual(store.synchronizeCount, 3)
    }

    func testDeletingASlotPushesATombstoneAndTheOtherDeviceDeletesToo() throws {
        let store = FakeKeyValueStore()
        // Device B has the company and is at the door.
        let b = session("b")
        startRunning(b)
        b.returnToFrontDoor()
        let syncB = sync(store, for: b)
        b.attachCloud(syncB)
        XCTAssertFalse(b.slots[0].isEmpty)

        // Device A has it too, and deletes it a minute from now.
        let a = session("a")
        startRunning(a)
        a.returnToFrontDoor()
        let syncA = sync(store, for: a)
        syncA.now = { Date().addingTimeInterval(60) }
        a.attachCloud(syncA)
        a.deleteSlot(0)
        XCTAssertTrue(store.isTombstone("slot0"))
        XCTAssertEqual(syncA.pushLog.last?.kind, "tombstone")

        // B pulls: the slot goes, the engine behind Continue becomes the placeholder.
        b.pullFromCloud()
        XCTAssertTrue(b.slots[0].isEmpty)
        XCTAssertFalse(b.hasCurrentGame)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saves("b").appendingPathComponent("slot0.json").path))
        XCTAssertEqual(b.cloud.state, .idle)
    }

    func testAnOversizeSlotStaysLocalAndSaysSo() throws {
        let store = FakeKeyValueStore()
        let session = session("a")
        let sync = sync(store, for: session)
        session.attachCloud(sync)
        // Random bytes do not compress; two megabytes of them are over budget.
        var generator = SystemRandomNumberGenerator()
        let huge = Data((0..<(2 * 1024 * 1024)).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
        sync.requestPush(key: "slot1") { huge }
        XCTAssertFalse(store.writes.contains("slot1"))
        XCTAssertEqual(sync.localOnlyKeys, ["slot1"])
        XCTAssertEqual(session.cloud.localOnlySlots, [1])
        XCTAssertTrue(session.cloud.settingsLine.contains("Slot 2 too large to sync"), session.cloud.settingsLine)

        // Once it shrinks it syncs again, and the row stops saying so.
        sync.flush()
        sync.now = { Date().addingTimeInterval(60) }
        sync.requestPush(key: "slot1") { Data("{\"formatVersion\":1}".utf8) }
        XCTAssertTrue(store.writes.contains("slot1"))
        XCTAssertTrue(session.cloud.localOnlySlots.isEmpty)
    }

    func testANewerAppsBlobIsNeverJudgedOrOverwrittenButGarbageIs() throws {
        let store = FakeKeyValueStore()
        let future: [String: Any] = [
            "formatVersion": 99, "savedAt": "2030-01-01T00:00:00Z", "appVersion": "9.0", "state": [:],
        ]
        let futureBlob = try CloudBlob.compress(try JSONSerialization.data(withJSONObject: future))
        store.values["slot0"] = futureBlob
        store.values["slot1"] = Data("not a blob".utf8)
        let session = session("a")
        startRunning(session)
        session.returnToFrontDoor()
        let sync = sync(store, for: session)
        session.attachCloud(sync)

        XCTAssertEqual(sync.remote(forKey: "slot0"), .newerFormat(99))
        XCTAssertEqual(store.values["slot0"], futureBlob, "a newer app's blob is left alone")
        XCTAssertEqual(session.slots[0].summary?.companyName, "Northgate", "and the local copy stands")
        XCTAssertEqual(session.cloud.state, .idle)
        session.engine.autosave?(session.engine.state)
        XCTAssertFalse(store.writes.contains("slot0"))

        // Damage is nothing: a local company in that slot goes up over it.
        XCTAssertEqual(sync.remote(forKey: "slot1"), .unreadable)
        session.beginNewGame(inSlot: 1)
        session.startNewGame(profile: founder("Dev Anand"), companyName: "Rooftop", difficulty: .normal, seed: 9)
        XCTAssertTrue(store.writes.contains("slot1"))
        XCTAssertEqual(store.day(forKey: "slot1", via: session.store), 0)
    }

    // MARK: - Degrade

    func testNoAccountMeansOffAndNothingIsWritten() throws {
        let store = FakeKeyValueStore()
        let session = session("a")
        session.attachCloud(sync(store, for: session, available: false))
        XCTAssertEqual(session.cloud.state, .off)
        XCTAssertFalse(session.cloud.isOn)
        XCTAssertEqual(session.cloud.settingsLine, "Off — saves stay on this device")
        startRunning(session)
        session.returnToFrontDoor()
        session.deleteSlot(0)
        XCTAssertTrue(store.writes.isEmpty)
        XCTAssertEqual(store.synchronizeCount, 0)

        session.attachCloud(nil)
        XCTAssertEqual(session.cloud, .off)
    }

    // MARK: - The ledger

    func testTheLedgerMergesBothWaysThroughTheCloud() throws {
        let store = FakeKeyValueStore()
        let a = session("a")
        a.attachCloud(sync(store, for: a))
        var ended = a.engine.state
        ended.day = 400
        ended.gameOver = try JSONDecoder().decode(
            GameOverInfo.self,
            from: Data(#"{"day":400,"reason":"Rang the bell.","kind":"ipo"}"#.utf8)
        )
        a.recordEnding(of: ended, balance: a.engine.balance)
        XCTAssertEqual(a.ledger.runs.count, 1)
        XCTAssertNotNil(store.values["legacy"], "the ledger is pushed when it changes")

        // A second device with its own finished company: after one pull each
        // has both runs, and the cloud has the union.
        let b = session("b")
        var otherEnding = b.engine.state
        otherEnding.day = 90
        otherEnding.gameOver = try JSONDecoder().decode(
            GameOverInfo.self,
            from: Data(#"{"day":90,"reason":"Broke.","kind":"bankruptcy"}"#.utf8)
        )
        b.recordEnding(of: otherEnding, balance: b.engine.balance)
        XCTAssertEqual(b.ledger.runs.count, 1)
        b.attachCloud(sync(store, for: b))
        XCTAssertEqual(b.ledger.runs.count, 2)
        XCTAssertEqual(b.ledger.endingsReached, [.ipo, .bankruptcy])
        XCTAssertEqual(b.legacyStore.load().runs.count, 2, "the union is on B's disk")

        a.pullFromCloud()
        XCTAssertEqual(a.ledger.runs.count, 2)
        XCTAssertEqual(a.legacyStore.load().runs.count, 2)
    }

    // MARK: - Status copy

    func testStatusLines() {
        var status = CloudSyncStatus()
        XCTAssertEqual(status.settingsLine, "Off — saves stay on this device")
        XCTAssertNil(status.titleNotice)
        status.state = .idle
        XCTAssertEqual(status.settingsLine, "On")
        status.state = .updated(slot: 1, day: 340)
        XCTAssertEqual(status.settingsLine, "Slot 2 updated from iCloud, day 340")
        XCTAssertEqual(status.titleNotice, "Slot 2 · updated from iCloud, day 340")
        status.state = .failed("no room")
        XCTAssertEqual(status.settingsLine, "Couldn't sync — no room")
        status.localOnlySlots = [0, 2]
        XCTAssertTrue(status.settingsLine.hasSuffix("Slot 1, slot 3 too large to sync, kept here"))
        XCTAssertTrue(ServiceFlags.cloud, "the Settings row is live")
    }
}
