import Foundation
import TycoonContent
import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// A store the session's tests can drive: the entitlement, the price,
/// what a purchase and a restore answer, and a way to push what
/// `Transaction.updates` would push (a purchase elsewhere, a refund).
final class FakeEntitlements: EntitlementSource, @unchecked Sendable {
    private let lock = NSLock()
    private var entitled: Bool
    private var continuations: [AsyncStream<Bool>.Continuation] = []
    var price: String? = "$4.99"
    var purchaseOutcome: PurchaseOutcome = .purchased
    var restoreAnswer: Bool?
    var restoreThrows = false
    private(set) var restoreCalls = 0

    init(entitled: Bool) {
        self.entitled = entitled
    }

    func isEntitled() async -> Bool {
        lock.withLock { entitled }
    }

    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            lock.withLock { continuations.append(continuation) }
        }
    }

    /// What the store would report on its own: a refund, or a purchase
    /// on another device.
    func push(_ entitled: Bool) {
        let targets: [AsyncStream<Bool>.Continuation] = lock.withLock {
            self.entitled = entitled
            return continuations
        }
        for continuation in targets {
            continuation.yield(entitled)
        }
    }

    func displayPrice() async -> String? { price }

    func purchase() async throws -> PurchaseOutcome {
        if purchaseOutcome == .purchased {
            lock.withLock { entitled = true }
        }
        return purchaseOutcome
    }

    func restore() async throws -> Bool {
        lock.withLock { restoreCalls += 1 }
        if restoreThrows { throw Entitlements.StoreUnavailable() }
        return restoreAnswer ?? lock.withLock { entitled }
    }
}

