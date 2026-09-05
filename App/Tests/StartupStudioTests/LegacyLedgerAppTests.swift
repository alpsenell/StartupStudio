import Foundation
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// The ledger on the app side (iteration 7, R2): it lives beside the
/// slots and survives `deleteAll`, it is written the moment a company
/// ends and only once, an heirloom is spent when a company starts with
/// one, the first launch seeds the endings from the slots, and the
/// Heirlooms page appears only when there is something to offer.
@MainActor
final class LegacyLedgerAppTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyLedgerAppTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    private var saves: URL { root.appendingPathComponent("Saves", isDirectory: true) }
    private var ledgerFile: URL { root.appendingPathComponent("Legacy/slot0.json") }

    private func founder(_ name: String) -> FounderProfile {
        FounderProfile(name: name, archetype: .hacker, appearanceSeed: 0x5EED)
    }

    private func ended(_ state: GameState, kind: String, day: Int) throws -> GameState {
        var ended = state
        ended.day = day
        ended.gameOver = try JSONDecoder().decode(
            GameOverInfo.self,
            from: Data(#"{"day":\#(day),"reason":"It ended.","kind":"\#(kind)"}"#.utf8)
        )
        return ended
    }

    func testDeleteAllLeavesTheLedger() throws {
        let session = GameSession(saveDirectory: saves, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        session.recordEnding(of: try ended(session.engine.state, kind: "acquired", day: 500), balance: session.engine.balance)
        XCTAssertEqual(session.ledger.runs.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ledgerFile.path), "the ledger has its own file")
        XCTAssertEqual(LegacyStore.directory(besideSaves: saves), root.appendingPathComponent("Legacy", isDirectory: true))

        // Every slot goes, through both doors: the store's sweep and the UI's deletes.
        try session.store.deleteAll()
        session.returnToFrontDoor()
        for slot in 0..<3 { session.deleteSlot(slot) }
        XCTAssertTrue(session.slots.allSatisfy(\.isEmpty))
        XCTAssertFalse(FileManager.default.fileExists(atPath: saves.appendingPathComponent("slot0.json").path))

        XCTAssertTrue(FileManager.default.fileExists(atPath: ledgerFile.path))
        XCTAssertEqual(session.legacyStore.load().runs.first?.companyName, "Northgate")

        // And the next launch reads it back.
        let again = GameSession(saveDirectory: saves, slot: 0, remembersSlot: false)
        XCTAssertEqual(again.ledger.runs.count, 1)
        XCTAssertEqual(again.ledger.endingsReached, [.acquired])
    }

    func testARunIsRecordedOnceAndTheObserverIsWired() throws {
        let session = GameSession(saveDirectory: saves, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        XCTAssertNotNil(session.eventObservers["legacy"], "the game-over observer rides every engine")
        XCTAssertNotNil(session.engine.eventSink)

        // A running company is not a run.
        session.recordEndingIfNeeded()
        XCTAssertTrue(session.ledger.runs.isEmpty)

        let ended = try ended(session.engine.state, kind: "bankruptcy", day: 120)
        session.recordEnding(of: ended, balance: session.engine.balance)
        session.recordEnding(of: ended, balance: session.engine.balance)
        XCTAssertEqual(session.ledger.runs.count, 1, "the same ending twice is one run")
        XCTAssertEqual(session.ledger.runs[0].ending, .bankruptcy)
        XCTAssertEqual(session.ledger.runs[0].day, 120)
        XCTAssertEqual(session.legacyStore.load(), session.ledger)
    }

    func testStartingWithAnHeirloomSpendsItAndUnranksTheRun() throws {
        let session = GameSession(saveDirectory: saves, slot: 0, remembersSlot: false)
        session.ledger = .sample
        let offers = session.ledger.offers
        XCTAssertFalse(offers.isEmpty)
        XCTAssertTrue(session.newGameOptions.showsHeirloomsStep)
        XCTAssertEqual(session.newGameOptions.ledger, session.ledger)

        let deed = try XCTUnwrap(offers.first { if case .deed = $0.heirloom { return true } else { return false } }).heirloom
        session.beginNewGame(inSlot: 0)
        session.startNewGame(
            profile: founder("Mira Okafor"), companyName: "Heir & Co", difficulty: .normal, heirloom: deed
        )
        XCTAssertEqual(session.engine.state.heirloom, deed)
        XCTAssertFalse(session.engine.state.isRanked)
        XCTAssertEqual(session.engine.state.company.officeTier, .studio)
        XCTAssertTrue(session.engine.state.city.ownership.isOwned)
        XCTAssertTrue(session.ledger.spentHeirlooms.contains(deed.id))
        XCTAssertTrue(session.legacyStore.load().spentHeirlooms.contains(deed.id), "spent on disk, not just in memory")
        XCTAssertFalse(session.ledger.offers.contains { $0.heirloom == deed }, "the deed carries once")

        // No heirloom spends nothing and the run stays ranked.
        session.beginNewGame(inSlot: 1)
        session.startNewGame(profile: founder("Dev Anand"), companyName: "Plain", difficulty: .normal)
        XCTAssertNil(session.engine.state.heirloom)
        XCTAssertTrue(session.engine.state.isRanked)
        XCTAssertEqual(session.ledger.spentHeirlooms.count, 1)
    }

    func testTheHeirloomsPageIsOfferedOnlyWhenTheLedgerHasSomething() {
        let session = GameSession(saveDirectory: saves, slot: 0, remembersSlot: false)
        XCTAssertTrue(session.ledger.isEmpty)
        XCTAssertFalse(session.newGameOptions.showsHeirloomsStep)

        // A ledger with runs but nothing left to carry shows no page either.
        var spent = LegacyLedger.sample
        for offer in spent.offers { spent.spend(offer.heirloom) }
        session.ledger = spent
        XCTAssertFalse(session.newGameOptions.showsHeirloomsStep)
        XCTAssertFalse(session.newGameOptions.startsOnHeirlooms)
    }

    func testTheFirstLaunchSeedsTheEndingsFromTheSlots() throws {
        // Two slots written by an app without a ledger: one finished, one running.
        let store = SaveStore<GameState>(directory: saves, currentFormatVersion: 1)
        let running = GameEngine.newGame(companyName: "Running", seed: 1, founder: founder("A")).state
        let finished = try ended(GameEngine.newGame(companyName: "Done", seed: 2, founder: founder("B")).state, kind: "independent", day: 900)
        try store.save(running, appVersion: "0.1.0", summary: SaveSummary(state: running), slot: 0)
        try store.save(finished, appVersion: "0.1.0", summary: SaveSummary(state: finished), slot: 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ledgerFile.path))

        let session = GameSession(saveDirectory: saves, slot: 0, remembersSlot: false)
        XCTAssertEqual(session.ledger.endingsReached, [.independent])
        XCTAssertTrue(session.ledger.runs.isEmpty, "the migration knows the ending, not the company")
        XCTAssertTrue(session.legacyStore.exists, "written once, so it never runs again")

        // A later launch with the finished slot gone keeps the ending.
        try store.delete(slot: 2)
        let later = GameSession(saveDirectory: saves, slot: 0, remembersSlot: false)
        XCTAssertEqual(later.ledger.endingsReached, [.independent])
    }
}
