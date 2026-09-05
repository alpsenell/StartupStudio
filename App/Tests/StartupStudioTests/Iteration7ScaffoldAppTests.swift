import TycoonEngine
import TycoonSave
import XCTest

@testable import StartupStudio

/// The app-side seams the iteration 7 scaffold cut: the rail's new
/// priority order, the session's gate and observer composition, the
/// title menu and the onboarding pages that stay hidden until a lane
/// turns them on, the summary's seed, and the privacy manifest.
@MainActor
final class Iteration7ScaffoldAppTests: XCTestCase {
    private final class RefusingGate: AdvanceGate {
        let id: String
        var open: Bool
        init(id: String, open: Bool) {
            self.id = id
            self.open = open
        }
        func allows(_ state: GameState) -> Bool { open }
    }

    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("I7ScaffoldApp-\(UUID().uuidString)", isDirectory: true)
    }

    func testRailPriorityOrderIsPauseTourDeferredReportEventTip() {
        let tip = CoachTip.all[0]
        let toast = Toast(id: 7, icon: "bell", message: "x", tint: .primary, severity: .info)
        let notices: [RailNotice] = [
            .tip(tip),
            .event(toast),
            .report(week: 2),
            .deferred(id: "d", title: "t", daysLeft: 3, category: nil),
            .tour(.hire),
            .pause(.gameOver(day: 1), more: 0),
        ]
        let sorted = notices.sorted { $0.priority < $1.priority }.map(\.id)
        XCTAssertEqual(sorted, ["pause", "tour-2", "deferred-d", "report-2", "toast-\(toast.id)", "tip-\(tip.id)"])
    }

    func testSessionComposesGatesAndObserversIntoTheLiveEngine() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)

        XCTAssertTrue(session.engine.mayAdvance, "no gate means the clock runs")
        // R2's ledger observer rides every engine from launch; it is the only one.
        XCTAssertEqual(Array(session.eventObservers.keys), ["legacy"])
        XCTAssertNotNil(session.engine.eventSink)

        let closed = RefusingGate(id: "unlock", open: false)
        session.installGate(closed)
        XCTAssertFalse(session.engine.mayAdvance)
        session.installGate(RefusingGate(id: "daily", open: true))
        XCTAssertFalse(session.engine.mayAdvance, "any refusing gate refuses")
        closed.open = true
        XCTAssertTrue(session.engine.mayAdvance)
        session.removeGate(id: "unlock")
        session.removeGate(id: "daily")
        XCTAssertNil(session.engine.advanceGate)

        session.observeEvents("tour") { _ in }
        XCTAssertNotNil(session.engine.eventSink)

        // The hooks follow the engine across a new game.
        session.installGate(RefusingGate(id: "unlock", open: false))
        session.startNewGame(difficulty: .normal)
        XCTAssertFalse(session.engine.mayAdvance, "a swapped-in engine keeps the gates")
        XCTAssertNotNil(session.engine.eventSink, "and the observers")
    }

    func testNewGameSeedRulesAndModeReachTheState() {
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(saveDirectory: directory, slot: 0, remembersSlot: false)
        session.beginNewGame(inSlot: 1)
        session.startNewGame(
            profile: FounderProfile(name: "Ada", archetype: .hacker),
            companyName: "Seeded", difficulty: .hard, seed: 4242,
            rules: GameRules(rivalsEnabled: false), mode: .custom
        )
        XCTAssertEqual(session.engine.state.seed, 4242)
        XCTAssertEqual(session.engine.state.mode, .custom)
        XCTAssertFalse(session.engine.state.rules.rivalsEnabled)
        XCTAssertEqual(session.engine.balance.rivals.rivalCount, 0)
        XCTAssertEqual(session.currentSlot, 1)
        XCTAssertEqual(session.currentSummary?.seed, 4242)
    }

    func testTitleMenuAndOnboardingPagesStayOffUntilALaneFlipsThem() {
        let menu = TitleMenu.make(onDaily: {}, onCustom: {}, onFromCode: {})
        XCTAssertEqual(menu.rows.count, 3)
        // R3 and R4 have landed: the daily and the two custom rows are on;
        // R6's Restore is still behind its flag.
        XCTAssertEqual(menu.enabledRows.map(\.id), [.daily, .custom, .fromCode])
        XCTAssertTrue(TitleMenu.Flags.daily && TitleMenu.Flags.custom && TitleMenu.Flags.fromCode)
        XCTAssertFalse(NewGameOptions.standard.showsCustomStep)
        XCTAssertFalse(NewGameOptions.standard.showsHeirloomsStep)
        // R2, R3 and R6 have all flipped theirs.
        XCTAssertTrue(ServiceFlags.gameCenter && ServiceFlags.cloud && ServiceFlags.restore)
    }

    func testPrivacyManifestShipsInTheBundleAndDeclaresNoTracking() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0)
    }

    func testDailyChallengeAndUnlockProductAreWiredForTheirLanes() {
        XCTAssertEqual(UnlockState.productID, "com.alpsenel.startupstudio.fullgame")
        XCTAssertEqual(GameCenterID.achievement(goalID: "g1_ship_it"), "com.alpsenel.startupstudio.goal.g1_ship_it")
        XCTAssertEqual(GameCenterID.leaderboard("daily"), "com.alpsenel.startupstudio.lb.daily")
        XCTAssertEqual(DailyChallenge.forDay(0).seed, 7_228_580_221_918_885_751)
    }
}