/// R6: the gate's rule as a table, the paywall's order, the review
/// prompt's rule, and the session composing all of it on a fake store.
@MainActor
final class UnlockTests: XCTestCase {
    private var directory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnlockTests-\(UUID().uuidString)", isDirectory: true)
        suiteName = "UnlockTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        ReviewPromptPolicy.resetForTesting()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Polls the main actor until `condition` holds, or fails.
    private func waitUntil(
        _ what: String, timeout: Duration = .seconds(5),
        file: StaticString = #filePath, line: UInt = #line,
        _ condition: @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition() {
            if clock.now > deadline {
                XCTFail("timed out waiting for \(what)", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// A company that has just opened chapter 2 the honest way: enough
    /// garage goals done, one tick. The events carry `.chapterReached`.
    static func chapterTwoCompany() -> (state: GameState, events: [GameEvent]) {
        let engine = GameEngine.newGame(
            companyName: "Northgate Softworks", seed: 4242,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        var state = engine.state
        for _ in 0..<30 { _ = Reducer.tick(&state, balance: engine.balance, content: engine.content) }
        let needed = engine.balance.progression.goalsToAdvanceChapter
        for goal in engine.content.goals(inChapter: 1).prefix(needed) {
            state.progression.completedGoalIDs.insert(goal.id)
        }
        let events = Reducer.tick(&state, balance: engine.balance, content: engine.content)
        precondition(state.progression.chapter == 2)
        return (state, events)
    }

    private func saveIntoSlotZero(_ state: GameState) throws {
        let store = SaveStore<GameState>(directory: directory, currentFormatVersion: 1)
        try store.save(state, appVersion: "test", summary: SaveSummary(state: state), slot: 0)
    }

    // MARK: - The rule

    func testUnlockRuleTableOverChapterEntitlementAndMode() {
        let modes: [(RunMode, String)] = [(.standard, "standard"), (.custom, "custom"), (.daily(day: 20_660), "daily")]
        for chapter in 1...ProgressionState.chapterCount {
            for entitled in [false, true] {
                for (mode, name) in modes {
                    let expected = entitled || chapter < 2 || mode.isDaily
                    XCTAssertEqual(
                        UnlockRule.allows(chapter: chapter, entitled: entitled, mode: mode), expected,
                        "chapter \(chapter), entitled \(entitled), \(name)"
                    )
                }
            }
        }
        XCTAssertEqual(UnlockRule.firstPaidChapter, 2)
    }

    func testTheGateReadsTheChapterFromStateAndTheEntitlementLive() {
        final class Owner { var entitled = false }
        let owner = Owner()
        let gate = UnlockGate { owner.entitled }
        XCTAssertEqual(gate.id, "unlock")

        let garage = GameEngine.newGame(companyName: "Acme", seed: 1).state
        XCTAssertTrue(gate.allows(garage), "chapter 1 is free")

        let loft = Self.chapterTwoCompany().state
        XCTAssertFalse(gate.allows(loft), "chapter 2 needs the purchase")
        owner.entitled = true
        XCTAssertTrue(gate.allows(loft), "the entitlement is read on every call")
        owner.entitled = false

        var daily = loft
        daily.mode = .daily(day: 20_660)
        XCTAssertTrue(gate.allows(daily), "the daily is free in every chapter")

        var custom = loft
        custom.mode = .custom
        XCTAssertFalse(gate.allows(custom), "a custom company is gated like a standard one")
    }

    // MARK: - The order

    /// The chapter card comes first: while the rail is still showing
    /// `.chapterReached` as the reason the clock stopped, the paywall
    /// does not open by itself; the moment that reason is gone, it does.
    func testTheChapterCardIsDismissedBeforeThePaywallOpens() {
        let (_, events) = Self.chapterTwoCompany()
        let reached = events.contains { if case .chapterReached(2, _) = $0 { true } else { false } }
        XCTAssertTrue(reached, "the fixture opens chapter 2 on its tick")

        let underTheCard = PaywallPresentation.autoPresents(
            gated: true, known: true, inGame: true, ended: false, paused: true, pauseReasonUp: true
        )
        XCTAssertFalse(underTheCard, "never under the chapter card")
        let afterTheCard = PaywallPresentation.autoPresents(
            gated: true, known: true, inGame: true, ended: false, paused: true, pauseReasonUp: false
        )
        XCTAssertTrue(afterTheCard, "after it, yes")

        // And never before the store has answered, over an ended run,
        // behind the front door, or while the clock is running.
        XCTAssertFalse(PaywallPresentation.autoPresents(gated: true, known: false, inGame: true, ended: false, paused: true, pauseReasonUp: false))
        XCTAssertFalse(PaywallPresentation.autoPresents(gated: true, known: true, inGame: true, ended: true, paused: true, pauseReasonUp: false))
        XCTAssertFalse(PaywallPresentation.autoPresents(gated: true, known: true, inGame: false, ended: false, paused: true, pauseReasonUp: false))
        XCTAssertFalse(PaywallPresentation.autoPresents(gated: true, known: true, inGame: true, ended: false, paused: false, pauseReasonUp: false))
        XCTAssertFalse(PaywallPresentation.autoPresents(gated: false, known: true, inGame: true, ended: false, paused: true, pauseReasonUp: false))
    }

    // MARK: - The session

    func testAGatedSaveLoadsAndShowsThePaywallOnContinue() async throws {
        let (state, _) = Self.chapterTwoCompany()
        try saveIntoSlotZero(state)
        let store = FakeEntitlements(entitled: false)
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        defer { session.engine.shutdown() }
        XCTAssertTrue(session.hasCurrentGame)
        XCTAssertTrue(session.isAtFrontDoor)
        XCTAssertEqual(session.engine.state.progression.chapter, 2)

        session.installUnlock(source: store, defaults: defaults)
        XCTAssertFalse(session.unlock.isKnown, "the cache is not an answer")
        XCTAssertFalse(session.engine.mayAdvance, "the gate is on the loaded engine at once")
        await waitUntil("the store's answer") { session.unlock.isKnown }
        XCTAssertFalse(session.unlock.isEntitled)
        XCTAssertFalse(session.unlock.isPresentingPaywall, "nothing is sold behind the front door")

        // Continue: the door closes, the game view appears and asks.
        session.continueGame()
        XCTAssertFalse(session.isAtFrontDoor)
        session.reconsiderPaywall()
        XCTAssertTrue(session.unlock.isPresentingPaywall, "Continue on a gated save brings the paywall back")
        XCTAssertTrue(session.unlock.paywallShownThisSession)

        // The clock will not run, and the save is exactly as it was.
        session.engine.setSpeed(.x2)
        XCTAssertEqual(session.engine.state.speed, .paused)
        XCTAssertEqual(session.engine.state.progression.chapter, 2)
        XCTAssertEqual(session.currentSummary?.chapter, 2)

        // Not now: back to the paused game, nothing deleted or hidden.
        session.dismissPaywall()
        XCTAssertFalse(session.unlock.isPresentingPaywall)
        XCTAssertTrue(session.hasCurrentGame)
        XCTAssertEqual(session.slots[0].summary?.companyName, "Northgate Softworks")

        // The lock on the speed control is the way back in.
        session.clockLockTapped()
        XCTAssertTrue(session.unlock.isPresentingPaywall)
    }

    func testPurchaseOpensTheGateAndRunsTheClockAndARefundClosesItAgain() async throws {
        let (state, _) = Self.chapterTwoCompany()
        try saveIntoSlotZero(state)
        let store = FakeEntitlements(entitled: false)
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        defer { session.engine.shutdown() }
        session.installUnlock(source: store, defaults: defaults)
        await waitUntil("the store's answer") { session.unlock.isKnown }
        session.continueGame()
        session.reconsiderPaywall()
        XCTAssertTrue(session.unlock.isPresentingPaywall)
        await session.loadPriceIfNeeded()
        XCTAssertEqual(session.unlock.displayPrice, "$4.99")

        // Buy: the sheet closes, the gate opens, the clock runs.
        await session.purchaseUnlock()
        XCTAssertTrue(session.unlock.isEntitled)
        XCTAssertFalse(session.unlock.isPresentingPaywall)
        XCTAssertTrue(session.engine.mayAdvance)
        XCTAssertEqual(session.engine.state.speed, .x1, "the clock the gate stopped runs again")
        XCTAssertTrue(defaults.bool(forKey: GameSession.entitledCacheKey), "cached for the next first frame")

        // A refund arrives through the store's updates: the gate closes.
        session.engine.setSpeed(.paused)
        store.push(false)
        await waitUntil("the refund") { !session.unlock.isEntitled }
        XCTAssertFalse(session.engine.mayAdvance)
        XCTAssertFalse(defaults.bool(forKey: GameSession.entitledCacheKey))
        XCTAssertEqual(session.engine.state.progression.chapter, 2, "nothing is deleted")
        XCTAssertTrue(session.unlock.isPresentingPaywall, "the paused, gated game asks again")

        // A purchase on another device reaches this one the same way.
        store.push(true)
        await waitUntil("the purchase elsewhere") { session.unlock.isEntitled }
        XCTAssertFalse(session.unlock.isPresentingPaywall)
        XCTAssertTrue(session.engine.mayAdvance)
    }

    func testChapterOneRunsWithoutAPurchaseAndTheGateFollowsANewGame() async {
        let store = FakeEntitlements(entitled: false)
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        defer { session.engine.shutdown() }
        session.installUnlock(source: store, defaults: defaults)
        await waitUntil("the store's answer") { session.unlock.isKnown }
        session.beginNewGame(inSlot: 0)
        session.startNewGame(
            profile: FounderProfile(name: "Ada", archetype: .hacker), companyName: "Garage Co", difficulty: .normal
        )
        XCTAssertTrue(session.engine.mayAdvance, "the garage is free")
        XCTAssertFalse(session.isCurrentGameGated)
        session.reconsiderPaywall()
        XCTAssertFalse(session.unlock.isPresentingPaywall)
        session.clockLockTapped()
        XCTAssertFalse(session.unlock.isPresentingPaywall, "nothing refuses, nothing opens")
        XCTAssertTrue(session.gates.contains { $0.id == "unlock" }, "the gate rides the engine swap")
    }

    func testRestoreAndTheFailuresAreOneLineEach() async throws {
        let (state, _) = Self.chapterTwoCompany()
        try saveIntoSlotZero(state)
        let store = FakeEntitlements(entitled: false)
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        defer { session.engine.shutdown() }
        session.installUnlock(source: store, defaults: defaults)
        await waitUntil("the store's answer") { session.unlock.isKnown }
        session.continueGame()
        session.presentPaywall()

        store.purchaseOutcome = .cancelled
        await session.purchaseUnlock()
        XCTAssertNil(session.unlock.lastStoreMessage, "backing out says nothing")
        XCTAssertTrue(session.unlock.isPresentingPaywall)

        store.purchaseOutcome = .pending
        await session.purchaseUnlock()
        XCTAssertNotNil(session.unlock.lastStoreMessage)
        XCTAssertFalse(session.unlock.isEntitled)

        store.restoreThrows = true
        let restored = await session.restorePurchases()
        XCTAssertFalse(restored)
        XCTAssertEqual(store.restoreCalls, 1)
        XCTAssertNotNil(session.unlock.lastStoreMessage)

        store.restoreThrows = false
        store.restoreAnswer = true
        let restoredNow = await session.restorePurchases()
        XCTAssertTrue(restoredNow)
        XCTAssertTrue(session.unlock.isEntitled)
        XCTAssertFalse(session.unlock.isPresentingPaywall, "restored: the sheet has done its job")
        XCTAssertTrue(session.engine.mayAdvance)
    }

    // MARK: - The review prompt

    func testReviewPromptRuleTable() {
        // The one case that asks.
        XCTAssertTrue(ReviewPromptPolicy.decide(
            askedForVersion: nil, doorAppearances: 2, currentRunEnded: true, isDaily: false, paywallShownThisSession: false
        ))
        // Already asked on this install.
        XCTAssertFalse(ReviewPromptPolicy.decide(
            askedForVersion: "0.1.0", doorAppearances: 2, currentRunEnded: true, isDaily: false, paywallShownThisSession: false
        ))
        // The launch itself, with an ended save waiting.
        XCTAssertFalse(ReviewPromptPolicy.decide(
            askedForVersion: nil, doorAppearances: 1, currentRunEnded: true, isDaily: false, paywallShownThisSession: false
        ))
        // Back from a running game.
        XCTAssertFalse(ReviewPromptPolicy.decide(
            askedForVersion: nil, doorAppearances: 2, currentRunEnded: false, isDaily: false, paywallShownThisSession: false
        ))
        // A daily's ending.
        XCTAssertFalse(ReviewPromptPolicy.decide(
            askedForVersion: nil, doorAppearances: 2, currentRunEnded: true, isDaily: true, paywallShownThisSession: false
        ))
        // The paywall was shown this session.
        XCTAssertFalse(ReviewPromptPolicy.decide(
            askedForVersion: nil, doorAppearances: 2, currentRunEnded: true, isDaily: false, paywallShownThisSession: true
        ))
    }

    func testTheTitleScreenAsksOnceAfterTheFirstBiographyAndRemembers() throws {
        var (state, _) = Self.chapterTwoCompany()
        // The engine writes endings; from outside it the way in is the save format.
        state.gameOver = try JSONDecoder().decode(
            GameOverInfo.self,
            from: Data(#"{"day":210,"reason":"Sold up.","kind":"acquired"}"#.utf8)
        )
        try saveIntoSlotZero(state)
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        defer { session.engine.shutdown() }
        XCTAssertEqual(session.currentSummary?.endingKind, .acquired)

        // Launch: the door's first appearance never asks, even with an
        // ended save waiting.
        XCTAssertFalse(ReviewPromptPolicy.titleScreenAppeared(session: session, defaults: defaults))
        XCTAssertNil(defaults.string(forKey: ReviewPromptPolicy.askedKey))

        // Read the ending, come back: ask, and remember the version.
        session.continueGame()
        session.returnToFrontDoor()
        XCTAssertTrue(ReviewPromptPolicy.titleScreenAppeared(session: session, defaults: defaults))
        XCTAssertNotNil(defaults.string(forKey: ReviewPromptPolicy.askedKey))

        // Never twice on one install.
        session.continueGame()
        session.returnToFrontDoor()
        XCTAssertFalse(ReviewPromptPolicy.titleScreenAppeared(session: session, defaults: defaults))
    }

    func testTheReviewPromptStaysQuietAfterThePaywall() throws {
        var (state, _) = Self.chapterTwoCompany()
        state.gameOver = try JSONDecoder().decode(
            GameOverInfo.self,
            from: Data(#"{"day":210,"reason":"Ran out of money.","kind":"bankruptcy"}"#.utf8)
        )
        try saveIntoSlotZero(state)
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        defer { session.engine.shutdown() }
        XCTAssertFalse(ReviewPromptPolicy.titleScreenAppeared(session: session, defaults: defaults))
        session.presentPaywall()
        session.dismissPaywall()
        session.continueGame()
        session.returnToFrontDoor()
        XCTAssertFalse(ReviewPromptPolicy.titleScreenAppeared(session: session, defaults: defaults))
        XCTAssertNil(defaults.string(forKey: ReviewPromptPolicy.askedKey))
    }
}
