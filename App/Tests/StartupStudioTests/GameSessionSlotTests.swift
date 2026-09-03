import Foundation
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// U7: the session addresses one slot at a time, and a new company in
/// another slot leaves the first one's file exactly as it was.
@MainActor
final class GameSessionSlotTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GameSessionSlotTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func fileURL(slot: Int) -> URL {
        directory.appendingPathComponent("slot\(slot).json")
    }

    private func founder(_ name: String) -> FounderProfile {
        FounderProfile(name: name, archetype: .hacker, appearanceSeed: 0x5EED)
    }

    func testANewGameInSlotOneLeavesSlotZeroUntouched() throws {
        // A first session founds a company in slot 0 and leaves for the door.
        let first = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        XCTAssertTrue(first.isAtFrontDoor)
        XCTAssertFalse(first.hasCurrentGame, "a fresh directory has nothing to continue")
        XCTAssertEqual(first.slots.count, 3)
        XCTAssertTrue(first.slots.allSatisfy { $0.isEmpty })

        first.beginNewGame(inSlot: 0)
        XCTAssertTrue(first.needsOnboarding)
        first.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        XCTAssertFalse(first.isAtFrontDoor)
        XCTAssertEqual(first.currentSlot, 0)
        XCTAssertTrue(first.hasCurrentGame)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL(slot: 0).path), "a new game is saved at once")
        first.returnToFrontDoor()
        XCTAssertTrue(first.isAtFrontDoor)
        let slot0Bytes = try Data(contentsOf: fileURL(slot: 0))

        // A second company in slot 1.
        first.beginNewGame(inSlot: 1)
        first.startNewGame(profile: founder("Dev Anand"), companyName: "Rooftop", difficulty: .hard)
        XCTAssertEqual(first.currentSlot, 1)
        XCTAssertEqual(first.engine.state.company.name, "Rooftop")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL(slot: 1).path))

        // Slot 0's file has not moved by a byte, and the picker lists both.
        XCTAssertEqual(try Data(contentsOf: fileURL(slot: 0)), slot0Bytes)
        XCTAssertEqual(first.slots[0].summary?.companyName, "Northgate")
        XCTAssertEqual(first.slots[1].summary?.companyName, "Rooftop")
        XCTAssertEqual(first.slots[1].summary?.founderName, "Dev Anand")
        XCTAssertTrue(first.slots[2].isEmpty)

        // The engine in slot 1 autosaves into slot 1, not slot 0.
        first.engine.autosave?(first.engine.state)
        XCTAssertEqual(try Data(contentsOf: fileURL(slot: 0)), slot0Bytes)
        first.engine.shutdown()
    }

    func testOpeningASlotLoadsItsGameAndDeletingOneLeavesTheOther() throws {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        session.returnToFrontDoor()
        session.beginNewGame(inSlot: 2)
        session.startNewGame(profile: founder("Dev Anand"), companyName: "Rooftop", difficulty: .normal)
        session.returnToFrontDoor()
        XCTAssertEqual(session.currentSlot, 2)

        // Open slot 0 again: its company comes back, the door closes.
        session.openSlot(0)
        XCTAssertFalse(session.isAtFrontDoor)
        XCTAssertEqual(session.currentSlot, 0)
        XCTAssertEqual(session.engine.state.company.name, "Northgate")
        XCTAssertNil(session.loadFailureMessage)

        // Delete slot 2: slot 0 stays, and so does the game in hand.
        session.returnToFrontDoor()
        session.deleteSlot(2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL(slot: 2).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL(slot: 0).path))
        XCTAssertTrue(session.slots[2].isEmpty)
        XCTAssertTrue(session.hasCurrentGame)
        XCTAssertEqual(session.currentSummary?.companyName, "Northgate")

        // Delete the slot in hand: Continue goes with it.
        session.deleteSlot(0)
        XCTAssertFalse(session.hasCurrentGame)
        XCTAssertNil(session.currentSummary)
        XCTAssertTrue(session.slots.allSatisfy { $0.isEmpty })
        session.engine.shutdown()
    }

    func testASecondLaunchResumesTheSlotWithContinue() throws {
        let first = GameSession(saveDirectory: directory, slot: 1, remembersSlot: false)
        first.beginNewGame(inSlot: 1)
        first.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        first.engine.shutdown()

        let second = GameSession(saveDirectory: directory, slot: 1, remembersSlot: false)
        XCTAssertTrue(second.isAtFrontDoor)
        XCTAssertTrue(second.hasCurrentGame)
        XCTAssertEqual(second.currentSlot, 1)
        XCTAssertEqual(second.currentSummary?.companyName, "Northgate")
        XCTAssertEqual(second.currentSummary?.founderName, "Mira Okafor")
        XCTAssertEqual(second.engine.state.speed, .paused, "nothing ticks behind the door")
        second.continueGame()
        XCTAssertFalse(second.isAtFrontDoor)
        second.engine.shutdown()
    }

    func testCancellingTheNewGameFlowLeavesEverySlotAsItWas() throws {
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 0)
        session.startNewGame(profile: founder("Mira Okafor"), companyName: "Northgate", difficulty: .normal)
        session.returnToFrontDoor()
        let bytes = try Data(contentsOf: fileURL(slot: 0))

        session.beginNewGame(inSlot: 0)
        XCTAssertTrue(session.needsOnboarding)
        session.cancelOnboarding()
        XCTAssertFalse(session.needsOnboarding)
        XCTAssertEqual(try Data(contentsOf: fileURL(slot: 0)), bytes)
        XCTAssertEqual(session.currentSummary?.companyName, "Northgate")
        session.engine.shutdown()
    }

    func testADamagedSlotListsAsDamagedAndDoesNotOpen() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{{ not a save".utf8).write(to: fileURL(slot: 2))

        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        XCTAssertEqual(session.slots[2].contents, .corrupt)
        session.openSlot(2)
        XCTAssertTrue(session.isAtFrontDoor)
        XCTAssertNotNil(session.loadFailureMessage)
        XCTAssertEqual(session.currentSlot, 0)
        session.clearLoadFailure()

        // A launch straight into the damaged slot says so and waits at the door.
        let straightIn = GameSession(saveDirectory: directory, slot: 2, remembersSlot: false)
        XCTAssertTrue(straightIn.isAtFrontDoor)
        XCTAssertFalse(straightIn.hasCurrentGame)
        XCTAssertNotNil(straightIn.loadFailureMessage)
        straightIn.engine.shutdown()
        session.engine.shutdown()
    }
}
