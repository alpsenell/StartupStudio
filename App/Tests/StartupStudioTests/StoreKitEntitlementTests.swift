import Foundation
import StoreKit
import StoreKitTest
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// R6: the real `Entitlements` actor over StoreKit 2, driven by
/// `SKTestSession` on `App/StoreKit/StartupStudio.storekit` (in the test
/// bundle, never the app's): purchase → the gate opens; refund → it
/// closes; clearTransactions → chapter 1 still runs; Restore after the
/// app has forgotten, with the purchase present → opens.
@MainActor
final class StoreKitEntitlementTests: XCTestCase {
    private var testSession: SKTestSession!
    private var directory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let bundle = Bundle(for: StoreKitEntitlementTests.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "StartupStudio", withExtension: "storekit"),
            "App/StoreKit/StartupStudio.storekit must be a resource of the test bundle (project.yml)"
        )
        testSession = try SKTestSession(contentsOf: url)
        testSession.disableDialogs = true
        testSession.clearTransactions()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreKitEntitlementTests-\(UUID().uuidString)", isDirectory: true)
        suiteName = "StoreKitEntitlementTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        testSession?.clearTransactions()
        testSession = nil
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func waitUntil(
        _ what: String, timeout: Duration = .seconds(10),
        file: StaticString = #filePath, line: UInt = #line,
        _ condition: @MainActor () async -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while await !condition() {
            if clock.now > deadline {
                XCTFail("timed out waiting for \(what)", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: - The actor

    func testTheProductLoadsFromTheConfigurationWithItsPrice() async {
        let entitlements = Entitlements()
        let price = await entitlements.displayPrice()
        XCTAssertEqual(price, "$4.99")
        let owned = await entitlements.isEntitled()
        XCTAssertFalse(owned, "a cleared session owns nothing")
    }

    func testPurchaseEntitlesAndRefundRevokes() async throws {
        let entitlements = Entitlements()
        let transaction = try await testSession.buyProduct(identifier: UnlockState.productID)
        XCTAssertEqual(transaction.productID, UnlockState.productID)
        await waitUntil("the purchase") { await entitlements.isEntitled() }

        try testSession.refundTransaction(identifier: UInt(transaction.id))
        await waitUntil("the refund") { await !entitlements.isEntitled() }
    }

    func testRestoreFindsAPurchaseTheAppHadForgotten() async throws {
        let entitlements = Entitlements()
        _ = try await testSession.buyProduct(identifier: UnlockState.productID)
        await waitUntil("the purchase") { await entitlements.isEntitled() }

        // A fresh actor with nothing cached: Restore asks the store.
        let restored = try await Entitlements().restore()
        XCTAssertTrue(restored)

        testSession.clearTransactions()
        await waitUntil("the clear") { await !entitlements.isEntitled() }
        let restoredAfterClear = try await Entitlements().restore()
        XCTAssertFalse(restoredAfterClear, "nothing to restore once the purchase is gone")
    }

    // MARK: - The session on the real store

    func testTheGateFollowsTheStoreThroughPurchaseRefundClearAndRestore() async throws {
        let (state, _) = UnlockTests.chapterTwoCompany()
        let store = TycoonSaveStoreFixture.store(in: directory)
        try store.save(state, appVersion: "test", summary: SaveSummary(state: state), slot: 0)
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        defer { session.engine.shutdown() }
        let entitlements = Entitlements()
        session.installUnlock(source: entitlements, defaults: defaults)
        await waitUntil("the store's first answer") { session.unlock.isKnown }
        XCTAssertFalse(session.unlock.isEntitled)
        XCTAssertFalse(session.engine.mayAdvance, "chapter 2, not owned: the clock will not run")

        // Purchase → the gate opens (through `Transaction.updates`).
        let transaction = try await testSession.buyProduct(identifier: UnlockState.productID)
        await waitUntil("the purchase to reach the session") { session.unlock.isEntitled }
        XCTAssertTrue(session.engine.mayAdvance)
        XCTAssertTrue(defaults.bool(forKey: GameSession.entitledCacheKey))

        // Refund → it closes.
        try testSession.refundTransaction(identifier: UInt(transaction.id))
        await waitUntil("the refund to reach the session") { !session.unlock.isEntitled }
        XCTAssertFalse(session.engine.mayAdvance)
        XCTAssertEqual(session.engine.state.progression.chapter, 2, "the save is intact")

        // clearTransactions → chapter 1 still runs.
        testSession.clearTransactions()
        session.beginNewGame(inSlot: 1)
        session.startNewGame(
            profile: FounderProfile(name: "Ada", archetype: .hacker), companyName: "Garage Co", difficulty: .normal
        )
        XCTAssertEqual(session.engine.state.progression.chapter, 1)
        XCTAssertTrue(session.engine.mayAdvance, "the garage is free with no purchase at all")

        // Restore after the app forgot, with a purchase present → opens.
        _ = try await testSession.buyProduct(identifier: UnlockState.productID)
        await waitUntil("the purchase") { await entitlements.isEntitled() }
        defaults.set(false, forKey: GameSession.entitledCacheKey)
        session.openSlot(0)
        XCTAssertEqual(session.engine.state.progression.chapter, 2)
        let restored = await session.restorePurchases()
        XCTAssertTrue(restored)
        XCTAssertTrue(session.unlock.isEntitled)
        XCTAssertTrue(session.engine.mayAdvance)
    }
}

/// The save store the way the session builds it, for a test that needs
/// to plant a file where the session will look.
enum TycoonSaveStoreFixture {
    static func store(in directory: URL) -> TycoonSave.SaveStore<GameState> {
        TycoonSave.SaveStore<GameState>(directory: directory, currentFormatVersion: 1)
    }
}
